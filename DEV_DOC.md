# Guide développeur

## Préparation et structure
Le dépôt initial GitHub était vide. Le sujet exact fourni ensuite est Inception v5.3. Toutes les configurations et tous les outils sont sous `srcs/` ; Makefile et documents sont à la racine. `secrets/` est local et ignoré, conformément à l’exemple du sujet.

Prérequis : VM Linux dédiée, Docker Engine rootful, Compose v2 avec `up --wait`, Make, Python 3, curl et OpenSSL. Réseau nécessaire pour les paquets Debian, GitHub et WordPress pendant le build et pour la génération des salts WordPress au premier démarrage. Docker Desktop n’est pas la cible de validation du sujet.

Exécuter `make setup`, adapter `srcs/.env` (login 42 réel, domaine `LOGIN.42.fr`, `DATA_PATH=/home/LOGIN/data`, noms et emails), puis préparer le moteur ci-dessous. Ne pas changer les secrets après initialisation sans rotation coordonnée des comptes.

## Stockage obligatoire sans bind mounts
Le sujet interdit les bind mounts pour les deux stockages persistants. Les anciennes options `type: none`, `o: bind`, `device:` ont été supprimées. Les volumes `mariadb_data` et `wordpress_data` sont des volumes natifs du driver local, sans options.

Pour les placer sous `/home/LOGIN/data`, configurer le `data-root` de Docker Engine sur ce chemin. Cette configuration concerne tout le moteur : utiliser une VM dédiée, fraîche, avant son premier lancement du projet. Si le moteur contient déjà des données, sauvegarder celles-ci et organiser leur migration avant de changer sa configuration ; changer le chemin ne migre rien automatiquement.

Sur une VM fraîche, remplacer LOGIN par le login réel :

```sh
sudo systemctl stop docker.service docker.socket
sudo mkdir -p /etc/docker /home/LOGIN/data
# Si daemon.json existe, le sauvegarder puis conserver ses autres paramètres.
sudoedit /etc/docker/daemon.json
```

Ajouter la propriété suivante à l’objet JSON (ne pas écraser d’autres réglages existants) :

```json
{
  "data-root": "/home/LOGIN/data"
}
```

Puis :

```sh
sudo dockerd --validate --config-file=/etc/docker/daemon.json
sudo systemctl start docker.service
docker info --format '{{.DockerRootDir}}'
make config
make build
make up
make test
```

Le chemin retourné doit être `/home/LOGIN/data`. Les contenus seront sous :

```text
/home/LOGIN/data/volumes/mariadb_data/_data
/home/LOGIN/data/volumes/wordpress_data/_data
```

`srcs/tools/check_storage.py`, appelé avant build/up et dans les tests, refuse un mauvais data-root, un domaine différent de LOGIN.42.fr, ou des volumes existants avec options bind. Il ne modifie pas le moteur. `srcs/.env` décrit le chemin attendu ; seul le fichier daemon.json configure effectivement le stockage Docker. Les volumes ne doivent pas être utilisés par un autre projet sur ce moteur.

Si l’ancienne version du projet a déjà tourné : arrêter les services, sauvegarder la base et les fichiers à froid, conserver les secrets et wp-config, puis migrer dans des volumes natifs neufs sur le moteur correctement configuré. Les objets volumes existants conservent leurs options : changer Compose ne les transforme pas. Ne supprimer les anciens objets et dossiers qu’après vérification de la sauvegarde et de la restauration. Ne jamais effacer les données automatiquement pour faire passer le contrôle.

## Construction et processus
Chaque service construit son propre Dockerfile depuis `debian:12-slim`. Tags : `nginx:inception`, `wordpress:inception`, `mariadb:inception`. Aucune image applicative n’est téléchargée. Debian 12 est l’avant-dernière version stable majeure à la date de l’audit, Debian 13 étant stable. WordPress est téléchargé au build en version 7.1.3 avec contrôle des checksums officiels. WP-CLI 2.12.0 vient de sa release HTTPS versionnée ; sa signature indépendante n’est pas vérifiée.

Les entrypoints terminent par `exec` : NGINX au premier plan, PHP-FPM avec `-F`, MariaDB avec `--console`. Attentes bornées et échec explicite ; aucun maintien artificiel. MariaDB utilise temporairement une instance socket-only pour initialiser le datadir ; son arrêt est attendu avant l’exec et les signaux déclenchent son nettoyage.

Les healthchecks testent une requête SQL authentifiée, le ping FastCGI et NGINX en HTTPS. Le test d’intégration vérifie aussi le site WordPress. `depends_on: service_healthy` ordonne le démarrage ; `restart: unless-stopped` redémarre les processus morts, sans soigner un service seulement unhealthy. NGINX résout de nouveau l’IP de WordPress via le DNS Docker après recréation.

## Idempotence et secrets
MariaDB initialise seulement un datadir neuf : base dédiée, compte limité à cette base, root local avec mot de passe, suppression des comptes anonymes et root distants. `.inception-ready` n’est écrit qu’après arrêt propre. Des tables système sans marqueur sont traitées comme une initialisation interrompue ou un datadir étranger : restaurer ou réinitialiser explicitement un volume jetable, jamais effacer automatiquement.

WordPress garde son `wp-config.php` et teste `wp core is-installed`. Il ne remplace pas une installation ni ses mots de passe. Le second utilisateur abonné est créé seulement s’il manque. Le login propriétaire ne contient pas « admin ». Les secrets générés sont des chaînes hexadécimales d’au moins 32 caractères ; `credentials.txt` contient exactement deux lignes terminées par newline, propriétaire puis abonné.

`WP_TITLE`, les emails et les mots de passe initiaux ne synchronisent pas le site existant. Changer MYSQL_DATABASE ne migre rien et ne remplace pas le wp-config persistant. Toute rotation SQL exige de modifier le compte SQL, le wp-config et les secrets de façon cohérente. WordPress ne reçoit pas le secret root.

Le certificat autosigné est généré localement au conteneur et renouvelé si absent ou proche expiration. Une recréation NGINX peut changer son empreinte. La clé n’est jamais embarquée dans une image ou publiée dans Git.

## Gestion, sauvegarde et restauration
`make ps`, `make logs`, `make stop`, `make start`, `make down` et `make up` gèrent le cycle de vie. `make clean` conserve les volumes comme `down`. `docker compose down -v` détruit les volumes natifs et leur contenu : aucune cible Make ne le fait.

Contrôles :

```sh
docker volume inspect mariadb_data wordpress_data
docker network inspect inception
docker compose --env-file srcs/.env -f srcs/docker-compose.yml exec nginx nginx -t
docker compose --env-file srcs/.env -f srcs/docker-compose.yml exec wordpress php-fpm8.2 -tt
docker compose --env-file srcs/.env -f srcs/docker-compose.yml exec mariadb cat /proc/1/comm
```

Sauvegarde froide cohérente sur le moteur configuré, après vérification des Mountpoint :

```sh
make down
sudo tar --numeric-owner -C /home/LOGIN/data/volumes \
  -czf /CHEMIN/PRIVE/BACKUP-data.tgz mariadb_data/_data wordpress_data/_data
# Sauvegarder aussi srcs/.env et secrets/ sur un support privé protégé.
make up
```

Restauration : arrêter la stack, conserver une sauvegarde de son état actuel, préparer un moteur au bon data-root et des volumes natifs vides (`docker volume create mariadb_data`, puis `docker volume create wordpress_data`). Vérifier leurs Mountpoint ; extraire l’archive dans `/home/LOGIN/data/volumes` avec les propriétaires et permissions d’origine. Remettre la configuration et les secrets correspondants, puis `make up` et `make test`. Ne pas restaurer à chaud ni écraser des volumes non vides. Une mise à niveau MariaDB exige une procédure de migration compatible et un test de restauration.

## Modification en direct et validation
Pour changer la limite d’upload, modifier `srcs/requirements/nginx/conf/inception.conf.template`, reconstruire seulement NGINX et vérifier sa configuration :

```sh
docker compose --env-file srcs/.env -f srcs/docker-compose.yml build nginx
docker compose --env-file srcs/.env -f srcs/docker-compose.yml up -d --no-deps nginx
docker compose --env-file srcs/.env -f srcs/docker-compose.yml exec nginx nginx -T
```

Les limites PHP sont distinctes, dans `uploads.ini`. `srcs/tests/integration.sh` vérifie TLS, comptes, PID 1, ports, secrets et persistance après down/up. Il provoque une interruption temporaire. Exécuter aussi les contrôles manuels de VALIDATION.md.

Avant publication : vérifier `git ls-files secrets srcs/.env`, les exclusions Git, les fichiers suivis et `git log -p --all`, éventuellement avec un scanner de secrets. Ne jamais publier les fichiers locaux de mots de passe.
