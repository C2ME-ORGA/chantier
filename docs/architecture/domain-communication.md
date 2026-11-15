# Communication inter-domaines : contrats synchrones et événements

Ce document définit les conventions applicables aux **échanges entre domaines métier** de **C2ME Chantier** :

- les **contrats synchrones** (Lot 2), lorsqu'un domaine demande une capacité à un autre et attend une réponse immédiate ;
- les **événements inter-domaines** (Lot 3), lorsqu'un domaine annonce un fait métier accompli auquel d'autres domaines peuvent réagir indépendamment.

**Repères.**

- Ticket : CHAN-28 — Définir les contrats et règles de communication inter-domaines.
- Ticket parent : CHAN-10 — Mettre en place l'architecture Modular Monolith.
- Portée : contrats synchrones (sections 1 à 14), événements inter-domaines (sections 15 à 22), propriété, structure, publication, consommation, idempotence, erreurs, tests et évolution.
- Hors portée : files d'attente supervisées, Outbox, broker externe, architecture distribuée, matrice de dépendances CHAN-29, tests d'architecture CHAN-31 et harmonisation générale de `AGENTS.md` CHAN-30.

> **Statut : document de travail — Lots 2 et 3.**
>
> Le Lot 2 formalise les contrats synchrones. Le Lot 3 formalise les événements inter-domaines. Aucun contrat, DTO, Model de domaine, Action, Service, événement, listener ou provider de domaine n'est implémenté à ce stade : les exemples sont **fictifs et pédagogiques**. Ils ne représentent ni un besoin métier validé, ni une fonctionnalité existante.
>
> Le Lot 3 est **documentaire**. Il ne crée aucune classe PHP, aucun test applicatif, aucune migration, aucune dépendance, aucun broker, aucune file d'attente supervisée et aucune configuration. Les règles ci-dessous décrivent la cible à respecter lors de l'implémentation réelle des premiers événements.

Les conventions internes d'un domaine restent définies par [`domain-conventions.md`](domain-conventions.md) (CHAN-27). Ce document ne les remplace pas ; il les complète pour la frontière entre domaines.

Les sections 1 à 14 sont la référence des contrats synchrones et ne sont pas rouvertes par le Lot 3. Les sections 15 à 22 sont la référence des événements inter-domaines. Les règles communes sont référencées, pas recopiées : propriété du contrat, interdiction d'importer l'implémentation interne, payload typé, absence de Model Eloquent dans les signatures publiques, autorisation côté fournisseur et discipline d'évolution.

---

> **Partie I — Contrats synchrones.** Les sections 1 à 14 formalisent les contrats synchrones du Lot 2.

## 1. Objectif et principes

### 1.1 Objectif

Permettre à un domaine de consommer une capacité d'un autre domaine de façon :

- explicite ;
- typée ;
- testable ;
- compatible avec les invariants du fournisseur ;
- indépendante de l'organisation interne du fournisseur ;
- suffisamment simple pour ne pas transformer le modular monolith en architecture distribuée.

### 1.2 Principes

1. **Le fournisseur est propriétaire de sa capacité et de son contrat.** Le domaine qui possède la donnée, l'invariant ou la décision expose le contrat public correspondant.
2. **Le consommateur dépend du contrat, pas de l'implémentation.** Il n'importe ni les Models, ni les Actions, ni les Services, ni les tables du fournisseur.
3. **Un contrat n'existe que pour un consommateur réel.** Aucun contrat, dossier `Contracts/` ou DTO public ne doit être créé pour anticiper un besoin hypothétique.
4. **Le contrat est une frontière, pas un framework.** Il ne doit pas introduire de hiérarchie générique, de `BaseContract`, de `BaseDTO` ou de bus interne maison.
5. **Les signatures publiques sont explicites et typées.** Aucun Model Eloquent, Builder, Collection Eloquent, `Request`, vue ou objet Livewire/Filament ne traverse la frontière.
6. **Le fournisseur protège ses invariants et ses autorisations.** Le consommateur ne contourne ni les règles métier, ni les droits.
7. **Pas de transaction partagée implicite.** Une opération inter-domaines ne doit pas devenir une transaction distribuée improvisée.
8. **Le serveur reste l'autorité.** Les données du navigateur et du mode hors connexion ne sont jamais considérées comme fiables (`AGENTS.md:64-67`).
9. **Minimalisme.** Une classe concrète suffit souvent ; une interface, un provider ou un DTO supplémentaire doit apporter un bénéfice démontrable.
10. **Pas d'anticipation de CHAN-29.** Ce document définit la forme des échanges, pas la matrice des dépendances autorisées entre domaines.
11. **Le mécanisme suit le besoin.** Une réponse immédiate nécessaire à la poursuite d'une opération exige un contrat synchrone. Une réaction indépendante à un fait accompli relève d'un événement. Aucun des deux mécanismes ne remplace l'autre : un événement n'est pas un RPC déguisé et un contrat synchrone n'est pas un canal de notification.

### 1.3 Niveaux de règle

Les niveaux reprennent le vocabulaire de CHAN-27.

| Terme | Signification |
| --- | --- |
| **Obligatoire** | Une dérogation exige une justification explicite en revue et, si elle est structurante, une décision d'architecture documentée. |
| **Recommandé** | Pratique par défaut. Une alternative est acceptable si elle est plus simple et justifiée. |
| **Conditionnel** | S'applique uniquement lorsqu'un besoin concret est présent. |
| **Hors périmètre** | Sujet traité par un autre ticket ; ne pas l'implémenter dans CHAN-28. |

## 2. Vocabulaire

| Terme | Définition |
| --- | --- |
| **Domaine fournisseur** | Domaine qui possède la donnée, l'invariant ou la décision exposée. |
| **Domaine consommateur** | Domaine qui a besoin de la capacité et dépend du contrat public. |
| **Contrat synchrone** | API publique permettant à un consommateur d'obtenir une réponse immédiate du fournisseur. |
| **Contrat public inter-domaines** | Élément importable par un autre domaine : contrat, DTO public, exception publique. |
| **Implémentation interne** | Model, Action, Service, DTO interne, Policy ou logique non importable par un autre domaine. |
| **Port consommateur** | Interface définie par le consommateur, implémentée par un adaptateur, lorsque l'inversion de dépendance est réellement justifiée. |
| **DTO public** | Objet de transport typé, immuable si pertinent, faisant partie du contrat public. |
| **Exception de contrat** | Exception publique, stable, décrivant un refus ou un conflit prévu par le contrat. |
| **Acteur** | Utilisateur ou système à l'origine de l'appel, lorsque l'autorisation ou la traçabilité l'exigent. |
| **Capacité** | Ce que le fournisseur sait faire ou décider : vérifier une disponibilité, calculer un montant, réserver une ressource, etc. |
| **Effet de bord** | Écriture, notification, envoi, réservation ou tout changement observable produit par l'appel. |

Le « contrat public » de ce document est une **API interne** entre domaines. Il ne doit pas être confondu avec le « contrat public » externe de [`release-process.md`](../development/release-process.md), qui couvre les routes HTTP, les formats hors connexion, les exports et les intégrations externes.

## 3. Décisions de cadrage

Ces décisions sont celles validées pour CHAN-28. Elles ne sont pas rouvertes par ce document.

| Sujet | Décision |
| --- | --- |
| Propriété | Le domaine fournisseur est propriétaire de son contrat public par défaut. |
| Emplacement | `app/Domains/{Provider}/Contracts/` |
| Forme | Interface non imposée ; classe concrète par défaut lorsque cela suffit. |
| Données | Entrées et sorties typées ; pas de Model Eloquent dans les signatures publiques. |
| Identité | Pas de `App\Models\User` dans l'API publique ; représentation minimale explicite si nécessaire. |
| Périmètre | Contrats synchrones (sections 1 à 14) ; événements inter-domaines traités au Lot 3 (sections 15 à 22). |

Les décisions propres aux événements inter-domaines sont formalisées en section 15.10. Elles complètent ce tableau sans rouvrir les décisions des contrats synchrones.

## 4. Structure et namespaces

### 4.1 Emplacement par défaut

```text
app/
└── Domains/
    └── ReferenceProvider/
        ├── Contracts/
        │   ├── ReferenceAvailability.php
        │   ├── ReferenceAvailabilityQuery.php
        │   ├── ReferenceAvailabilityResult.php
        │   └── Exceptions/
        │       └── ReferenceNotFoundException.php
        ├── Models/
        │   └── ReferenceItem.php
        ├── Actions/
        ├── Services/
        ├── DTO/
        └── Events/
```

Le répertoire `Contracts/` est créé **uniquement lorsqu'il reçoit son premier contrat réel**. Il ne doit pas être créé dans les 18 domaines pour préparer l'architecture.

### 4.2 Namespaces

| Élément | Namespace | Exemple |
| --- | --- | --- |
| Contrat public | `App\Domains\{Provider}\Contracts` | `App\Domains\ReferenceProvider\Contracts` |
| DTO public | `App\Domains\{Provider}\Contracts` | `App\Domains\ReferenceProvider\Contracts\ReferenceAvailabilityQuery` |
| Exception publique | `App\Domains\{Provider}\Contracts\Exceptions` | `App\Domains\ReferenceProvider\Contracts\Exceptions\ReferenceNotFoundException` |
| Implémentation interne | `App\Domains\{Provider}\Services` | `App\Domains\ReferenceProvider\Services\ReferenceAvailabilityChecker` |
| Model interne | `App\Domains\{Provider}\Models` | `App\Domains\ReferenceProvider\Models\ReferenceItem` |

Le mapping PSR-4 `App\` vers `app/` couvre déjà ces namespaces (`composer.json:32-38`). Aucune modification de `composer.json` n'est nécessaire.

### 4.3 Nommage

| Élément | Convention | Exemples | À éviter |
| --- | --- | --- | --- |
| Contrat | Nom de la capacité, sans suffixe `Contract`, `Interface` ou `Service` | `ReferenceAvailability`, `StockAvailability`, `BudgetCommitment` | `ReferenceAvailabilityContract`, `ReferenceService`, `Manager` |
| Méthode du contrat | Verbe explicite décrivant l'opération | `check()`, `calculate()`, `reserve()` | `handle()`, `process()`, `execute()` |
| DTO d'entrée | `<Capacité>Query` pour une lecture/décision, `<Capacité>Command` pour une commande | `ReferenceAvailabilityQuery`, `StockReservationCommand` | `ReferenceRequest`, `InputData`, `Payload` |
| DTO de sortie | `<Capacité>Result` | `ReferenceAvailabilityResult`, `StockReservationResult` | `ReferenceResponse`, `OutputData` |
| Exception publique | `<Raison>Exception` | `ReferenceNotFoundException`, `StockConflictException` | `ContractException`, `BusinessError`, `Error` |
| Port consommateur | Nom du besoin du consommateur | `ReferenceLookup` | `ReferenceProviderAdapterInterface` |

Les suffixes `Query`, `Command` et `Result` sont des conventions de contrat synchrone. Ils ne remplacent pas la convention `Data` de CHAN-27 pour les DTO internes. Un DTO public peut aussi utiliser le suffixe `Data` s'il clarifie davantage le rôle ; il faut rester cohérent au sein d'un même contrat.

### 4.4 Contrat public et implémentation interne

| Élément | Importable par un autre domaine | Remarque |
| --- | --- | --- |
| `Contracts/` | **Oui** | Surface publique synchrone du fournisseur. |
| `Contracts/Exceptions/` | **Oui** | Exceptions déclarées par le contrat. |
| `Events/Integration/` | **Oui** | Surface publique événementielle du fournisseur (Partie II). |
| `Models/` | **Non** | Aucun Model Eloquent ne traverse la frontière. |
| `Actions/` | **Non** | Une Action porte autorisation, transaction et intention d'interface ; ce n'est pas une API. |
| `Services/` | **Non** | Logique interne, non stabilisée. |
| `DTO/` | **Non** | DTO internes, libres d'évoluer. |
| `Policies/` | **Non** | Chaque domaine applique ses propres droits. |
| `Events/` local | **Non** | Événement local au domaine ; il ne traverse pas la frontière. |

**Règle de lecture :** pour la surface d'échange définie par CHAN-28, un consommateur importe uniquement `App\Domains\{Provider}\Contracts\...` et `App\Domains\{Provider}\Events\Integration\...`, et rien d'autre du fournisseur. La matrice des dépendances autorisées entre domaines reste du ressort de CHAN-29.

### 4.5 Importations autorisées et interdites

```php
// Autorisé : contrat public, DTO public et événement d'intégration public.
use App\Domains\ReferenceProvider\Contracts\ReferenceAvailability;
use App\Domains\ReferenceProvider\Contracts\ReferenceAvailabilityQuery;
use App\Domains\ReferenceProvider\Contracts\ReferenceAvailabilityResult;
use App\Domains\ReferenceProvider\Contracts\Exceptions\ReferenceNotFoundException;
use App\Domains\Projects\Events\Integration\AffaireOpened;

// Interdit : implémentation interne du fournisseur.
use App\Domains\ReferenceProvider\Models\ReferenceItem;
use App\Domains\ReferenceProvider\Services\ReferenceAvailabilityChecker;
use App\Domains\ReferenceProvider\DTO\ReferenceAvailabilityData;
use App\Domains\ReferenceProvider\Actions\CheckReference;
use App\Domains\Clients\Events\ClientCreated; // événement local, non importable
```

Un contrat ne doit pas exposer un objet interne « stabilisé par commodité ». Si un objet interne doit devenir public, il doit être déplacé ou dupliqué sous une forme publique explicite, avec une revue de compatibilité.

### 4.6 DTO interne, DTO public, Model et objet de valeur

| Élément | Rôle | Peut être public ? | Dépendances autorisées |
| --- | --- | --- | --- |
| DTO interne (`DTO/`) | Transport interne au domaine | Non | Peut dépendre de types internes |
| DTO public (`Contracts/`) | Entrée/sortie d'un contrat | Oui | Types scalaires, enums, dates, objets de valeur publics |
| Model Eloquent (`Models/`) | Persistance | Non | Interne au domaine |
| Objet de valeur métier | Concept avec invariants | Oui, si stable et autonome | Types scalaires, autres objets de valeur publics |

Un DTO public ne doit pas contenir de méthode `fromModel()` qui importerait un Model interne. La conversion Model → DTO public appartient à l'implémentation du fournisseur.

## 5. Choix de la forme du contrat

### 5.1 Arbre de décision

```text
Un autre domaine a-t-il besoin d'une capacité synchrone ?
├─ Non
│  └─ Ne rien créer.
└─ Oui
   ├─ Le fournisseur possède-t-il la donnée, l'invariant ou la décision ?
   │  ├─ Oui
   │  │  ├─ Une substitution réelle est-elle nécessaire ?
   │  │  │  ├─ Non → classe concrète publique dans Contracts/
   │  │  │  └─ Oui → interface publique + implémentation dans Services/
   │  └─ Non
   │     └─ Le besoin est-il spécifique au consommateur ou le fournisseur est-il volatil ?
   │        ├─ Oui → port consommateur + adaptateur
   │        └─ Non → clarifier la propriété avant de créer un contrat
   └─ Un seul contrat doit couvrir la capacité ; ne pas créer deux contrats concurrents.
```

### 5.2 Classe concrète publique

**Cas d'usage :** le besoin est générique, le fournisseur possède la donnée et l'invariant, aucune substitution n'est nécessaire.

```php
namespace App\Domains\ReferenceProvider\Contracts;

final class ReferenceAvailability
{
    public function check(ReferenceAvailabilityQuery $query): ReferenceAvailabilityResult
    {
        // Implémentation interne au fournisseur.
    }
}
```

| Avantage | Coût |
| --- | --- |
| Aucun binding, aucun provider | Le consommateur dépend d'une classe concrète |
| Autowiring Laravel direct | Substitution de test moins directe si la classe est `final` |
| Lecture immédiate du contrat | Risque de faire grossir la classe si l'implémentation est complexe |
| Moins de classes, moins d'indirection | Le contrat et l'implémentation ne sont pas séparés |

**Recommandation :** classe concrète `final` par défaut. Si l'implémentation devient complexe, si elle doit être substituée ou si plusieurs implémentations sont réelles, convertir en interface + implémentation interne.

### 5.3 Interface publique avec implémentation interne

**Cas d'usage :** plusieurs implémentations réelles, isolation d'un système externe, substitution nécessaire en test, ou volonté explicite de séparer le contrat de l'implémentation.

```php
namespace App\Domains\ReferenceProvider\Contracts;

interface ReferenceAvailability
{
    public function check(ReferenceAvailabilityQuery $query): ReferenceAvailabilityResult;
}
```

```php
namespace App\Domains\ReferenceProvider\Services;

use App\Domains\ReferenceProvider\Contracts\ReferenceAvailability;
use App\Domains\ReferenceProvider\Contracts\ReferenceAvailabilityQuery;
use App\Domains\ReferenceProvider\Contracts\ReferenceAvailabilityResult;

final class ReferenceAvailabilityChecker implements ReferenceAvailability
{
    public function check(ReferenceAvailabilityQuery $query): ReferenceAvailabilityResult
    {
        // Implémentation interne.
    }
}
```

| Avantage | Coût |
| --- | --- |
| Contrat et implémentation séparés | Une classe et un binding supplémentaires |
| Substitution explicite en test | Un provider ou un enregistrement doit exister |
| Plusieurs implémentations possibles | Risque d'abstraction prématurée |
| Le consommateur ne dépend que de l'interface | Le container devient une dépendance de câblage |

**Recommandation :** interface uniquement si la substitution ou la séparation apporte un bénéfice réel. Ne pas créer une interface « pour respecter l'architecture » lorsqu'une classe concrète suffit.

### 5.4 Port appartenant au consommateur

**Cas d'usage :** le besoin est propre au consommateur, le fournisseur est volatil, plusieurs fournisseurs sont possibles, ou le consommateur doit isoler une dépendance externe.

```text
app/Domains/ReferenceConsumer/
├── Ports/
│   └── ReferenceLookup.php
├── Adapters/
│   └── ProviderReferenceLookup.php
└── Actions/
    └── CheckReferenceBeforeUse.php
```

```php
namespace App\Domains\ReferenceConsumer\Ports;

use App\Domains\ReferenceConsumer\DTO\ReferenceLookupResult;

interface ReferenceLookup
{
    public function find(string $reference): ?ReferenceLookupResult;
}
```

| Avantage | Coût |
| --- | --- |
| Le consommateur définit uniquement son besoin | Un adaptateur et un binding supplémentaires |
| Le fournisseur peut évoluer derrière l'adaptateur | Duplication possible entre consommateurs |
| Test du consommateur sans fournisseur | Le couplage runtime existe toujours |
| Plusieurs fournisseurs possibles | Risque de masquer une dépendance forte |

**Recommandation :** port consommateur exceptionnel, justifié dans la Pull Request. Il ne doit pas créer un second contrat concurrent pour la même capacité. Si le fournisseur expose déjà un contrat public stable, le consommer directement est plus simple.

### 5.5 Comparaison synthétique

| Critère | Classe concrète fournisseur | Interface fournisseur | Port consommateur |
| --- | --- | --- | --- |
| Nombre de classes | 1 | 2 + binding | 2 + adaptateur + binding |
| Binding Laravel | Aucun | Obligatoire | Obligatoire |
| Substitution en test | Limitée si `final` | Facile | Facile |
| Couplage au fournisseur | Direct mais explicite | Via contrat | Via adaptateur |
| Risque d'abstraction prématurée | Faible | Moyen | Élevé |
| Cas par défaut | **Oui** | Conditionnel | Exceptionnel |

## 6. DTO et types échangés

### 6.1 Règles des DTO publics

| Règle | Niveau |
| --- | --- |
| Le DTO public est `final readonly` lorsque l'immutabilité est pertinente. | Recommandé |
| Les propriétés sont typées et promues par le constructeur. | Obligatoire |
| Aucun Model Eloquent, Builder ou Collection Eloquent dans une signature publique. | Obligatoire |
| Aucun tableau non typé servant de structure publique. | Obligatoire |
| Aucun type Livewire, Filament, HTTP, vue ou `Request`. | Obligatoire |
| Aucune donnée sensible inutile. | Obligatoire |
| Aucune logique de persistance, requête ou validation métier dans le DTO. | Obligatoire |
| Aucune méthode `fromModel()` dépendant d'un Model interne. | Obligatoire |
| Le DTO ne doit pas être un Model déguisé. | Obligatoire |
| Un DTO n'est créé que s'il apporte un bénéfice réel (CHAN-27 §6). | Recommandé |

### 6.2 Types autorisés

| Type | Usage | Remarque |
| --- | --- | --- |
| `string`, `int`, `float`, `bool` | Valeurs simples | Éviter `float` pour les montants. |
| `?Type` | Absence explicitement prévue | Ne pas utiliser `null` pour masquer une erreur. |
| Enum backed | Statut ou catégorie stable | Ajouter un cas peut être un changement de contrat. |
| `DateTimeImmutable` / `CarbonImmutable` | Date/heure | Le projet configure `CarbonImmutable` par défaut (`AppServiceProvider.php:34`). |
| Objet de valeur public | Identifiant typé, intervalle, quantité | Uniquement s'il est stable et autonome. |
| `array` typé par PHPDoc | Liste simple de DTO publics | Préférer une collection dédiée si un comportement est nécessaire. |

Les types `mixed`, `object`, `array` sans type et les unions non documentées sont interdits dans une signature publique.

### 6.3 Identifiants, dates et montants

- **Identifiants :** la stratégie UUID/ULID n'est pas encore décidée dans le projet. Le contrat doit utiliser le type réellement retenu par le domaine propriétaire. Ne pas inventer un type d'identifiant global dans CHAN-28.
- **Dates :** utiliser un type immuable, avec un fuseau explicite ou une convention UTC documentée. Ne pas transporter une date sous forme de chaîne non typée.
- **Montants :** ne pas utiliser `float`. L'unité (centimes, unité entière, devise) doit être explicite et cohérente avec la décision du domaine. Aucune convention monétaire globale n'est fixée par ce lot.
- **Quantités :** préciser l'unité et la précision. Ne pas mélanger unités et quantités dans un même champ.

Ces points devront être coordonnés avec CHAN-29 ou une décision transversale ultérieure s'ils deviennent structurants.

### 6.4 Nullabilité et absence

| Situation | Représentation recommandée |
| --- | --- |
| Absence normale et attendue | Propriété nullable ou résultat typé avec statut `NotFound` |
| Absence exceptionnelle pour le contrat | Exception publique dédiée |
| Refus métier | Exception publique dédiée |
| Conflit d'état | Exception publique dédiée |
| Erreur technique | Exception technique propagée, non convertie en résultat métier |
| Erreur de programmation | `LogicException` / `InvalidArgumentException`, non masquée |

Une propriété nullable doit être documentée : le consommateur doit savoir si `null` signifie « absent », « inconnu » ou « non applicable ».

### 6.5 Collections

- Ne jamais retourner une `Illuminate\Database\Eloquent\Collection`.
- Pour une liste simple de DTO publics, un `array` avec PHPDoc `list<ReferenceAvailabilityResult>` peut suffire.
- Si la collection porte un comportement ou un invariant, créer un objet de collection public dédié, sans hériter d'une collection Eloquent.
- Ne pas créer de hiérarchie `BaseCollection` ou `DataCollection` générique.

### 6.6 Données sensibles

Le contrat expose le minimum nécessaire. Aucune donnée bancaire, mot de passe, token, secret ou donnée personnelle non indispensable ne doit figurer dans un DTO public. Les exceptions publiques ne doivent pas contenir de détails internes, de SQL, de trace ou de données sensibles.

## 7. Erreurs et résultats

### 7.1 Catégories

| Catégorie | Représentation | Comportement du consommateur |
| --- | --- | --- |
| Succès avec valeur | Type de retour explicite ou DTO `Result` | Utilise la valeur. |
| Absence normale | `null` documenté ou statut `NotFound` dans un résultat | Traite l'absence comme un cas prévu. |
| Refus métier | Exception publique dédiée | Capture uniquement l'exception déclarée et applique sa règle. |
| Conflit d'état | Exception publique dédiée | Peut demander une reprise ou signaler le conflit. |
| Ressource indisponible | Exception technique ou exception de contrat dédiée | Ne pas présenter comme un refus métier si c'est une panne. |
| Erreur technique | Exception technique propagée | Laisse remonter ou traite au niveau approprié. |
| Erreur de programmation | `LogicException` / `InvalidArgumentException` | Ne pas capturer silencieusement ; corriger le code. |
| Erreur inattendue | Exception originale, journalisée | Ne pas la convertir en résultat métier trompeur. |

### 7.2 Règles

| Règle | Niveau |
| --- | --- |
| Un contrat déclare ses exceptions métier dans sa documentation (`@throws`). | Obligatoire |
| Une exception publique est stable, nommée par sa raison et située dans `Contracts/Exceptions/`. | Obligatoire |
| Une exception publique ne contient ni détail interne, ni donnée sensible. | Obligatoire |
| Une erreur technique n'est jamais transformée en résultat métier trompeur. | Obligatoire |
| Le consommateur ne capture pas `\Throwable` pour masquer une erreur. | Obligatoire |
| Le consommateur capture uniquement les exceptions prévues par le contrat. | Recommandé |
| Un `null` ne doit pas signifier plusieurs choses à la fois. | Obligatoire |
| Les erreurs de programmation ne sont pas converties en erreurs métier. | Obligatoire |
| Un résultat typé peut être utilisé lorsque plusieurs issues normales sont prévues. | Conditionnel |

### 7.3 Résultat ou exception ?

| Situation | Mécanisme |
| --- | --- |
| La réponse est une valeur simple | Type de retour direct |
| Plusieurs issues normales et aucune n'est exceptionnelle | DTO `Result` avec enum de statut |
| Le contrat ne peut pas répondre à cause d'une règle métier | Exception publique |
| Le contrat détecte un conflit de version ou d'état | Exception publique |
| Le fournisseur est techniquement indisponible | Exception technique, éventuellement enveloppée avec `previous` |
| Le contrat est mal appelé | `InvalidArgumentException` |

Ne pas créer un `Result` générique pour toutes les réponses. Un `Result` n'est utile que si le contrat a réellement plusieurs issues normales à distinguer.

### 7.4 Exceptions publiques

```php
namespace App\Domains\ReferenceProvider\Contracts\Exceptions;

use RuntimeException;

final class ReferenceNotFoundException extends RuntimeException
{
}
```

Une exception publique peut exposer un accesseur minimal si le consommateur en a besoin, par exemple un code stable. Elle ne doit pas exposer le Model, la requête SQL ou la trace interne.

### 7.5 Erreurs techniques

Une panne de base, un timeout ou une indisponibilité d'un service externe ne doit pas être présenté comme « référence indisponible » si cela change le sens métier. Le fournisseur peut envelopper l'erreur technique dans une exception dédiée en conservant `previous` :

```php
throw new ReferenceLookupFailedException(
    'The reference lookup failed.',
    previous: $exception,
);
```

Le message public reste générique ; le détail technique est journalisé côté fournisseur, sans données sensibles.

### 7.6 Autorisation

Le contrat ne doit pas exposer `App\Models\User`. Si l'acteur est nécessaire, utiliser une représentation minimale :

- un identifiant scalaire (`int` ou `string`) aligné sur la stratégie Identity ;
- un objet de valeur ou DTO public minimal si plusieurs informations sont réellement nécessaires ;
- aucun acteur pour un contrat système explicitement documenté.

| Représentation | Avantage | Limite |
| --- | --- | --- |
| Identifiant scalaire | Minimal, sans dépendance à un Model | Le type doit être aligné sur Identity ; ne transporte pas les rôles. |
| DTO d'acteur public | Explicite si plusieurs données sont nécessaires | Risque de dupliquer l'identité et ses règles. |
| Aucun acteur | Adapté à un contrat système | L'absence d'acteur doit être documentée et ne doit pas masquer une autorisation. |

Une autorisation refusée peut être représentée par une exception publique dédiée si le refus est exceptionnel, ou par un statut explicite dans un résultat si le refus est un cas normal du contrat. Le choix doit être documenté et cohérent pour tout le contrat.

Le fournisseur applique ses propres Policies/Gates. Le consommateur ne doit pas vérifier l'autorisation à la place du fournisseur, ni considérer qu'un acteur transmis vaut autorisation.

Le type exact de l'acteur dépend de la décision Identity, non tranchée par CHAN-28. Tant qu'elle n'est pas prise, un contrat nécessitant un acteur doit être différé ou documenter explicitement le type scalaire utilisé.

## 8. Injection et bindings Laravel

### 8.1 Comportement vérifié dans Laravel 13

| Capacité | Constat | Référence |
| --- | --- | --- |
| Autowiring d'une classe concrète | Le container construit la classe par réflexion et résout ses dépendances | `vendor/laravel/framework/src/Illuminate/Container/Container.php:1135-1200` |
| Résolution d'une interface non liée | Échec `BindingResolutionException` | `Container.php:1434-1445` |
| Binding explicite | `bind()`, `singleton()`, `scoped()` disponibles | `Container.php:359`, `:502`, `:528` |
| Résolution contextuelle | `when()->needs()->give()` disponible | `ContextualBindingBuilder.php:49-69` |
| Attributs de binding | `#[Bind]`, `#[BindWhen]`, `#[Give]` disponibles | `Illuminate/Container/Attributes/` |
| Chargement des providers | `bootstrap/providers.php` est fusionné dans `app.providers` | `RegisterProviders.php:45-65` |
| Enregistrement des bindings | `register()` du provider | `ServiceProvider.php:97` |
| État actuel du projet | `AppServiceProvider::register()` est vide ; aucun provider de domaine | `app/Providers/AppServiceProvider.php:16-19`, `bootstrap/providers.php:6-9` |

### 8.2 Classe concrète

Une classe concrète publique est injectée directement :

```php
final class CheckReferenceBeforeUse
{
    public function __construct(
        private readonly ReferenceAvailability $availability,
    ) {}
}
```

Aucun binding, aucun provider et aucune modification de `bootstrap/providers.php` ne sont nécessaires. C'est la solution par défaut.

### 8.3 Interface publique

Une interface nécessite un binding explicite :

```php
namespace App\Domains\ReferenceProvider\Providers;

use App\Domains\ReferenceProvider\Contracts\ReferenceAvailability;
use App\Domains\ReferenceProvider\Services\ReferenceAvailabilityChecker;
use Illuminate\Support\ServiceProvider;

final class ReferenceProviderServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->bind(
            ReferenceAvailability::class,
            ReferenceAvailabilityChecker::class,
        );
    }
}
```

Le binding est enregistré dans `register()`, pas dans `boot()`. `bind()` crée une nouvelle instance à chaque résolution ; `singleton()` ne doit être utilisé que si le contrat est sans état et que le partage est réellement souhaité.

### 8.4 Emplacement du provider

Si un provider de domaine est réellement nécessaire, le placer dans le domaine propriétaire :

```text
app/Domains/ReferenceProvider/Providers/ReferenceProviderServiceProvider.php
```

et l'enregistrer dans `bootstrap/providers.php` :

```php
use App\Domains\ReferenceProvider\Providers\ReferenceProviderServiceProvider;
use App\Providers\AppServiceProvider;
use App\Providers\Filament\AdminPanelProvider;

return [
    AppServiceProvider::class,
    AdminPanelProvider::class,
    ReferenceProviderServiceProvider::class,
];
```

**Règles :**

| Règle | Niveau |
| --- | --- |
| Ne pas créer de provider de domaine sans binding ou enregistrement réel. | Obligatoire |
| Un provider de domaine est propriétaire de ses bindings. | Recommandé |
| `AppServiceProvider` ne doit pas devenir un registre de bindings métier. | Recommandé |
| Un provider de domaine est enregistré dans `bootstrap/providers.php`. | Obligatoire |
| Le binding est déclaré dans `register()`. | Obligatoire |
| Le provider ne contient pas de logique métier. | Obligatoire |

Un binding unique et temporaire dans `AppServiceProvider::register()` reste possible, mais il doit être justifié et déplacé dès qu'un provider de domaine existe. Ne pas créer un provider par domaine « pour l'organisation ».

### 8.5 Résolution contextuelle

Laravel permet de résoudre une même interface différemment selon la classe consommatrice :

```php
$this->app->when(SomeConsumer::class)
    ->needs(ReferenceAvailability::class)
    ->give(SomeConsumerReferenceAvailability::class);
```

Cette possibilité est disponible, mais elle n'est **pas recommandée par défaut** pour les contrats inter-domaines : elle rend le câblage implicite et peut masquer deux contrats concurrents. Elle ne doit être utilisée que si un même besoin a réellement plusieurs implémentations selon le consommateur, avec une justification documentée.

Les attributs `#[Bind]`, `#[BindWhen]` et `#[Give]` existent également. Ils sont écartés par défaut pour la même raison : le binding explicite dans un provider reste plus lisible et plus facile à tester.

### 8.6 Ce qu'il ne faut pas faire

- `app(ReferenceAvailability::class)` dans le code métier : préférer l'injection par constructeur.
- Un `ServiceLocator` ou un `Container` injecté dans une Action pour résoudre des contrats.
- Un binding d'interface sans provider ni enregistrement.
- Un provider de domaine vide.
- Un `singleton` sur un contrat qui contient un état de requête.
- Un binding dans `boot()` alors qu'il doit être disponible avant le boot des autres providers.

### 8.7 Substitution en test

Pour une interface, le test peut remplacer l'implémentation :

```php
$this->app->bind(ReferenceAvailability::class, FakeReferenceAvailability::class);
```

Pour une classe concrète, préférer un test d'intégration avec la vraie implémentation et une base de test. Ne pas créer une interface uniquement pour pouvoir mocker : c'est une abstraction prématurée si aucun autre besoin ne la justifie.

## 9. Transactions et effets de bord

### 9.1 Responsabilité du fournisseur

Le fournisseur reste responsable de ses invariants et de ses écritures. Le consommateur ne manipule jamais directement les Models ou les tables du fournisseur.

| Règle | Niveau |
| --- | --- |
| Lorsqu'une transaction est nécessaire, le fournisseur l'ouvre et la ferme. | Obligatoire |
| Le consommateur ne complète pas une écriture du fournisseur par une écriture directe. | Obligatoire |
| Un contrat de lecture ou de décision ne doit pas avoir d'effet de bord. | Recommandé |
| Un contrat de commande doit documenter ses effets de bord et son idempotence. | Obligatoire |
| Le contrat ne doit pas exposer une API générique de modification de toutes les données du fournisseur. | Obligatoire |

### 9.2 Lecture et décision

Un contrat de lecture ou de décision :

- lit les données du fournisseur ;
- applique ses règles d'accès ;
- retourne un DTO public ;
- ne modifie rien ;
- ne publie pas d'événement métier ;
- ne déclenche pas d'effet de bord caché.

Si un contrat de lecture doit journaliser ou auditer, cet effet doit être explicitement documenté et ne doit pas modifier l'état métier.

### 9.3 Commande synchrone

Une commande synchrone est une exception, pas la norme. Elle peut être justifiée lorsqu'un domaine doit demander à un autre une opération dont il a besoin immédiatement, par exemple une réservation explicite.

Une commande synchrone doit :

- être nommée comme une opération (`Reserve...`, `Commit...`, `Allocate...`) ;
- avoir un DTO de commande explicite ;
- retourner un résultat typé ;
- documenter ses effets de bord ;
- être idempotente lorsque le risque de double appel existe ;
- faire porter la transaction au fournisseur ;
- ne pas permettre au consommateur de modifier des champs arbitraires.

### 9.4 Transaction partagée

**Par défaut, aucune transaction partagée entre domaines n'est introduite.** Une transaction qui englobe deux domaines crée un couplage fort, des verrous plus longs et des règles de rollback difficiles à comprendre.

Si une atomicité inter-domaines est réellement nécessaire, elle doit faire l'objet d'une décision explicite (architecture, workflow ou compensation) et non d'un `DB::transaction()` ajouté dans le consommateur autour d'un appel de contrat.

Laravel imbrique les transactions sur une même connexion, mais cela ne rend pas l'opération inter-domaines saine pour autant. Le fait que le framework le permette ne constitue pas une autorisation architecturale.

### 9.5 Erreurs et rollback

- Si le fournisseur échoue avant son commit, il rollback ses écritures et remonte une exception.
- Si le fournisseur a commité puis que le consommateur échoue, le consommateur ne peut pas annuler le commit du fournisseur. Ce cas doit être prévu par le workflow ou la compensation.
- Une exception technique ne doit pas être transformée en « refus métier » pour éviter de traiter le rollback.
- Le consommateur ne doit pas supposer qu'un appel de contrat est atomique avec sa propre écriture.

Les événements d'intégration et la publication après commit sont traités dans la Partie II (sections 15 à 22). Ils ne modifient pas les règles de transaction de la Partie I : le fournisseur reste responsable de sa transaction, et aucune transaction partagée n'est introduite.

### 9.6 Limites

Un contrat ne doit pas devenir :

- un CRUD générique inter-domaines ;
- un moyen de contourner une Action ou une Policy ;
- un accès direct à une table ;
- un outil de migration de données entre domaines ;
- un bus de commandes déguisé.

## 10. Responsabilités du fournisseur et du consommateur

### 10.1 Fournisseur

| Responsabilité | Détail |
| --- | --- |
| Définir la capacité | Le contrat expose une capacité identifiable, pas un ensemble de méthodes sans rapport. |
| Posséder le contrat | Le contrat est dans `app/Domains/{Provider}/Contracts/`. |
| Protéger les invariants | Le fournisseur vérifie ses règles avant de répondre. |
| Contrôler l'autorisation | Le fournisseur applique ses Policies/Gates. |
| Mapper vers le public | Il convertit ses Models en DTO publics. |
| Documenter | Il documente les paramètres, retours, exceptions et effets de bord. |
| Maîtriser l'évolution | Il ne casse pas un contrat sans coordination. |
| Tester | Il teste le comportement réel du contrat. |

### 10.2 Consommateur

| Responsabilité | Détail |
| --- | --- |
| Dépendre du contrat | Il importe uniquement `Contracts/`. |
| Ne pas importer l'interne | Aucun Model, Action, Service, DTO interne, Policy ou table. |
| Utiliser le résultat typé | Il ne reconstruit pas les règles du fournisseur. |
| Gérer les erreurs prévues | Il capture uniquement les exceptions déclarées. |
| Ne pas masquer les erreurs techniques | Il les laisse remonter ou les traite explicitement. |
| Ne pas dupliquer la règle | Il ne réimplémente pas l'invariant du fournisseur. |
| Tester son usage | Il teste l'injection, le résultat et les erreurs. |

### 10.3 Anti-patterns

| Anti-pattern | Problème | Correction |
| --- | --- | --- |
| Contrat qui retourne un Model | Couplage au schéma et aux relations | DTO public |
| Contrat qui expose un Builder | Le consommateur peut contourner les règles | Méthode de contrat explicite |
| Contrat CRUD générique | API instable et dangereuse | Capacités ciblées |
| Consommateur qui importe une Action | Contourne autorisation et transaction | Contrat public |
| Consommateur qui interroge la table du fournisseur | Contourne les invariants | Contrat public |
| Contrat qui appelle le consommateur | Cycle et couplage | Déplacer la responsabilité |
| Interface pour une seule implémentation sans besoin | Complexité | Classe concrète |
| Provider de domaine vide | Bruit architectural | Ne pas le créer |
| Contrat dans `Core` | `Core` dépendrait d'un domaine | Contrat dans le fournisseur |
| Exception générique `BusinessException` | Impossible à traiter précisément | Exceptions nommées |
| `null` pour toutes les erreurs | Le consommateur ne peut pas distinguer les cas | Résultat typé ou exception |

## 11. Exemple complet de référence

> **Exemple fictif.** `ReferenceProvider` et `ReferenceConsumer` ne font pas partie des 18 domaines du projet. Ils illustrent uniquement la convention. Aucune de ces classes ne doit être créée dans `app/Domains/` à la suite de ce lot.

### 11.1 Variante A — classe concrète par défaut

Arborescence :

```text
app/Domains/ReferenceProvider/
├── Contracts/
│   ├── ReferenceAvailability.php
│   ├── ReferenceAvailabilityQuery.php
│   ├── ReferenceAvailabilityResult.php
│   └── Exceptions/
│       └── ReferenceNotFoundException.php
├── Models/
│   └── ReferenceItem.php
└── Services/
    └── ReferenceAvailabilityChecker.php
```

Contrat public :

```php
<?php

namespace App\Domains\ReferenceProvider\Contracts;

use App\Domains\ReferenceProvider\Services\ReferenceAvailabilityChecker;

final class ReferenceAvailability
{
    public function __construct(
        private readonly ReferenceAvailabilityChecker $checker,
    ) {}

    public function check(ReferenceAvailabilityQuery $query): ReferenceAvailabilityResult
    {
        return $this->checker->check($query);
    }
}
```

Implémentation interne :

```php
<?php

namespace App\Domains\ReferenceProvider\Services;

use App\Domains\ReferenceProvider\Contracts\Exceptions\ReferenceNotFoundException;
use App\Domains\ReferenceProvider\Contracts\ReferenceAvailabilityQuery;
use App\Domains\ReferenceProvider\Contracts\ReferenceAvailabilityResult;
use App\Domains\ReferenceProvider\Models\ReferenceItem;
use DateTimeImmutable;

final class ReferenceAvailabilityChecker
{
    public function check(ReferenceAvailabilityQuery $query): ReferenceAvailabilityResult
    {
        $item = ReferenceItem::query()
            ->where('code', $query->reference)
            ->first();

        if ($item === null) {
            throw new ReferenceNotFoundException();
        }

        return new ReferenceAvailabilityResult(
            available: (bool) $item->is_available,
            checkedAt: new DateTimeImmutable(),
        );
    }
}
```

DTO d'entrée :

```php
<?php

namespace App\Domains\ReferenceProvider\Contracts;

final readonly class ReferenceAvailabilityQuery
{
    public function __construct(
        public string $reference,
    ) {}
}
```

DTO de sortie :

```php
<?php

namespace App\Domains\ReferenceProvider\Contracts;

use DateTimeImmutable;

final readonly class ReferenceAvailabilityResult
{
    public function __construct(
        public bool $available,
        public DateTimeImmutable $checkedAt,
    ) {}
}
```

Exception publique :

```php
<?php

namespace App\Domains\ReferenceProvider\Contracts\Exceptions;

use RuntimeException;

final class ReferenceNotFoundException extends RuntimeException
{
}
```

Model interne, non importable par le consommateur :

```php
<?php

namespace App\Domains\ReferenceProvider\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

final class ReferenceItem extends Model
{
    use HasFactory;

    protected $table = 'reference_items';

    protected function casts(): array
    {
        return [
            'is_available' => 'bool',
        ];
    }
}
```

> **Note sur la variante concrète.** La classe publique délègue à un Service interne ; le consommateur n'importe que `ReferenceAvailability`, ses DTO et son exception. Aucun binding n'est nécessaire : le container autowire la classe concrète et son Service interne. Le test de substitution par `implements` n'est **pas applicable** à cette variante : le test consommateur doit utiliser la classe concrète réelle (§11.5). Si une substitution est nécessaire, passer à la variante B.

Dans cette variante :

- le consommateur peut importer `ReferenceAvailability`, `ReferenceAvailabilityQuery`, `ReferenceAvailabilityResult` et `ReferenceNotFoundException` ;
- il ne peut pas importer `ReferenceItem` ni `ReferenceAvailabilityChecker` ;
- aucun binding n'est nécessaire ;
- aucun provider de domaine n'est créé.

### 11.2 Variante B — interface, implémentation et binding

Arborescence :

```text
app/Domains/ReferenceProvider/
├── Contracts/
│   ├── ReferenceAvailability.php
│   ├── ReferenceAvailabilityQuery.php
│   ├── ReferenceAvailabilityResult.php
│   └── Exceptions/
│       └── ReferenceNotFoundException.php
├── Models/
│   └── ReferenceItem.php
├── Services/
│   └── ReferenceAvailabilityChecker.php
└── Providers/
    └── ReferenceProviderServiceProvider.php
```

Contrat public :

```php
<?php

namespace App\Domains\ReferenceProvider\Contracts;

interface ReferenceAvailability
{
    public function check(ReferenceAvailabilityQuery $query): ReferenceAvailabilityResult;
}
```

Implémentation interne :

```php
<?php

namespace App\Domains\ReferenceProvider\Services;

use App\Domains\ReferenceProvider\Contracts\Exceptions\ReferenceNotFoundException;
use App\Domains\ReferenceProvider\Contracts\ReferenceAvailability;
use App\Domains\ReferenceProvider\Contracts\ReferenceAvailabilityQuery;
use App\Domains\ReferenceProvider\Contracts\ReferenceAvailabilityResult;
use App\Domains\ReferenceProvider\Models\ReferenceItem;
use DateTimeImmutable;

final class ReferenceAvailabilityChecker implements ReferenceAvailability
{
    public function check(ReferenceAvailabilityQuery $query): ReferenceAvailabilityResult
    {
        $item = ReferenceItem::query()
            ->where('code', $query->reference)
            ->first();

        if ($item === null) {
            throw new ReferenceNotFoundException();
        }

        return new ReferenceAvailabilityResult(
            available: (bool) $item->is_available,
            checkedAt: new DateTimeImmutable(),
        );
    }
}
```

Binding et provider :

```php
<?php

namespace App\Domains\ReferenceProvider\Providers;

use App\Domains\ReferenceProvider\Contracts\ReferenceAvailability;
use App\Domains\ReferenceProvider\Services\ReferenceAvailabilityChecker;
use Illuminate\Support\ServiceProvider;

final class ReferenceProviderServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->bind(
            ReferenceAvailability::class,
            ReferenceAvailabilityChecker::class,
        );
    }
}
```

Enregistrement futur dans `bootstrap/providers.php` :

```php
use App\Domains\ReferenceProvider\Providers\ReferenceProviderServiceProvider;
use App\Providers\AppServiceProvider;
use App\Providers\Filament\AdminPanelProvider;

return [
    AppServiceProvider::class,
    AdminPanelProvider::class,
    ReferenceProviderServiceProvider::class,
];
```

Ce fichier n'est **pas modifié** dans le Lot 2. Il le sera uniquement lors de l'implémentation réelle de la première interface de contrat.

La substitution n'est possible que parce que le contrat est une interface. Le test correspondant est donc **propre à la variante B** (§11.5).

### 11.3 Appel depuis le consommateur

Le consommateur n'importe que les éléments publics :

```php
<?php

namespace App\Domains\ReferenceConsumer\Actions;

use App\Domains\ReferenceProvider\Contracts\Exceptions\ReferenceNotFoundException;
use App\Domains\ReferenceProvider\Contracts\ReferenceAvailability;
use App\Domains\ReferenceProvider\Contracts\ReferenceAvailabilityQuery;

final class CheckReferenceBeforeUse
{
    public function __construct(
        private readonly ReferenceAvailability $availability,
    ) {}

    public function handle(string $reference): bool
    {
        try {
            return $this->availability
                ->check(new ReferenceAvailabilityQuery($reference))
                ->available;
        } catch (ReferenceNotFoundException) {
            return false;
        }
    }
}
```

Le code ci-dessus est **commun dans sa forme**, mais `ReferenceAvailability` ne désigne pas le même symbole selon la variante :

- **variante A** : la classe concrète `final` `ReferenceAvailability` ;
- **variante B** : l'interface `ReferenceAvailability`.

Les deux variantes sont des exemples **alternatifs**, pas deux implémentations simultanées. En variante A, le consommateur reçoit la classe concrète ; en variante B, il reçoit l'implémentation liée à l'interface par le provider. Une même déclaration de type ne peut pas être à la fois la classe concrète et l'interface.

### 11.4 Gestion d'une erreur métier

- `ReferenceNotFoundException` est une **absence prévue par le contrat** ; le consommateur la capture et la transforme en résultat fonctionnel (`false`).
- Une exception technique (base indisponible, timeout) n'est pas capturée ici : elle remonte et ne devient pas un faux `false`.
- Si le contrat avait un refus métier plus complexe, il déclarerait une exception dédiée, par exemple `ReferenceBlockedException`, et le consommateur la traiterait explicitement.

### 11.5 Tests représentatifs

Les tests ci-dessous sont rattachés explicitement à une variante. Ils ne sont pas interchangeables : le test par `implements` de la variante B ne compile pas si `ReferenceAvailability` est la classe finale de la variante A.

#### Test du contrat côté fournisseur

Ce test vérifie le comportement du contrat et son intégration avec la persistance du fournisseur. Il s'applique aux deux variantes : `app(ReferenceAvailability::class)` résout la classe concrète en variante A, ou l'interface liée en variante B.

```php
<?php

use App\Domains\ReferenceProvider\Contracts\Exceptions\ReferenceNotFoundException;
use App\Domains\ReferenceProvider\Contracts\ReferenceAvailability;
use App\Domains\ReferenceProvider\Contracts\ReferenceAvailabilityQuery;
use App\Domains\ReferenceProvider\Models\ReferenceItem;

it('returns availability for a known reference', function () {
    ReferenceItem::factory()->create([
        'code' => 'REF-001',
        'is_available' => true,
    ]);

    $result = app(ReferenceAvailability::class)
        ->check(new ReferenceAvailabilityQuery('REF-001'));

    expect($result->available)->toBeTrue();
});

it('throws a business exception for an unknown reference', function () {
    expect(fn () => app(ReferenceAvailability::class)
        ->check(new ReferenceAvailabilityQuery('REF-404')))
        ->toThrow(ReferenceNotFoundException::class);
});
```

#### Variante A — test du consommateur avec la classe concrète

Le consommateur reçoit la **véritable classe concrète**. Ce test est un test de comportement et d'intégration : il ne substitue pas l'implémentation, n'utilise pas `implements` et ne tente pas de mocker la classe `final`.

```php
<?php

use App\Domains\ReferenceConsumer\Actions\CheckReferenceBeforeUse;
use App\Domains\ReferenceProvider\Contracts\ReferenceAvailability;
use App\Domains\ReferenceProvider\Models\ReferenceItem;

it('uses the real concrete contract in the consumer', function () {
    ReferenceItem::factory()->create([
        'code' => 'REF-001',
        'is_available' => true,
    ]);

    $action = new CheckReferenceBeforeUse(
        app(ReferenceAvailability::class),
    );

    expect($action->handle('REF-001'))->toBeTrue();
});

it('maps an unknown reference to false through the real contract', function () {
    $action = new CheckReferenceBeforeUse(
        app(ReferenceAvailability::class),
    );

    expect($action->handle('REF-404'))->toBeFalse();
});
```

Si un test unitaire isolé est nécessaire, tester séparément le composant interne approprié — par exemple le Service interne du fournisseur — sans créer une abstraction publique uniquement pour permettre le test.

#### Variante B — test du consommateur avec une implémentation de test

Ce test n'est valide que dans la **variante B**, où `ReferenceAvailability` est une interface. Il ne peut pas être utilisé avec la classe finale de la variante A. L'implémentation anonyme est un double de test de l'interface ; elle n'existe pas dans l'application réelle.

```php
<?php

use App\Domains\ReferenceConsumer\Actions\CheckReferenceBeforeUse;
use App\Domains\ReferenceProvider\Contracts\Exceptions\ReferenceNotFoundException;
use App\Domains\ReferenceProvider\Contracts\ReferenceAvailability;
use App\Domains\ReferenceProvider\Contracts\ReferenceAvailabilityQuery;
use App\Domains\ReferenceProvider\Contracts\ReferenceAvailabilityResult;

it('maps a missing reference to false', function () {
    $availability = new class implements ReferenceAvailability {
        public function check(ReferenceAvailabilityQuery $query): ReferenceAvailabilityResult
        {
            throw new ReferenceNotFoundException();
        }
    };

    $action = new CheckReferenceBeforeUse($availability);

    expect($action->handle('REF-404'))->toBeFalse();
});
```

#### Variante B — test de résolution du binding

```php
<?php

use App\Domains\ReferenceProvider\Contracts\ReferenceAvailability;
use App\Domains\ReferenceProvider\Services\ReferenceAvailabilityChecker;

it('resolves the configured contract implementation', function () {
    expect(app(ReferenceAvailability::class))
        ->toBeInstanceOf(ReferenceAvailabilityChecker::class);
});
```

### 11.6 Ce qui est public et ce qui reste interne

| Élément | Public | Interne |
| --- | --- | --- |
| `ReferenceAvailability` | Oui | — |
| `ReferenceAvailabilityQuery` | Oui | — |
| `ReferenceAvailabilityResult` | Oui | — |
| `ReferenceNotFoundException` | Oui | — |
| `ReferenceAvailabilityChecker` | — | Oui |
| `ReferenceItem` | — | Oui |
| `ReferenceProviderServiceProvider` | — | Oui (câblage) |

## 12. Tests recommandés

### 12.1 Tests de comportement du contrat

| Test | Objectif |
| --- | --- |
| Cas nominal | Le contrat retourne le résultat attendu. |
| Entrée absente ou inconnue | Le contrat respecte le comportement documenté. |
| Refus métier | L'exception publique attendue est levée. |
| Conflit d'état | Le conflit est distingué d'une absence ou d'une panne. |
| Autorisation refusée | Le fournisseur applique ses règles. |
| Invariant du fournisseur | Une donnée invalide ne peut pas produire un résultat trompeur. |
| Absence d'effet de bord | Une lecture ne modifie rien. |
| Données sensibles | Le DTO et l'exception n'exposent pas de détail interne. |

### 12.2 Tests d'injection et de résolution

| Test | Objectif |
| --- | --- |
| Classe concrète | `app(Contract::class)` retourne l'implémentation attendue sans binding. |
| Interface liée | Le container retourne l'implémentation déclarée dans le provider. |
| Substitution | Un test peut remplacer l'interface par une implémentation de test. |
| Provider | Le binding est enregistré dans `register()` et disponible. |
| Consommateur | L'Action reçoit le contrat par constructeur. |

### 12.3 Tests de comportement et tests d'architecture

Les tests ci-dessus sont des **tests de comportement**. Ils vérifient ce que le contrat fait.

Les tests d'architecture vérifient les imports, les dépendances et les règles structurelles. Ils relèvent de **CHAN-31** et ne doivent pas être ajoutés dans ce lot. Exemples de règles futures, à ne pas implémenter ici :

- un domaine ne peut pas importer un Model d'un autre domaine ;
- un consommateur ne peut importer que `Contracts/` et `Events/Integration/` ;
- aucun DTO public ni événement d'intégration ne contient de type Eloquent ;
- un événement d'intégration respecte le payload typé et minimal de la section 15.7.

### 12.4 Ne pas créer de tests maintenant

Aucun domaine métier n'existe. Il ne faut pas créer de tests artificiels dans `tests/` pour des contrats fictifs. Les exemples de ce document restent dans la documentation.

## 13. Évolution et compatibilité

Un contrat public est une **API interne** : il n'est pas publié hors de l'application, mais il est consommé par d'autres domaines. Il doit donc avoir une discipline d'évolution, même si le projet est encore en version `0.x`.

### 13.1 Changements compatibles

| Changement | Compatibilité | Remarque |
| --- | --- | --- |
| Ajouter une méthode à une classe concrète | Compatible | Ne pas modifier le comportement des méthodes existantes. |
| Ajouter une propriété optionnelle à un DTO | Compatible | Prévoir une valeur par défaut et documenter l'absence. |
| Ajouter un cas à un enum | Souvent compatible | Peut casser un consommateur qui traite tous les cas de façon exhaustive. |
| Ajouter une exception déclarée | Conditionnel | Un consommateur qui ne gère pas ce cas peut voir son comportement changer. |
| Ajouter une nouvelle implémentation derrière une interface | Compatible | Le binding par défaut doit rester explicite. |

### 13.2 Changements incompatibles

| Changement | Impact |
| --- | --- |
| Renommer ou supprimer une méthode publique | Rupture pour tous les consommateurs. |
| Supprimer ou renommer une propriété de DTO | Rupture de sérialisation et de code. |
| Changer le type d'une propriété | Rupture de typage et de comportement. |
| Ajouter un paramètre obligatoire | Rupture pour tous les appels existants. |
| Changer le type de retour | Rupture pour les consommateurs. |
| Changer la sémantique d'un résultat sans changer sa forme | Rupture silencieuse, la plus dangereuse. |
| Changer le comportement d'une exception | Rupture de traitement chez le consommateur. |
| Modifier les règles d'autorisation | Rupture fonctionnelle et sécurité. |

### 13.3 Règles d'évolution

| Règle | Niveau |
| --- | --- |
| Un contrat public évolue de façon additive en priorité. | Recommandé |
| Une rupture doit être coordonnée avec tous les consommateurs connus. | Obligatoire |
| Une méthode ou un champ déprécié est documenté avant suppression. | Recommandé |
| Le fournisseur ne change pas silencieusement la sémantique d'un contrat. | Obligatoire |
| Chaque contrat public a une liste de consommateurs connue. | Recommandé |
| Un contrat public est couvert par des tests de comportement. | Recommandé |
| Le consommateur ne duplique pas le contrat pour contourner une évolution. | Obligatoire |
| Deux contrats concurrents ne doivent pas couvrir la même capacité. | Obligatoire |

### 13.4 Versionnement

Aucun framework de versionnement de contrat n'est introduit par ce lot. En cas de rupture réelle :

- préférer une nouvelle classe de contrat explicitement nommée ou un nouveau DTO, avec une période de coexistence ;
- conserver l'ancien contrat tant que des consommateurs existent ;
- documenter la migration dans la Pull Request et dans le futur catalogue des contrats ;
- ne pas utiliser un numéro de version dans le nom d'une classe pour un changement compatible.

Tant que le projet est en version `0.x`, une rupture reste possible, mais elle doit être documentée et coordonnée. La stabilité des contrats est un objectif, pas une hypothèse.

### 13.5 Catalogue des contrats

Lorsqu'un premier contrat réel sera créé, tenir un tableau minimal :

| Fournisseur | Contrat | Consommateurs connus | Statut |
| --- | --- | --- | --- |
| — | — | — | Aucun contrat implémenté à ce jour |

Ce catalogue ne doit pas être rempli avec des exemples fictifs. Il doit refléter uniquement les contrats réellement présents dans le code.

## 14. Checklist de revue des contrats synchrones

Cette checklist couvre uniquement les contrats synchrones. La checklist des événements inter-domaines est en section 22.

- [ ] Le contrat est placé dans `app/Domains/{Provider}/Contracts/`.
- [ ] Un consommateur réel existe ; le contrat n'est pas anticipé.
- [ ] Le fournisseur possède la donnée, l'invariant ou la décision.
- [ ] Le contrat ne retourne ni Model, ni Builder, ni Collection Eloquent.
- [ ] Les DTO publics sont typés, sans type framework, et immuables si pertinent.
- [ ] Les DTO publics ne contiennent pas de méthode dépendant d'un Model interne.
- [ ] Aucun `App\Models\User` n'est exposé dans l'API publique.
- [ ] L'acteur, s'il est nécessaire, est représenté de façon minimale et explicite.
- [ ] Le fournisseur applique ses propres règles d'autorisation.
- [ ] Une classe concrète est utilisée si aucun binding n'est nécessaire.
- [ ] Une interface est justifiée par une substitution ou plusieurs implémentations réelles.
- [ ] Le binding, s'il existe, est dans `register()` d'un provider de domaine enregistré dans `bootstrap/providers.php`.
- [ ] Aucun provider de domaine vide n'est créé.
- [ ] Un contrat de lecture n'a pas d'effet de bord.
- [ ] Une commande synchrone est explicite, documentée et, si nécessaire, idempotente.
- [ ] Aucune transaction partagée n'est introduite sans décision explicite.
- [ ] Les exceptions publiques sont nommées, stables et sans détail sensible.
- [ ] Le consommateur capture uniquement les exceptions déclarées.
- [ ] Les erreurs techniques ne sont pas converties en résultats métier trompeurs.
- [ ] Les tests couvrent le comportement, les erreurs et l'injection.
- [ ] L'évolution du contrat est additive ou explicitement coordonnée.
- [ ] Les consommateurs connus sont identifiés.
- [ ] Les règles de CHAN-29 et CHAN-31 ne sont pas décidées implicitement.
- [ ] Un fait accompli n'est pas notifié par un contrat synchrone, et une réponse immédiate n'est pas attendue d'un événement.

---

> **Partie II — Événements inter-domaines.** Les sections 15 à 22 formalisent les événements inter-domaines. Elles ne réouvrent aucune décision des sections 1 à 14 et ne créent aucun code applicatif.

## 15. Événements inter-domaines : définition et structure

### 15.1 Définition

Un **événement inter-domaines** — également appelé **événement d'intégration** dans ce document — est un objet immuable qui décrit un **fait métier accompli** dans un domaine émetteur et que d'autres domaines peuvent consommer sans que l'émetteur attende une réponse.

Un événement inter-domaines :

- est nommé au passé et décrit ce qui s'est produit, pas ce qu'il faut faire ;
- appartient au domaine qui a produit le fait ;
- est une **API interne publique** entre domaines, pas un objet interne stabilisé par commodité ;
- peut avoir un ou plusieurs consommateurs, mais n'est créé que si au moins un consommateur réel est identifié ;
- ne retourne pas de valeur métier à l'émetteur ;
- ne remplace ni une décision, ni une lecture, ni une commande synchrone ;
- n'est pas une source de vérité : l'état métier reste dans la base du domaine propriétaire ;
- ne bénéficie d'aucune garantie de livraison, d'ordre ou d'exactly-once du seul fait qu'il est un événement.

Un événement inter-domaines n'est pas :

- une commande déguisée (`OpenAffaire`, `ReserveStock`) ;
- une requête déguisée (`GetAffaire`, `CheckBudget`) ;
- un RPC déguisé, même si son listener est synchrone ;
- un journal technique (`JobStarted`, `QueryExecuted`, `CacheMissed`) ;
- un événement Eloquent (`created`, `updated`, `deleted`) ;
- un moyen de contourner une Action, une Policy ou une transaction du domaine propriétaire.

**Règles communes et règles propres.** Les règles communes de la Partie I ne sont pas recopiées ; elles s'appliquent aussi aux événements. Le tableau suivant rappelle la répartition.

| Sujet | Contrat synchrone | Événement inter-domaines |
| --- | --- | --- |
| Propriété | Domaine fournisseur | Domaine émetteur |
| Surface publique | `Contracts/` | `Events/Integration/` |
| Type Eloquent | Interdit | Interdit |
| Payload | DTO public typé | Événement immuable au payload minimal |
| Réponse | Immédiate et typée | Aucune réponse métier |
| Déclenchement | Demande du consommateur | Fait accompli chez l'émetteur |
| Publication | Non applicable | Après commit |
| Idempotence | Commande si risque de double appel | Listener selon les effets de bord |
| Exactly-once | Non | Non |
| Évolution | Section 13 | Section 19 |

### 15.2 Événement local et événement inter-domaines

CHAN-27 définit les événements **locaux**, internes à un domaine. Le tableau suivant fixe la distinction. Il ne modifie pas les règles locales de CHAN-27.

| Critère | Événement local | Événement inter-domaines |
| --- | --- | --- |
| Propriétaire | Le domaine | Le domaine émetteur |
| Emplacement | `app/Domains/{Domain}/Events/` | `app/Domains/{Provider}/Events/Integration/` |
| Namespace | `App\Domains\{Domain}\Events` | `App\Domains\{Provider}\Events\Integration` |
| Visibilité | Interne au domaine | Public pour les autres domaines |
| Payload | Peut référencer des objets internes, conformément à CHAN-27 | Types publics uniquement ; aucun Model Eloquent |
| Consommateurs | Listeners du même domaine | Listeners des domaines consommateurs |
| Enregistrement | Interne au domaine | Explicite chez chaque consommateur |
| Évolution | Libre dans le domaine | Discipline de compatibilité inter-domaines |
| Publication | Après commit de la transaction | Après commit de la transaction |
| Exemple | `ClientCreated` | `AffaireOpened` |

> **Précision sur CHAN-27 §7.4.** L'exemple `ClientCreated` transporte un Model `Client`. Il reste un **événement local**. Un événement placé dans `Events/Integration/` ne doit jamais transporter ce Model. De plus, `ShouldDispatchAfterCommit` ne garantit la publication après commit que lorsqu'une transaction et le gestionnaire de transactions Laravel sont actifs ; hors transaction, la publication est immédiate. La section 17 précise ce comportement. Cette précision ne modifie pas la règle locale de CHAN-27.

Déplacer un événement local vers `Events/Integration/` ne suffit pas à en faire un événement d'intégration. La promotion exige au minimum :

1. un consommateur réel identifié ;
2. un payload public typé, minimal et sans type interne ;
3. une revue de compatibilité et une documentation des consommateurs ;
4. le déplacement du fichier et la mise à jour des imports ;
5. des tests de structure, de publication et de consommation.

### 15.3 Propriété

| Règle | Niveau |
| --- | --- |
| Le domaine émetteur possède la classe de l'événement, son nom, son schéma et son évolution. | Obligatoire |
| L'événement est placé dans le domaine émetteur, jamais dans `Core`, `Shared`, `App\Events` ou le domaine consommateur. | Obligatoire |
| Le consommateur importe uniquement la classe de l'événement et les types publics qu'elle expose. | Obligatoire |
| Le consommateur n'importe ni le Model, ni l'Action, ni le Service, ni le DTO interne, ni la Policy, ni la table de l'émetteur. | Obligatoire |
| Un événement n'est créé que pour un consommateur réel identifié. | Obligatoire |
| Deux domaines ne publient pas le même fait sous deux événements concurrents ; un seul domaine est propriétaire du fait. | Obligatoire |
| Un domaine qui réagit à un événement publie ensuite **son propre** événement s'il produit un nouveau fait. | Recommandé |
| Le fournisseur documente les consommateurs connus et les changements de schéma. | Obligatoire |
| Le consommateur ne modifie jamais l'événement reçu. | Obligatoire |
| Seul le serveur publie un événement d'intégration ; un navigateur ou un client hors connexion ne peut pas en publier. | Obligatoire |

Un événement partagé dans `Core` serait une erreur : `Core` ne dépend d'aucun domaine et ne doit pas connaître un fait métier. Un événement placé chez le consommateur inverserait la propriété du fait.

### 15.4 Emplacement et namespaces

```text
app/
└── Domains/
    ├── Projects/
    │   ├── Actions/
    │   │   └── OpenAffaire.php
    │   └── Events/
    │       └── Integration/
    │           └── AffaireOpened.php
    └── Budgets/
        ├── Actions/
        │   └── CreateBudgetDraft.php
        ├── Listeners/
        │   └── CreateAffaireBudgetDraft.php
        └── Providers/
            └── BudgetsServiceProvider.php
```

| Élément | Emplacement | Namespace |
| --- | --- | --- |
| Événement inter-domaines | `app/Domains/{Provider}/Events/Integration/` | `App\Domains\{Provider}\Events\Integration` |
| Type public spécifique au payload | `app/Domains/{Provider}/Events/Integration/` ou emplacement public explicitement documenté | Même domaine, namespace public |
| Listener consommateur | `app/Domains/{Consumer}/Listeners/` | `App\Domains\{Consumer}\Listeners` |
| Provider du consommateur | `app/Domains/{Consumer}/Providers/` | `App\Domains\{Consumer}\Providers` |

Le dépôt utilise `app/Domains/` depuis CHAN-26. La mention historique `modules/` dans `AGENTS.md` relève de l'harmonisation CHAN-30 et ne change pas l'emplacement des événements.

**Règles :**

- `Events/Integration/` n'est créé qu'au premier événement réel. Aucun dossier vide n'est créé dans les 18 domaines pour préparer l'architecture.
- Un événement n'est pas placé dans `Contracts/` : il n'est pas un contrat synchrone.
- Un type de payload public ne doit pas être un DTO interne déplacé par commodité. S'il devient public, il doit être nommé, documenté et revu comme tel.
- Un événement ne réutilise pas un DTO de `Contracts/` par défaut : son schéma reste autonome. Un type public partagé doit être documenté comme commun aux deux contrats.
- Le consommateur ne crée pas de copie locale de l'événement pour éviter d'importer le fournisseur. Une copie serait un second contrat non propriétaire.

### 15.5 Nommage

| Élément | Convention | Exemples | À éviter |
| --- | --- | --- | --- |
| Événement | Fait métier au passé, sans suffixe technique | `AffaireOpened`, `ChantierClosed`, `PurchaseOrderApproved` | `AffaireOpenedEvent`, `OpenAffaire`, `AffaireOpening`, `AffaireStatusChanged` |
| Événement avec variantes | Un nom distinct par fait distinct | `AffaireOpened`, `AffaireConfirmed`, `AffaireCancelled` | Un seul `AffaireChanged` avec un statut ambigu |
| Listener | Verbe ou réaction explicite | `CreateAffaireBudgetDraft`, `NotifyProjectManager` | `HandleAffaireOpened`, `Listener1`, `EventProcessor` |
| Type de payload public | Nom métier stable | `AffaireOpenedData` si un objet est réellement nécessaire | `Payload`, `Data`, `ArrayData` |

Le nom de la classe est une partie du contrat public. Le renommer est un changement incompatible.

Un événement ne doit pas porter :

- un suffixe `Event` ou `Integration` redondant avec son emplacement ;
- un préfixe de domaine décoratif (`ProjectsAffaireOpened`) ;
- un numéro de version systématique (`AffaireOpenedV2`) ;
- un nom d'action ou d'impératif (`OpenAffaire`) ;
- un nom technique (`DatabaseUpdated`, `ModelSaved`).

Le vocabulaire métier BTP peut rester en français (`Affaire`, `Chantier`, `Réserve`) tandis que la classe suit la convention du projet (`AffaireOpened`). Un même concept conserve le même nom dans le domaine, l'événement et la documentation.

### 15.6 Construction et immutabilité

Forme recommandée :

```php
<?php

namespace App\Domains\Projects\Events\Integration;

use DateTimeImmutable;
use Illuminate\Contracts\Events\ShouldDispatchAfterCommit;
use Illuminate\Foundation\Events\Dispatchable;

/**
 * Fait : une affaire a été ouverte par le domaine Projects.
 * Propriétaire : Projects.
 */
final readonly class AffaireOpened implements ShouldDispatchAfterCommit
{
    use Dispatchable;

    public function __construct(
        public string $affaireId,
        public DateTimeImmutable $openedAt,
    ) {}
}
```

Le type `string` de `affaireId` est **illustratif**. Le type réel doit suivre la stratégie d'identifiant retenue par le domaine propriétaire et Identity. CHAN-28 ne fixe aucune convention UUID/ULID globale (section 6.3).

| Règle | Niveau |
| --- | --- |
| La classe est `final readonly` et toutes les propriétés sont typées et promues par le constructeur. | Recommandé |
| Aucun setter, aucune propriété mutable, aucun état statique modifiable. | Obligatoire |
| Le constructeur ne fait aucune requête, aucun accès au container, à la session, à l'authentification ou au système de fichiers. | Obligatoire |
| Le constructeur ne contient aucune règle métier nécessitant la persistance. | Obligatoire |
| Des gardes simples (identifiant non vide, date cohérente) sont possibles sans requête. | Conditionnel |
| Aucune méthode `fromModel()`, `toArray()`, `jsonSerialize()` ou équivalent ne dépend d'un Model interne. | Obligatoire |
| L'événement ne porte pas de logique de persistance, de validation d'entrée ou d'appel externe. | Obligatoire |
| Le fait est construit avec des valeurs déjà validées par l'Action du domaine. | Obligatoire |
| Les arguments nommés sont utilisés lorsque plusieurs scalaires peuvent être confondus. | Recommandé |
| `Dispatchable` est utilisé si le projet retient `AffaireOpened::dispatch(...)` ; sinon, `Event::dispatch(new AffaireOpened(...))` est équivalent. | Conditionnel |
| Aucun `SerializesModels`, `InteractsWithSockets` ou `ShouldBroadcast` n'est ajouté par défaut. | Obligatoire |

Le constructeur ne doit pas appeler `now()` pour déterminer le fait : la date du fait est fournie par l'Action qui l'a produit. Un événement construit plus tard, ou rejoué, doit conserver la date du fait, pas la date de la nouvelle tentative.

**À éviter :**

```php
public function __construct(
    public Affaire $affaire,
) {}
```

**Préférer :**

```php
public function __construct(
    public string $affaireId,
    public DateTimeImmutable $openedAt,
) {}
```

Le premier exemple expose un Model, ses relations et son état de persistance. Le second expose uniquement l'identité et le fait.

### 15.7 Payload typé

| Type | Usage | Remarque |
| --- | --- | --- |
| `string`, `int`, `bool`, `float` | Valeurs simples | `float` uniquement pour une mesure non monétaire, avec précision documentée. |
| Enum backed | Statut ou catégorie stable | Un nouveau cas peut être un changement de contrat. |
| `DateTimeImmutable` / `CarbonImmutable` | Date ou horodatage | Le projet configure `CarbonImmutable` par défaut (`AppServiceProvider.php:34`). |
| Objet de valeur public | Identifiant typé, quantité, intervalle | Uniquement s'il est stable, autonome et documenté. |
| `list<T>` avec PHPDoc | Liste simple de valeurs autorisées | Préférer un DTO public dédié si un comportement est nécessaire. |
| `?Type` | Absence explicitement prévue | Documenter la signification de `null`. |

Types et structures interdits dans un payload d'intégration :

- Model Eloquent, Builder, Relation, Collection Eloquent ;
- `Illuminate\Support\Collection` ou `Arrayable` utilisé comme structure publique non typée ;
- `App\Models\User` ou tout Model d'identité ;
- `Illuminate\Http\Request`, `Response`, `UploadedFile`, objet Livewire ou Filament ;
- `mixed`, `object`, `array` sans type PHPDoc, union non documentée ;
- closure, ressource, `PDO`, service, repository, container, configuration, session, guard d'authentification ;
- objet de domaine interne non explicitement public ;
- contenu de fichier, binaire, donnée de stockage privé.

Un tableau associatif non typé n'est pas un schéma. Si plusieurs champs forment une structure, créer un DTO public immuable et le documenter, ou éviter la structure.

### 15.8 Données autorisées et interdites

| Donnée | Autorisée dans un événement ? | Remarque |
| --- | --- | --- |
| Identifiant stable du fait ou de l'objet | Oui | Type aligné sur le domaine propriétaire. |
| Date/heure du fait | Oui | Fuseau explicite ou convention UTC documentée. |
| Statut ou catégorie stable | Oui, si un consommateur réel en a besoin | Préférer un enum public. |
| Référence métier lisible | Conditionnel | Seulement si un consommateur réel l'utilise et si elle est stable. |
| Quantité avec unité | Conditionnel | Unité explicite ; pas de mélange d'unités. |
| Montant | Conditionnel | Entier en unité mineure et devise explicite ; jamais `float`. |
| Identifiant d'acteur minimal | Conditionnel | Uniquement si le consommateur doit appliquer ses propres règles. |
| Données personnelles | Exceptionnel | Minimum strictement nécessaire, jamais par défaut. |
| Coordonnées client, notes libres, commentaires internes | Non | Le consommateur doit utiliser un contrat public ou une source autorisée. |
| Prix, marge, coût interne | Non par défaut | Uniquement si un consommateur réel et une règle validée l'exigent. |
| Mot de passe, token, secret, clé, donnée bancaire | Non | Jamais. |
| Donnée de santé, de sécurité nominative ou sensible | Non par défaut | Cadre de protection à définir avant toute exposition. |
| Contenu de document ou fichier | Non | Référencer un document public via un contrat dédié. |
| Trace, SQL, exception interne | Non | Journaliser côté domaine, sans exposer le détail. |

**Règle de nécessité :** chaque champ doit répondre à un besoin identifié d'un consommateur réel. Un champ « au cas où », « pour plus tard » ou « pour éviter un appel » est supprimé. Si un consommateur a besoin de plus de détails, il utilise un contrat synchrone public du fournisseur ; il ne transforme pas l'événement en snapshot complet.

**Règle de stabilité :** un champ exposé ne peut pas changer de type ou de sémantique sans coordination. Les identifiants, dates et unités doivent être explicites dès le premier consommateur.

### 15.9 Événement ou contrat synchrone ?

```text
Un autre domaine a-t-il besoin d'une réponse immédiate pour poursuivre son opération ?
├─ Oui
│  └─ Contrat synchrone (Partie I)
└─ Non
   ├─ Un fait métier est-il accompli et le domaine émetteur n'attend-il aucune réponse ?
   │  ├─ Oui
   │  │  ├─ Un consommateur réel est-il identifié ?
   │  │  │  ├─ Oui → événement inter-domaines
   │  │  │  └─ Non → ne rien créer ; le fait reste interne
   │  │  └─ Le payload peut-il rester minimal, typé et public ?
   │  │     ├─ Oui → événement
   │  │     └─ Non → revoir le besoin ; un contrat synchrone est peut-être nécessaire
   │  └─ Non → clarifier le besoin
   └─ Le but est uniquement de notifier un fait accompli ?
      └─ Oui → événement, pas contrat synchrone
```

| Anti-pattern | Problème | Correction |
| --- | --- | --- |
| Événement qui attend une réponse | RPC déguisé ; l'émetteur dépend d'un consommateur | Contrat synchrone |
| Événement `CheckStock` ou `GetBudget` | Requête déguisée | Contrat synchrone de lecture |
| Contrat synchrone `NotifyAffaireOpened` | Notification d'un fait accompli avec une API de commande | Événement |
| Listener qui appelle l'Action interne de l'émetteur | Contourne la frontière et l'autorisation | Contrat public ou événement du consommateur |
| Émetteur qui dispatch un événement pour déclencher une étape dont il dépend | Couplage temporel caché | Contrat synchrone ou orchestration explicite |
| Consommateur qui retourne une valeur attendue par l'émetteur | Le dispatcher Laravel n'est pas un bus de réponse | Contrat synchrone |

### 15.10 Décisions de cadrage du Lot 3

| Sujet | Décision |
| --- | --- |
| Mécanisme | Contrat synchrone pour une réponse immédiate ; événement pour un fait accompli consommé indépendamment. |
| Propriété | Le domaine émetteur possède l'événement, son nom, son schéma et son évolution. |
| Emplacement | `app/Domains/{Provider}/Events/Integration/`. |
| Nom | Fait métier au passé, sans suffixe technique ni version systématique. |
| Payload | Typé, minimal, stable ; aucun Model, Builder ou Collection Eloquent. |
| Publication | Après commit, avec un mécanisme Laravel natif ; `ShouldDispatchAfterCommit` par défaut. |
| Listeners | Synchrones par défaut, enregistrés explicitement chez chaque consommateur. |
| Idempotence | Responsabilité du consommateur ; adaptée aux effets de bord ; aucune garantie exactly-once. |
| Infrastructure | Aucun broker, Outbox, retry complexe ou transport supplémentaire introduit par le Lot 3. |
| Évolution | Additive en priorité ; rupture coordonnée et documentée. |
| Tests | Structure, publication après commit, rollback, listeners, erreurs et idempotence. |

## 16. Cycle de vie d'un événement inter-domaines

### 16.1 Vue d'ensemble

1. Le domaine émetteur produit le fait métier dans une Action.
2. L'Action construit l'événement avec des données publiques minimales.
3. L'émetteur vérifie les données exposées et l'absence de type interne.
4. L'événement est publié après le commit de la transaction.
5. Les listeners des consommateurs sont identifiés et enregistrés explicitement.
6. Chaque consommateur reçoit l'événement et délègue le traitement à son domaine.
7. Les erreurs sont traitées selon la criticité de la réaction.
8. Les traitements répétés sont évités par une idempotence adaptée.
9. Un rejeu éventuel est documenté et sûr, ou n'est pas promis.

```text
Action du domaine émetteur
├─ autorisation et invariants
├─ transaction
│  ├─ écritures métier
│  ├─ construction de l'événement
│  └─ dispatch avec ShouldDispatchAfterCommit
├─ commit
└─ listeners synchrones (ou mise en file, si une infrastructure dédiée existe)
```

### 16.2 Production du fait métier

L'événement est produit par l'opération métier qui accomplit réellement le fait, généralement une Action au sens de CHAN-27.

| Règle | Niveau |
| --- | --- |
| L'événement est dispatché par l'Action qui accomplit le fait, pas par un Model, un Observer, un contrôleur, une Policy ou un composant Livewire/Filament. | Obligatoire |
| L'Action vérifie l'autorisation et les invariants avant de produire le fait. | Obligatoire |
| Aucun événement n'est dispatché si l'opération échoue avant le fait. | Obligatoire |
| L'Action reste le point d'entrée métier, même si elle est appelée par une commande, un job ou un listener. | Obligatoire |
| Un Service peut publier un événement seulement s'il est propriétaire du fait et si ce comportement est documenté ; pour un événement inter-domaines, l'Action est la forme par défaut. | Conditionnel |
| Un événement Eloquent n'est jamais utilisé comme événement d'intégration. | Obligatoire |

Un Observer ou un événement Eloquent se déclenche au niveau de la persistance, souvent avant le commit, et peut être exécuté pour des écritures techniques. Il ne porte ni l'intention métier ni la garantie de publication après commit attendue à la frontière.

### 16.3 Construction de l'événement

L'Action mappe l'état métier déjà validé vers les champs publics de l'événement :

```php
// Dans l'Action, après les écritures et avant la fin de la transaction.
AffaireOpened::dispatch(
    affaireId: (string) $affaire->getKey(),
    openedAt: $affaire->opened_at,
);
```

| Règle | Niveau |
| --- | --- |
| Les valeurs sont lues depuis l'état métier déjà chargé, sans requête supplémentaire dans le constructeur. | Obligatoire |
| Les relations ne sont pas exposées ; seuls les identifiants et valeurs nécessaires le sont. | Obligatoire |
| Aucun appel à `refresh()`, `load()` ou à un contrat d'un autre domaine n'est nécessaire pour construire l'événement. | Recommandé |
| L'événement est construit après que le fait est acquis, pas avant la validation finale. | Obligatoire |
| L'événement ne contient pas de données calculées uniquement pour l'affichage. | Obligatoire |

Le Model qui fournit `opened_at` doit le caster en type immuable. Sinon, l'Action convertit explicitement la valeur avant le dispatch ; elle ne passe pas une chaîne non typée à l'événement.

### 16.4 Validation des données exposées

La validation d'un événement n'est pas une validation de formulaire. C'est une revue de contrat :

| Question | Vérification |
| --- | --- |
| Le domaine émetteur possède-t-il chaque champ ? | Aucun champ ne doit venir d'un domaine consommateur ou d'une table étrangère. |
| Chaque champ a-t-il un consommateur réel ? | Supprimer les champs anticipés. |
| Le type est-il public et stable ? | Scalaire, enum, date immuable, objet de valeur public ou liste typée. |
| Le champ peut-il exposer une donnée sensible ? | Retirer ou minimiser. |
| Le champ peut-il évoluer de façon additive ? | Préférer les champs optionnels et les nouveaux événements. |
| L'identifiant est-il stable et unique pour le fait ? | Utiliser l'identifiant métier réel, pas un identifiant de session ou de requête. |
| La date du fait est-elle explicite ? | Fuseau ou convention UTC documenté. |
| Le montant, s'il existe, est-il sans `float` ? | Unité mineure et devise explicites. |

Cette revue est obligatoire avant le premier consommateur et à chaque changement de schéma.

### 16.5 Publication après commit

La publication est différée après le commit de la transaction qui a produit le fait. Le mécanisme recommandé est `ShouldDispatchAfterCommit` sur la classe de l'événement, dispatché depuis l'Action à l'intérieur de la transaction. La section 17 détaille les mécanismes, leurs limites et les comportements de rollback.

### 16.6 Découverte et enregistrement des listeners

Les listeners de domaine ne sont pas découverts automatiquement par défaut : Laravel scanne `app/Listeners`, pas `app/Domains/*/Listeners`. L'enregistrement est donc **explicite**, dans le provider du domaine consommateur.

```php
<?php

namespace App\Domains\Budgets\Providers;

use App\Domains\Budgets\Listeners\CreateAffaireBudgetDraft;
use App\Domains\Projects\Events\Integration\AffaireOpened;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\ServiceProvider;

final class BudgetsServiceProvider extends ServiceProvider
{
    public function boot(): void
    {
        Event::listen(
            AffaireOpened::class,
            CreateAffaireBudgetDraft::class,
        );
    }
}
```

Le provider est enregistré dans `bootstrap/providers.php` lors de l'implémentation réelle. Le Lot 3 ne modifie pas ce fichier.

| Règle | Niveau |
| --- | --- |
| Chaque consommateur enregistre ses propres listeners. | Obligatoire |
| L'enregistrement est visible dans un provider de domaine, pas caché dans un Observer ou une convention magique. | Obligatoire |
| Les bindings vont dans `register()` ; les listeners vont dans `boot()`. | Recommandé |
| Un provider de domaine n'est créé que s'il a un binding ou un listener réel. | Obligatoire |
| L'ordre des listeners n'est pas un contrat métier. | Obligatoire |
| Un listener n'est pas enregistré deux fois. | Obligatoire |
| La découverte automatique de `app/Domains/*/Listeners` n'est pas activée sans décision documentée. | Recommandé |
| `php artisan event:list` peut être utilisé pour vérifier l'enregistrement réel. | Recommandé |

**Pourquoi ne pas utiliser la découverte automatique ?** `Application::configure()` active la découverte Laravel, mais son chemin par défaut est `app/Listeners` (`EventServiceProvider::discoverEventsWithin()`). Étendre la découverte à `app/Domains/*/Listeners` avec `withEvents(discover: ...)` est possible, mais rend les abonnements implicites, dépendants d'une convention de nommage et plus difficiles à auditer. L'enregistrement explicite est préféré pour un modular monolith.

**Alternative rejetée par défaut :** un provider central `DomainEventServiceProvider` contenant toutes les correspondances. Il rendrait le graphe visible en un point, mais créerait un fichier transversal impliquant tous les domaines et deviendrait un point de couplage. Il peut être reconsidéré si le nombre de listeners rend la dispersion réellement coûteuse, avec une décision documentée.

### 16.7 Réception et traitement par le consommateur

Un listener est un **adaptateur de frontière**. Il reçoit l'événement, vérifie ce qui doit l'être, puis délègue à une Action ou un Service du domaine consommateur.

```php
<?php

namespace App\Domains\Budgets\Listeners;

use App\Domains\Budgets\Actions\CreateBudgetDraft;
use App\Domains\Projects\Events\Integration\AffaireOpened;

final class CreateAffaireBudgetDraft
{
    public function __construct(
        private readonly CreateBudgetDraft $createBudgetDraft,
    ) {}

    public function handle(AffaireOpened $event): void
    {
        $this->createBudgetDraft->handle($event->affaireId);
    }
}
```

| Règle | Niveau |
| --- | --- |
| Le listener appartient au domaine consommateur et reste dans son périmètre. | Obligatoire |
| Le listener importe uniquement l'événement public et les types publics nécessaires. | Obligatoire |
| Le listener délègue la logique métier à une Action ou un Service du consommateur. | Recommandé |
| Le listener retourne `void` ; il ne retourne pas de valeur métier à l'émetteur. | Obligatoire |
| Le listener ne modifie jamais les données du domaine émetteur. | Obligatoire |
| Le listener n'ouvre pas de transaction englobant l'émetteur ; il gère sa propre transaction si nécessaire. | Obligatoire |
| Le listener ne suppose pas que la transaction de l'émetteur est encore ouverte. | Obligatoire |
| Le listener ne suppose pas un ordre entre événements. | Obligatoire |
| Le listener ne suppose pas qu'il est exécuté une seule fois. | Obligatoire |
| Le listener applique les invariants et autorisations de son propre domaine. | Obligatoire |
| Le listener ne rappelle pas l'Action interne de l'émetteur ; il utilise un contrat public si un complément est nécessaire. | Obligatoire |

Les dépendances du listener sont injectées par le conteneur Laravel, comme pour toute classe de service. Le listener ne résout pas ses dépendances via `app()` dans son corps.

### 16.8 Gestion des erreurs

Un listener synchrone s'exécute dans le processus de l'émetteur, après le commit. Une exception remonte à l'appelant, mais **ne peut plus annuler le commit**. Les listeners suivants ne sont pas exécutés.

| Situation | Comportement |
| --- | --- |
| Erreur prévue et non critique | Le listener peut la capturer, la journaliser et laisser le système dans un état cohérent. |
| Erreur technique inattendue | Elle ne doit pas être silencieusement ignorée ; elle est journalisée et remonte ou est traitée explicitement. |
| Réaction indispensable au succès de l'opération métier | Elle ne doit pas être un événement : utiliser un contrat synchrone avant le commit. |
| Réaction indépendante et différée | Un échec ne doit pas faire croire que le fait métier a échoué. |
| Erreur de programmation | Elle doit être visible en développement et en test ; ne pas la masquer. |

### 16.9 Prévention des traitements multiples

Les doublons peuvent venir :

- d'un double appel de l'Action (double clic, retry utilisateur, job rejoué) ;
- d'un rejeu manuel de l'événement ;
- d'une future file d'attente à livraison au moins une fois ;
- d'un listener enregistré deux fois ;
- d'un événement dispatché deux fois par une Action mal structurée.

La prévention est d'abord une **idempotence métier** chez le consommateur : clé naturelle, contrainte d'unicité, transition conditionnelle, `firstOrCreate`, `updateOrCreate`, `upsert` de projection ou clé d'idempotence externe. Un drapeau en mémoire ou un cache volatil ne suffit pas. La section 18 détaille les techniques et leurs limites.

### 16.10 Comportement en cas de rejeu

Laravel ne fournit aucun rejeu automatique d'un événement synchrone. Rejouer un événement consiste à le reconstruire ou à le rediffuser ; les listeners sont alors rappelés. Sans déduplication, les effets de bord peuvent être répétés.

| Règle | Niveau |
| --- | --- |
| Un rejeu n'est autorisé que si les listeners sont idempotents ou si le rejeu est explicitement supporté. | Obligatoire |
| Le rejeu utilise la même identité métier que l'événement initial. | Obligatoire |
| Un identifiant d'événement généré aléatoirement à chaque tentative ne protège pas contre un nouvel appel de l'Action. | Obligatoire |
| La procédure de rejeu est documentée lorsqu'elle est nécessaire. | Conditionnel |
| Aucun rejeu automatique n'est introduit dans ce lot. | Obligatoire |

### 16.11 Garanties fournies par Laravel et garanties d'infrastructure

| Garantie | Laravel seul | Infrastructure supplémentaire |
| --- | --- | --- |
| Les listeners d'un dispatch sont appelés dans le processus | Oui | — |
| Publication après commit avec `ShouldDispatchAfterCommit` | Oui, si une transaction et le gestionnaire de transactions sont actifs | — |
| Absence de publication après rollback avec `ShouldDispatchAfterCommit` | Oui, le callback est écarté | — |
| Publication immédiate hors transaction | Oui, c'est le comportement Laravel | — |
| Livraison durable après un crash du processus | Non | Outbox ou event store |
| Rejeu automatique d'un listener synchrone | Non | Mécanisme dédié |
| Retry automatique d'un listener en file après échec | Oui, via la queue | Worker supervisé, politique de retry, `failed_jobs` |
| Exactly-once | Non | Non garanti ; au mieux at-least-once + idempotence |
| Ordre global des événements | Non | Ordre de file éventuel, non global |
| Déduplication | Non | Contrainte métier, table de déduplication ou clé d'idempotence |
| Piste d'audit des traitements | Non, seulement des logs | Event store ou table d'audit |

Aucune ligne « Oui » du tableau ne doit être lue comme une garantie de livraison. Laravel garantit un comportement d'exécution dans le processus, pas un transport fiable.

## 17. Publication après commit

### 17.1 Principe

Un événement lié à une écriture transactionnelle ne doit être publié qu'après le commit. Sinon, un consommateur peut réagir à un fait qui sera annulé par un rollback, et produire un effet irréversible (email, écriture, notification, réservation).

Le mécanisme recommandé est `Illuminate\Contracts\Events\ShouldDispatchAfterCommit` sur la classe de l'événement. Il est natif, déclaratif et colocalisé avec l'événement.

### 17.2 `ShouldDispatchAfterCommit` — recommandé

```php
use DateTimeImmutable;
use Illuminate\Contracts\Events\ShouldDispatchAfterCommit;
use Illuminate\Foundation\Events\Dispatchable;

final readonly class AffaireOpened implements ShouldDispatchAfterCommit
{
    use Dispatchable;

    public function __construct(
        public string $affaireId,
        public DateTimeImmutable $openedAt,
    ) {}
}
```

Comportement vérifié dans Laravel 13 :

- le dispatcher détecte l'interface sur l'objet événement ;
- si le gestionnaire de transactions est disponible, il enregistre un callback et **n'invoque pas** les listeners immédiatement (`Dispatcher.php:295-306`) ;
- le callback est attaché à la dernière transaction en cours ; au commit racine, les callbacks sont exécutés (`DatabaseTransactionsManager.php:67-97`, `:213-220`) ;
- en cas de rollback, le callback est écarté et les listeners ne sont pas invoqués (`DatabaseTransactionsManager.php:128-182`) ;
- **hors transaction**, le gestionnaire n'a aucune transaction applicable et exécute le callback immédiatement. L'événement est alors publié sans attendre un commit ;
- si le gestionnaire de transactions n'est pas lié dans le container, le dispatcher publie immédiatement (`Dispatcher.php:298-306`, `:862-865`).

`ShouldDispatchAfterCommit` ne signifie donc pas « publication différée jusqu'à un commit qui existera forcément ». Cela signifie : **après le commit si une transaction est active ; immédiatement sinon**.

**Limite multi-connexions.** Le gestionnaire de transactions suit les transactions par connexion. Avec plusieurs connexions actives, le callback est rattaché à la dernière transaction applicable et ne garantit pas une atomicité entre connexions. Le projet utilise une connexion principale ; ne pas fonder une garantie inter-domaines sur une transaction multi-connexions implicite.

| Avantage | Limite |
| --- | --- |
| Déclaratif et colocalisé avec l'événement. | Publication immédiate hors transaction. |
| Protège tous les points de dispatch de l'événement. | Aucune durabilité si le processus s'arrête après le commit. |
| Écarte le callback en cas de rollback. | Une exception de listener survient après le commit et ne peut pas l'annuler. |
| Ne nécessite aucun broker ni infrastructure. | Ne garantit ni livraison, ni ordre, ni exactly-once. |
| Compatible avec le gestionnaire de transactions de test. | Dépend du gestionnaire `db.transactions` et d'une transaction réellement active. |

### 17.3 `DB::afterCommit`

Une alternative native consiste à enregistrer explicitement le dispatch :

```php
use Illuminate\Support\Facades\DB;

DB::transaction(function () use ($affaire): void {
    $affaire->save();

    DB::afterCommit(function () use ($affaire): void {
        AffaireOpened::dispatch(
            affaireId: (string) $affaire->getKey(),
            openedAt: $affaire->opened_at,
        );
    });
});
```

| Avantage | Limite |
| --- | --- |
| Le dispatch après commit est visible localement. | Il faut penser à l'enregistrer dans chaque transaction. |
| Utile si la classe d'événement ne peut pas implémenter l'interface. | `DB::afterCommit()` lève une `RuntimeException` si le gestionnaire de transactions n'est pas disponible (`ManagesTransactions.php:368-375`). |
| Permet de regrouper plusieurs publications dans un même callback. | Le callback ne doit contenir que la publication, pas de logique métier. |
| Fonctionne avec le gestionnaire de transactions de test. | Il ne rend pas l'événement durable après un crash. |

Hors transaction, `DB::afterCommit()` exécute le callback immédiatement, comme `ShouldDispatchAfterCommit`. Pour un événement d'intégration, l'interface sur la classe reste la convention par défaut : elle protège tous les points de dispatch et évite d'oublier un appel.

### 17.4 `ShouldHandleEventsAfterCommit` sur un listener

`Illuminate\Contracts\Events\ShouldHandleEventsAfterCommit` diffère l'invocation **d'un listener** après commit, sans différer les autres listeners du même événement.

| Cas | Usage |
| --- | --- |
| L'événement est déjà `ShouldDispatchAfterCommit` | Le listener est déjà invoqué après commit ; l'interface supplémentaire est inutile. |
| Un seul listener doit attendre le commit, les autres non | Possible, mais crée une asymétrie difficile à comprendre ; à justifier. |
| La classe d'événement ne peut pas être modifiée | Solution de contournement ; documenter. |

Le mécanisme dépend aussi du gestionnaire de transactions : sans transaction active, le listener est invoqué immédiatement. Il ne remplace pas une garantie de livraison.

### 17.5 `ShouldQueueAfterCommit` et files d'attente

`Illuminate\Contracts\Queue\ShouldQueueAfterCommit` est réservé aux listeners qui implémentent `ShouldQueue` et qui doivent être **mis en file** après le commit. Il ne s'applique pas au listener synchrone par défaut.

| Sujet | État dans le projet |
| --- | --- |
| File par défaut | `config/queue.php` : `env('QUEUE_CONNECTION', 'database')` |
| `.env.example` | `QUEUE_CONNECTION=database` |
| Tests | `phpunit.xml` : `QUEUE_CONNECTION=sync` |
| `after_commit` des connexions | `false` par défaut dans `config/queue.php` |
| Worker supervisé démontré | Non |
| Listener asynchrone autorisé par ce lot | Non |

Un listener `ShouldQueue` sans worker supervisé accumule des jobs dans la table `jobs` sans être exécuté. Le Lot 3 ne l'autorise donc pas. Si une file est introduite plus tard :

- le worker doit être supervisé, surveillé et documenté ;
- la livraison est au moins une fois, jamais exactly-once ;
- les listeners doivent être idempotents ;
- les échecs vont dans `failed_jobs` selon la configuration ;
- l'ordre n'est pas garanti globalement ;
- l'événement doit rester sérialisable avec des types publics, jamais un Model.

### 17.6 `Event::defer` n'est pas un mécanisme après-commit

Laravel 13 propose `Event::defer()`, qui diffère des événements jusqu'à la fin d'un callback. Ce mécanisme :

- ne consulte pas l'état de la transaction ;
- ne garantit pas que le callback corresponde à un commit ;
- écarte les événements différés si le callback lève une exception ;
- peut être utile pour regrouper des publications après la création de plusieurs enregistrements.

Il ne doit pas être présenté comme une publication après commit. Pour un fait lié à une transaction, utiliser `ShouldDispatchAfterCommit` ou `DB::afterCommit()`.

### 17.7 Comportement commit, rollback et absence de transaction

| Situation | Avec `ShouldDispatchAfterCommit` | Sans mécanisme après-commit |
| --- | --- | --- |
| Transaction validée | Listeners après le commit racine | Listeners immédiatement, avant le commit |
| Transaction annulée | Aucun listener | Les listeners ont déjà pu s'exécuter |
| Commit d'une transaction imbriquée | Les callbacks sont exécutés au commit racine | Les listeners s'exécutent immédiatement |
| Rollback d'une transaction imbriquée | Les callbacks de la transaction annulée sont écartés | Les listeners ont déjà pu s'exécuter |
| Aucune transaction active | Publication immédiate | Publication immédiate |
| Listener qui lève une exception | Exception après commit ; les listeners suivants sont ignorés | Exception avant commit ; la transaction peut être annulée |
| Crash du processus après commit | Événement perdu si les callbacks n'ont pas été exécutés | Événement possiblement perdu ou déjà exécuté |

Les callbacks après commit sont en mémoire. Ils ne constituent pas un journal durable. Une panne entre le commit et l'exécution du callback perd l'événement. Un Outbox serait nécessaire pour une durabilité forte ; il est hors périmètre.

### 17.8 Risques de publication prématurée

| Risque | Conséquence |
| --- | --- |
| Événement dispatché avant le commit | Le consommateur réagit à un fait qui peut être annulé. |
| Listener qui envoie un email ou appelle une API avant le commit | L'effet externe est irréversible même si la transaction échoue. |
| Événement Eloquent utilisé comme événement d'intégration | Le déclenchement est lié à la persistance, pas à l'intention métier, et survient souvent avant le commit. |
| Événement dispatché depuis un contrôleur ou un composant d'interface | L'autorisation, la transaction et les invariants peuvent être contournés. |
| Événement dispatché deux fois | Effets de bord dupliqués. |
| Événement publié sans consommateur réel | Bruit, couplage anticipé, maintenance inutile. |

### 17.9 Implications d'un listener synchrone

| Aspect | Conséquence |
| --- | --- |
| Exécution | Dans le même processus et la même requête/commande que l'émetteur, après le commit. |
| Latence | La durée du listener s'ajoute au temps de réponse. |
| Erreur | L'exception remonte à l'appelant après le commit ; elle ne peut pas annuler le fait. |
| Listeners suivants | Ils ne sont pas exécutés si le listener lève une exception. |
| Retry | Aucun retry automatique pour un listener synchrone. |
| Transaction | Le listener n'est pas dans la transaction de l'émetteur ; il gère ses propres écritures. |
| Isolation | Aucune isolation entre listeners ; un listener peut voir les effets d'un précédent. |
| Ordre | Ordre d'enregistrement dans le dispatcher, non contractuel. |
| Coût | Un listener lent bloque la réponse et peut provoquer un timeout. |

Un listener synchrone doit rester court et limiter ses effets de bord. Un traitement lourd, un appel externe lent ou une notification non critique ne doivent pas être exécutés de façon synchrone sans justification.

### 17.10 Implications d'un listener asynchrone

| Aspect | Conséquence |
| --- | --- |
| Prérequis | File configurée et worker supervisé. |
| Latence | Traitement différé ; le fait métier n'attend pas le listener. |
| Livraison | Au moins une fois ; doublons possibles. |
| Erreur | Retry selon la configuration, puis `failed_jobs`. |
| Ordre | Non garanti globalement. |
| Sérialisation | L'événement doit être sérialisable et ne contenir aucun Model. |
| Complexité | Supervision, surveillance, reprise, idempotence, exploitation. |
| Exactly-once | Non garanti. |

Le projet ne dispose pas aujourd'hui d'un worker supervisé démontré. Les listeners restent donc synchrones. L'introduction d'un listener asynchrone devra être justifiée par un besoin réel, avec une décision d'exploitation et une stratégie d'idempotence.

### 17.11 Garanties réelles et limites

| Question | Réponse |
| --- | --- |
| Laravel garantit-il que le listener est exécuté après le commit ? | Oui avec `ShouldDispatchAfterCommit` et une transaction active ; non hors transaction. |
| Laravel garantit-il que le listener ne sera jamais exécuté si le rollback a lieu ? | Oui pour un événement dispatché dans la transaction annulée avec le mécanisme après-commit ; le callback est écarté. |
| Laravel garantit-il que le listener s'exécute ? | Non. Un crash, un timeout ou une exception peut l'empêcher. |
| Laravel garantit-il une seule exécution ? | Non. Un dispatch peut être répété ; une file peut redélivrer. |
| Laravel garantit-il l'ordre ? | Non, au-delà de l'ordre d'enregistrement dans le processus. |
| Laravel garantit-il la durabilité de l'événement ? | Non. Les callbacks sont en mémoire. |
| Laravel fournit-il une déduplication ? | Non. |
| Laravel fournit-il un audit des traitements ? | Non. Les logs ne sont pas un journal de livraison. |

### 17.12 Configuration actuelle et vérification

Les constats suivants sont vérifiables dans le dépôt à la date du Lot 3 :

- `bootstrap/app.php` utilise `Application::configure()`, qui active la découverte d'événements Laravel ; le chemin par défaut est `app/Listeners`.
- `app/Listeners/` n'existe pas ; les listeners de domaine ne sont donc pas découverts automatiquement.
- `config/queue.php` utilise `database` par défaut et `after_commit => false`.
- `.env.example` utilise `QUEUE_CONNECTION=database`.
- `phpunit.xml` utilise `QUEUE_CONNECTION=sync`.
- Aucune configuration de worker supervisé, Supervisor ou Horizon n'est fournie pour les listeners.
- Le script de déploiement prévoit un `queue:restart` optionnel, mais cela ne démontre pas l'existence d'un worker supervisé.

Avant de déclarer une garantie après-commit, vérifier :

1. que l'événement implémente `ShouldDispatchAfterCommit` ;
2. qu'une transaction est réellement active au moment du dispatch ;
3. que le gestionnaire `db.transactions` est lié ;
4. que la configuration de test n'exécute pas les callbacks immédiatement à cause de la transaction de test ;
5. que le listener n'est pas asynchrone sans worker.

`php artisan event:list --event=AffaireOpened` peut aider à vérifier l'enregistrement. `event:cache` ne remplace pas l'enregistrement explicite dans un provider : il cache les événements découverts et les `$listen` des `EventServiceProvider`, pas les appels `Event::listen()` faits dans un `boot()` de provider.

## 18. Consommation et idempotence

### 18.1 Responsabilité du listener

Le listener est responsable de la réaction du domaine consommateur. Il ne devient pas propriétaire du fait ni de la donnée de l'émetteur.

| Responsabilité | Détail |
| --- | --- |
| Recevoir | Le listener reçoit l'événement typé. |
| Vérifier | Il vérifie les données minimales et les invariants de son propre domaine. |
| Déléguer | Il appelle une Action ou un Service du consommateur. |
| Protéger | Il applique l'idempotence adaptée à ses effets de bord. |
| Tracer | Il journalise le traitement sans donnée sensible. |
| Ne pas contourner | Il n'accède ni aux Models, ni aux tables, ni aux Actions internes de l'émetteur. |
| Ne pas répondre | Il ne retourne pas de valeur métier à l'émetteur. |

### 18.2 Règles de consommation

| Règle | Niveau |
| --- | --- |
| Le listener importe uniquement l'événement public, ses types publics, les contrats publics nécessaires et ses propres composants. | Obligatoire |
| Le listener ne dépend pas d'un Model, d'un Builder, d'une Collection Eloquent, d'une Policy ou d'une table de l'émetteur. | Obligatoire |
| Le listener ne suppose jamais que la transaction de l'émetteur est ouverte. | Obligatoire |
| Le listener ne suppose jamais un ordre entre événements. | Obligatoire |
| Le listener ne suppose jamais une exécution unique. | Obligatoire |
| Le listener ne retourne pas de valeur et ne stoppe pas la propagation avec `false`. | Obligatoire |
| Le listener ne réémet pas le même événement pour compenser un échec. | Obligatoire |
| Le listener applique les règles d'autorisation et les invariants de son domaine. | Obligatoire |
| Le listener utilise un contrat public pour obtenir des données complémentaires. | Recommandé |
| Le listener reste court et délègue les traitements lourds. | Recommandé |
| Le listener journalise les erreurs prévues sans exposer de données sensibles. | Obligatoire |

Un listener n'est pas un orchestrateur de workflow inter-domaines. Si une réaction nécessite plusieurs étapes ordonnées, une compensation ou une décision humaine, elle doit être modélisée explicitement dans le domaine consommateur ou dans un processus documenté, pas improvisée dans une chaîne d'événements.

### 18.3 Traitements qui doivent être idempotents

| Traitement | Idempotence nécessaire ? | Remarque |
| --- | --- | --- |
| Lecture et calcul sans écriture | Non, mais le résultat doit rester cohérent | Une répétition ne change rien. |
| Création d'une ligne unique par fait | Oui | Clé naturelle et contrainte d'unicité. |
| Mise à jour d'un statut | Oui | Transition conditionnelle et vérification de l'état. |
| Mouvement de stock | Oui | Risque de double quantité ; clé de mouvement. |
| Écriture comptable ou financière | Oui, obligatoire | Aucun last-write-wins ; audit et clé explicites. |
| Envoi d'email ou notification | Oui, si le doublon est visible | Clé d'idempotence ou journal d'envoi. |
| Appel à une API externe | Oui, si l'API le permet | Clé d'idempotence fournie par l'API ou journal local. |
| Création de fichier ou document | Oui | Nom ou clé stable, pas de doublon. |
| Journalisation | Tolérée en doublon | Attention au bruit et aux données sensibles. |

### 18.4 Techniques d'idempotence

**Clé métier naturelle et contrainte d'unicité — recommandé :**

```php
Budget::firstOrCreate([
    'affaire_id' => $affaireId,
]);
```

Avec un index unique sur `budgets.affaire_id`, la base garantit qu'un seul brouillon existe. Dans Laravel 13, `firstOrCreate()` s'appuie sur `createOrFirst()` et gère la violation d'unicité en relisant l'enregistrement (`Builder.php:753-778`). La contrainte d'unicité reste la protection réelle en concurrence.

**Transition conditionnelle :**

```php
$updated = Budget::query()
    ->whereKey($budgetId)
    ->where('status', BudgetStatus::Draft)
    ->update(['status' => BudgetStatus::Submitted]);

if ($updated === 0) {
    // Déjà traité ou état incompatible : ne pas rejouer l'effet.
}
```

**Table de déduplication dédiée — conditionnel :** si la clé métier ne suffit pas ou si l'effet de bord n'est pas naturellement unique, une table possédée par le consommateur peut enregistrer `(event_type, event_key)` avec une contrainte d'unicité. Elle doit être créée dans le domaine consommateur, avec une politique de purge et une transaction commune avec l'effet de bord si possible. Ce n'est pas un event store générique et ce n'est pas introduit par le Lot 3.

**Clé d'idempotence externe :** si un appel externe accepte une clé d'idempotence, l'utiliser avec une valeur stable dérivée du fait métier. Ne pas générer une nouvelle clé à chaque tentative.

**À éviter :**

- un booléen en mémoire ou une propriété statique ;
- un cache volatil comme seule protection ;
- un `if (! $alreadyProcessed)` sans contrainte en base ;
- un `updateOrCreate` qui écrase un état métier déjà avancé ;
- une déduplication basée uniquement sur le contenu du payload si le contenu peut changer.

### 18.5 Identifiant d'événement et clé d'idempotence

Le Lot 3 **ne rend pas obligatoire** un champ `eventId` dans chaque événement.

Raisons :

- un identifiant aléatoire généré à chaque exécution de l'Action ne déduplique pas un nouvel appel de la même Action ;
- pour être stable lors d'un rejeu, l'identifiant doit être persisté avec le fait ou dérivé de façon déterministe ;
- cette persistance relève d'un event store ou d'un Outbox, hors périmètre ;
- une clé métier stable (`affaireId`, `mouvementId`, etc.) suffit lorsque le fait est unique par cette clé.

| Situation | Clé recommandée |
| --- | --- |
| Un fait unique par affaire | `affaireId` + type de fait |
| Un fait unique par mouvement de stock | `mouvementId` |
| Plusieurs occurrences du même type pour un même objet | Identifiant métier propre à l'occurrence, persisté par le producteur |
| Rejeu d'un événement déjà sérialisé | Identité stable portée par l'événement, si elle existe |

Si un `eventId` est ajouté plus tard :

- il doit être opaque et stable ;
- sa génération, sa persistance et sa durée de conservation doivent être documentées ;
- il ne remplace pas une contrainte métier ;
- il ne doit pas être régénéré à chaque retry ;
- il ne doit pas être présenté comme une garantie exactly-once.

`occurredAt` est la date du fait, pas une clé d'idempotence.

### 18.6 Erreurs et reprises

| Contexte | Comportement attendu |
| --- | --- |
| Listener synchrone, erreur prévue non critique | Capturer, journaliser, laisser le système cohérent ; ne pas faire échouer l'émetteur pour une réaction indépendante. |
| Listener synchrone, erreur technique inattendue | Journaliser et remonter ou traiter explicitement ; ne pas masquer. |
| Listener synchrone, réaction critique | Ne pas utiliser un événement ; contrat synchrone avant commit. |
| Listener asynchrone, erreur | Retry selon la configuration de la file, puis `failed_jobs` ; idempotence obligatoire. |
| Rejeu manuel | Documenté, avec la même identité métier, après vérification de l'idempotence. |
| Échec après commit | Le fait métier reste acquis ; l'appelant ne doit pas supposer un rollback. |

**Ne pas faire :**

- capturer `\Throwable` puis ignorer silencieusement ;
- transformer une erreur technique en succès métier ;
- promettre un retry automatique qui n'existe pas ;
- relancer l'Action complète pour réessayer un listener sans analyser les effets déjà produits ;
- supprimer un événement ou un listener pour masquer un doublon.

### 18.7 Traçabilité des traitements

Le projet n'a pas d'event store et ne fait pas d'event sourcing : les événements ne reconstruisent pas l'état métier. La traçabilité minimale repose sur les logs applicatifs.

| À journaliser | Pourquoi |
| --- | --- |
| Classe de l'événement | Identifier le fait. |
| Clé métier stable (`affaireId`, etc.) | Corréler avec le domaine. |
| Date du fait | Distinguer le fait de son traitement. |
| Classe du listener | Identifier la réaction. |
| Résultat (`handled`, `skipped`, `failed`) | Diagnostiquer. |
| Identifiant de corrélation, s'il existe déjà | Relier à la requête ou au job. |

**À ne pas journaliser :** payload complet, données personnelles, coordonnées, montants non nécessaires, secrets, tokens, contenu de document.

Les logs ne prouvent pas qu'un événement a été livré ou traité une seule fois. Pour un audit opposable, une table dédiée ou un event store est nécessaire ; ce n'est pas introduit par le Lot 3.

### 18.8 Limites de l'idempotence sans stockage dédié

| Sans mécanisme de déduplication | Conséquence possible |
| --- | --- |
| Double appel de l'Action | Deux événements, deux effets si le listener n'est pas idempotent. |
| Rejeu manuel | Effet répété. |
| File à livraison au moins une fois | Doublon après retry ou redélivrance. |
| Email ou notification | Doublon visible par l'utilisateur. |
| Mouvement de stock sans clé unique | Quantité doublée. |
| Écriture financière sans clé unique | Écriture comptable dupliquée. |
| Projection de reporting | Ligne dupliquée ou compteur gonflé. |
| Crash après l'effet de bord, avant l'accusé | Le listener peut être rejoué sans savoir que l'effet a eu lieu. |

Une contrainte d'unicité en base protège uniquement le périmètre de cette base. Elle ne protège pas un appel externe, un email ou un fichier. Une clé d'idempotence externe ou un journal dédié est nécessaire pour ces effets. Aucune solution ne fournit exactly-once de bout en bout.

### 18.9 Autorisation, acteurs et données sensibles

Un événement est un fait système, pas une requête utilisateur. Le listener peut s'exécuter sans utilisateur authentifié.

| Règle | Niveau |
| --- | --- |
| Le listener n'utilise pas `Auth::user()` comme si l'émetteur garantissait un acteur. | Obligatoire |
| Si un acteur est nécessaire, l'événement porte un identifiant minimal, jamais un Model `User`. | Conditionnel |
| L'acteur transmis ne vaut pas autorisation ; le consommateur applique ses propres règles. | Obligatoire |
| Une réaction qui exige une validation humaine crée une tâche ou une notification, elle ne l'exécute pas silencieusement. | Recommandé |
| Aucune donnée sensible inutile n'est exposée ou journalisée. | Obligatoire |
| Un événement financier ou sensible ne déclenche pas une écriture automatique sans règle validée et idempotence explicite. | Obligatoire |

### 18.10 Chaînes d'événements et workflows

Un consommateur peut publier son propre événement après avoir accompli son propre fait. Cela ne doit pas créer un workflow distribué implicite.

| Risque | Règle |
| --- | --- |
| Chaîne A → B → C non documentée | Documenter le processus ou utiliser une orchestration explicite. |
| Boucle d'événements | Interdire ; un événement ne doit pas revenir à son émetteur sous une forme qui le redéclenche. |
| Dépendance à l'ordre | Ne pas supposer l'ordre ; utiliser l'état métier ou une orchestration. |
| Événement utilisé comme compensation | Une compensation doit être explicite, pas un événement implicite. |
| Chaîne difficile à tester | Réduire le nombre de sauts ; préférer un contrat ou une Action orchestratrice. |

Les événements servent à notifier des faits indépendants. Si un processus métier exige une séquence, des décisions ou des compensations, il doit être décrit dans [`business-processes.md`](business-processes.md) et implémenté explicitement.

## 19. Évolution et compatibilité des événements

### 19.1 Principes

Un événement public est une API interne. Il n'est pas publié hors de l'application, mais il est consommé par d'autres domaines. Il doit donc évoluer avec discipline, même si le projet est en version `0.x`.

- L'évolution additive est la voie par défaut.
- Une rupture est coordonnée avec tous les consommateurs connus.
- La sémantique d'un champ ne change jamais silencieusement.
- Un événement n'est pas renommé pour refléter une mode de nommage.
- Aucun versionnement systématique n'est introduit dans les noms.

### 19.2 Évolutions additives compatibles

| Changement | Compatible ? | Remarque |
| --- | --- | --- |
| Ajouter un champ optionnel avec valeur par défaut | Oui | Le consommateur qui ne le lit pas l'ignore ; le constructeur doit rester compatible. |
| Ajouter un nouvel événement pour un nouveau fait | Oui | Aucun impact sur les événements existants. |
| Ajouter un listener consommateur | Oui | Le producteur n'est pas modifié. |
| Ajouter un cas à un enum | Conditionnel | Un consommateur avec un `match` exhaustif peut casser. |
| Ajouter une méthode de commodité à l'événement | Conditionnel | Elle ne doit pas dépendre d'un service ou d'un Model. |
| Ajouter un type public de payload | Oui, s'il est stable et documenté | Ne pas modifier les types existants. |
| Ajouter un consommateur inconnu | Oui | Le producteur doit le documenter dans le catalogue. |

### 19.3 Modifications incompatibles

| Changement | Impact |
| --- | --- |
| Renommer ou supprimer un champ | Rupture pour tous les consommateurs. |
| Changer le type d'un champ | Rupture de typage et de comportement. |
| Rendre un champ optionnel obligatoire | Rupture pour les producteurs et les jeux de données existants. |
| Changer la sémantique d'un champ sans changer son nom | Rupture silencieuse, la plus dangereuse. |
| Renommer l'événement ou changer son namespace | Rupture des imports et de l'enregistrement des listeners. |
| Déplacer la propriété vers un autre domaine | Rupture de contrat et de dépendances. |
| Changer la date du fait ou son fuseau | Rupture d'interprétation. |
| Changer la clé d'idempotence | Doublons ou effets manqués. |
| Passer d'un listener synchrone à un listener asynchrone | Changement de latence, d'ordre et de reprise ; coordination requise. |
| Supprimer un cas d'enum | Rupture pour les consommateurs qui l'utilisent. |
| Fusionner ou scinder un événement | Rupture de contrat ; nouvelle conception à coordonner. |

### 19.4 Coordination entre émetteur et consommateurs

| Étape | Responsabilité |
| --- | --- |
| Identifier les consommateurs | L'émetteur tient le catalogue et recherche les imports dans le code. |
| Décrire le changement | La Pull Request indique le champ, le type, la sémantique et les consommateurs. |
| Mettre à jour les consommateurs | Dans la même Pull Request si possible, sinon dans une Pull Request coordonnée. |
| Prévoir une coexistence | Conserver l'ancien champ ou l'ancien événement pendant la transition. |
| Tester | Tester l'émetteur, chaque consommateur et la compatibilité. |
| Déprécier | Documenter la dépréciation et la date cible de retrait. |
| Retirer | Supprimer après migration de tous les consommateurs connus ; c'est une rupture. |

Aucun domaine ne doit découvrir un changement de schéma en production. Une rupture non coordonnée est un défaut de contrat, même si le projet est en `0.x`.

### 19.5 Dépréciation d'un champ ou d'un événement

| Règle | Niveau |
| --- | --- |
| Un champ déprécié reste présent et alimenté pendant la transition. | Obligatoire |
| Le docblock indique `@deprecated`, la date ou la version depuis laquelle il est déprécié, le remplacement et la condition de retrait. | Recommandé |
| Le catalogue indique le statut `Deprecated`. | Recommandé |
| L'événement déprécié reste publié tant que des consommateurs existent. | Obligatoire |
| La suppression d'un champ ou d'un événement est annoncée et coordonnée. | Obligatoire |
| Un nom déprécié n'est pas réutilisé pour une nouvelle sémantique. | Obligatoire |

### 19.6 Documentation des changements

| Support | Contenu |
| --- | --- |
| Docblock de l'événement | Fait, propriétaire, consommateurs connus, date du fait, éventuelles dépréciations. |
| Catalogue des événements | Propriétaire, consommateurs, statut, date d'introduction. |
| Pull Request | Résumé du changement, impact, consommateurs, tests, plan de migration. |
| Docblock du listener | Réaction, clé d'idempotence, erreurs attendues. |
| Ce document | Mise à jour si une convention change. |

Aucun fichier de changelog séparé n'est imposé. Le catalogue et la Pull Request suffisent tant que le nombre d'événements reste faible.

### 19.7 Versionnement

Aucun versionnement systématique des noms d'événements n'est introduit.

- Un changement compatible ne crée pas de `V2`.
- Un nouveau fait crée un nouvel événement au nom métier explicite.
- Une rupture réelle peut nécessiter une nouvelle classe ou un nouveau namespace, avec une période de coexistence.
- Un suffixe de version n'est utilisé qu'en dernier recours, s'il existe réellement plusieurs contrats simultanés à maintenir ; il doit être documenté et justifié.
- Le numéro de version du projet ne remplace pas la compatibilité d'un événement.

### 19.8 Catalogue des événements

Lorsqu'un premier événement réel sera créé, tenir un tableau minimal :

| Événement | Propriétaire | Consommateurs connus | Depuis | Statut |
| --- | --- | --- | --- | --- |
| — | — | — | — | Aucun événement implémenté à ce jour |

Ce catalogue ne doit pas être rempli avec l'exemple fictif de la section 20. Il doit refléter uniquement les événements réellement présents dans le code.

### 19.9 Robustesse du consommateur face à l'évolution

- Le consommateur ne doit pas dépendre de l'ordre des propriétés ni d'une sérialisation maison.
- Il doit tolérer un champ optionnel absent si le contrat le permet.
- Il ne doit pas utiliser `toArray()` de l'événement comme schéma public.
- Il doit traiter les valeurs inconnues d'un enum de façon explicite (ignorer, journaliser ou échouer selon la règle métier), sans supposer que l'enum est exhaustif pour toujours.
- Il doit être testé avec la version courante de l'événement et, si une coexistence existe, avec l'ancienne.

## 20. Exemple complet illustratif

> **Exemple fictif et illustratif.** Aucun flux métier de ce type n'est implémenté. Les classes `Affaire`, `OpenAffaireData`, `Budget`, `CreateBudgetDraft` et les règles de création d'un brouillon de budget ne sont pas validées par ce lot. L'exemple ne vaut pas autorisation de dépendance entre Projects et Budgets ; la matrice de CHAN-29 Lot 2 doit la confirmer. Il ne doit pas être copié tel quel dans `app/Domains/`.

### 20.1 Contexte

Le domaine **Projects** ouvre une affaire à l'issue de P01 (devis accepté) ou de P02 (commande ou ordre de service). D'autres domaines peuvent réagir indépendamment.

L'exemple retient un consommateur **Budgets** qui crée un brouillon de budget pour l'affaire ouverte. Ce choix sert uniquement à illustrer la publication, l'enregistrement, l'idempotence et les tests. Il ne signifie pas que Budgets doit automatiquement créer un budget à l'ouverture d'une affaire.

### 20.2 Arborescence

```text
app/Domains/Projects/
├── Actions/
│   └── OpenAffaire.php
└── Events/
    └── Integration/
        └── AffaireOpened.php

app/Domains/Budgets/
├── Actions/
│   └── CreateBudgetDraft.php
├── Listeners/
│   └── CreateAffaireBudgetDraft.php
└── Providers/
    └── BudgetsServiceProvider.php
```

### 20.3 Classe de l'événement

```php
<?php

namespace App\Domains\Projects\Events\Integration;

use DateTimeImmutable;
use Illuminate\Contracts\Events\ShouldDispatchAfterCommit;
use Illuminate\Foundation\Events\Dispatchable;

/**
 * Fait : une affaire a été ouverte.
 *
 * Propriétaire : Projects.
 * Consommateurs connus : Budgets (exemple illustratif).
 * Publication : après commit de la transaction qui ouvre l'affaire.
 */
final readonly class AffaireOpened implements ShouldDispatchAfterCommit
{
    use Dispatchable;

    public function __construct(
        public string $affaireId,
        public DateTimeImmutable $openedAt,
    ) {}
}
```

**Payload :**

| Champ | Type | Rôle | Justification |
| --- | --- | --- | --- |
| `affaireId` | `string` illustratif | Identifier l'affaire ouverte | Clé de corrélation et d'idempotence. |
| `openedAt` | `DateTimeImmutable` | Date du fait | Permet au consommateur de dater sa réaction. |

Le payload ne contient ni client, ni montant, ni périmètre, ni liste de chantiers. Un consommateur qui a besoin de ces données utilise un contrat public de Projects ; il ne les exige pas dans l'événement.

### 20.4 Action du domaine émetteur

```php
<?php

namespace App\Domains\Projects\Actions;

use App\Domains\Projects\DTO\OpenAffaireData;
use App\Domains\Projects\Events\Integration\AffaireOpened;
use App\Domains\Projects\Models\Affaire;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;

final class OpenAffaire
{
    public function handle(User $actor, OpenAffaireData $data): Affaire
    {
        Gate::forUser($actor)->authorize('create', Affaire::class);

        return DB::transaction(function () use ($data): Affaire {
            $affaire = Affaire::create([
                'numero' => $data->numero,
                'client_id' => $data->clientId,
                'opened_at' => now(),
            ]);

            AffaireOpened::dispatch(
                affaireId: (string) $affaire->getKey(),
                openedAt: $affaire->opened_at,
            );

            return $affaire;
        });
    }
}
```

`OpenAffaireData` et le Model `Affaire` sont illustratifs. Le Model caste `opened_at` en type immuable. L'Action réelle doit respecter CHAN-27 : autorisation, invariants, transaction et publication visible dans l'orchestration. L'événement est dispatché **à l'intérieur** de la transaction ; grâce à `ShouldDispatchAfterCommit`, les listeners sont invoqués après le commit.

### 20.5 Listener du domaine consommateur

```php
<?php

namespace App\Domains\Budgets\Listeners;

use App\Domains\Budgets\Actions\CreateBudgetDraft;
use App\Domains\Projects\Events\Integration\AffaireOpened;

final class CreateAffaireBudgetDraft
{
    public function __construct(
        private readonly CreateBudgetDraft $createBudgetDraft,
    ) {}

    public function handle(AffaireOpened $event): void
    {
        $this->createBudgetDraft->handle($event->affaireId);
    }
}
```

Le listener ne fait que recevoir et déléguer. Il ne retourne rien, n'accède pas à `Affaire` et ne modifie pas Projects.

### 20.6 Traitement idempotent du consommateur

```php
<?php

namespace App\Domains\Budgets\Actions;

use App\Domains\Budgets\Models\Budget;

final class CreateBudgetDraft
{
    public function handle(string $affaireId): void
    {
        Budget::firstOrCreate([
            'affaire_id' => $affaireId,
        ]);
    }
}
```

L'idempotence repose sur un index unique `budgets.affaire_id` et sur `firstOrCreate()`. Le Model définit le statut par défaut du brouillon, ou l'Action fournit les valeurs manquantes. Si le brouillon existe déjà, aucun doublon n'est créé. Si deux traitements concurrents arrivent, la contrainte d'unicité tranche et `createOrFirst()` relit l'enregistrement existant.

Si la règle métier interdit de créer un brouillon dans certains cas, l'Action du consommateur doit vérifier cette règle **avant** l'écriture et rester idempotente. Le brouillon de budget n'est pas une écriture financière validée ; une écriture comptable nécessiterait une clé d'idempotence et un audit dédiés.

### 20.7 Enregistrement des listeners

```php
<?php

namespace App\Domains\Budgets\Providers;

use App\Domains\Budgets\Listeners\CreateAffaireBudgetDraft;
use App\Domains\Projects\Events\Integration\AffaireOpened;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\ServiceProvider;

final class BudgetsServiceProvider extends ServiceProvider
{
    public function boot(): void
    {
        Event::listen(
            AffaireOpened::class,
            CreateAffaireBudgetDraft::class,
        );
    }
}
```

Enregistrement futur dans `bootstrap/providers.php` :

```php
use App\Domains\Budgets\Providers\BudgetsServiceProvider;
use App\Providers\AppServiceProvider;
use App\Providers\Filament\AdminPanelProvider;

return [
    AppServiceProvider::class,
    AdminPanelProvider::class,
    BudgetsServiceProvider::class,
];
```

Ce fichier n'est **pas modifié** dans le Lot 3. Il le sera lors de l'implémentation réelle du premier listener. Chaque autre consommateur ajoute son propre provider et son propre listener sans modifier Projects.

### 20.8 Séquence

1. L'interface appelle `OpenAffaire`.
2. L'Action autorise l'ouverture, ouvre une transaction et crée l'affaire.
3. L'Action construit `AffaireOpened` avec l'identifiant et la date du fait.
4. Le dispatcher voit `ShouldDispatchAfterCommit` et enregistre un callback.
5. La transaction est validée.
6. Le callback invoque `CreateAffaireBudgetDraft`.
7. Le listener appelle `CreateBudgetDraft`, qui crée le brouillon ou ne fait rien s'il existe déjà.
8. Si un listener lève une exception, l'affaire reste ouverte et l'exception remonte ; aucun retry automatique n'est promis.

### 20.9 Ce qui est public et ce qui reste interne

| Élément | Public | Interne |
| --- | --- | --- |
| `AffaireOpened` | Oui | — |
| `affaireId`, `openedAt` | Oui, via l'événement | — |
| `OpenAffaire` | — | Oui (Projects) |
| `Affaire` | — | Oui (Projects) |
| `CreateAffaireBudgetDraft` | — | Oui (Budgets) |
| `CreateBudgetDraft` | — | Oui (Budgets) |
| `Budget` | — | Oui (Budgets) |
| `BudgetsServiceProvider` | — | Oui (câblage) |

Le consommateur importe uniquement `App\Domains\Projects\Events\Integration\AffaireOpened`. S'il a besoin du client, du montant, du périmètre ou d'une décision, il utilise un contrat public de Projects et vérifie que la dépendance est autorisée par CHAN-29.

### 20.10 Variantes et limites de l'exemple

- Si le domaine distingue **ouverture** et **confirmation** de l'affaire, il publie deux faits distincts (`AffaireOpened`, `AffaireConfirmed`) plutôt qu'un événement avec un statut ambigu.
- Si un consommateur a besoin de l'identité du client, Projects expose un contrat de lecture ; l'événement n'est pas élargi sans besoin réel.
- Si Budgets ne doit pas créer automatiquement de brouillon, le listener illustratif est remplacé ; la mécanique de publication et d'idempotence reste la même.
- Une correction technique ou un import de données ne doit pas publier un événement métier sans décision explicite. Si une opération légitime s'exécute hors transaction, le comportement immédiat doit être documenté et accepté.
- L'exemple ne crée aucune dépendance Projects → Budgets. La dépendance va de Budgets vers l'événement public de Projects ; sa validation relève de CHAN-29.

## 21. Tests documentaires des événements

> **Aucun test applicatif n'est créé dans le Lot 3.** Les exemples ci-dessous décrivent les tests à écrire lors de l'implémentation réelle. Ils utilisent les API disponibles dans Laravel 13 et Pest 5.

### 21.1 Principes

| Test | Objectif |
| --- | --- |
| Structure et payload | L'événement est immuable, typé et expose uniquement les champs prévus. |
| Publication après commit | Les listeners ne sont pas invoqués avant le commit. |
| Absence de publication en cas de rollback | Un fait annulé ne produit aucun effet. |
| Déclenchement des listeners | Le listener est enregistré et réagit à l'événement. |
| Comportement en cas d'erreur | Une erreur de listener ne fait pas croire à un rollback de l'émetteur. |
| Idempotence | Un traitement répété ne duplique pas l'effet de bord. |
| Évolution | Un champ optionnel ancien ne casse pas le consommateur, si une coexistence existe. |

Les tests doivent vérifier le comportement observable, pas l'implémentation interne du dispatcher. Les tests d'architecture complets relèvent de CHAN-31.

### 21.2 Structure et payload de l'événement

```php
<?php

use App\Domains\Projects\Events\Integration\AffaireOpened;
use Illuminate\Contracts\Events\ShouldDispatchAfterCommit;

it('exposes the minimal AffaireOpened payload', function () {
    $openedAt = new DateTimeImmutable('2026-11-15T09:00:00+00:00');

    $event = new AffaireOpened(
        affaireId: 'affaire-1',
        openedAt: $openedAt,
    );

    expect($event)
        ->toBeInstanceOf(ShouldDispatchAfterCommit::class)
        ->and($event->affaireId)->toBe('affaire-1')
        ->and($event->openedAt)->toBe($openedAt);
});
```

Un test de réflexion peut vérifier que la classe est `readonly` et que le constructeur n'expose pas de type Eloquent. Ces contrôles structurels relèvent plutôt de CHAN-31 ; le test de comportement ci-dessus suffit pour le payload.

### 21.3 Publication après commit

```php
<?php

use App\Domains\Projects\Events\Integration\AffaireOpened;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;

it('publishes AffaireOpened only after the transaction commits', function () {
    Event::fake();

    DB::transaction(function (): void {
        AffaireOpened::dispatch(
            affaireId: 'affaire-1',
            openedAt: new DateTimeImmutable('2026-11-15T09:00:00+00:00'),
        );

        Event::assertNotDispatched(AffaireOpened::class);
    });

    Event::assertDispatchedOnce(AffaireOpened::class);
});
```

Le test doit encapsuler le dispatch dans `DB::transaction()`. Sans transaction imbriquée, le gestionnaire de transactions de test considère qu'il n'y a pas de transaction applicable et exécute le callback immédiatement. La section 21.9 explique ce comportement.

### 21.4 Absence de publication en cas de rollback

```php
<?php

use App\Domains\Projects\Events\Integration\AffaireOpened;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;

it('does not publish AffaireOpened when the transaction rolls back', function () {
    Event::fake();

    try {
        DB::transaction(function (): void {
            AffaireOpened::dispatch(
                affaireId: 'affaire-1',
                openedAt: new DateTimeImmutable('2026-11-15T09:00:00+00:00'),
            );

            throw new RuntimeException('rollback');
        });
    } catch (RuntimeException) {
        // Rollback attendu.
    }

    Event::assertNotDispatched(AffaireOpened::class);
});
```

### 21.5 Déclenchement et enregistrement des listeners

```php
<?php

use App\Domains\Budgets\Listeners\CreateAffaireBudgetDraft;
use App\Domains\Projects\Events\Integration\AffaireOpened;
use Illuminate\Support\Facades\Event;

it('registers the Budgets listener', function () {
    Event::fake();

    Event::assertListening(
        AffaireOpened::class,
        CreateAffaireBudgetDraft::class,
    );
});
```

Ce test échoue si le provider du consommateur n'est pas enregistré dans `bootstrap/providers.php` ou si le listener est renommé. Il vérifie l'enregistrement, pas le comportement métier.

### 21.6 Comportement du listener et idempotence

```php
<?php

use App\Domains\Budgets\Listeners\CreateAffaireBudgetDraft;
use App\Domains\Budgets\Models\Budget;
use App\Domains\Projects\Events\Integration\AffaireOpened;

it('creates a single budget draft for the same opened affaire', function () {
    $listener = app(CreateAffaireBudgetDraft::class);
    $event = new AffaireOpened(
        affaireId: 'affaire-1',
        openedAt: new DateTimeImmutable('2026-11-15T09:00:00+00:00'),
    );

    $listener->handle($event);
    $listener->handle($event);

    expect(
        Budget::query()->where('affaire_id', 'affaire-1')->count(),
    )->toBe(1);
});
```

Le test appelle le listener deux fois pour simuler un rejeu. Il ne prouve pas la sécurité en concurrence : celle-ci repose sur l'index unique de la base. Un test d'intégration concurrent peut être ajouté si le risque est réel.

### 21.7 Comportement en cas d'erreur du listener

```php
<?php

use App\Domains\Projects\Events\Integration\AffaireOpened;
use App\Domains\Projects\Models\Affaire;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;

it('does not roll back the committed producer when a listener throws', function () {
    Event::forget(AffaireOpened::class);
    Event::listen(
        AffaireOpened::class,
        fn (AffaireOpened $event): never => throw new RuntimeException('listener failure'),
    );

    $affaireId = null;

    expect(function () use (&$affaireId): void {
        DB::transaction(function () use (&$affaireId): void {
            $affaire = Affaire::create([
                'numero' => 'AFF-001',
                'client_id' => 'client-1',
                'opened_at' => now(),
            ]);

            $affaireId = $affaire->getKey();

            AffaireOpened::dispatch(
                affaireId: (string) $affaire->getKey(),
                openedAt: $affaire->opened_at,
            );
        });
    })->toThrow(RuntimeException::class);

    expect($affaireId)->not->toBeNull()
        ->and(Affaire::find($affaireId))->not->toBeNull();
});
```

Ce test vérifie une limite fondamentale : le listener s'exécute après le commit, donc son exception ne peut pas annuler l'affaire. Il ne faut pas utiliser `Event::fake()` ici, sinon le listener ne serait pas exécuté. Le test est une démonstration de comportement, pas une invitation à laisser les erreurs de listener non traitées.

### 21.8 Absence de publication en cas d'échec métier

```php
<?php

use App\Domains\Projects\Actions\OpenAffaire;
use App\Domains\Projects\Events\Integration\AffaireOpened;
use Illuminate\Support\Facades\Event;

it('does not publish when the operation is rejected before commit', function () {
    Event::fake();

    expect(fn () => app(OpenAffaire::class)->handle($actor, $invalidData))
        ->toThrow(DomainException::class);

    Event::assertNotDispatched(AffaireOpened::class);
});
```

`$actor`, `$invalidData` et `DomainException` sont illustratifs. Le test réel doit utiliser les objets et l'exception du domaine.

### 21.9 Comportement de test des callbacks après commit

Le projet applique `RefreshDatabase` aux tests Feature (`tests/Pest.php:18-20`). Laravel remplace alors le gestionnaire de transactions par `Illuminate\Foundation\Testing\DatabaseTransactionsManager` (`RefreshDatabase.php:159-181`). Ce gestionnaire de test :

- ignore la transaction englobante du test dans `callbackApplicableTransactions()` (`DatabaseTransactionsManager.php:44-52`) ;
- exécute immédiatement un callback après commit s'il n'y a pas de transaction imbriquée ;
- exécute les callbacks au commit d'une transaction imbriquée, car `afterCommitCallbacksShouldBeExecuted(1)` retourne `true` (`DatabaseTransactionsManager.php:54-63`).

Conséquences pour les tests :

| Situation | Comportement |
| --- | --- |
| Événement dispatché directement dans le test, sans `DB::transaction` | Le callback est exécuté immédiatement ; `assertDispatched` passe, mais le test ne prouve pas l'après-commit. |
| Événement dispatché dans `DB::transaction` | Le callback est attaché à la transaction imbriquée et exécuté à son commit. |
| Exception dans `DB::transaction` | Le callback est écarté ; `assertNotDispatched` passe. |
| Appel à `DB::commit()` sur la transaction de test | À éviter : cela casse l'isolation du test. |

`Event::fake()` respecte `ShouldDispatchAfterCommit` : le fake enregistre aussi le callback auprès du gestionnaire de transactions (`EventFake.php:365-373`). Il ne contourne donc pas le comportement testé.

### 21.10 Tests d'architecture différés

Les contrôles suivants relèvent de CHAN-31 et ne sont pas ajoutés dans ce lot :

- l'événement est dans `Events/Integration/` ;
- le payload ne contient aucun type Eloquent ;
- le consommateur n'importe que l'événement public et les contrats publics ;
- aucun listener n'est enregistré deux fois ;
- aucun événement n'est dispatché depuis un Model, un Observer ou un contrôleur ;
- aucun listener ne dépend d'une table de l'émetteur.

Ces règles doivent être automatisées lorsqu'un premier événement réel existera.

## 22. Checklist de revue des événements

- [ ] Un consommateur réel est identifié ; l'événement n'est pas anticipé.
- [ ] L'événement appartient au domaine émetteur et est placé dans `Events/Integration/`.
- [ ] Le nom décrit un fait métier au passé, sans suffixe `Event` ou `Integration`.
- [ ] La classe est immuable, typée et sans logique de persistance.
- [ ] Le constructeur ne fait aucune requête et n'appelle aucun service.
- [ ] Le payload est minimal ; chaque champ a un consommateur réel.
- [ ] Aucun Model, Builder, Collection Eloquent, `User`, `Request`, Livewire ou Filament n'est exposé.
- [ ] Aucun tableau non typé ne sert de schéma.
- [ ] Aucune donnée sensible, personnelle ou financière inutile n'est exposée.
- [ ] L'événement implémente `ShouldDispatchAfterCommit`.
- [ ] L'Action dispatch l'événement après le fait métier et dans la transaction.
- [ ] L'événement n'est pas dispatché depuis un Model, un Observer, une Policy ou un contrôleur.
- [ ] Le listener est dans le domaine consommateur et délègue à une Action ou un Service.
- [ ] Le listener retourne `void` et n'attend aucune réponse.
- [ ] Le listener n'importe aucun composant interne de l'émetteur.
- [ ] L'enregistrement est explicite dans le provider du consommateur et `bootstrap/providers.php`.
- [ ] L'ordre des listeners n'est pas supposé.
- [ ] L'idempotence est assurée par une clé métier, une contrainte d'unicité ou une stratégie documentée.
- [ ] Les effets de bord externes ont une protection contre les doublons ou une limite documentée.
- [ ] Aucune garantie exactly-once n'est annoncée.
- [ ] Une erreur de listener ne peut pas être confondue avec un rollback de l'émetteur.
- [ ] Une réaction critique utilise un contrat synchrone, pas un événement.
- [ ] Le listener ne publie pas le même événement et ne crée pas de boucle.
- [ ] La traçabilité journalise la clé métier et le listener, sans payload sensible.
- [ ] L'évolution est additive ou coordonnée avec les consommateurs connus.
- [ ] Le catalogue des événements est mis à jour.
- [ ] Les tests couvrent le payload, l'après-commit, le rollback, le listener, l'erreur et l'idempotence.
- [ ] Aucun broker, Outbox, worker ou retry complexe n'est introduit sans décision.

## 23. Sujets différés

| Sujet | Ticket ou lot |
| --- | --- |
| Matrice des dépendances autorisées et interdites entre domaines | CHAN-29 |
| Tests d'architecture et contrôle automatisé des imports | CHAN-31 |
| Harmonisation de `AGENTS.md` (`modules/`, Bootstrap, etc.) | CHAN-30 |
| Files d'attente supervisées, workers, `failed_jobs` et reprise | Décision d'exploitation ultérieure |
| Outbox, event store, durabilité et rejeu automatique | Décision d'architecture ultérieure |
| Broker externe et architecture distribuée | Hors périmètre CHAN-28 |
| Déduplication générique et table de traitement | À instruire au premier besoin réel |
| Stratégie d'identifiants UUID/ULID | Décision transversale / Identity |
| Convention monétaire et devise | Décision transversale |
| Organisation des tests par domaine | Ticket d'implémentation du premier domaine |
| Mapping des exceptions de contrat vers Livewire/Filament | Ticket d'interface concerné |
| Catalogue exhaustif des contrats et des événements | À remplir au premier contrat et au premier événement réels |
| Audit opposable des traitements | À définir avec l'exploitation et les besoins métier |

## 24. Références

- [`docs/architecture/domain-conventions.md`](domain-conventions.md) — conventions internes CHAN-27, notamment les événements locaux.
- [`docs/architecture/domain-responsibilities.md`](domain-responsibilities.md) — responsabilités et périmètres des 18 domaines.
- [`docs/architecture/business-processes.md`](business-processes.md) — processus P01 et P02, ouverture d'affaire.
- [`docs/architecture/domain-boundary-decisions.md`](domain-boundary-decisions.md) — décisions V-09, V-10, V-11 et V-12.
- [`docs/architecture/domain-interactions-register.md`](domain-interactions-register.md) — interactions métier, notamment INT-006, INT-007 et INT-014.
- [`app/Core/README.md`](../../app/Core/README.md) — périmètre du noyau technique.
- [`app/Domains/README.md`](../../app/Domains/README.md) — organisation des domaines.
- [`AGENTS.md`](../../AGENTS.md) — règles générales du dépôt.
- [`docs/development/git-workflow.md`](../development/git-workflow.md) — branches, commits et Pull Requests.
- [`docs/development/release-process.md`](../development/release-process.md) — contrat public externe et versionnement.
- [Laravel 13 — Events](https://laravel.com/docs/13.x/events) — `ShouldDispatchAfterCommit`, `ShouldHandleEventsAfterCommit`, découverte et tests.
- [Laravel 13 — Queues](https://laravel.com/docs/13.x/queues) — `ShouldQueueAfterCommit`, retries, `failed_jobs`.
- [Laravel 13 — Database Transactions](https://laravel.com/docs/13.x/database#database-transactions) — `DB::afterCommit()` et transactions.
- [Laravel 13 — Service Container](https://laravel.com/docs/13.x/container) — autowiring, bindings et résolution contextuelle.
- [Laravel 13 — Service Providers](https://laravel.com/docs/13.x/providers) — `register()`, `boot()` et enregistrement.
- [Jira — CHAN-28](https://sarlc2me.atlassian.net/browse/CHAN-28) — ticket de référence.
- [Jira — CHAN-10](https://sarlc2me.atlassian.net/browse/CHAN-10) — architecture Modular Monolith.
