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
| [`domain-dependency-matrix.md`](domain-dependency-matrix.md) | CHAN-29 Lot 2 | Matrice technique de référence et liens vers les livrables de qualification. |
| [`domain-dependency-register.md`](domain-dependency-register.md) | CHAN-29 Lot 2 / Lot B | Registre de qualification métier des 125 interactions d'origine (130 lignes actives après cinq scissions réelles et correction de `INT-072`). |
| [`domain-dependency-matrix-lot-c.md`](domain-dependency-matrix-lot-c.md) | CHAN-29 Lot C | Qualification technique des 130 interactions ; les 130 classes restent « À qualifier » faute de preuve d'implémentation. |
| [`domain-dependency-matrix-lot-d.md`](domain-dependency-matrix-lot-d.md) | CHAN-29 Lot D | Matrice consolidée des relations candidates, analyse des 17 paires réciproques, cycles documentaires et limites de l'audit des accès internes. |
| [`domain-dependency-examples-lot-e.md`](domain-dependency-examples-lot-e.md) | CHAN-29 Lot E | Neuf scénarios métier illustrés par des schémas, règles de propriété et checklist documentaire par domaine et transversale. |
| [`domain-dependency-final-review-lot-f.md`](domain-dependency-final-review-lot-f.md) | CHAN-29 Lot F | Revue finale croisée, état des quatre critères d'acceptation, vérification des PR/CI et points restant à démontrer avant clôture. |
| [`domain-dependency-qualification-lot-g.md`](domain-dependency-qualification-lot-g.md) | CHAN-29 Lot G | Qualification technique cible des 130 interactions, conditions, périmètres hors matrice et limites de preuve d'implémentation. |
| [`domain-dependency-final-review-lot-h.md`](domain-dependency-final-review-lot-h.md) | CHAN-29 Lot H | Revue finale des quatre critères Jira après Lot G et décision de conception progressive ; validation documentaire de l'architecture cible, sans certification du code futur. |

## Ordre de lecture recommandé

Pour comprendre les frontières métier :

1. [`domain-responsibilities.md`](domain-responsibilities.md) — ce que chaque domaine possède et ne possède pas.
2. [`business-processes.md`](business-processes.md) — comment les domaines coopèrent dans les processus.
3. [`business-objects.md`](business-objects.md) — quels objets sont propriétaires et quels domaines les consomment.
4. [`domain-interactions-register.md`](domain-interactions-register.md) — quels échanges sont nécessaires et à quel moment.
5. [`domain-boundary-decisions.md`](domain-boundary-decisions.md) — quelles ambiguïtés restent à trancher.

Pour comprendre les relations candidates et leurs exemples :

1. [`domain-dependency-matrix-lot-c.md`](domain-dependency-matrix-lot-c.md) — qualification technique des interactions.
2. [`domain-dependency-matrix-lot-d.md`](domain-dependency-matrix-lot-d.md) — matrice consolidée et analyse des cycles.
3. [`domain-dependency-examples-lot-e.md`](domain-dependency-examples-lot-e.md) — scénarios, schémas et checklist.
4. [`domain-dependency-final-review-lot-f.md`](domain-dependency-final-review-lot-f.md) — revue finale et préparation de clôture.
5. [`domain-dependency-qualification-lot-g.md`](domain-dependency-qualification-lot-g.md) — qualification technique cible des 130 interactions.
6. [`domain-dependency-final-review-lot-h.md`](domain-dependency-final-review-lot-h.md) — revue finale des critères d'acceptation après le Lot G.

Pour les règles de code et de contrat, consulter d'abord [`domain-conventions.md`](domain-conventions.md) et [`domain-communication.md`](domain-communication.md).

Les contrats synchrones sont traités dans les sections 1 à 14 de `domain-communication.md` ; les événements inter-domaines dans les sections 15 à 22 ; la fiabilité, le synchronisme et l'évolution dans les sections 23 à 32 ; la synthèse finale et la checklist d'un nouvel échange dans la section 33. Les Lots 1 à 5 de CHAN-28 sont documentaires : aucun contrat, événement, listener, job, worker ou Outbox n'est implémenté à ce stade.

## Statut des documents CHAN-29

Le Lot 1 décrit l'inventaire et la cartographie des responsabilités métier. Le Lot B qualifie métier les interactions : 125 interactions d'origine, 130 lignes actives après cinq scissions réelles et correction de `INT-072`, dont 106 qualifiées, 11 à préciser, 4 à décomposer, 7 à arbitrer et 2 hors matrice inter-domaines.

Le Lot C sépare le statut métier de la classe technique et du mécanisme CHAN-28 pressenti. Les 130 interactions restent « À qualifier » techniquement, car les sources ne démontrent pas de contrats publics ou d'événements effectivement implémentés.

Le Lot D consolide les relations candidates et analyse les cycles du graphe documentaire. Les cycles apparents ne prouvent pas des cycles d'appels ou de dépendances PHP. Les 18 répertoires `app/Domains/` ne contenant encore que des fichiers `.gitkeep`, l'audit des imports et accès directs aux tables reste à refaire après implémentation.

Le Lot E illustre neuf parcours métier et les frontières de propriété associées. Ses schémas représentent des flux conceptuels et non des appels techniques implémentés. Sa checklist aide à relire la documentation ; elle ne remplace pas les tests d'architecture CHAN-31.

Le Lot F présente la revue finale des documents, des références CHAN-27/28/31, de l'organisation Core/Domains, des critères Jira et des PR/CI. Il conclut que le critère relatif à la classification des dépendances reste partiellement démontré faute de preuve d'implémentations techniques.

Le Lot G qualifie les 130 interactions pour l'architecture cible : 105 admissibles sous contrat public, 19 conditionnelles, 4 à décomposer et 2 hors périmètre inter-domaines. Une admissibilité cible exige une interaction qualifiée au Lot B ainsi qu'un consommateur, un propriétaire et une capacité explicitement identifiés. Cette qualification ne certifie pas le code existant ; les dépendances implémentées restent à vérifier lorsque les domaines seront développés.

Le Lot H reprend les quatre critères d'acceptation Jira après intégration du principe de conception progressive. Il conclut que les critères sont démontrés au niveau documentaire de l'architecture cible : la qualification des relations et les interdictions générales répondent au critère sur les dépendances, sans prétendre certifier les dépendances PHP futures. Il propose la présentation de CHAN-29 pour validation de clôture ; aucun statut Jira n'est modifié par le livrable.

**Principe de conception progressive :** les 18 domaines et leurs responsabilités constituent un cadre initial. Leurs périmètres fonctionnels et techniques détaillés seront décidés et affinés au fur et à mesure de la programmation, sur la base des besoins réellement implémentés. Les qualifications du Lot G orientent la cible sans imposer de créer immédiatement chaque contrat ou composant. Les évolutions de périmètre restent soumises aux règles de propriété, d'isolation et de communication CHAN-27/28.

> **Garde-fou :** la qualification métier, la matrice candidate, l'analyse de graphe et les scénarios illustratifs ne valent pas preuve d'implémentation. Le Lot G qualifie la cible d'architecture sous contrats publics CHAN-28 ; les dépendances PHP réellement implémentées restent non vérifiables tant que les domaines ne contiennent pas de code.

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
