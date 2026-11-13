# AGENTS.md — C2ME Chantier

## Objectif

Construire une application de gestion de chantiers pour SARL C2ME. Toute modification doit préserver la cohérence métier, la sécurité des données et la maintenabilité.

## Stack de référence

- PHP 8.4
- Laravel 13
- Livewire 4
- Filament 5
- Bootstrap 5 et Vite
- MySQL / MariaDB
- Redis lorsque nécessaire
- Pest, Laravel Pint et Larastan

Ne pas supposer qu'une dépendance est installée : vérifier `composer.json`, `package.json` et le code existant avant de l'utiliser. Ne pas inventer d'API de framework ou de package ; consulter les sources et versions réellement installées.

## Architecture

- Architecture cible : Modular Monolith.
- Les domaines métier sont isolés dans `modules/`.
- Les dépendances entre modules doivent être explicites et orientées vers des contrats stables.
- Éviter les dépendances circulaires et les accès directs aux tables d'un autre domaine.
- Le code transversal doit rester limité et justifié.
- Ne pas introduire de microservices sans décision d'architecture documentée.

## Règles PHP / Laravel

- Respecter les conventions Laravel et le style validé par Laravel Pint.
- Utiliser les Form Requests, Policies, Gates et validations serveur adaptés au contexte.
- Préférer les transactions pour les opérations métier multi-écritures.
- Les opérations financières et les changements d'état sensibles doivent être validés côté serveur.
- Les migrations doivent être sûres, réversibles lorsque possible et compatibles avec une livraison progressive.
- Ne jamais exposer de données sensibles dans les logs, réponses ou exceptions.

## Sécurité

- Appliquer le principe du moindre privilège.
- Vérifier l'autorisation côté serveur pour chaque action sensible.
- Ne jamais faire confiance aux données provenant du navigateur, y compris en mode offline.
- Protéger les fichiers privés par une autorisation explicite.
- Ne jamais committer de secrets, tokens, mots de passe ou données personnelles réelles.

## Frontend

- Utiliser Vite pour les assets.
- Bootstrap 5 est le socle CSS cible.
- Éviter d'ajouter un second framework CSS ou JavaScript sans décision documentée.
- Préserver l'accessibilité, la validation et les états de chargement/erreur.
- Ne pas introduire de JavaScript inline inutile ; privilégier des modules dédiés.

## Tests et qualité

- Écrire des tests Pest pour les comportements métier et les régressions.
- Tester les autorisations, validations, cas limites et échecs.
- Exécuter Pint, les tests, Larastan et le build frontend lorsqu'ils sont disponibles.
- Ne pas déclarer un contrôle réussi s'il n'a pas été exécuté.
- Une CI verte est un prérequis à la fusion.

## Données et mode hors connexion

- Toute synchronisation offline doit être idempotente et traçable.
- Utiliser des identifiants d'opération uniques et une stratégie explicite de résolution des conflits.
- Ne pas utiliser un mécanisme générique « last-write-wins » pour les données financières ou les validations métier.
- Le serveur reste l'autorité pour les calculs, droits et transitions d'état.

## Git et tickets

La référence détaillée pour Git est [`docs/development/git-workflow.md`](docs/development/git-workflow.md). Celle pour les versions et les releases est [`docs/development/release-process.md`](docs/development/release-process.md). Celle pour les environnements est [`docs/development/environments.md`](docs/development/environments.md) et celle pour les déploiements est [`docs/development/deployment-process.md`](docs/development/deployment-process.md). Les règles ci-dessous sont impératives.

- Ne jamais pousser directement sur `main` ou `develop` : toute modification passe par une Pull Request.
- Créer `feature/CHAN-123-description` et `bugfix/CHAN-123-description` depuis `develop`, et `hotfix/CHAN-123-description` depuis `main`.
- Utiliser un préfixe et une clé Jira obligatoires, avec une description courte en minuscules séparée par des tirets.
- Respecter les Conventional Commits : `type(scope): description`, avec un scope obligatoire et un type parmi `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `build`, `ci` et `perf`.
- Ouvrir une Pull Request vers la branche cible avec la référence Jira, le résumé des changements, les tests et contrôles effectués.
- Ne fusionner qu'après le succès du contrôle GitHub Actions `ci`, sans contourner les protections ni les contrôles.
- Supprimer la branche temporaire après fusion. Après un hotfix, synchroniser `develop` depuis `main` via une Pull Request.
- Ne pas utiliser de force-push et ne pas supprimer `main` ou `develop`.
- Ne pas modifier le périmètre d'un ticket sans le signaler.
- Respecter le processus de versionnement et de release documenté dans [`docs/development/release-process.md`](docs/development/release-process.md).
- Ne jamais déplacer, réutiliser ou supprimer un tag de release publié.
- Les environnements `staging` et `production` et leurs protections sont définis dans [`docs/development/environments.md`](docs/development/environments.md) (CHAN-96). Ne jamais partager de secret, de fichier `.env`, de base de données, de stockage ou d'accès SQL entre ces environnements.
- Les déploiements sont automatisés par les workflows `deploy-staging` et `deploy-production` décrits dans [`docs/development/deployment-process.md`](docs/development/deployment-process.md) (CHAN-97). Ne jamais déployer manuellement, ne jamais reconstruire un paquet en production, ne jamais déplacer un artefact et ne jamais exécuter de commande sur le serveur hors de la procédure documentée. Un paquet de déploiement ne doit contenir ni lien symbolique, ni lien physique, ni chemin hors de la release ; le binaire PHP doit être vérifié en 8.4 avant toute commande Artisan. Le fichier `shared/.env` ne doit jamais être accessible en écriture au groupe ou aux autres utilisateurs. Les migrations, la recette détaillée et le rollback relèvent de CHAN-98.
- Ne jamais affirmer qu'une tâche, un test, un déploiement ou une revue a été réalisé sans preuve.

## Méthode de travail

1. Examiner le code et la documentation existants.
2. Identifier le ticket et les critères d'acceptation.
3. Proposer une modification minimale et cohérente.
4. Ajouter ou adapter les tests.
5. Exécuter les contrôles pertinents.
6. Résumer les fichiers modifiés, les résultats et les limites restantes.
