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
4. N’ajouter des tests négatifs de dépendances que lorsqu’ils peuvent s’appuyer sur des composants réels ou sur un mécanisme de fixture fiable, vérifié indépendamment.
5. Ne pas ajouter de contrats, événements, modèles ou classes applicatives fictifs pour satisfaire les tests.
6. Ne pas confondre dépendance PHP statique et interaction métier : SQL direct, résolution dynamique, conteneur Laravel et transactions inter-domaines nécessitent des contrôles complémentaires.
7. Ne pas utiliser une liste blanche générale par domaine. Les surfaces publiques autorisées doivent suivre les conventions validées de CHAN-28.

## Périmètre progressif

Les règles sont introduites progressivement dans CHAN-31 : frontières Core/Domains, imports inter-domaines, cohérence PSR-4, puis cas de violation et limites de détection.

## Dépendances

Aucune nouvelle dépendance n’est ajoutée dans ces lots. Les règles de dépendances reposent sur Pest Arch déjà disponible dans l’environnement verrouillé du projet. Les contrôles PSR-4 et de cycles réutilisent `nikic/php-parser`, déjà présent dans le verrou Composer via l’outillage de tests et d’analyse statique ; aucune entrée Composer n’est ajoutée.

## Règles de frontières automatisées — CHAN-31 Lot C

La suite `DomainDependencyRulesTest.php` applique les règles statiques suivantes à partir des namespaces PSR-4 de l'application :

1. **Core → Domains interdit** : aucun composant sous `App\Core` ne peut dépendre d'un composant sous `App\Domains`.
2. **Domaine → domaine via surface publique uniquement** : un domaine consommateur ne peut importer chez un autre domaine que les namespaces publics définis par CHAN-28 :
   - `App\Domains\{Provider}\Contracts\...`
   - `App\Domains\{Provider}\Events\Integration\...`
3. **Dépendances internes interdites** : les Models, Actions, Services, DTO internes, Policies et événements locaux restent privés à leur domaine. La règle générale bloque aussi tout autre namespace fournisseur hors des deux surfaces publiques.

Les 18 domaines sont énumérés explicitement dans le test. Toute évolution de cette liste doit être accompagnée d'une décision d'architecture et d'une mise à jour du test.

### Articulation avec CHAN-29

L'autorisation syntaxique d'importer une surface publique CHAN-28 ne classe pas automatiquement une relation métier comme autorisée au sens de CHAN-29. Les 130 interactions recensées dans la matrice Lot C restent « À qualifier » tant qu'une décision technique traçable ne confirme pas le consommateur, le fournisseur, la capacité et les conditions. Ces tests contrôlent la frontière de code, pas l'existence ni la légitimité métier de chaque relation.

## Tests négatifs sur fixtures isolées — CHAN-31 Lot 2

Le fichier `DomainDependencyRulesFixturesTest.php` démontre que les règles du lot C rejettent réellement les violations et acceptent les surfaces publiques CHAN-28. Il ne se contente pas de rechercher des chaînes dans les sources : il exécute la règle Pest Arch elle-même sur une arborescence PHP temporaire.

### Mécanisme

1. Une arborescence temporaire est créée hors de `app/`, dans le répertoire temporaire système.
2. Les fixtures utilisent un namespace PSR-4 unique et un autoloader dédié, enregistré uniquement pour la durée du test.
3. Le dépôt d’objets interne de Pest Arch est temporairement remplacé par un dépôt limité à la racine de la fixture.
4. La règle réelle `expect(...)->not->toUse(...)->ignoring([...])` est évaluée, puis le dépôt précédent est restauré.
5. Le namespace, l’autoloader et le répertoire sont nettoyés dans un bloc `finally`, y compris lorsque l’assertion échoue.

### Scénarios couverts

| Scénario | Résultat attendu |
| --- | --- |
| `App\Core` importe un Model d’un domaine | Violation détectée, message nommant le namespace fournisseur. |
| Un domaine importe le Model interne d’un autre domaine | Violation détectée malgré l’autorisation de `Contracts` et `Events\Integration`. |
| Un domaine importe `App\Domains\{Provider}\Contracts\...` | Règle satisfaite. Le test vérifie d’abord que la même fixture est rejetée sans l’exception, afin de prouver que la dépendance est réellement analysée. |
| Un domaine importe `App\Domains\{Provider}\Events\Integration\...` | Règle satisfaite, avec le même contrôle préalable. |

La règle testée reste celle du fichier `DomainDependencyRulesTest.php`. Les fixtures ne créent aucun composant dans `app/Core` ou `app/Domains`.

### Limites

Les tests sur fixtures prouvent le comportement du moteur de règles, mais ne certifient pas la conformité de futurs composants métier qui n’existent pas encore. Ils ne détectent pas non plus les accès SQL directs, les résolutions par le conteneur, les noms de classes construits dynamiquement ou les transactions inter-domaines implicites.

**Exécution :** `php artisan test tests/Architecture/DomainDependencyRulesFixturesTest.php`. Environnement local PHP 8.4 et Composer ; aucune base de données ; Docker non nécessaire.

## Contrôle PSR-4 — CHAN-31 Lot 2

### Règle vérifiée

Sous `app/Core` et `app/Domains`, chaque fichier PHP contenant une déclaration nommée doit contenir exactement une classe, interface, trait ou enum, et son nom qualifié complet doit correspondre au chemin PSR-4 `App\` → `app/`.

### Mécanisme

`PhpArchitectureAnalyzer::psr4Violations()` parcourt les fichiers `.php` de façon récursive et triée. `PhpFileInspector` analyse chaque source avec `nikic/php-parser` sans charger la classe. Il collecte toutes les déclarations nommées, y compris dans un fichier qui en contient plusieurs. Une erreur de parsing est restituée avec le fichier concerné au lieu d’être ignorée.

Le contrôle :

- ignore les fichiers non PHP ;
- ignore les fichiers PHP sans déclaration nommée (fonctions, classes anonymes) ;
- accepte un répertoire vide ou absent sans erreur ;
- signale le fichier, la déclaration trouvée et le nom attendu ;
- produit des violations triées de façon déterministe.

### Cas couverts

Les tests `Psr4ComplianceTest.php` couvrent les classes, interfaces, traits et enums valides, un namespace incorrect, un nom de classe incorrect, un fichier à plusieurs déclarations, les fichiers non PHP, les répertoires vides, une erreur de parsing et la stabilité de l’ordre des violations.

### Limites

Le contrôle valide la convention de chemin et de namespace, pas la configuration Composer elle-même. Il ne vérifie pas la présence de la classe dans l’autoloader optimisé et n’impose pas de règle aux fichiers PHP qui ne déclarent aucun type nommé.

**Exécution :** `php artisan test tests/Architecture/Psr4ComplianceTest.php`. Environnement local PHP 8.4 et Composer ; aucune base de données ; Docker non nécessaire.

## Détection des cycles PHP — CHAN-31 Lot 2

### Règle vérifiée

Le graphe orienté des dépendances statiques entre les classes déclarées sous `app/Core` et `app/Domains` ne doit contenir aucun cycle. Chaque cycle détecté est restitué sous la forme d’un chemin explicite `A -> B -> A`.

### Mécanisme

`PhpArchitectureAnalyzer::dependencyGraph()` construit le graphe à partir des références de classes observables dans l’AST :

- imports `use` de classes, y compris groupés et aliasés ;
- extends, implements et usage de traits ;
- types de propriétés, paramètres, retours et types de catch ;
- instanciations, appels statiques, constantes de classe, `instanceof` et attributs ;
- références pleinement qualifiées sans instruction `use`.

Les noms sont résolus par `NameResolver`. Seules les références vers une classe déclarée dans les racines analysées sont conservées. Les arêtes et les classes sont triées ; les cycles sont normalisés et dédupliqués avant restitution. Une erreur de parsing est exposée dans la liste `errors` et fait échouer le contrôle applicatif.

### Cas couverts

`ImportCycleTest.php` couvre l’absence de cycle dans les racines réelles, un cycle à deux classes, un cycle à trois classes, plusieurs cycles distincts, un graphe acyclique, des références pleinement qualifiées sans `use`, des répertoires vides et une erreur de parsing.

### Limites

Le graphe ne représente que les dépendances statiques de classes. Il ne détecte pas :

- les noms de classes construits dynamiquement ou stockés dans des chaînes ;
- les résolutions par le conteneur Laravel (`app()`, `resolve()`, bindings, providers) ;
- les accès SQL directs aux tables d’un autre domaine ;
- les appels indirects via configuration, files d’attente, événements ou dispatch dynamique ;
- les types déclarés uniquement en PHPDoc ;
- les dépendances métier sans référence PHP, qui relèvent de CHAN-29.

Un cycle absent du graphe PHP n’est donc pas une preuve d’absence de couplage métier. Ces contrôles complètent la revue d’architecture, ils ne la remplacent pas.

**Exécution :** `php artisan test tests/Architecture/ImportCycleTest.php`. Environnement local PHP 8.4 et Composer ; aucune base de données ; Docker non nécessaire.

## Exécution, environnement et Docker

Les contrôles de cette suite sont autonomes et n’utilisent aucune base de données. Ils s’exécutent avec l’environnement local dès que PHP, Composer et les dépendances verrouillées sont disponibles :

```bash
php artisan test --testsuite=Architecture
php artisan test
composer lint:check
composer types:check
git diff --check
```

Docker n’est pas nécessaire pour ces contrôles : ils ne requièrent ni service externe, ni moteur de base de données, ni version PHP différente de celle du projet. Les résultats locaux ne constituent pas une validation de la CI GitHub, qui reste vérifiée séparément.

## État de couverture

À ce stade, `app/Core/` et les répertoires `app/Domains/*` ne contiennent pas encore de systèmes métier. Les règles du lot C et les nouveaux contrôles définissent et vérifient les frontières attendues sur le code présent et sur des fixtures isolées. Ils ne constituent pas une preuve de conformité de dépendances métier réelles tant que ces composants n’existent pas.

> **Avertissement.** Les tests sur fixtures prouvent le comportement du moteur de règles, mais ne certifient pas la conformité de futurs composants métier qui n’existent pas encore.

### Portée et limites

Ces contrôles s'appuient sur l'analyse statique des dépendances PHP effectuée par Pest Arch et par `nikic/php-parser`. Ils détectent les références de classes analysables, mais ne prouvent pas à eux seuls l'absence :
- de requêtes SQL directes vers les tables d'un autre domaine ;
- de résolution dynamique de classes ou de services ;
- de contournement via le conteneur Laravel, la configuration ou des chaînes de classes ;
- de transactions inter-domaines implicites ;
- d'une violation sémantique du contrat public.

Ces cas nécessitent des contrôles ciblés complémentaires et une revue du code.
