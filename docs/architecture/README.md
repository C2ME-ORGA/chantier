# Documentation d'architecture

Ce répertoire regroupe les documents d'architecture de **C2ME Chantier**.

## Documents disponibles

| Document | Ticket | Objet |
| --- | --- | --- |
| [`domain-conventions.md`](domain-conventions.md) | CHAN-27 | Conventions internes d'un domaine : Models, Actions, Services, DTO, Events, Policies, validation, orchestration et nommage. |
| [`domain-communication.md`](domain-communication.md) | CHAN-28 | Communication inter-domaines consolidée : contrats synchrones, événements, fiabilité, synchronisme, erreurs, reprise, idempotence, traçabilité, évolution, critères d'Outbox/transport et synthèse finale. |
| [`domain-responsibilities.md`](domain-responsibilities.md) | CHAN-29 Lot 1 | Catalogue des 18 domaines : responsabilités, périmètres, objets, acteurs, règles, états, entrées et sorties. |
| [`business-processes.md`](business-processes.md) | CHAN-29 Lot 1 | Cartographie des 12 processus métier : déclencheurs, acteurs, étapes, résultats, exceptions et interactions. |
| [`business-objects.md`](business-objects.md) | CHAN-29 Lot 1 | Catalogue des objets métier, de leur propriétaire pressenti et de leurs consommateurs. |
| [`domain-interactions-register.md`](domain-interactions-register.md) | CHAN-29 Lot 1 | Registre des interactions métier entre domaines : source, destinataire, motif, informations et moment. |
| [`domain-boundary-decisions.md`](domain-boundary-decisions.md) | CHAN-29 Lot 1 | Chevauchements, arbitrages proposés, décisions validées et questions ouvertes. |
| [`domain-dependency-matrix.md`](domain-dependency-matrix.md) | CHAN-29 Lot 2 | Matrice technique des dépendances inter-domaines — document de travail à qualifier et valider. |

## Ordre de lecture recommandé

Pour comprendre les frontières métier :

1. [`domain-responsibilities.md`](domain-responsibilities.md) — ce que chaque domaine possède et ne possède pas.
2. [`business-processes.md`](business-processes.md) — comment les domaines coopèrent dans les processus.
3. [`business-objects.md`](business-objects.md) — quels objets sont propriétaires et quels domaines les consomment.
4. [`domain-interactions-register.md`](domain-interactions-register.md) — quels échanges sont nécessaires et à quel moment.
5. [`domain-boundary-decisions.md`](domain-boundary-decisions.md) — quelles ambiguïtés restent à trancher.

Pour les règles de code et de contrat, consulter d'abord [`domain-conventions.md`](domain-conventions.md) et [`domain-communication.md`](domain-communication.md).

Les contrats synchrones sont traités dans les sections 1 à 14 de `domain-communication.md` ; les événements inter-domaines dans les sections 15 à 22 ; la fiabilité, le synchronisme et l'évolution dans les sections 23 à 32 ; la synthèse finale et la checklist d'un nouvel échange dans la section 33. Les Lots 1 à 5 de CHAN-28 sont documentaires : aucun contrat, événement, listener, job, worker ou Outbox n'est implémenté à ce stade.

## Statut des documents CHAN-29

Les cinq documents CHAN-29 du **Lot 1** décrivent l'inventaire et la cartographie des responsabilités métier. Le document `domain-dependency-matrix.md` ouvre le **Lot 2** : matrice technique des dépendances, à qualifier à partir des livrables du Lot 1.

> **Lot 1 — documentaire.** Il ne définit pas la matrice technique des dépendances autorisées et interdites.
>
> **Lot 2 — documentaire.** La matrice candidate référence le Lot 1 et distingue les dépendances à qualifier des règles déjà validées. Elle ne crée aucune classe, aucun contrat, aucun événement, aucune migration et aucun test d'architecture. Les relations issues des consommateurs du Lot 1 ne valent pas autorisation technique.

Le dépôt ne contient pas encore de code métier dans `app/Domains/` : les domaines sont matérialisés par des répertoires et des fichiers `.gitkeep`.

## Conventions de lecture

| Élément | Signification |
| --- | --- |
| `D01` à `D18` | Domaines métier. |
| `P01` à `P12` | Processus métier. |
| `BD-xx` | Chevauchement analysé. |
| `PD-xx` | Décision proposée. |
| `V-xx` | Décision validée de frontière. |
| `Q-xx` | Question ouverte. |
| `INT-xxx` | Interaction métier. |
| Préfixe d'objet | Objet métier, par exemple `PRJ-01` Affaire ou `INV-05` MouvementDeStock. |

Les documents distinguent explicitement :

- les **décisions validées** ;
- les **constats** vérifiables dans le dépôt ;
- les **propositions** de cadrage ;
- les **questions ouvertes** qui restent à arbitrer.

## Documents liés

- [`AGENTS.md`](../../AGENTS.md) — règles générales du dépôt.
- [`app/Core/README.md`](../../app/Core/README.md) — périmètre du noyau technique.
- [`app/Domains/README.md`](../../app/Domains/README.md) — organisation des domaines.
- [`docs/development/git-workflow.md`](../development/git-workflow.md) — branches, commits et Pull Requests.
