# Guide utilisateur

## Services et accès
NGINX reçoit les connexions sur `https://LOGIN.42.fr`, WordPress fournit le site et l’administration `/wp-admin/`, MariaDB conserve les comptes, articles et options. Aucun port 80, 9000 ou 3306 n’est publié. Faire pointer le domaine sur l’IP de la VM dans le fichier hosts de l’ordinateur client.

## Premier démarrage
1. Installer Docker Engine et Compose v2 dans la VM Linux dédiée, avec Make et Python 3. Autoriser le compte à accéder à Docker selon les règles du campus.
2. Exécuter `make setup` à la racine. Ce script ne remplace jamais une configuration ou un secret existant.
3. Modifier `srcs/.env` : login 42, domaine `LOGIN.42.fr`, `DATA_PATH=/home/LOGIN/data`, noms et emails. Le propriétaire ne doit contenir aucune variante de « admin » ; le second compte doit être distinct.
4. Créer les deux dossiers `DATA_PATH/mariadb` et `DATA_PATH/wordpress` sur l’hôte Docker. Le compte de la VM doit pouvoir créer ces dossiers ; les entrypoints adaptent ensuite les droits internes des données.
5. Lancer `make` puis `make ps`. Attendre l’état healthy des trois services.
6. Ouvrir le site et accepter le certificat autosigné de cette VM de confiance, ou importer son certificat dans son environnement de test.

## Identifiants
`srcs/.env` indique les noms des comptes. `secrets/credentials.txt` contient deux lignes : mot de passe du propriétaire WordPress, puis du compte abonné. `db_password.txt` et `db_root_password.txt` sont les mots de passe SQL ; ne pas les utiliser pour le formulaire WordPress. Lire ces fichiers localement, sans les coller dans un ticket ou un terminal partagé. Les secrets sont aléatoires en hexadécimal et ne sont pas publiés dans Git.

## Utilisation quotidienne
- `make stop` puis `make start` : suspendre/reprendre les conteneurs.
- `make down` puis `make` : recréer l’infrastructure en conservant les données.
- `make logs` : derniers journaux ; `make ps` : santé et ports.
- `make test` : contrôles d’intégration, avec arrêt/recréation temporaire des services et nettoyage des données de test.

Un redémarrage ne change ni les mots de passe existants ni le titre du site. `WP_TITLE` et les comptes servent à l’initialisation. Pour le titre d’un site installé :

```sh
docker compose --env-file srcs/.env -f srcs/docker-compose.yml exec wordpress \
  wp option update blogname 'Nouveau titre' --allow-root
```

Pour changer un mot de passe WordPress, utiliser l’administration. Une rotation SQL exige de modifier le compte MariaDB et la configuration persistante WordPress avant de remplacer les secrets de façon coordonnée. Ne pas simplement régénérer les fichiers.

## Diagnostic et protection des données
Si le site affiche 502, vérifier WordPress et les journaux NGINX. Si la base est inaccessible, vérifier d’abord MariaDB. Si le domaine ne répond pas, contrôler hosts, IP VM, port 443 et pare-feu. `make config` vérifie le Compose sans lancer les services.

Sauvegarder la base et les fichiers WordPress ensemble, avec les secrets, dans un emplacement privé. La procédure froide est décrite dans DEV_DOC.md. `make clean` conserve les volumes. Ne pas effacer les répertoires de données pour réparer une panne : restaurer une sauvegarde. `docker compose down -v` supprime les objets volumes ; avec ce stockage bind, les dossiers de données demeurent mais ne doivent jamais être considérés comme une sauvegarde.
