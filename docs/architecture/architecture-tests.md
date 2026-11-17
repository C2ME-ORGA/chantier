# Tests d’architecture

Cette suite vérifie les invariants structurels du Modular Monolith. Elle est distincte des tests Unit, Feature et MariaDB : elle contrôle les dépendances et l’organisation du code, sans démarrer une base de données ni créer de classes métier fictives.

## Emplacement et exécution

- Fichiers : `tests/Architecture/*Test.php`.
- Suite PHPUnit : `Architecture`, déclarée dans `phpunit.xml`.
- Exécution ciblée : `php artisan test --testsuite=Architecture`.
- Exécution d’un fichier : `php artisan test tests/Architecture/ArchitectureSuiteTest.php`.
- Exécution globale : `composer ci:check --no-interaction`.

Les tests de cette suite restent indépendants de la base de données. Ils peuvent utiliser le système de fichiers et analyser le code source. Ils ne doivent pas modifier les répertoires applicatifs pendant l’exécution.

## Principes de conception

1. Tester les règles d’architecture à partir du code réellement présent ; ne pas supposer qu’un domaine vide contient déjà des composants.
2. Une absence de violation doit être démontrée par une analyse effective, pas par un scan qui ignore silencieusement les fichiers ou les répertoires.
3. Garder les règles explicites, déterministes et ciblées ; les exceptions doivent être rares, motivées et documentées.
4. Isoler les cas négatifs dans des fixtures temporaires hors de `app/`, puis nettoyer ces fixtures même en cas d’échec.
5. Ne pas ajouter de contrats, événements, modèles ou classes applicatives fictifs pour satisfaire les tests.
6. Ne pas confondre dépendance PHP statique et interaction métier : SQL direct, résolution dynamique, conteneur Laravel et transactions inter-domaines nécessitent des contrôles complémentaires.
7. Ne pas utiliser une liste blanche générale par domaine. Les surfaces publiques autorisées doivent suivre les conventions validées de CHAN-28.

## Périmètre progressif

Les règles sont introduites progressivement dans CHAN-31 : frontières Core/Domains, imports inter-domaines, cohérence PSR-4, puis cas de violation et limites de détection. Le présent socle ne prétend pas encore vérifier ces règles ; il garantit que la suite dédiée est découverte et que ses racines applicatives existent.

## Dépendances

Aucune nouvelle dépendance n’est ajoutée dans ce lot. Les outils déjà présents dans le verrou Composer pourront être utilisés après vérification de leur API et de leur adéquation aux règles à tester.
