# Conventions internes des domaines métier

Ce document définit les conventions internes applicables au code métier de **C2ME Chantier**.

- Ticket : CHAN-27 — Définir les conventions internes Model / Actions / Services / DTO / Events / Policies.
- Ticket parent : CHAN-10 — Mettre en place l'architecture Modular Monolith.
- Portée : organisation interne d'un domaine, responsabilités des composants, validation, événements locaux, orchestration, autorisation et nommage.
- Hors portée : contrats et communications inter-domaines (CHAN-28), frontières et dépendances entre domaines (CHAN-29), harmonisation générale de `AGENTS.md` (CHAN-30), tests d'architecture (CHAN-31), règles de style automatisées (CHAN-32).

> **Statut.** Ce document est la référence des développements métier à venir. À la date de rédaction, `app/Domains/` ne contient encore aucune classe métier : les domaines sont matérialisés par des répertoires et des fichiers `.gitkeep`. Les exemples de ce document sont **illustratifs** ; ils ne décrivent pas des classes existantes et ne doivent pas être créés uniquement pour illustrer la documentation.

## 1. Objectifs et principes généraux

### 1.1 Objectifs

Le document doit permettre de répondre sans ambiguïté aux questions suivantes :

- dans quel répertoire placer une classe métier ;
- quelle responsabilité attribuer à cette classe ;
- quand un composant est réellement nécessaire ;
- quand une couche supplémentaire serait inutile ;
- comment les composants d'un domaine collaborent ;
- comment les règles métier restent appliquées indépendamment de Livewire, Filament, d'une commande ou d'un job.

### 1.2 Principes

1. **Le domaine est propriétaire de ses règles.** Un domaine est la seule autorité sur ses modèles, ses invariants, ses transitions d'état et ses données.
2. **Organisation par type de composant.** À l'intérieur d'un domaine, les classes sont rangées par responsabilité technique (`Models`, `Actions`, `Services`, etc.), et non par écran ou par controller.
3. **Le métier ne dépend pas de l'interface.** Une règle critique doit produire le même résultat qu'elle soit déclenchée par Livewire, Filament, une commande Artisan, un job ou un test.
4. **Le serveur est l'autorité.** Les données venant du navigateur, y compris en mode hors connexion, ne sont jamais considérées comme fiables. Les droits, calculs et transitions d'état sont vérifiés côté serveur.
5. **Minimalisme.** Un dossier ou une classe n'est créé que lorsqu'un besoin réel le justifie. L'architecture cible n'impose pas de remplir un gabarit.
6. **Explicite plutôt qu'implicite.** Une dépendance, une transaction, une autorisation ou un événement doivent être visibles dans le code de l'opération. Les effets de bord cachés sont à éviter.
7. **Pas d'anticipation.** Les contrats inter-domaines, les frontières de dépendance et les tests d'architecture relèvent de tickets distincts.
8. **Cohérence avec le socle existant.** Le code doit respecter Laravel 13, PHP 8.4, Livewire 4, Filament 5, Laravel Pint et Larastan. `app/Core` reste réservé aux composants techniques transverses décrits dans [`app/Core/README.md`](../../app/Core/README.md).

### 1.3 Niveaux de règle

| Terme | Signification |
| --- | --- |
| **Obligatoire** | Une dérogation exige une justification explicite en revue et, si elle est structurante, une décision d'architecture documentée. |
| **Recommandé** | Pratique par défaut. Une alternative est acceptable si elle est plus simple et justifiée. |
| **Conditionnel** | S'applique uniquement lorsqu'un besoin concret est présent. |
| **Hors périmètre** | Sujet traité par un autre ticket ; ne pas l'implémenter dans le cadre de CHAN-27. |

## 2. Organisation de référence d'un domaine

### 2.1 Arborescence indicative

```text
app/
└── Domains/
    └── Clients/
        ├── Models/
        │   └── Client.php
        ├── Actions/
        │   ├── CreateClient.php
        │   └── UpdateClient.php
        ├── Services/
        │   └── ClientNumberGenerator.php
        ├── DTO/
        │   └── ClientData.php
        ├── Events/
        │   └── ClientCreated.php
        └── Policies/
            └── ClientPolicy.php
```

Cette arborescence est **indicative**. Elle montre l'organisation attendue lorsque les composants existent ; elle ne constitue pas une liste de dossiers à créer.

### 2.2 Namespace et fichiers

- Le mapping PSR-4 `App\` vers `app/` couvre déjà les domaines. Aucune modification de `composer.json` n'est nécessaire.
- Un domaine `Clients` situé dans `app/Domains/Clients` utilise le namespace `App\Domains\Clients\`.
- Une classe `App\Domains\Clients\Actions\CreateClient` est placée dans `app/Domains/Clients/Actions/CreateClient.php`.
- Le namespace doit correspondre exactement au chemin, une classe par fichier.
- Le nom du répertoire du domaine est en `PascalCase` et identique au segment de namespace.

> **Emplacement.** Le dépôt utilise `app/Domains/` depuis CHAN-26. `AGENTS.md` mentionne encore `modules/` et le README racine contient une formulation historique. Ce document suit l'emplacement réellement implémenté. L'harmonisation générale des documents relève de CHAN-30 et n'est pas réalisée ici.

### 2.3 Création des dossiers

| Règle | Niveau |
| --- | --- |
| Un sous-répertoire de type (`Models/`, `Actions/`, etc.) n'est créé qu'au moment où il reçoit sa première classe réelle. | Obligatoire |
| Aucun dossier vide, aucune classe vide, aucun composant créé « pour plus tard ». | Obligatoire |
| Un fichier `.gitkeep` ne sert qu'à versionner le répertoire du domaine. Il ne doit pas être multiplié dans chaque sous-répertoire pour simuler une structure. | Recommandé |
| Les dossiers affichés dans l'arborescence de référence ne sont pas obligatoires dans chaque domaine. Un domaine peut ne contenir que `Models/` et `Actions/`. | Obligatoire |

### 2.4 Rôle des répertoires

| Répertoire | Rôle | Création |
| --- | --- | --- |
| `Models/` | Modèles Eloquent du domaine : relations, casts, scopes, comportements de persistance. | Dès qu'une entité persistée appartient au domaine. |
| `Actions/` | Opérations métier identifiables et orchestration de ces opérations. | Dès qu'une opération dépasse une simple écriture triviale ou porte une règle. |
| `Services/` | Logique réutilisable qui ne correspond pas à une opération métier unique. | Uniquement lorsqu'un traitement est partagé ou réellement distinct de l'orchestration. |
| `DTO/` | Transport de données structurées et typées. | Uniquement lorsqu'un tableau ou des paramètres dispersés deviennent coûteux ou ambigus. |
| `Events/` | Faits métier locaux au domaine. | Lorsqu'un fait doit être signalé à l'intérieur du domaine. |
| `Policies/` | Autorisations d'accès aux ressources et opérations. | Dès qu'une ressource doit être protégée par des règles d'autorisation. |
| `Exceptions/` | Exceptions métier du domaine, lorsqu'elles apportent une information exploitable. | Conditionnel. |
| `Listeners/` | Réactions internes aux événements locaux du domaine. | Conditionnel, si un abonnement explicite est nécessaire. |

D'autres répertoires (`Enums/`, `ValueObjects/`, etc.) peuvent être ajoutés lorsqu'un besoin réel apparaît, en respectant les mêmes principes. Ils ne doivent pas être créés par symétrie avec d'autres domaines.

### 2.5 Ce que le domaine ne contient pas

Le domaine ne contient pas :

- les contrôleurs HTTP, les routes et les middleware ;
- les composants Livewire et les ressources Filament ;
- les vues Blade, les assets et la configuration du panel ;
- les migrations, seeders et factories, qui restent dans les répertoires Laravel existants tant qu'une décision dédiée n'en dispose pas autrement ;
- les contrats et mécanismes d'échange inter-domaines ;
- les composants techniques transverses, qui appartiennent à `app/Core`.

L'emplacement des composants d'interface n'est pas modifié par ce document. Le provider Filament configuré découvre ses ressources dans `app/Filament/Resources`, ses pages dans `app/Filament/Pages` et ses widgets dans `app/Filament/Widgets`. Une interface appelle les Actions et Policies du domaine ; elle ne porte pas les règles métier.

## 3. Responsabilités des Models

### 3.1 Rôle

Un Model représente une entité persistée du domaine et les comportements directement liés à sa persistance.

Un Model **peut** porter :

- la définition de la table et de la clé primaire ;
- les relations Eloquent ;
- les casts de types et les formats de date ;
- les accesseurs et mutateurs simples ;
- les query scopes réutilisables ;
- les contraintes de persistance vérifiables localement (valeurs par défaut, attributs calculés simples) ;
- les traits strictement nécessaires au modèle (`HasFactory`, `SoftDeletes`, etc.).

Un Model **ne doit pas** :

- orchestrer une opération métier complète ;
- envoyer des emails, appeler une API externe, écrire des fichiers ou publier un événement inter-domaine ;
- contenir une décision d'autorisation ;
- dépendre de Livewire, Filament, de la requête HTTP ou de la session ;
- devenir un « god model » parce qu'il est pratique d'y ajouter une méthode.

### 3.2 Exemples

```php
namespace App\Domains\Clients\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

final class Client extends Model
{
    public function contacts(): HasMany
    {
        return $this->hasMany(Contact::class);
    }
}
```

Ce modèle peut porter la relation et les casts. Il ne doit pas contenir `createWithNumber()`, `approve()` ou `close()` si ces opérations impliquent plusieurs écritures, une règle métier ou un événement.

### 3.3 Model events et événements de domaine

Les événements Eloquent (`creating`, `created`, `updated`, etc.) sont des **événements de persistance**. Ils ne remplacent pas les événements métier décrits à la section 7 :

- un événement Eloquent ne doit pas être le seul support d'une règle métier critique ;
- un `Observer` ne doit pas déclencher une transition d'état métier cachée ;
- un événement de domaine doit rester identifiable dans l'Action qui réalise l'opération.

### 3.4 État transitoire du dépôt

Le seul modèle existant est `App\Models\User`, hérité de l'installation Laravel et utilisé par Filament. Il n'est pas déplacé par CHAN-27. Son rattachement éventuel au domaine `Identity` relève d'un travail distinct et ne doit pas être anticipé ici.

## 4. Responsabilités des Actions

### 4.1 Définition

Une Action représente **une opération métier identifiable**. Elle porte l'orchestration de cette opération : vérifications métier, appel des Services nécessaires, écritures, transition d'état et publication des événements locaux.

Exemples : `CreateClient`, `UpdateClient`, `ApprovePurchaseOrder`, `CloseChantier`.

### 4.2 Quand créer une Action

Une Action est **obligatoire** lorsque l'opération :

- porte une règle métier ou un invariant ;
- réalise une transition d'état (`approuver`, `clôturer`, `valider`, `annuler`) ;
- effectue plusieurs écritures liées ;
- doit publier un événement métier ;
- doit être appelée depuis plusieurs interfaces ou depuis un job/une commande ;
- manipule des données financières ou des droits.

Une Action peut être **évitée** pour une modification triviale d'un seul champ, sans règle métier, sans transition d'état, sans événement et sans effet de bord. Dans ce cas, l'écriture peut rester une opération Eloquent simple. Dès qu'une règle, une transition, plusieurs écritures ou un événement apparaissent, l'Action redevient obligatoire.

### 4.3 Forme attendue

| Règle | Niveau |
| --- | --- |
| Une Action porte une seule opération métier. | Obligatoire |
| Une Action possède une seule méthode publique d'entrée, `handle()`, et retourne un type explicite. | Recommandé |
| Les dépendances sont injectées par le constructeur. | Obligatoire |
| L'Action ne retourne pas de réponse HTTP, de vue ou de composant d'interface. | Obligatoire |
| L'Action ne valide pas les formats de saisie ; elle valide les invariants métier. | Obligatoire |
| L'Action ne contient pas de requête de lecture destinée à l'affichage. | Recommandé |
| Le nom de la classe décrit l'opération, sans suffixe `Action`. | Obligatoire |
| Une Action d'une opération sensible vérifie explicitement l'autorisation avant d'écrire. Si un acteur lui est transmis, elle utilise `Gate::forUser($actor)->authorize(...)` ; sinon, elle utilise `Gate::authorize(...)`. Un acteur transmis ne vaut pas autorisation. | Obligatoire |

L'autorisation et les invariants métier sont deux contrôles distincts. La Policy détermine les droits de l'utilisateur ; l'Action vérifie l'état actuel de la ressource et les conditions de transition.

### 4.4 Exemple de forme

```php
namespace App\Domains\Clients\Actions;

use App\Domains\Clients\DTO\ClientData;
use App\Domains\Clients\Events\ClientCreated;
use App\Domains\Clients\Models\Client;
use App\Domains\Clients\Services\ClientNumberGenerator;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;

final class CreateClient
{
    public function __construct(
        private readonly ClientNumberGenerator $numbers,
    ) {}

    public function handle(User $actor, ClientData $data): Client
    {
        Gate::forUser($actor)->authorize('create', Client::class);

        $client = DB::transaction(function () use ($data): Client {
            return Client::create([
                'number' => $this->numbers->next(),
                'name' => $data->name,
                'email' => $data->email,
            ]);
        });

        ClientCreated::dispatch($client);

        return $client;
    }
}
```

Cet exemple est illustratif. Il montre la séparation attendue : l'Action orchestre, le Service génère le numéro, le Model persiste, l'événement est publié après la transaction.

### 4.5 Actions et transactions

- L'Action est le niveau par défaut de la transaction pour une opération multi-écritures.
- La transaction doit englober toutes les écritures qui doivent réussir ou échouer ensemble.
- Un événement métier ne doit pas être publié avant la validation de la transaction, sauf mécanisme explicite de publication après commit.
- Une Action ne doit pas laisser une transaction ouverte à son appelant.
- Une Action imbriquée dans une autre transaction doit rester compatible avec la transaction englobante ; elle ne doit pas provoquer un commit partiel.

## 5. Responsabilités des Services

### 5.1 Définition

Un Service fournit une **logique réutilisable** qui ne représente pas une opération métier unique.

Exemples : `ClientNumberGenerator`, `ChantierCostCalculator`, `PurchaseOrderTotalCalculator`.

### 5.2 Différence avec une Action

| Question | Action | Service |
| --- | --- | --- |
| Représente une opération métier identifiable ? | Oui | Non |
| Orchestre plusieurs étapes métier ? | Oui | En général non |
| Est appelé directement par une interface pour réaliser l'opération ? | Oui | Non, sauf cas explicite |
| Peut être réutilisé par plusieurs Actions ? | Possible, mais l'Action reste l'entrée | Oui, c'est son intérêt |
| Porte la transaction principale ? | Oui, par défaut | Non, sauf opération autonome documentée |
| Publie les événements métier de l'opération ? | Oui | Non, sauf événement propre au service et documenté |

**Règle fondamentale :** si le composant représente une opération métier identifiable, c'est une Action. Si c'est une logique réutilisable au service d'une ou plusieurs opérations, c'est un Service.

### 5.3 Règles

| Règle | Niveau |
| --- | --- |
| Un Service ne doit pas devenir un conteneur générique de méthodes sans rapport. | Obligatoire |
| Un Service ne doit pas être créé uniquement pour déplacer du code d'un contrôleur ou d'un composant Livewire. | Obligatoire |
| Un Service ne doit pas être créé uniquement pour déléguer à Eloquent sans logique supplémentaire. | Obligatoire |
| Un Service doit avoir un nom qui décrit sa responsabilité, sans suffixe `Service` par défaut. | Obligatoire |
| Un Service ne doit pas ouvrir puis valider une transaction appartenant à l'Action appelante. | Obligatoire |
| Un Service peut porter sa propre transaction s'il est un point d'entrée autonome et que son opération est indivisible ; ce comportement doit être explicite. | Conditionnel |
| Un Service qui ne dépend d'aucun état d'instance doit rester sans état. | Recommandé |
| Un Service doit être testable sans interface et sans base lorsqu'il s'agit d'un calcul. | Recommandé |

### 5.4 Exemple

```php
namespace App\Domains\Costing\Services;

use App\Domains\Costing\Models\ChantierCostLine;

final class ChantierCostCalculator
{
    /**
     * @param  iterable<ChantierCostLine>  $lines
     */
    public function total(iterable $lines): int
    {
        $total = 0;

        foreach ($lines as $line) {
            $total += $line->amountCents();
        }

        return $total;
    }
}
```

Ce Service calcule. Il ne persiste rien, ne publie aucun événement et ne décide pas si un chantier peut être clôturé.

## 6. Responsabilités des DTO

### 6.1 Définition

Un DTO transporte des données structurées et typées entre deux frontières : interface vers domaine, domaine vers job, ou tout autre échange encadré par une décision d'architecture.

### 6.2 Quand créer un DTO

Un DTO est justifié lorsqu'il apporte au moins un des bénéfices suivants :

- regrouper plusieurs paramètres qui circulent ensemble ;
- rendre explicite un contrat d'entrée ou de sortie ;
- garantir l'immutabilité d'une donnée transmise ;
- éviter qu'un tableau non typé traverse plusieurs couches ;
- simplifier la signature d'une Action ou d'un Service.

Exemples : `ClientData`, `ChantierClosureData`, `PurchaseOrderApprovalData`.

### 6.3 Quand ne pas créer de DTO

- Pour un unique identifiant ou deux paramètres scalaires simples.
- Pour chaque entrée ou sortie d'Action par principe.
- Pour chaque Model, afin de « masquer » Eloquent.
- Lorsqu'un tableau associatif clairement documenté suffit et reste local.
- Pour transporter un Model Eloquent déguisé sans valeur ajoutée.

### 6.4 Règles

| Règle | Niveau |
| --- | --- |
| Un DTO ne contient ni logique de persistance, ni requête, ni dépendance à un service. | Obligatoire |
| Un DTO ne remplace pas la validation métier ; il peut garantir la présence et le type des données qu'il transporte. | Obligatoire |
| Un DTO doit être immuable lorsque l'état transmis ne doit pas être modifié. | Recommandé |
| PHP 8.4 permet d'utiliser `final readonly class` et la promotion de constructeur. | Recommandé |
| Le suffixe `Data` est utilisé lorsqu'il clarifie le rôle de la classe. | Recommandé |
| Le DTO ne doit pas exposer de données sensibles inutiles (mot de passe, token, données bancaires). | Obligatoire |

### 6.5 Exemple

```php
namespace App\Domains\Clients\DTO;

final readonly class ClientData
{
    public function __construct(
        public string $name,
        public string $email,
        public ?string $phone = null,
    ) {}
}
```

La validation du format de l'email reste dans la couche de saisie. La validation d'une règle métier, par exemple l'unicité fonctionnelle d'un client, reste dans l'Action ou le Service approprié.

## 7. Responsabilités des Events

### 7.1 Définition

Un Event représente un **fait métier qui s'est produit**. Il est nommé au passé et ne décrit pas une étape technique.

Exemples : `ClientCreated`, `PurchaseOrderApproved`, `ChantierClosed`.

Un événement technique (`JobStarted`, `CacheMissed`, `QueryExecuted`) n'est pas un événement métier de domaine.

### 7.2 Deux catégories à distinguer

| Catégorie | Usage | Périmètre |
| --- | --- | --- |
| **Événement local** | Signaler un fait à l'intérieur du domaine et déclencher des traitements internes. | Défini par CHAN-27. |
| **Événement inter-domaines** | Informer un autre domaine. | Contrats, propriété, publication et évolution réservés à CHAN-28. |

Un événement local reste interne au domaine. Les échanges inter-domaines ne doivent pas être improvisés dans ce document.

### 7.3 Règles

| Règle | Niveau |
| --- | --- |
| Un Event est nommé au passé. | Obligatoire |
| Un Event transporte les données minimales nécessaires à ses consommateurs locaux. | Obligatoire |
| Un Event ne doit pas contenir de données sensibles inutiles. | Obligatoire |
| Un Event ne doit pas exécuter de requête ni de logique dans son constructeur. | Recommandé |
| Un Event est publié après la validation de la transaction qui a produit le fait, ou via un mécanisme après-commit explicite. | Obligatoire |
| Un Event local est déclaré dans `app/Domains/{Domaine}/Events/`. | Obligatoire |
| Un Listener local est placé dans le domaine et son abonnement est explicite. | Conditionnel |
| Un Event ne doit pas être créé s'il n'a aucun consommateur réel, sauf s'il documente un fait métier structurant et fait partie du contrat du domaine. | Recommandé |
| Les événements Eloquent ne sont pas des événements de domaine. | Obligatoire |

### 7.4 Exemple

```php
namespace App\Domains\Clients\Events;

use App\Domains\Clients\Models\Client;
use Illuminate\Contracts\Events\ShouldDispatchAfterCommit;
use Illuminate\Foundation\Events\Dispatchable;

final class ClientCreated implements ShouldDispatchAfterCommit
{
    use Dispatchable;

    public function __construct(
        public readonly Client $client,
    ) {}
}
```

`ShouldDispatchAfterCommit` garantit que l'événement n'est publié qu'après la validation de la transaction englobante. Ce mécanisme est disponible dans Laravel 13.

## 8. Responsabilités des Policies

### 8.1 Définition

Une Policy détermine si un utilisateur est autorisé à réaliser une action sur une ressource. Elle évalue les droits de l'utilisateur, pas l'état métier de la ressource. Elle ne réalise pas l'opération.

Exemples : `ClientPolicy`, `ChantierPolicy`, `PurchaseOrderPolicy`.

### 8.2 Règles

| Règle | Niveau |
| --- | --- |
| Une Policy répond à une question d'autorisation et retourne `bool` ou `Response`. | Obligatoire |
| Une Policy ne crée, ne met à jour et ne supprime aucune donnée métier. | Obligatoire |
| Une Policy ne publie pas d'événement et n'appelle pas d'API externe. | Obligatoire |
| Une Policy ne contient pas la règle métier elle-même, seulement la condition d'accès. | Obligatoire |
| Une Policy ne vérifie pas l'état de la ressource (déjà clôturée, statut, réserves ouvertes, pointages en attente) ; ces invariants appartiennent à l'Action. | Obligatoire |
| Une Policy est nommée avec le suffixe `Policy`. | Obligatoire |
| Les abilities couvrent au minimum les opérations standard (`viewAny`, `view`, `create`, `update`, `delete`) et les opérations métier explicites (`approve`, `close`, etc.). | Recommandé |
| Une Policy ne doit pas dépendre de Livewire ou Filament. | Obligatoire |
| Le nom de l'ability doit correspondre au vocabulaire de l'opération métier. | Recommandé |

### 8.3 Découverte et enregistrement des Policies

La découverte automatique est le comportement par défaut de Laravel. Une Policy est découverte automatiquement lorsqu'elle est placée dans un répertoire `Policies` situé au niveau du répertoire contenant les Models ou au-dessus, et que son nom correspond au Model avec le suffixe `Policy`.

Pour un Model `App\Domains\Clients\Models\Client`, Laravel examine notamment :

- `App\Domains\Clients\Models\Policies\ClientPolicy` ;
- `App\Domains\Clients\Policies\ClientPolicy` ;
- `App\Domains\Policies\ClientPolicy` ;
- `App\Policies\ClientPolicy`.

La Policy `App\Domains\Clients\Policies\ClientPolicy` est donc compatible avec la structure du domaine. Aucun enregistrement explicite n'est nécessaire lorsque cette convention de nommage et de placement est respectée. Voir [Laravel 13 — Authorization](https://laravel.com/docs/13.x/authorization).

`#[UsePolicy(ClientPolicy::class)]` et `Gate::policy(Client::class, ClientPolicy::class)` restent des mécanismes explicites alternatifs. Ils sont utiles lorsqu'il faut fixer un rattachement indépendamment de la convention de nommage, choisir entre plusieurs Policies, ou rendre le rattachement visible dans un contexte particulier. Ils ne doivent pas être imposés systématiquement.

Il est recommandé qu'un test vérifie la découverte effective de la Policy, par exemple :

```php
expect(Gate::getPolicyFor(Client::class))->toBeInstanceOf(ClientPolicy::class);
```

Un test qui exerce une ability réelle convient également. Il détecte un renommage, un déplacement ou un namespace incorrect. Les tests d'architecture complets relèvent de CHAN-31.

### 8.4 Exemple

```php
namespace App\Domains\Projects\Policies;

use App\Domains\Projects\Models\Chantier;
use App\Models\User;

final class ChantierPolicy
{
    public function view(User $user, Chantier $chantier): bool
    {
        return $user->id === $chantier->manager_id
            || $chantier->members()->whereKey($user->id)->exists();
    }

    public function update(User $user, Chantier $chantier): bool
    {
        return $user->id === $chantier->manager_id;
    }

    public function close(User $user, Chantier $chantier): bool
    {
        return $user->id === $chantier->manager_id;
    }
}
```

Cet exemple est illustratif. La relation `members()` et l'attribut `manager_id` ne sont pas implémentés dans le dépôt et ne doivent pas être créés pour illustrer le document. Une vraie Policy s'appuiera sur les rôles, permissions et affectations réellement disponibles.

La Policy vérifie uniquement les droits. Elle ne teste ni la clôture déjà effective, ni les réserves ouvertes, ni les pointages en attente. Ces invariants sont vérifiés par l'Action `CloseChantier`.

## 9. Validation de saisie et validation métier

### 9.1 Deux validations distinctes

| Validation | Objet | Emplacement |
| --- | --- | --- |
| **Validation de saisie** | Champs requis, formats, longueurs, types, règles de formulaire. | Livewire, Filament, Form Requests, règles de validation Laravel. |
| **Validation métier** | Cohérence fonctionnelle, invariants, contraintes critiques, conditions de transition. | Action, Service ou Model selon le niveau approprié. |
| **Intégrité des données** | Unicité, clés étrangères, contraintes de colonne. | Base de données, en complément. |

La validation de saisie améliore l'expérience utilisateur. Elle ne garantit pas les règles métier, car une Action peut être appelée sans passer par le formulaire.

### 9.2 Règles

| Règle | Niveau |
| --- | --- |
| Une règle métier critique doit être appliquée dans le domaine, même si l'Action est appelée directement. | Obligatoire |
| La validation de saisie ne doit pas être le seul rempart d'une règle critique. | Obligatoire |
| Les données du navigateur et du mode hors connexion ne sont jamais fiables. | Obligatoire |
| Une contrainte d'intégrité importante peut être garantie par la base de données. | Recommandé |
| Un message d'erreur métier doit rester compréhensible et ne doit pas exposer d'informations sensibles. | Obligatoire |
| Les exceptions métier doivent être converties en messages de validation ou en erreurs d'interface au niveau de la frontière appropriée. | Recommandé |

### 9.3 Exemples

**Création d'un client**

- Validation de saisie : nom requis, email au bon format, longueur maximale du téléphone.
- Validation métier : le numéro client doit être unique et respecter la règle de numérotation du domaine.
- Base de données : index unique sur le numéro client.

**Validation d'un bon de commande**

- Validation de saisie : identifiant du bon, commentaire éventuel.
- Validation métier : le bon doit être en attente et ne pas être déjà validé ou annulé.
- Autorisation : `PurchaseOrderPolicy::approve()` vérifie que l'utilisateur peut valider ce bon.
- Base de données : contrainte sur le statut si elle est stable et portable.

**Clôture d'un chantier**

- Validation de saisie : date de clôture valide, motif éventuel.
- Validation métier : le chantier ne doit pas avoir de réserves ouvertes ni de pointages en attente, et son état doit permettre la clôture.
- Base de données : contrainte de cohérence uniquement si elle ne duplique pas une règle évolutive.

## 10. Règles d'orchestration

### 10.1 Répartition des responsabilités

| Composant | Responsabilité |
| --- | --- |
| **Interface** (Livewire, Filament, HTTP) | Collecter et valider la saisie, vérifier l'autorisation au point d'entrée, appeler l'Action, afficher le résultat ou les erreurs. |
| **Action** | Orchestrer l'opération métier, vérifier l'autorisation des opérations sensibles, appliquer les invariants, délimiter la transaction, publier les événements locaux. |
| **Service** | Fournir un calcul ou un traitement réutilisable, sans orchestrer l'opération complète. |
| **Model** | Représenter les données et les comportements de persistance. |
| **Policy** | Autoriser ou refuser une opération selon les droits de l'utilisateur, sans vérifier les invariants d'état. |
| **Event** | Décrire un fait métier accompli. |

### 10.2 Règles

1. **L'interface ne contient pas de règle métier critique.** Elle peut filtrer, formater et valider la saisie, mais la décision métier appartient au domaine.
2. **L'Action est le point d'entrée métier.** Une opération qui porte une règle, une transition d'état, plusieurs écritures ou un événement passe par une Action.
3. **Le Service ne remplace pas l'Action.** Il est appelé par l'Action ou par un autre composant du domaine pour un traitement réutilisable.
4. **Le Model ne pilote pas l'opération.** Il ne décide pas si une clôture est autorisée et ne publie pas d'événement inter-domaine.
5. **La Policy autorise, elle n'exécute pas et ne vérifie pas les invariants d'état.** L'Action reste responsable de l'opération et de ses conditions de transition.
6. **La transaction est gérée au niveau qui préserve la cohérence.** Par défaut : l'Action.
7. **Les effets de bord sont explicites.** Email, notification, job ou événement doivent être visibles dans l'orchestration.
8. **Les frontières entre domaines sont respectées.** Un domaine ne doit pas accéder directement aux modèles ou tables d'un autre domaine. La définition détaillée des dépendances autorisées et interdites relève de CHAN-29.

### 10.3 Séquence type

```text
Livewire / Filament
    │
    ├─ validation de saisie
    ├─ Policy (autorisation au point d'entrée)
    └─ Action
         ├─ validation métier / invariants
         ├─ Service (calcul ou traitement réutilisable)
         ├─ Model (persistance)
         ├─ transaction
         └─ Event local (après commit)
```

### 10.4 Exemple d'orchestration : clôture d'un chantier

1. Le composant Filament valide la date et le motif.
2. `ChantierPolicy::close()` vérifie que l'utilisateur dispose des droits de clôture.
3. `CloseChantier` vérifie les invariants : aucune réserve ouverte, aucun pointage en attente, état compatible.
4. L'Action applique les conditions de transition et, si nécessaire, appelle un Service de calcul de son domaine.
5. L'Action met à jour le chantier et enregistre les données de clôture dans une transaction.
6. `ChantierClosed` est publié après commit.
7. L'interface affiche le résultat.

Aucune de ces règles ne doit être déplacée dans le composant Filament.

### 10.5 Intégration avec Livewire 4 et Filament 5

| Interface | Rôle autorisé | Interdit |
| --- | --- | --- |
| Composant Livewire | Valider la saisie, vérifier l'autorisation, appeler une Action, afficher le résultat. | Ouvrir une transaction, appliquer une règle métier critique, publier un événement métier. |
| Ressource Filament | Définir les champs, la validation de saisie et les abilities d'affichage. | Décider d'une transition d'état dans le schéma ou dans une closure d'action. |
| Bouton ou action Filament | Déléguer à une Action du domaine. | Réaliser plusieurs écritures métier ou dupliquer les invariants. |
| Page ou widget Filament | Lire et présenter des données, appeler des Actions pour les commandes. | Écrire directement un état métier sans passer par le domaine. |

Les closures d'action Filament et les méthodes de composants Livewire doivent rester minces. Si une closure contient une règle, une transaction ou plusieurs écritures, cette logique appartient à une Action.

## 11. Règles d'autorisation

### 11.1 Principes

- L'authentification identifie l'utilisateur ; l'autorisation détermine ce qu'il peut faire.
- L'autorisation est vérifiée **côté serveur**, jamais uniquement par l'affichage ou le masquage d'un bouton.
- Le principe du moindre privilège s'applique : une opération n'est autorisée que si une règle explicite l'accorde.
- Les Policies sont le mécanisme de référence pour les ressources du domaine.
- Une Policy évalue les droits de l'utilisateur, pas l'état métier de la ressource.
- Une Policy ne doit pas devenir le seul endroit où une règle métier critique est appliquée : elle autorise l'accès, l'Action vérifie la cohérence métier et les conditions de transition.

### 11.2 Points de contrôle

| Point d'entrée | Vérification |
| --- | --- |
| Composant Livewire | Vérification d'autorisation (`Gate::authorize()` ou mécanisme équivalent) avant l'appel de l'Action. |
| Ressource ou action Filament | Policy et abilities Filament, avec vérification serveur. |
| Contrôleur HTTP | Form Request, middleware et Policy. |
| Commande Artisan ou job | Vérification explicite des droits de l'acteur ; l'Action applique `Gate::forUser($actor)`. |
| Appel direct depuis un test | L'Action vérifie les droits et les invariants ; le contexte de test ne contourne pas les règles. |

### 11.3 Actions sensibles

Pour une opération sensible (validation d'un bon de commande, clôture d'un chantier, opération financière), l'Action vérifie explicitement l'autorisation avant d'écrire.

- Si l'Action utilise l'utilisateur authentifié courant : `Gate::authorize('close', $chantier);`
- Si un acteur lui est transmis par un job, une commande ou un import : `Gate::forUser($actor)->authorize('close', $chantier);`

Un acteur transmis ne constitue pas une preuve d'autorisation. Il doit être vérifié avec la Policy applicable.

Les points d'entrée Livewire et Filament conservent leur propre vérification d'autorisation avant d'appeler l'Action. Le masquage d'un bouton n'est jamais une protection. Aucun appel direct à une Action, y compris depuis une commande, un job ou un test, ne doit permettre de contourner les droits.

L'autorisation et les invariants métier restent distincts : la Policy détermine les droits, l'Action vérifie l'état de la ressource, les conditions de transition, les réserves, les pointages et les autres invariants.

### 11.4 Exemple

```php
namespace App\Domains\Projects\Actions;

use App\Domains\Projects\DTO\ChantierClosureData;
use App\Domains\Projects\Models\Chantier;
use App\Models\User;
use Illuminate\Support\Facades\Gate;

final class CloseChantier
{
    public function handle(User $actor, Chantier $chantier, ChantierClosureData $data): void
    {
        Gate::forUser($actor)->authorize('close', $chantier);

        // Invariants métier : état, réserves, pointages, données de clôture...
    }
}
```

L'interface Filament ou Livewire vérifie également `Gate::authorize('close', $chantier)` avant d'appeler l'Action. Cette double vérification est intentionnelle : elle protège l'interface et garantit qu'un autre appelant ne contourne pas les droits. L'Action `CloseChantier` reste responsable des invariants métier.

## 12. Conventions de nommage

### 12.1 Règles générales

| Élément | Convention | Exemple |
| --- | --- | --- |
| Répertoire de domaine | `PascalCase`, nom métier | `Clients`, `Procurement`, `TimeTracking` |
| Classe | `PascalCase` | `PurchaseOrder` |
| Méthode | `camelCase`, verbe explicite | `approve()`, `close()`, `calculateTotal()` |
| Propriété | `camelCase` | `$approvedAt`, `$totalCents` |
| Constante | `UPPER_SNAKE_CASE` | `STATUS_APPROVED` |
| Table | snake_case pluriel, convention Laravel | `purchase_orders` |
| Booléen | préfixe `is`, `has`, `can` | `isActive()`, `hasOpenReserves()` |
| Namespace | identique au chemin | `App\Domains\Clients\Actions` |

### 12.2 Composants

| Composant | Convention | Exemples | À éviter |
| --- | --- | --- | --- |
| Model | Nom de l'entité au singulier | `Client`, `Chantier`, `PurchaseOrder` | `ClientModel`, `Clients` |
| Action | Verbe explicite + objet, sans suffixe `Action` | `CreateClient`, `ApprovePurchaseOrder`, `CloseChantier` | `ClientAction`, `Manager`, `Process` |
| Service | Nom décrivant la responsabilité, sans suffixe `Service` par défaut | `ClientNumberGenerator`, `ChantierCostCalculator` | `ClientService`, `Helper`, `Utils` |
| DTO | Nom + suffixe `Data` lorsque pertinent | `ClientData`, `ChantierClosureData` | `ClientDTO`, `ClientArray` |
| Event | Fait au passé | `ClientCreated`, `ChantierClosed` | `CreateClientEvent`, `ClientCreation` |
| Policy | Ressource + suffixe `Policy` | `ClientPolicy`, `ChantierPolicy` | `ClientAuthorization` |
| Exception | Nom + suffixe `Exception` | `ChantierAlreadyClosedException` | `Error`, `BusinessError` |
| Listener | Verbe ou réaction explicite | `NotifyProjectManager` | `Listener1`, `HandleEvent` |

### 12.3 Règles complémentaires

- Une classe doit être compréhensible sans ouvrir son fichier.
- Éviter les abréviations non métier (`Mgr`, `Svc`, `Proc`).
- Éviter les noms génériques : `Helper`, `Manager`, `Utils`, `Processor`, `Handler` sans qualification.
- Un nom d'Action ne doit pas regrouper plusieurs opérations (`CreateOrUpdateClient`, `ProcessChantier`).
- Le nom d'une ability de Policy doit refléter l'opération (`approve`, `close`, `submit`), pas un écran.
- Les noms de classes et de fichiers doivent rester cohérents avec le vocabulaire métier du BTP utilisé dans le projet.
- Le vocabulaire peut rester français pour les termes métier du BTP (`Chantier`, `Réserve`) et anglais pour les concepts génériques (`Client`, `PurchaseOrder`). Un même concept conserve le même nom dans le domaine et dans ses tables.
- Pas de préfixe ou suffixe décoratif `Domain`, `Module` ou `Bounded` sur les classes ou les répertoires.

## 13. Exemples concrets adaptés à C2ME Chantier

> Les classes ci-dessous sont des exemples de conception. Elles ne doivent pas être créées dans l'application uniquement pour illustrer ce document.

### 13.1 Création d'un client

**Objectif :** créer un client avec un numéro généré par le domaine, tracer le fait et protéger l'opération.

**Composants :**

- `App\Domains\Clients\Models\Client` : modèle Eloquent, relations et casts.
- `App\Domains\Clients\DTO\ClientData` : nom, email, téléphone.
- `App\Domains\Clients\Services\ClientNumberGenerator` : génération d'un numéro unique.
- `App\Domains\Clients\Actions\CreateClient` : orchestration et transaction.
- `App\Domains\Clients\Events\ClientCreated` : fait métier local.
- `App\Domains\Clients\Policies\ClientPolicy` : autorisation de création et de consultation.

**Séquence :**

1. Le formulaire Livewire ou Filament valide le nom et l'email.
2. `ClientPolicy::create()` vérifie que l'utilisateur peut créer un client.
3. `CreateClient` génère le numéro via le Service, crée le client dans une transaction et publie `ClientCreated` après commit.
4. L'interface affiche le client créé.

**Pourquoi cette séparation :**

- le format de l'email appartient à la validation de saisie ;
- l'unicité du numéro appartient au domaine et à la base ;
- l'événement est un fait métier, pas un simple log ;
- la Policy ne crée pas le client.

### 13.2 Validation d'un bon de commande

**Objectif :** passer un bon de commande de l'état « en attente » à l'état « validé ».

**Composants :**

- `App\Domains\Procurement\Models\PurchaseOrder` : modèle et statut.
- `App\Domains\Procurement\Actions\ApprovePurchaseOrder` : opération métier.
- `App\Domains\Procurement\Policies\PurchaseOrderPolicy::approve()` : autorisation.
- `App\Domains\Procurement\Events\PurchaseOrderApproved` : fait métier local.

**Règles métier dans l'Action :**

- le bon doit exister et être en attente ;
- il ne doit pas déjà être validé ou annulé ;
- la validation doit être atomique ;
- l'événement n'est publié qu'après commit.

**Erreur à éviter :** vérifier uniquement le statut dans le formulaire Filament. Une commande ou un job pourrait appeler l'Action sans passer par le formulaire.

### 13.3 Clôture d'un chantier

**Objectif :** clôturer un chantier uniquement lorsque les conditions métier sont réunies.

**Composants :**

- `App\Domains\Projects\Models\Chantier` : modèle et état.
- `App\Domains\Projects\DTO\ChantierClosureData` : date de clôture, motif, commentaire.
- `App\Domains\Projects\Actions\CloseChantier` : invariants, autorisation et transition.
- `App\Domains\Projects\Policies\ChantierPolicy::close()` : droits de l'utilisateur.
- `App\Domains\Projects\Events\ChantierClosed` : fait métier local.

**Invariants :**

- le chantier n'est pas déjà clôturé ;
- aucune réserve ouverte ne bloque la clôture ;
- aucun pointage en attente ne doit être perdu ;
- les données de clôture sont cohérentes.

**Séparation :**

- la Policy vérifie le droit de clôturer ;
- l'Action vérifie l'état, les conditions de transition et les autres invariants avant d'écrire ;
- le Model persiste ;
- l'Event informe les consommateurs locaux.

### 13.4 Calcul des coûts d'un chantier

`ChantierCostCalculator` est un Service, pas une Action :

- il ne représente pas une opération métier complète ;
- il peut être appelé par plusieurs Actions ;
- il ne persiste rien ;
- il ne publie pas d'événement ;
- il est testable indépendamment de l'interface et de la base lorsque ses entrées sont des objets ou des valeurs.

Si le calcul doit être figé, l'Action du domaine propriétaire du calcul appelle le Service et enregistre le résultat. Le Service ne décide pas d'une transition d'état.

### 13.5 Génération d'un numéro client

`ClientNumberGenerator` est un Service parce que :

- la génération ne représente pas à elle seule une opération métier ;
- elle peut être utilisée par `CreateClient` et éventuellement par un import ;
- elle encapsule une règle de numérotation réutilisable ;
- elle ne doit pas créer le client.

La transaction et la décision de créer le client restent dans l'Action.

### 13.6 Autorisation de modifier un chantier

`ChantierPolicy::update()` répond à la question « cet utilisateur dispose-t-il des droits pour modifier ce chantier ? ». Elle peut consulter les rôles, les affectations ou les règles d'accès réellement disponibles. Elle ne vérifie pas si le chantier est déjà clôturé : cette condition de transition appartient à l'Action. Elle ne modifie pas le chantier et ne déclenche aucun traitement.

L'interface vérifie la Policy avant d'afficher ou d'exécuter l'action. Le serveur revérifie lors de l'appel, et l'Action sensible vérifie les droits avec l'acteur concerné. Le masquage d'un bouton n'est jamais une mesure de sécurité.

## 14. Anti-patterns et erreurs d'architecture

| Anti-pattern | Pourquoi c'est un problème | Correction |
| --- | --- | --- |
| **God Model** | Le modèle concentre règles, requêtes, emails et autorisations ; il devient impossible à tester et à faire évoluer. | Déplacer les opérations dans des Actions et les calculs dans des Services. |
| **God Service** | Un Service fourre-tout recrée un couplage fort et masque les responsabilités. | Découper par responsabilité réelle ou supprimer la couche. |
| **Action générique** | `ProcessClient`, `ManageChantier` ou `CreateOrUpdateClient` masquent plusieurs opérations. | Une Action par opération identifiable. |
| **Action qui retourne une réponse HTTP** | Le métier dépend de l'interface et devient inutilisable en job ou commande. | Retourner un Model, un DTO, un booléen ou lever une exception métier. |
| **Règle métier dans Livewire/Filament** | La règle disparaît dès qu'un autre point d'entrée appelle le domaine. | Déplacer la règle dans l'Action ou le Service. |
| **Validation métier uniquement côté formulaire** | Un appel direct contourne la règle. | Valider les invariants dans le domaine. |
| **Policy qui écrit** | L'autorisation et l'opération sont confondues ; les effets de bord deviennent imprévisibles. | Policy en lecture seule, Action pour l'écriture. |
| **Policy qui vérifie l'état métier** | Les droits et les invariants sont mélangés ; la Policy devient dépendante du cycle de vie de la ressource. | Policy = droits de l'utilisateur ; état et transition dans l'Action. |
| **DTO pour chaque Model** | Multiplication de classes de transfert sans usage réel. | Créer un DTO seulement lorsqu'il apporte un bénéfice concret. |
| **DTO qui contient de la validation ou de la persistance** | Le DTO devient un service déguisé. | DTO de transport uniquement. |
| **Événement pour chaque étape technique** | Le système d'événements devient un journal technique difficile à maîtriser. | Réserver les Events aux faits métier. |
| **Événement publié avant commit** | Les consommateurs peuvent réagir à un fait annulé par un rollback. | Publier après commit ou utiliser `ShouldDispatchAfterCommit`. |
| **Événement local consommé par un autre domaine** | Le couplage inter-domaines est improvisé. | Définir un contrat inter-domaines dans CHAN-28. |
| **Accès direct aux modèles d'un autre domaine** | Les frontières et invariants de l'autre domaine sont contournés. | Respecter les frontières définies dans CHAN-29. |
| **Repository systématique** | Ajoute une couche qui ne fait que déléguer à Eloquent, sans besoin métier démontré. | Utiliser Eloquent directement dans le domaine, sauf besoin réel documenté. |
| **Interface pour une seule implémentation** | Complexité sans bénéfice de substitution ni de test. | Classe concrète injectable. |
| **Observer qui cache une transition d'état** | La règle devient invisible et difficile à tester. | Transition explicite dans une Action. |
| **Classe `Helper` ou `Utils`** | Responsabilité vague, couplage diffus, tests difficiles. | Classe nommée par sa responsabilité réelle. |
| **`BaseAction` / `BaseService` générique** | Abstraction prématurée qui impose un cadre sans besoin réel. | Pas de classe de base par défaut ; extraire seulement lorsqu'un motif stable apparaît. |
| **Dossier vide « pour l'architecture »** | Donne une fausse impression de structure et encourage des classes inutiles. | Créer le dossier avec sa première classe réelle. |
| **Nom de classe vague** | `Manager`, `Processor`, `Helper` ne disent pas quelle règle est portée. | Nommer par l'opération ou la responsabilité. |
| **Transaction dans le contrôleur** | La cohérence dépend de l'interface et n'est pas garantie pour les autres appelants. | Transaction dans l'Action. |
| **Écriture directe depuis Filament pour une opération métier** | Contourne les invariants, la transaction et les événements. | Appeler l'Action du domaine dès qu'une règle ou une orchestration existe. |

## 15. Principes pour ne pas créer de couches inutiles

### 15.1 Principe de départ minimal

Un domaine commence avec le strict nécessaire :

- un Model lorsqu'il y a une entité persistée ;
- une Policy lorsqu'une ressource doit être protégée ;
- une Action lorsqu'une opération porte une règle ou une orchestration.

Les autres composants apparaissent uniquement lorsqu'un besoin concret les justifie.

### 15.2 Arbre de décision

```text
Le besoin est-il une opération métier identifiable ?
├─ Oui → Action
└─ Non
   ├─ Est-ce une logique réutilisable ou un calcul ?
   │  ├─ Oui → Service
   │  └─ Non
   ├─ Est-ce un transport de données structurées ?
   │  ├─ Oui → DTO (si le besoin est réel)
   │  └─ Non
   ├─ Est-ce un fait métier à signaler localement ?
   │  ├─ Oui → Event
   │  └─ Non
   ├─ Est-ce une autorisation ?
   │  ├─ Oui → Policy
   │  └─ Non
   └─ Est-ce une donnée persistée et ses comportements ?
      ├─ Oui → Model
      └─ Non → Ne pas créer de composant
```

### 15.3 Questions à se poser avant de créer une classe

1. Quelle responsabilité précise cette classe porte-t-elle ?
2. Existe-t-il déjà un composant du domaine qui peut assumer cette responsabilité sans devenir incohérent ?
3. La classe sera-t-elle réellement appelée par plusieurs opérations ou points d'entrée ?
4. Apporte-t-elle un typage, une sécurité ou une lisibilité mesurable ?
5. Peut-on obtenir le même résultat avec moins de code et moins d'indirection ?
6. La classe dépend-elle d'une interface ou d'un framework alors qu'elle devrait rester métier ?
7. Si elle disparaît, quelle règle ou quel comportement devient impossible à exprimer ?

Si les réponses ne démontrent pas un bénéfice réel, la classe ne doit pas être créée.

### 15.4 Signaux d'une couche inutile

- une classe qui ne fait que déléguer à une autre ;
- une interface avec une seule implémentation et aucun besoin de substitution ;
- un DTO identique à un tableau ou à un Model ;
- un Service qui ne contient qu'une méthode copiée d'un contrôleur ;
- un Event sans consommateur ;
- un dossier créé avant sa première classe ;
- une abstraction `Base*` créée avant d'avoir plusieurs cas concrets ;
- un découpage en couches qui oblige à modifier trois fichiers pour changer un champ.

### 15.5 Signaux d'une responsabilité mal placée

- une règle métier présente dans Livewire, Filament ou un contrôleur ;
- une transaction ouverte dans l'interface ;
- une Policy qui écrit ;
- un Model qui envoie un email ou appelle une API ;
- une Action qui retourne une vue ou une réponse HTTP ;
- un Service qui décide d'une transition d'état ;
- un événement technique présenté comme un fait métier ;
- un domaine qui importe directement un Model d'un autre domaine.

## 16. Portée, sujets réservés et références

### 16.1 Sujets réservés aux autres tickets

| Sujet | Ticket | Règle dans CHAN-27 |
| --- | --- | --- |
| Contrats, propriété, publication et évolution des événements inter-domaines | CHAN-28 | Ne pas définir de mécanisme concurrent. Les événements de ce document sont locaux. |
| Frontières métier, responsabilités des domaines, dépendances autorisées et interdites | CHAN-29 | Ne pas formaliser de matrice de dépendances ni d'accès direct entre domaines. |
| Harmonisation des conventions générales dans `AGENTS.md` | CHAN-30 | Ne pas modifier `AGENTS.md` ; ce document reste spécifique aux domaines. |
| Tests automatisés d'architecture | CHAN-31 | Les règles sont documentées, mais aucun test d'architecture n'est ajouté ici. |
| Règles de style PHP automatisées avec Pint | CHAN-32 | Ne pas modifier la configuration Pint ; le style reste celui de Laravel/Pint. |

### 16.2 Sujets non décidés par ce document

- l'emplacement définitif des migrations, seeders et factories par domaine ;
- l'organisation des routes, des contrôleurs et des vues par domaine ;
- la structure des composants Livewire et Filament au-delà de leur rôle d'interface ;
- le mécanisme d'enregistrement des providers de domaine, si un provider s'avère nécessaire ;
- le mécanisme de synchronisation hors connexion et d'idempotence ;
- la stratégie de cache, de files d'attente et de notifications ;
- la matrice détaillée des rôles et permissions.

Ces sujets ne doivent pas être tranchés par une convention locale improvisée. Ils nécessitent une décision explicite.

### 16.3 Checklist de revue

- [ ] La classe est placée dans le répertoire correspondant à sa responsabilité.
- [ ] Le dossier n'a pas été créé sans classe réelle.
- [ ] Le nom respecte les conventions de la section 12.
- [ ] Une Action ne regroupe pas plusieurs opérations sans rapport.
- [ ] Un Service ne contient pas une opération métier complète.
- [ ] Un DTO n'est pas créé sans bénéfice concret.
- [ ] Un Event représente un fait métier et est publié après commit.
- [ ] Aucun événement inter-domaines n'est improvisé (CHAN-28).
- [ ] Une Policy ne réalise aucune écriture.
- [ ] Une Policy ne vérifie que les droits, pas l'état métier de la ressource.
- [ ] Une Action sensible vérifie explicitement l'autorisation avec l'acteur concerné.
- [ ] La découverte effective de la Policy est vérifiée par un test ciblé lorsque la Policy est utilisée.
- [ ] Les règles métier critiques sont appliquées dans le domaine.
- [ ] L'interface ne porte pas de règle métier critique.
- [ ] La transaction est gérée au niveau approprié.
- [ ] L'autorisation est vérifiée côté serveur.
- [ ] Aucune dépendance directe à un Model d'un autre domaine n'est introduite.
- [ ] Aucun composant n'a été créé uniquement pour respecter une symétrie de structure.

### 16.4 Références

- [`AGENTS.md`](../../AGENTS.md) — règles générales du dépôt.
- [`app/Domains/README.md`](../../app/Domains/README.md) — périmètre et organisation des domaines.
- [`app/Core/README.md`](../../app/Core/README.md) — composants techniques transverses.
- [`docs/development/git-workflow.md`](../development/git-workflow.md) — branches, commits et Pull Requests.
- [Laravel 13 — Authorization](https://laravel.com/docs/13.x/authorization) — découverte et enregistrement des Policies.
- [Jira — CHAN-27](https://sarlc2me.atlassian.net/browse/CHAN-27) — ticket de référence.
- [Jira — CHAN-10](https://sarlc2me.atlassian.net/browse/CHAN-10) — architecture Modular Monolith.
