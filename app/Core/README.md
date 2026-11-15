# Core applicatif

Ce répertoire héberge les composants **techniques transverses** réellement partagés par plusieurs domaines métier indépendants.

Il ne constitue ni une couche métier, ni un fourre-tout applicatif. La fondation est volontairement minimale : seuls les composants répondant aux critères de promotion décrits ci-dessous y sont ajoutés.

## Finalité

Le Core fournit des briques génériques, stables et indépendantes du contexte fonctionnel, afin d'éviter la duplication de code technique entre domaines sans créer de couplage entre eux.

Il poursuit trois objectifs :

- centraliser les préoccupations purement techniques partagées ;
- garantir que ces briques ne dépendent d'aucun domaine métier ;
- offrir aux domaines des points d'appui explicites et documentés.

## Responsabilités autorisées

Un composant du Core peut notamment porter, lorsqu'un besoin réel le justifie :

- des utilitaires techniques génériques sans connaissance métier ;
- des exceptions techniques transverses ;
- des objets de valeur purement techniques (identifiants, intervalles, durées) sans règle métier ;
- des traits (`Concerns`) techniques réutilisables ;
- des contrats techniques génériques, distincts des contrats inter-domaines ;
- des abstractions techniques minces au-dessus de packages Laravel ou Composer lorsque l'intégration est réellement transverse.

Chaque ajout doit rester limité à sa responsabilité et documenté par son code et, si nécessaire, par un README local.

## Responsabilités interdites

Le Core ne doit contenir :

- aucune règle métier propre à un domaine ;
- aucun modèle Eloquent métier ;
- aucun service, cas d'usage, action ou politique métier ;
- aucune logique fonctionnelle déplacée par commodité ;
- aucune migration, route, vue ou composant d'interface métier ;
- aucune dépendance vers une implémentation concrète d'un domaine métier.

Un composant simplement utilisé à plusieurs endroits n'a pas sa place dans le Core : la mutualisation n'est pas, à elle seule, un critère suffisant.

## Indépendance vis-à-vis des domaines

Le Core est indépendant des domaines métier, quel que soit leur répertoire. Il ne connaît ni leurs modèles, ni leurs services, ni leurs tables, ni leurs conventions internes.

La dépendance est strictement orientée dans un seul sens :

```text
Domaines métier  ──dépendent de──>  Core
Core             ──ne dépend pas de──>  Domaines métier
```

Les domaines ne consomment que les composants publics du Core. Le Core ne doit jamais importer de classe issue d'un domaine métier, y compris via un alias, une configuration ou un conteneur de services.

## Règles de dépendance

1. Les domaines métier peuvent dépendre de composants publics du Core.
2. Le Core ne dépend d'aucun domaine métier.
3. Le Core ne connaît pas les modèles, services ou implémentations internes des domaines.
4. Les composants du Core doivent être génériques et indépendants du contexte métier.
5. Un composant ne doit pas être placé dans le Core uniquement parce qu'il est utilisé à plusieurs endroits.
6. Les dépendances vers des packages Laravel ou Composer sont autorisées lorsqu'elles sont justifiées techniquement.

Une dépendance du Core vers un domaine constitue une erreur d'architecture : le composant doit être déplacé dans le domaine propriétaire ou redéfini sous une forme réellement générique.

## Organisation actuelle

```text
app/
└── Core/
    └── README.md
```

Le mapping PSR-4 existant `App\` vers `app/` prend déjà en charge le namespace `App\Core\`. Aucune modification de `composer.json` n'est nécessaire pour ajouter des classes dans ce répertoire.

Les sous-répertoires suivants sont des possibilités futures, à créer uniquement lorsqu'un besoin concret apparaît :

- `Support/`
- `Exceptions/`
- `ValueObjects/`
- `Concerns/`

Aucun répertoire vide ni aucune classe sans usage réel ne doit être créé.

## Conventions de nommage et d'organisation

- Les fichiers respectent la norme PSR-4 et le mapping `App\Core\...`.
- Les noms de classes sont en `PascalCase`, explicites et orientés responsabilité technique.
- Éviter les noms vagues du type `Helper`, `Manager`, `Utils` ou `Service` sans signification précise.
- Une classe par fichier, avec un namespace correspondant exactement au chemin.
- Le style suit les conventions Laravel et Laravel Pint.
- Aucun code métier ne doit être masqué derrière une abstraction générique.
- Les helpers globaux sont à éviter ; préférer des classes identifiables et testables.

## Critères de promotion vers le Core

Un composant ne peut être placé dans le Core que si l'ensemble des conditions suivantes est réuni :

- son usage est réellement transversal à plusieurs domaines indépendants ;
- sa responsabilité est technique et non métier ;
- il ne dépend d'aucun domaine particulier ;
- son API est suffisamment stable et générique ;
- son placement dans le Core apporte un bénéfice architectural démontrable.

En cas de doute, le composant reste dans son domaine propriétaire. La promotion doit être justifiée dans la Pull Request concernée, avec les usages réels qui la motivent.

## Critères de sortie

Un composant du Core doit être retiré lorsqu'il devient spécifique à un domaine, lorsque son API se révèle instable ou lorsque son usage transverse disparaît. Le retrait suit les mêmes règles de revue qu'une promotion.

## Références

- [`AGENTS.md`](../../AGENTS.md) — règles générales du dépôt.
- [Architecture cible](../../README.md#architecture-cible) — Modular Monolith.
- [`docs/development/git-workflow.md`](../../docs/development/git-workflow.md) — workflow Git et Pull Requests.
