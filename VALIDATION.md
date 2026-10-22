# Audit et validation — 22 octobre 2026

## Audit préalable
Dépôt cible : JulesLabrousse/inception, public, vide selon GitHub. Aucun fichier existant, instruction AGENTS.md ou historique accessible à auditer. La conversation de référence récupérée confirme les noms fixes des volumes, le template NGINX, les deux mots de passe WordPress dans `credentials`, l’idempotence et la persistance du wp-config. Le PDF exact du sujet n’était pas joint ; conformité fondée sur le protocole fourni par l’utilisateur.

## Contrôles effectués dans cette session
- Parsing Compose v2 et interpolation avec configuration et secrets locaux générés : validés sans moteur Docker.
- Syntaxe des entrypoints et healthchecks : `sh -n` ; syntaxe du test : `bash -n`.
- Setup exécuté deux fois : mêmes secrets, droits 0600, aucune valeur sensible dans les fichiers publiés.
- Inspection statique : trois builds Debian 12 slim ; un seul port publié (443) ; TLS 1.2/1.3 ; bridge explicite ; deux volumes nommés sous DATA_PATH ; secrets accordés au strict nécessaire ; exec des services.
- Makefile : recette de configuration vérifiée ; chemins de build locaux et absence des constructions interdites contrôlés.

## Limites et contrôles restant à exécuter
Docker CLI 28.3.2 et Compose 2.38.2 sont installés. L’accès au socket du moteur Docker Desktop est refusé par l’isolation de la session (`connect: operation not permitted`), y compris après autorisation ciblée. Aucun build, conteneur, handshake TLS, exécution PHP/SQL ou test de persistance réel n’a donc été exécuté ici. Aucune réussite de ces étapes n’est revendiquée.

Sur la VM Linux dédiée : exécuter `make build`, `make up`, `make test`, vérifier l’accès navigateur et le formulaire d’administration, créer un article et un upload, redémarrer la VM et confirmer leur conservation. Tester une sauvegarde/restauration. Vérifier également l’échec d’un démarrage avec secret invalide et la récupération d’une initialisation interrompue sur des volumes jetables. Les tests sont livrés, mais leurs résultats d’exécution restent à recueillir. Le test de persistance provoque un down/up temporaire et ne supprime pas les volumes.
