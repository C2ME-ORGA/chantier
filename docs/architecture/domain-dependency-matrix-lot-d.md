# Lot D — Matrice consolidée et analyse des cycles

## 1. Objet et statut

Ce document constitue le livrable d'analyse du Lot D de CHAN-29. Il consolide la lecture du graphe des dépendances candidates à partir des 130 identifiants du Lot C et identifie les cycles apparents à instruire.

**Ce document ne transforme pas les relations candidates en dépendances techniques autorisées.** À la date de l'analyse, les 130 interactions restent classées « À qualifier » dans `domain-dependency-matrix-lot-c.md`. Les 18 répertoires de `app/Domains/` ne contiennent que des fichiers `.gitkeep` : aucun contrat, événement ou import inter-domaines concret n'est disponible pour prouver une dépendance technique implémentée.

La matrice ci-dessous est donc une matrice de traçabilité des relations candidates, pas une liste d'autorisations techniques.

## 2. Sources et méthode

Sources de référence sur `develop`, commit `62b42056cc8400dec8c5506c5699b48091992128` :

- `docs/architecture/domain-dependency-matrix-lot-c.md` — 130 interactions et leur classe technique ;
- `docs/architecture/domain-dependency-register.md` — orientation consommateur → fournisseur et propriétaire ;
- `docs/architecture/domain-responsibilities.md` — périmètre des 18 domaines ;
- `docs/architecture/domain-communication.md` — règles de frontière CHAN-28 ;
- arborescence Git de `app/Domains/` — contrôle de présence des implémentations.

Méthode :
1. Une arête est extraite uniquement lorsqu'une ligne INT désigne explicitement un domaine consommateur et un domaine fournisseur.
2. L'orientation est conservée selon la capacité consommée et son propriétaire, pas selon le seul flux matériel de données.
3. Les lignes transverses, génériques ou externes sans paire de domaines déterminée ne sont pas converties en arêtes arbitraires.
4. Les cycles sont calculés sur ce graphe documentaire. Ils signalent des relations à examiner, et non des cycles d'appels ou de dépendances PHP démontrés.
5. Une dépendance technique ne peut être classée qu'après preuve d'un consommateur réel, d'un contrat public ou événement conforme à CHAN-28, et de son usage effectif.

## 3. Synthèse du graphe documentaire

| Indicateur | Résultat |
| --- | ---: |
| Domaines du périmètre | 18 |
| Interactions INT dans le Lot C | 130 |
| Identifiants uniques | 130 |
| Interactions avec une paire de domaines explicitement déterminée | 124 |
| Paires consommateur → fournisseur distinctes | 95 |
| Paires réciproques candidates | 17 |
| Interactions sans paire de domaines déterminée | 6 |
| Interactions techniquement « À qualifier » | 130 |

Les six lignes non transformées en arêtes sont :

| INT | Motif | Traitement |
| --- | --- | --- |
| INT-001 | Points d'entrée concernés → Identity transverse | Ne pas créer de dépendance métier universelle ; qualifier les points d'entrée concernés |
| INT-075 | Workforce → prestataire de paie externe | Dépendance externe, hors graphe des 18 domaines |
| INT-114 | Domaines déposants → Documents | Décomposer par domaine déposant réel |
| INT-115 | Tous les domaines → Documents | Décomposer par consommateur réel et besoin documentaire |
| INT-123 | Reporting → domaines sources | Décomposer par domaine source et données publiées |
| INT-124 | Consommateurs à identifier → Reporting | Décomposer par consommateur, rapport et usage réel |

## 4. Matrice synthétique des relations candidates

La liste ci-dessous regroupe les 95 paires distinctes extraites des interactions explicites. Les références INT restent la traçabilité détaillée vers les capacités décrites dans le Lot C. Chaque paire reste **À qualifier** techniquement.

| Consommateur | Fournisseur candidat | Références INT |
| --- | --- | --- |
| Budgets | Costing | INT-054 |
| Budgets | Procurement | INT-056 |
| Budgets | Projects | INT-014 |
| Budgets | Workforce | INT-070 |
| Clients | Handover | INT-010a |
| Clients | Identity | INT-004 |
| Clients | Projects | INT-007, INT-008, INT-010 |
| Costing | Budgets | INT-053 |
| Costing | Equipment | INT-062 |
| Costing | Inventory | INT-059 |
| Costing | Logistics | INT-063 |
| Costing | Procurement | INT-060 |
| Costing | Projects | INT-016a, INT-120 |
| Costing | Quality | INT-064 |
| Costing | Safety | INT-065 |
| Costing | TimeTracking | INT-058 |
| Costing | Workshop | INT-061 |
| Costing | Workforce | INT-066 |
| Costing | Handover | INT-120a |
| Documents | Reporting | INT-125 |
| Equipment | Logistics | INT-102 |
| Equipment | Procurement | INT-104, INT-105 |
| Handover | Clients | INT-009 |
| Handover | Documents | INT-116, INT-119 |
| Handover | Procurement | INT-122 |
| Handover | Quality | INT-109, INT-118 |
| Identity | Workforce | INT-003 |
| Inventory | Logistics | INT-096, INT-097 |
| Inventory | Procurement | INT-088 |
| Inventory | Quality | INT-098, INT-099 |
| Logistics | Equipment | INT-101 |
| Logistics | Projects | INT-030 |
| Planning | Equipment | INT-039, INT-040 |
| Planning | Inventory | INT-045, INT-046 |
| Planning | Logistics | INT-047, INT-048 |
| Planning | Procurement | INT-043, INT-044 |
| Planning | Projects | INT-012 |
| Planning | Safety | INT-051 |
| Planning | TimeTracking | INT-050 |
| Planning | Workshop | INT-041, INT-042 |
| Planning | Workforce | INT-037, INT-038 |
| Procurement | Budgets | INT-055 |
| Procurement | Identity | INT-005 |
| Procurement | Inventory | INT-089 |
| Procurement | Logistics | INT-093, INT-094 |
| Procurement | Quality | INT-090, INT-091 |
| Procurement | Safety | INT-092 |
| Projects | Budgets | INT-015 |
| Projects | Clients | INT-006 |
| Projects | Costing | INT-016, INT-017 |
| Projects | Documents | INT-026, INT-027 |
| Projects | Handover | INT-028, INT-029 |
| Projects | Inventory | INT-034, INT-035 |
| Projects | Logistics | INT-031 |
| Projects | Planning | INT-013 |
| Projects | Procurement | INT-020, INT-021 |
| Projects | Quality | INT-022, INT-023a |
| Projects | Safety | INT-025 |
| Projects | TimeTracking | INT-033 |
| Projects | Workshop | INT-018, INT-019 |
| Quality | Documents | INT-108 |
| Quality | Projects | INT-023 |
| Quality | Workforce | INT-073 |
| Reporting | Budgets | INT-057 |
| Reporting | Clients | INT-011 |
| Reporting | Costing | INT-067 |
| Reporting | Documents | INT-117 |
| Reporting | Equipment | INT-106 |
| Reporting | Identity | INT-002 |
| Reporting | Inventory | INT-100 |
| Reporting | Logistics | INT-107 |
| Reporting | Planning | INT-052 |
| Reporting | Projects | INT-036, INT-121 |
| Reporting | Handover | INT-121a |
| Reporting | Procurement | INT-095 |
| Reporting | Quality | INT-110 |
| Reporting | Safety | INT-113 |
| Reporting | TimeTracking | INT-076 |
| Reporting | Workforce | INT-074 |
| Reporting | Workshop | INT-087 |
| Safety | Documents | INT-112 |
| Safety | Equipment | INT-103 |
| Safety | Projects | INT-024 |
| Safety | Workforce | INT-071 |
| TimeTracking | Planning | INT-049 |
| TimeTracking | Projects | INT-032 |
| TimeTracking | Workforce | INT-068 |
| Workforce | Safety | INT-072a |
| Workforce | TimeTracking | INT-069 |
| Workshop | Documents | INT-085, INT-086 |
| Workshop | Inventory | INT-077, INT-078 |
| Workshop | Logistics | INT-083, INT-084 |
| Workshop | Procurement | INT-079, INT-080 |
| Workshop | Quality | INT-081, INT-082 |
| Workshop | Safety | INT-111 |

**Attention :** cette matrice est une synthèse de relations candidates. Elle ne remplace pas les lignes INT, leurs descriptions, les propriétaires ni les questions ouvertes du Lot C. La présence d'une paire dans ce tableau n'est pas une autorisation d'import ou d'appel.

## 5. Paires réciproques à examiner

Dix-sept paires présentent des interactions dans les deux sens dans le graphe documentaire :

| Paire | Références indicatives | Vigilance |
| --- | --- | --- |
| Budgets ↔ Costing | INT-053 / INT-054 | Distinguer enveloppe budgétaire et valorisation des coûts |
| Budgets ↔ Procurement | INT-055 / INT-056 | Distinguer disponibilité budgétaire et engagement/commande |
| Budgets ↔ Projects | INT-014 / INT-015 | Distinguer demande d'enveloppe et suivi de l'enveloppe |
| Clients ↔ Handover | INT-009 / INT-010a | Distinguer référentiel/contact client et suivi documentaire de réception/garanties |
| Clients ↔ Projects | INT-006 / INT-007, INT-008, INT-010 | Distinguer données du tiers, demande d'étude et faits du cycle de vie |
| Costing ↔ Projects | INT-016, INT-017 / INT-016a, INT-120 | Distinguer coûts/EAC et références contractuelles/réception |
| Documents ↔ Reporting | INT-125 / INT-117 | Distinguer publication d'un rapport et pilotage documentaire |
| Equipment ↔ Logistics | INT-101 / INT-102 | Distinguer disponibilité du parc et faits d'utilisation/retour/panne |
| Inventory ↔ Procurement | INT-088 / INT-089 | Distinguer référentiel article/stock et relation d'achat fournisseur |
| Logistics ↔ Projects | INT-030 / INT-031 | Distinguer faits logistiques et besoin de chantier |
| Planning ↔ Projects | INT-012 / INT-013 | Distinguer jalons contractuels et planification des activités |
| Planning ↔ TimeTracking | INT-049 / INT-050 | Distinguer temps constatés et besoins/affectations planifiés |
| Projects ↔ Quality | INT-022, INT-023a / INT-023 | Distinguer exigences contractuelles, exigences qualité et plan de contrôle |
| Projects ↔ Safety | INT-024 / INT-025 | Distinguer contraintes de prévention et contexte chantier |
| Projects ↔ TimeTracking | INT-032 / INT-033 | Distinguer temps réalisés et besoin de suivi d'affaire |
| Safety ↔ Workforce | INT-071 / INT-072a | Distinguer statut d'habilitation opérationnelle et données RH du collaborateur |
| TimeTracking ↔ Workforce | INT-068 / INT-069 | Appliquer V-21 : TimeTracking constate les événements/durées ; Workforce qualifie le motif RH |

Une paire réciproque n'est pas nécessairement un cycle technique. Chaque direction doit correspondre à une capacité distincte, avec un propriétaire identifié. Les faits accomplis sont publiés par leur domaine propriétaire ; le consommateur ne doit pas provoquer une modification implicite en retour chez l'émetteur.

## 6. Analyse des composantes cycliques

L'analyse du graphe explicite fait apparaître une composante fortement connexe englobant les domaines reliés par les interactions candidates. Cette composante subsiste lorsque Reporting est retiré du graphe, et également lorsque les domaines transverses Reporting, Identity et Documents sont exclus.

**Interprétation :** le registre décrit de nombreux échanges opérationnels réciproques ou en chaîne entre domaines. Il ne permet pas de conclure à un cycle d'appels techniques, à une dépendance de compilation circulaire ou à une transaction distribuée. Ces conclusions nécessiteraient des contrats, événements, appels et imports effectivement implémentés, absents de l'arborescence actuelle.

Le résultat doit donc être traité comme un signal de conception : décomposer chaque paire en capacités distinctes, attribuer chaque capacité à un fournisseur et éviter les retours synchrones automatiques.

## 7. Domaines transverses

### Identity

- Ne pas créer une dépendance métier universelle.
- INT-001 reste transverse et hors matrice métier uniforme.
- Seuls les points d'entrée qui ont réellement besoin d'authentification ou d'autorisation doivent être identifiés.
- Les données RH de Workforce ne sont pas remplacées par le service Identity.

### Documents

- Documents possède le contenant, les versions, les métadonnées et la diffusion.
- Le domaine métier propriétaire conserve la validité et les décisions sur le contenu.
- INT-114 et INT-115 doivent être décomposées par déposant et consommateur réels.
- Le dépôt d'une pièce ne transfère pas à Documents la propriété de la donnée métier.

### Reporting

- Reporting consomme les faits et indicateurs publiés par les domaines sources.
- Il ne devient pas propriétaire des données sources ni autorité de décision métier.
- INT-123 et INT-124 doivent être décomposées par source, consommateur, rapport et usage.
- Aucune lecture directe des tables des domaines sources n'est admise.

## 8. Vérification des accès internes

Le contrôle de l'arborescence de `develop` au commit de référence confirme que chacun des 18 répertoires `app/Domains/{Domain}/` ne contient qu'un fichier `.gitkeep`.

| Contrôle | Résultat |
| --- | --- |
| Répertoires des 18 domaines présents | Oui |
| Contrats publics inter-domaines observables | Aucun |
| Événements d'intégration observables | Aucun |
| Models / Actions / Services / Policies de domaines observables | Aucun |
| Imports inter-domaines à auditer | Aucun fichier applicatif dans les domaines |
| Accès directs aux tables d'un autre domaine | Non démontrable à ce stade |

La conclusion correcte n'est pas « aucun accès interdit n'existe », mais **« aucun accès inter-domaines applicatif n'est actuellement observable dans les répertoires de domaines ; l'audit des accès directs ne pourra être réalisé qu'après l'apparition d'implémentations »**.

Les règles d'interdiction restent applicables dès la première implémentation :
- aucun import de Models, Actions, Services, DTO internes ou Policies d'un autre domaine ;
- aucune lecture/écriture directe des tables d'un autre domaine ;
- aucune modification d'un invariant ou état dont un autre domaine est propriétaire ;
- aucun cycle d'appels ou transaction partagée implicite.

## 9. Décisions et actions de sortie du Lot D

| Sujet | Conclusion Lot D | Suite |
| --- | --- | --- |
| Matrice des 18 domaines | Cartographie candidate consolidée | Conserver « À qualifier » tant que les preuves techniques manquent |
| Paires réciproques | 17 paires détectées | Vérifier la capacité distincte dans chaque sens |
| Cycles du graphe | Composante fortement connexe documentaire | Ne pas assimiler à un cycle technique ; instruire au niveau des contrats futurs |
| Identity | Transverse, non universel | Décomposer par point d'entrée |
| Documents | Service de contenant | Décomposer les déposants/consommateurs réels |
| Reporting | Consommateur/agrégateur | Décomposer les sources et usages |
| Accès internes | Aucun code de domaine disponible | Refaire l'audit après implémentation |
| Classes autorisée / conditionnelle / interdite | Aucune preuve suffisante pour reclasser les 130 interactions | Ne pas inventer de classes ni de dérogations |

### Critère de sortie

Le livrable fournit une matrice candidate traçable, identifie les relations réciproques et les cycles apparents, explicite les limites de preuve et vérifie l'état de l'arborescence des domaines. Il ne peut pas déclarer la matrice techniquement autorisée ou garantir l'absence d'accès internes tant que les domaines ne contiennent pas d'implémentations.

## 10. Références

- [Matrice technique Lot C](domain-dependency-matrix-lot-c.md)
- [Registre des dépendances](domain-dependency-register.md)
- [Responsabilités des domaines](domain-responsibilities.md)
- [Communication inter-domaines — CHAN-28](domain-communication.md)
- [Organisation des domaines](../../app/Domains/README.md)
- Jira : CHAN-29

## 11. Traçabilité

- Lot : D — matrice finale et analyse des cycles.
- Base : `develop`, commit `62b42056cc8400dec8c5506c5699b48091992128`.
- Branche : `docs/chan-29-lot-d-final-matrix-cycle-analysis`.
- Périmètre : documentation uniquement.
- Aucun code applicatif, contrat, DTO, événement, listener, job, provider, migration, test d'architecture ou changement Jira n'est inclus.
- Les classes techniques du Lot C ne sont pas modifiées.
