# Guide développeur

## Préparation et structure
Le dépôt initial GitHub était vide (API contents : « This repository is empty »). Aucun historique, secret ou code existant n’a été écrasé.

`srcs/docker-compose.yml` définit trois services, leurs builds, les secrets, le bridge et les volumes ; chaque `requirements/SERVICE` possède son Dockerfile, sa configuration et ses outils. Le Makefile racine centralise les commandes. `tools/setup.py` génère les secrets privés et copie `.env.example` sans écrasement. `tests/integration.sh` s’exécute sur la VM de test.

Prérequis : VM Linux dédiée, Docker Engine, Compose v2 avec `up --wait`, Make, Python 3, curl et OpenSSL côté test. Accès réseau nécessaire pendant le build (Debian, GitHub, WordPress). `make setup`, adapter `.env`, créer `/home/LOGIN/data/{mariadb,wordpress}`, puis `make config`, `make build`, `make up`, `make test`. Pour Docker Desktop, les chemins de volumes sont interprétés sur l’hôte du moteur Linux et nécessitent un partage approprié ; préférer la VM Linux d’évaluation.

## Construction et processus
Les trois Dockerfiles partent de `debian:12-slim`. Tags locaux : `nginx:inception`, `wordpress:inception`, `mariadb:inception`. Aucun téléchargement d’image WordPress, NGINX ou MariaDB du registre. La version WordPress est téléchargée au build et contrôlée par les checksums officiels. Les sources sont copiées du build vers le volume au premier démarrage. WP-CLI est téléchargé depuis sa release versionnée sous HTTPS ; sa signature indépendante n’est pas vérifiée dans ce projet.

Après initialisation, `exec` remplace le shell par `nginx -g 'daemon off;'`, `php-fpm8.2 -F` ou `mariadbd --user=mysql --console`. Pas de superviseur, de service en arrière-plan permanent ou de commande de maintien artificiel. Les attentes d’initialisation sont bornées (60 essais), avec échec explicite. MariaDB a un processus temporaire socket-only pour l’installation, arrêté et attendu avant l’exec final ; les signaux déclenchent son nettoyage.

Les healthchecks vérifient une requête SQL authentifiée, le ping FastCGI et une route HTTPS NGINX. Le dernier teste NGINX seul : le test d’intégration complète vérifie aussi `/` et `/wp-login.php`. `depends_on: service_healthy` ordonne le démarrage, sans garantir la disponibilité permanente ; `restart: unless-stopped` redémarre un processus qui meurt, pas un service seulement unhealthy. NGINX utilise le résolveur Docker pour retrouver une nouvelle IP WordPress après recréation.

## Idempotence et état
MariaDB initialise seulement un datadir neuf, crée la base et un compte dédié limité à cette base, supprime les accès root distants et les comptes anonymes, puis fixe le mot de passe root local. `.inception-ready` n’est écrit qu’après arrêt propre de l’instance temporaire. Un datadir avec tables système mais sans marqueur est rejeté : une interruption exige une restauration ou un reset explicite d’un volume neuf, jamais un effacement automatique. L’authentification root distante n’est pas autorisée.

WordPress garde son `wp-config.php` persistant et teste `wp core is-installed`. Il ne réinstalle pas une base existante et ne réinitialise pas les mots de passe. Le second compte est créé uniquement s’il manque. Le compte administrateur n’a pas « admin » dans son login. `WP_TITLE`, les emails et secrets d’installation ne synchronisent pas des comptes existants. Changer `MYSQL_DATABASE` ne migre pas la base et ne remplace pas `wp-config.php` : une migration est manuelle. Les mots de passe générés doivent rester des chaînes hexadécimales d’au moins 32 caractères ; le fichier credentials doit avoir exactement deux lignes terminées par newline.

Le certificat autosigné est généré dans le conteneur NGINX et renouvelé si absent ou proche expiration ; une recréation peut changer son empreinte. La clé privée n’entre pas dans une image ou dans Git. En exploitation, remplacer ce mécanisme par une gestion explicite de certificats adaptée au contexte.

## Volumes, sauvegarde et restauration
Les volumes `mariadb_data` et `wordpress_data` pointent vers `${DATA_PATH}/mariadb` et `${DATA_PATH}/wordpress`. Le réseau se nomme `inception`. Les noms fixes supposent une seule instance sur cette VM. Ne pas lancer ce projet sur un moteur où ces noms sont déjà utilisés par d’autres services.

Sauvegarde froide cohérente (remplacer les chemins LOGIN et BACKUP) :

```sh
make down
sudo tar --numeric-owner -C /home/LOGIN/data -czf /CHEMIN/PRIVE/BACKUP-data.tgz mariadb wordpress
# Sauvegarder aussi srcs/.env et secrets/ dans un support privé protégé.
make up
```

Pour restaurer : arrêter les services, conserver une copie de l’état actuel, préparer des dossiers de destination vides, extraire l’archive avec les propriétaires et permissions d’origine, remettre la configuration et les secrets correspondants, puis `make up` et `make test`. Ne jamais écraser à chaud un datadir MariaDB. Une mise à niveau de version MariaDB exige une procédure compatible et un test de restauration.

`make down` enlève conteneurs et réseau sans supprimer les données. `make clean` a volontairement le même effet. Aucun objectif Make ne supprime automatiquement les dossiers. Pour repartir de zéro sur une VM jetable, sauvegarder puis supprimer explicitement les deux dossiers et les objets volumes, recréer les dossiers et relancer ; cette opération détruit articles, utilisateurs et uploads.

## Modifier et vérifier
Pour changer la limite NGINX, éditer `srcs/requirements/nginx/conf/inception.conf.template`, puis :

```sh
docker compose --env-file srcs/.env -f srcs/docker-compose.yml build nginx
docker compose --env-file srcs/.env -f srcs/docker-compose.yml up -d --no-deps nginx
docker compose --env-file srcs/.env -f srcs/docker-compose.yml exec nginx nginx -T
```

NGINX ne change pas les limites PHP ; adapter aussi `uploads.ini` si nécessaire. Inspecter la configuration PHP avec `php-fpm8.2 -tt`, le réseau avec `docker network inspect inception`, les volumes avec `docker volume inspect mariadb_data wordpress_data`, le PID 1 avec `docker compose ... exec SERVICE cat /proc/1/comm`. Utiliser les options Compose du Makefile pour toutes ces commandes.

Avant publication : `git ls-files secrets srcs/.env`, `git check-ignore secrets/db_password.txt`, recherche de credentials dans les fichiers suivis et dans `git log -p --all`. Une fois le dépôt utilisé, vérifier aussi l’historique complet avec un scanner de secrets. Les fichiers d’exemple ne contiennent aucun mot de passe.
