*This project has been created as part of the 42 curriculum by jlabrous.*

# Inception

## Description
Infrastructure mandatory : NGINX expose exclusivement HTTPS sur 443 (TLS 1.2/1.3), transmet le PHP à WordPress/PHP-FPM sur 9000, qui utilise MariaDB sur 3306. Les trois images sont construites depuis `debian:12-slim` ; aucune image applicative prête à l’emploi. Pas de bonus.

```text
Navigateur → 443/TLS → NGINX → 9000/FastCGI → PHP-FPM/WordPress → 3306/SQL → MariaDB
                       │                        │                         │
                       └── wordpress_data (ro) ─┘                  mariadb_data
```

## Instructions
Sur une VM Linux dédiée avec Docker Engine, Compose v2, Make et Python 3 :

```sh
make setup
# Adapter srcs/.env : login 42 réel, domaine, comptes et DATA_PATH.
# Créer les dossiers avec le compte utilisateur de la VM :
mkdir -p /home/LOGIN/data/mariadb /home/LOGIN/data/wordpress
# Ajouter IP_VM LOGIN.42.fr au fichier hosts du poste client.
make config
make
make test
```

Remplacer LOGIN par son login réel. Le login `jlabrous` du modèle est une valeur à confirmer avant évaluation. Les mots de passe aléatoires restent dans `secrets/`, ignorés par Git. Accès : `https://LOGIN.42.fr` et `/wp-admin/`. Le certificat autosigné déclenche un avertissement normal du navigateur. Consulter [USER_DOC.md](USER_DOC.md) et [DEV_DOC.md](DEV_DOC.md).

## Choix techniques et comparaisons
- **VM / Docker** : la VM fournit son propre noyau et l’hôte d’évaluation ; les conteneurs isolent les processus en partageant le noyau Linux de cette VM. Docker Desktop sur Mac utilise aussi une VM, mais la validation finale visée reste la VM Linux demandée.
- **Secrets / environnement** : `.env` contient les noms et paramètres non sensibles. Compose monte les secrets sous `/run/secrets` uniquement dans les services autorisés. Ce sont des fichiers locaux, pas un coffre chiffré ; protéger et sauvegarder l’hôte.
- **Réseau Docker / host** : un bridge explicite fournit l’isolation et le DNS des services ; host partagerait le réseau de l’hôte et n’est pas utilisé.
- **Volumes Docker / bind mounts** : deux named volumes utilisent le driver local et des dossiers sous `/home/LOGIN/data`. Ils restent des objets Docker nommés, avec un stockage physique fixé par `driver_opts`. Les bind mounts directs dans les services ne sont pas utilisés.

Debian 12 slim est fixé selon le protocole demandé. NGINX, MariaDB et PHP 8.2 viennent des paquets Debian ; WordPress **7.1.3** et WP-CLI **2.12.0** sont explicitement versionnés. Les paquets Debian suivent leurs mises à jour de sécurité au rebuild : les builds ne sont donc pas reproductibles octet pour octet. Ne pas changer de base pour suivre une nouvelle distribution sans vérifier le sujet de son campus.

## Ressources et usage de l’IA
- [Docker Compose : secrets](https://docs.docker.com/compose/how-tos/use-secrets/)
- [Docker Compose : services](https://docs.docker.com/reference/compose-file/services/)
- [NGINX : HTTPS](https://nginx.org/en/docs/http/configuring_https_servers.html)
- [WP-CLI : installation](https://developer.wordpress.org/cli/commands/core/install/)
- [MariaDB : initialisation](https://mariadb.com/docs/server/clients-and-utilities/deployment-tools/mariadb-install-db)
- [Archives WordPress](https://en-gb.wordpress.org/download/releases/)

L’IA (Codex) a été utilisée pour l’audit du dépôt vide, l’écriture des Dockerfiles, du Compose, des scripts, des tests et de la documentation, ainsi que les vérifications statiques. L’étudiant doit lire et comprendre chaque fichier et effectuer les tests sur sa VM. Le PDF exact du sujet et la grille du campus n’étaient pas accessibles dans la référence : les exigences fournies ont été suivies, sans prétendre à une conformité formelle à une version inconnue. Voir [VALIDATION.md](VALIDATION.md) pour les limites constatées.
