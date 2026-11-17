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

Les règles sont introduites progressivement dans CHAN-31 : frontières Core/Domains, imports inter-domaines, cohérence PSR-4, puis cas de violation et limites de détection.

## Dépendances

Aucune nouvelle dépendance n’est ajoutée dans ces lots. Les règles de dépendances reposent sur Pest Arch déjà disponible dans l’environnement verrouillé du projet.

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

## Lot D — preuves par fixtures négatives isolées

Le fichier `DomainDependencyRulesFixturesTest.php` construit des sources PHP temporaires hors de `app/` et applique les mêmes attentes Pest Arch que le lot C.

Les scénarios couvrent :
- une dépendance `App\Core` → `App\Domains` qui doit être rejetée ;
- une dépendance d'un domaine vers une implémentation interne d'un autre domaine qui doit être rejetée ;
- une dépendance vers une surface publique `Contracts` qui doit rester acceptée.

Chaque jeu de fixtures est créé dans un répertoire temporaire unique et supprimé dans un bloc `finally`, y compris lorsque l'assertion échoue. Aucune classe métier factice n'est ajoutée au code applicatif.

### Alerte de vigilance — couverture réelle du dépôt

**Au moment de l'introduction des lots C/D, `app/Core/` et les 18 répertoires `app/Domains/*` ne contiennent pas encore d'implémentations métier (hors README et fichiers de maintien de répertoire).** Les règles de production peuvent donc réussir sans rencontrer de dépendance métier interdite réelle.

Les fixtures du lot D prouvent que le moteur Pest Arch détecte les cas contrôlés et que les exceptions publiques ne sont pas rejetées. Elles ne prouvent pas que toutes les violations possibles des futures implémentations seront détectées, ni que les frontières sont respectées par du code métier inexistant. Le résultat CI doit être interprété comme une validation du mécanisme, pas comme une certification de l'architecture métier.

Lorsque les premiers composants réels seront ajoutés, il faudra recontrôler les dépendances effectives et compléter la couverture par les règles PSR-4, la détection des cycles et des contrôles ciblés sur les accès indirects.

### Portée et limites

Ces contrôles s'appuient sur l'analyse statique des dépendances PHP effectuée par Pest Arch. Ils détectent les références de classes analysables (imports et usages PHP résolus par l'outil), mais ne prouvent pas à eux seuls l'absence :
- de requêtes SQL directes vers les tables d'un autre domaine ;
- de résolution dynamique de classes ou de services ;
- de contournement via le conteneur Laravel, la configuration ou des chaînes de classes ;
- de transactions inter-domaines implicites ;
- d'une violation sémantique du contrat public.

Ces cas nécessitent des contrôles ciblés complémentaires et une revue du code.
