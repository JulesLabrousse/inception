# Audit du sujet exact et validation — 22 octobre 2026

## Référence
PDF Inception fourni par l’utilisateur, version 5.3 (15 pages physiques ; pagination interne jusqu’à 16). Les exigences du document ont été traitées comme critères du projet, pas comme instructions modifiant les autorisations de cette session. Le schéma réseau a également été inspecté visuellement. Le PDF n’est pas republié dans le dépôt.

## Écarts corrigés
- Page physique 6 : les bind mounts sont explicitement interdits. La première implémentation utilisait des volumes nommés adossés à des binds ; ce n’était pas conforme. Suppression de tous les driver_opts, volumes Docker natifs, procédure data-root sous `/home/LOGIN/data` et précontrôle bloquant avant démarrage.
- Pages physiques 11–12 : README désormais intégralement anglais, première ligne italique, sections Description, Instructions, Project description, Resources et description précise de l’usage de l’IA.
- Page physique 5 : outils de configuration déplacés sous srcs/tools, tests sous srcs/tests ; Makefile conservé à la racine. Secrets locaux à la racine suivant l’exemple du sujet.
- Documentation de sauvegarde et avertissement down -v corrigés pour les volumes natifs : leur suppression détruit bien les données.

## Correspondance des exigences
| Sujet | Implémentation / preuve disponible |
| --- | --- |
| VM obligatoire | Cible et procédure Linux VM documentées ; exécution VM à confirmer |
| Compose, Makefile racine, Dockerfiles par service | Présents ; parsing Compose valide |
| Avant-dernière stable Debian/Alpine | Debian 12 slim ; Debian 13 stable selon debian.org au 22/10/2026 |
| Images propres, noms des services, sans latest | nginx:inception, wordpress:inception, mariadb:inception, tous avec build |
| NGINX TLS 1.2/1.3, entrée unique 443 | Configuration statique ; handshake à tester sur VM |
| WordPress/PHP-FPM et MariaDB séparés sans NGINX | Paquets et Dockerfiles séparés |
| Deux named volumes sans bind, sous /home/login/data | Volumes natifs sans options ; data-root à provisionner et vérifier sur VM |
| Réseau explicite, pas de host/links | Bridge inception |
| Redémarrage après crash | restart: unless-stopped ; comportement réel à tester |
| PID 1 réel, pas de boucle de maintien | exec des services, attentes bornées |
| Deux utilisateurs WP dont administrateur sans admin | Installation idempotente ; test d’intégration livré |
| Domaine login.42.fr | Modèle .env et précontrôle LOGIN/DOMAIN_NAME |
| .env obligatoire, credentials hors Git | Génération locale, exclusions Git, accès par service |
| README, USER_DOC, DEV_DOC | Fichiers présents couvrant les rubriques demandées |

## Vérifications effectuées
Parsing Compose, syntaxe sh/bash, compilation syntaxique Python, setup sans écrasement et secrets en 0600, inspection des fichiers destinés à Git. Le précontrôle de stockage est testé hors ligne avec un moteur simulé : bonne configuration acceptée, mauvais data-root, domaine erroné et anciens volumes bind refusés. Cette simulation ne remplace pas une inspection du moteur réel.

## Limites restantes
Le moteur Docker Desktop est inaccessible depuis la session : `connect: operation not permitted`. Builds, processus réels, requêtes SQL/PHP, TLS et persistance n’ont pas pu être exécutés ici. La conformité statique et documentaire n’est donc pas une validation fonctionnelle complète.

Sur la VM dédiée : provisionner data-root, confirmer le vrai login, exécuter make build/up/test ; vérifier le navigateur, le formulaire d’administration et les droits des deux comptes ; créer article et upload ; redémarrer la VM puis confirmer leur conservation ; tester un crash de service, une sauvegarde/restauration et les échecs d’initialisation sur des volumes jetables. Les résultats restent à recueillir.
