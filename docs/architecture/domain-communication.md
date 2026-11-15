# Contrats synchrones inter-domaines

Ce document définit les conventions applicables aux **contrats synchrones** entre domaines métier de **C2ME Chantier**.

- Ticket : CHAN-28 — Définir les contrats et règles de communication inter-domaines.
- Ticket parent : CHAN-10 — Mettre en place l'architecture Modular Monolith.
- Portée de ce lot : contrats synchrones, propriété, structure, DTO, erreurs, injection Laravel, transactions, tests et évolution.
- Hors portée de ce lot : événements inter-domaines, files d'attente, Outbox, broker externe, matrice de dépendances CHAN-29, tests d'architecture CHAN-31 et harmonisation générale de `AGENTS.md` CHAN-30.

> **Statut : document de travail — Lot 2.**
>
> Ce document formalise uniquement les contrats synchrones. Les événements inter-domaines seront ajoutés au Lot 3. Aucun contrat, DTO, Model de domaine, Action, Service, événement ou provider de domaine n'est implémenté à ce stade : les exemples sont **fictifs et pédagogiques**. Ils ne représentent ni un besoin métier validé, ni une fonctionnalité existante.

Les conventions internes d'un domaine restent définies par [`domain-conventions.md`](domain-conventions.md) (CHAN-27). Ce document ne les remplace pas ; il les complète pour la frontière entre domaines.

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
| Périmètre | Contrats synchrones uniquement ; événements réservés au Lot 3. |

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
| `Contracts/` | **Oui** | Seule surface publique du fournisseur. |
| `Contracts/Exceptions/` | **Oui** | Exceptions déclarées par le contrat. |
| `Models/` | **Non** | Aucun Model Eloquent ne traverse la frontière. |
| `Actions/` | **Non** | Une Action porte autorisation, transaction et intention d'interface ; ce n'est pas une API. |
| `Services/` | **Non** | Logique interne, non stabilisée. |
| `DTO/` | **Non** | DTO internes, libres d'évoluer. |
| `Policies/` | **Non** | Chaque domaine applique ses propres droits. |
| `Events/` local | **Non** | Événement local ; les événements publics relèvent du Lot 3. |

**Règle de lecture :** pour la surface d'échange définie par CHAN-28, un consommateur importe uniquement `App\Domains\{Provider}\Contracts\...` et rien d'autre du fournisseur. La matrice des dépendances autorisées entre domaines reste du ressort de CHAN-29.

### 4.5 Importations autorisées et interdites

```php
// Autorisé : contrat public et DTO public.
use App\Domains\ReferenceProvider\Contracts\ReferenceAvailability;
use App\Domains\ReferenceProvider\Contracts\ReferenceAvailabilityQuery;
use App\Domains\ReferenceProvider\Contracts\ReferenceAvailabilityResult;
use App\Domains\ReferenceProvider\Contracts\Exceptions\ReferenceNotFoundException;

// Interdit : implémentation interne du fournisseur.
use App\Domains\ReferenceProvider\Models\ReferenceItem;
use App\Domains\ReferenceProvider\Services\ReferenceAvailabilityChecker;
use App\Domains\ReferenceProvider\DTO\ReferenceAvailabilityData;
use App\Domains\ReferenceProvider\Actions\CheckReference;
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

Les événements et la publication après commit relèvent du Lot 3 ; ils ne sont pas traités ici.

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
- un consommateur ne peut importer que `Contracts/` ;
- aucun DTO public ne contient de type Eloquent ;
- aucun événement public n'est créé avant le Lot 3.

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

## 14. Checklist de revue

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
- [ ] Aucun événement ni listener n'est introduit dans ce lot.

## 15. Sujets différés

| Sujet | Ticket ou lot |
| --- | --- |
| Événements inter-domaines, publication après commit, listeners, idempotence événementielle | Lot 3 de CHAN-28 |
| Matrice des dépendances autorisées et interdites entre domaines | CHAN-29 |
| Tests d'architecture et contrôle automatisé des imports | CHAN-31 |
| Harmonisation de `AGENTS.md` (`modules/`, Bootstrap, etc.) | CHAN-30 |
| Infrastructure de queue, Outbox, broker externe | Hors périmètre CHAN-28 |
| Stratégie d'identifiants UUID/ULID | Décision transversale / Identity |
| Convention monétaire et devise | Décision transversale |
| Organisation des tests par domaine | Ticket d'implémentation du premier domaine |
| Mapping des exceptions de contrat vers Livewire/Filament | Ticket d'interface concerné |
| Catalogue exhaustif des contrats | À remplir au premier contrat réel |

## 16. Références

- [`docs/architecture/domain-conventions.md`](domain-conventions.md) — conventions internes CHAN-27.
- [`app/Core/README.md`](../../app/Core/README.md) — périmètre du noyau technique.
- [`app/Domains/README.md`](../../app/Domains/README.md) — organisation des domaines.
- [`AGENTS.md`](../../AGENTS.md) — règles générales du dépôt.
- [`docs/development/git-workflow.md`](../development/git-workflow.md) — branches, commits et Pull Requests.
- [`docs/development/release-process.md`](../development/release-process.md) — contrat public externe et versionnement.
- [Laravel 13 — Service Container](https://laravel.com/docs/13.x/container) — autowiring, bindings et résolution contextuelle.
- [Laravel 13 — Service Providers](https://laravel.com/docs/13.x/providers) — `register()`, `boot()` et enregistrement.
- [Jira — CHAN-28](https://sarlc2me.atlassian.net/browse/CHAN-28) — ticket de référence.
- [Jira — CHAN-10](https://sarlc2me.atlassian.net/browse/CHAN-10) — architecture Modular Monolith.
