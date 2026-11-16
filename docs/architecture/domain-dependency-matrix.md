# Matrice technique des dépendances inter-domaines

- Ticket : CHAN-29 — Documenter les frontières et dépendances autorisées.
- Lot : Lot 2 — Matrice technique des dépendances.
- Référence : Lot 1 — Inventaire et cartographie des responsabilités métier.
- Statut : **document de travail — matrice à qualifier et à valider**.
- Portée : dépendances entre les 18 domaines, sens des échanges, règles d'accès et classification autorisée / conditionnelle / interdite.
- Hors portée : implémentation de contrats ou événements (CHAN-28), conventions internes (CHAN-27), tests automatisés d'architecture (CHAN-31), modification du code métier.

> **Précaution de lecture.** Les relations recensées dans ce document sont des candidates issues des consommateurs indiqués au Lot 1. Elles ne constituent pas, à elles seules, une autorisation technique. Une relation ne sera déclarée autorisée qu'après qualification de son besoin, de son sens, de son propriétaire et de son mécanisme d'échange.

## 1. Synthèse du Lot 1 — base métier du Lot 2

Le Lot 1 a été livré et fusionné dans `develop` par la PR [#19](https://github.com/C2ME-ORGA/chantier/pull/19), commit de fusion `e69e26f88bb7e06e402bad5f5ebeb01112e2f68a`.

Il a produit six fichiers documentaires :

| Livrable | Résultat | Utilisation dans le Lot 2 |
| --- | --- | --- |
| `domain-responsibilities.md` | Catalogue des 18 domaines, missions, périmètres, objets et consommateurs | Référence de propriété métier et première base de dépendances candidates |
| `business-processes.md` | Cartographie de 12 processus métier | Vérifier le contexte opérationnel et le sens réel des échanges |
| `business-objects.md` | Catalogue de 132 objets métier | Identifier le propriétaire de chaque donnée et les références consommées |
| `domain-interactions-register.md` | Registre de 125 interactions métier | Qualifier les besoins réels ; ne pas assimiler une interaction à un contrat |
| `domain-boundary-decisions.md` | 21 chevauchements, 20 propositions initiales et 53 questions ; arbitrages documentés | Appliquer les décisions validées et préserver les sujets encore ouverts |
| `README.md` | Index et ordre de lecture | Point d'entrée documentaire |

**Résultat du Lot 1 :** les responsabilités métier et les besoins d'échange sont cartographiés. Le Lot 1 est une cible métier, pas une description de code existant. À sa livraison, `app/Domains/` ne contenait que les répertoires et fichiers `.gitkeep`.

### 1.1 Décisions de frontière désormais validées

Les 14 questions bloquantes du Lot 1 ont été arbitrées le 16/11/2026 et intégrées dans `domain-boundary-decisions.md` (V-15 à V-28) :

| Référence | Décision à appliquer dans la matrice |
| --- | --- |
| Q-01 / V-17 | Une affaire peut regrouper plusieurs chantiers ; chaque chantier appartient à une seule affaire |
| Q-02 / V-18 | Un tiers peut cumuler plusieurs rôles dans une affaire ; les rôles sont explicitement distingués |
| Q-05 / V-15 | Clients possède le référentiel maître des tiers ; Procurement possède la relation d'achat et les données fournisseur propres aux achats |
| Q-09 / V-19 | L'engagement financier est reconnu à l'approbation de la commande fournisseur |
| Q-10 / V-20 | Costing possède l'EAC, calculé à partir des faits opérationnels et des engagements |
| Q-12 / V-21 | TimeTracking constate les événements et durées d'absence ; Workforce qualifie le motif RH |
| Q-17 / V-22 | Inventory possède le référentiel maître des articles ; Procurement possède les références d'achat fournisseur |
| Q-19 / V-23 | Le stock de chantier est un emplacement temporaire du stock central Inventory |
| Q-23 / V-24 | Workshop porte l'acceptation technique d'une fabrication externe ; Quality statue sur la conformité ; Procurement clôt l'aspect commercial |
| Q-27 / V-25 | Projects porte l'avancement contractuel ; Planning l'avancement des activités ; TimeTracking les temps réalisés |
| Q-30 / V-26 | Une réserve documentaire peut être clôturée sans NCR ; une réserve technique exige le traitement de la NCR correspondante |
| Q-36 / V-16 | Les références publiques inter-domaines sont des UUID stables ; la version de génération reste à préciser lors de l'implémentation |
| Q-41 / V-27 | La sous-traitance confiée par C2ME relève de Procurement ; la sous-traitance reçue suit le parcours Projects/Clients |
| Q-53 / V-28 | La clôture d'affaire intervient après réception, levée des réserves, DOE, clôture des coûts et clôture du budget |

Ces arbitrages ne valident pas automatiquement une dépendance technique ni un contrat.

## 2. Référentiel d'architecture applicable

Le Lot 2 doit respecter les décisions suivantes, déjà actées dans CHAN-29 et CHAN-28 :

1. Les 18 domaines sont figés ; aucun domaine n'est créé, fusionné, scindé ou supprimé.
2. Le domaine propriétaire conserve la maîtrise de ses données, invariants, états, transitions et décisions.
3. Les échanges inter-domaines passent exclusivement par un contrat public ou un événement explicite.
4. Un domaine ne consulte ni ne modifie directement les Models, Actions, Services, DTO internes, Policies ou tables d'un autre domaine.
5. Un contrat public n'existe que pour un consommateur réel ; aucun contrat anticipé.
6. Les signatures publiques ne transportent pas de Model Eloquent, Builder, Collection Eloquent, Request, vue ou objet Livewire/Filament.
7. Aucune transaction partagée implicite entre domaines.
8. Les références publiques inter-domaines utilisent des UUID stables.
9. Le contrat appartient par défaut au domaine fournisseur de la donnée, de l'invariant ou de la capacité.
10. Les règles de choix synchrone/événement, d'erreur, de reprise, d'idempotence et d'évolution restent celles de `domain-communication.md` (CHAN-28).

**Règle de séparation :** CHAN-29 décide quels domaines peuvent dépendre de quels autres et sous quelles conditions. CHAN-28 décide comment matérialiser un échange déjà justifié. CHAN-29 ne redéfinit donc ni les formats de contrats, ni les politiques de transport, ni les mécanismes de fiabilité de CHAN-28.

## 3. Légende de qualification

| Classe | Signification | Condition minimale |
| --- | --- | --- |
| **Autorisée** | Dépendance métier stable, justifiée et explicitement orientée vers un fournisseur | Consommateur réel identifié, propriétaire confirmé, données/capacité minimales, contrat ou événement conforme à CHAN-28 |
| **Conditionnelle** | Dépendance permise uniquement pour un cas d'usage borné | Condition, déclencheur, données et limites explicités ; pas d'accès général au domaine |
| **Interdite** | Dépendance qui viole la propriété métier, crée un couplage interne ou contourne une frontière | Aucun accès direct aux composants internes, aucune écriture dans les données d'un autre domaine |
| **À qualifier** | Relation candidate issue du Lot 1, pas encore classée | Analyse du processus et de l'interaction avant décision |

Une dépendance est orientée : si A consomme une capacité possédée par B, la dépendance est **A → B**. Le fait que B soit cité comme consommateur d'un autre domaine dans le Lot 1 ne renverse pas cette orientation.

## 4. Première cartographie des dépendances candidates

Le tableau ci-dessous reprend les principaux consommateurs indiqués dans la vue d'ensemble des 18 domaines du Lot 1. Il s'agit d'un inventaire de départ, et non de la matrice finale autorisée.

| Fournisseur pressenti (Lot 1) | Consommateurs cités au Lot 1 | Qualification Lot 2 |
| --- | --- | --- |
| Identity | Tous les domaines | À qualifier : distinguer authentification/autorisation technique et données métier ; éviter une dépendance métier généralisée |
| Clients | Projects, Handover, Reporting | À qualifier selon le besoin ; identité du tiers et rôles exposés par Clients |
| Projects | Planning, Budgets, Costing, Workshop, Procurement, Inventory, Quality, Safety, Handover | À qualifier par processus et capacité ; Projects reste propriétaire de l'affaire et du chantier |
| Planning | Projects, Workforce, Equipment, Logistics | À qualifier ; Planning possède activités, plan de charge et affectations |
| Budgets | Projects, Costing, Procurement | À qualifier ; Budgets possède enveloppes, versions et révisions |
| Costing | Projects, Budgets, Reporting | À qualifier ; Costing possède coûts, engagements, marge et EAC |
| Workforce | Planning, TimeTracking, Costing | À qualifier ; Workforce possède collaborateurs, contrats et qualifications |
| TimeTracking | Workforce, Costing, Planning | À qualifier ; TimeTracking possède pointages, temps et événements d'absence |
| Workshop | Projects, Inventory, Logistics, Quality | À qualifier ; Workshop possède ordres de fabrication et opérations |
| Procurement | Inventory, Costing, Planning | À qualifier ; Procurement possède commandes d'achat et relation d'achat |
| Inventory | Workshop, Projects, Costing | À qualifier ; Inventory possède articles, réceptions et mouvements |
| Equipment | Planning, Logistics, Safety | À qualifier ; Equipment possède parc, maintenance et inspections |
| Logistics | Inventory, Projects, Costing | À qualifier ; Logistics possède transports, livraisons et retours |
| Quality | Projects, Workshop, Handover | À qualifier ; Quality possède contrôles et non-conformités |
| Safety | Projects, Workshop, Workforce | À qualifier ; Safety possède prévention, incidents et habilitations opérationnelles |
| Documents | Tous les domaines | À qualifier : distinguer service documentaire transverse et dépendance métier ; définir les métadonnées minimales |
| Handover | Projects, Clients, Quality | À qualifier ; Handover possède réception contractuelle, réserves, DOE et garanties |
| Reporting | Direction et tous les domaines | À qualifier : privilégier des données de lecture/projections et éviter que les domaines dépendent de Reporting pour leurs décisions métier |

### 4.1 Points d'attention révélés par cette première cartographie

- Les mentions « tous les domaines » pour Identity, Documents et Reporting ne doivent pas devenir des dépendances métier obligatoires et universelles.
- Les relations réciproques apparentes (par exemple Projects/Costing, Projects/Planning, Workforce/TimeTracking) doivent être décomposées par cas d'usage. Elles ne justifient pas un cycle de dépendances.
- Les processus de sous-traitance donnée et reçue sont distincts (V-27).
- Le référentiel maître des tiers reste Clients ; les données d'achat propres aux fournisseurs restent Procurement (V-15).
- Le référentiel maître des articles reste Inventory ; les références fournisseur propres aux achats restent Procurement (V-22).
- Les responsabilités distinctes de l'avancement, des absences et de la fabrication externe doivent être conservées (V-21, V-24, V-25).
- Reporting ne devient pas une autorité métier ; il consomme et consolide.

## 4.1 Contraintes métier supplémentaires issues du questionnaire

Les décisions V-29 à V-59 de `domain-boundary-decisions.md` s'imposent à la qualification de la matrice :

- Clients est propriétaire du devis complet ; Projects ne possède plus le devis dans la cible métier, mais possède l'affaire et le contrat après signature.
- L'ouverture d'une affaire depuis un devis accepté nécessite une validation explicite.
- La création du chantier principal et du planning initial est déclenchée à la création de l'affaire ; les dépendances correspondantes restent à qualifier.
- Workforce décide des affectations à partir des besoins de Planning.
- Le responsable atelier valide techniquement les fabrications ; Quality conserve la qualification et la validation des non-conformités.
- Reporting ne peut accéder directement aux bases/tables des domaines : publications et contrats publics uniquement.
- La validation documentaire est répartie entre domaine propriétaire du contenu et responsable d'affaire pour l'approbation finale.
- La clôture administrative appartient au service administratif après confirmations métier ; Projects conserve la responsabilité du cycle de vie de l'affaire.

Ces décisions ne changent pas le statut des lignes de la matrice. Aucune interaction n'est « autorisée » du seul fait qu'un processus métier a été validé.

## 5. Travail de qualification à mener

Pour chaque interaction retenue dans `domain-interactions-register.md`, documenter :

1. identifiant de l'interaction métier (`INT-xxx`) et processus (`Pxx`) ;
2. domaine consommateur et domaine fournisseur ;
3. donnée, fait ou capacité réellement nécessaire ;
4. propriétaire de la donnée, de l'invariant et de la décision ;
5. sens de dépendance (consommateur → fournisseur) ;
6. classe proposée : autorisée, conditionnelle ou interdite ;
7. déclencheur et fréquence ;
8. mode attendu : contrat synchrone ou événement, selon CHAN-28 ;
9. référence publique minimale (UUID stable lorsque l'objet est référencé) ;
10. justification, restrictions, et conséquence en cas d'indisponibilité ;
11. risque de cycle ou de transaction inter-domaines ;
12. statut de validation.

**Important :** les 125 interactions du Lot 1 ne doivent pas devenir mécaniquement 125 contrats ou événements. Plusieurs interactions peuvent partager une même capacité ; d'autres peuvent rester des besoins de processus sans dépendance technique directe.

## 6. Matrice détaillée — structure cible

La matrice détaillée sera complétée par domaine fournisseur et consommateur, avec une ligne par relation technique justifiée :

| Consommateur | Fournisseur | INT / processus | Capacité ou donnée consommée | Propriétaire | Classe | Mode CHAN-28 | Référence publique | Conditions / restrictions | Statut |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| À renseigner | À renseigner | À renseigner | À renseigner | À confirmer | À qualifier | À qualifier | UUID si référence d'objet | À renseigner | Proposition |

Aucune relation du tableau de la section 4 ne doit être copiée ici comme « autorisée » sans cette qualification.

## 7. Règles d'interdiction explicites

Sont interdites, quel que soit le domaine :

- importer ou appeler un Model, Action, Service, DTO interne ou Policy d'un autre domaine ;
- lire ou écrire directement dans les tables d'un autre domaine ;
- modifier directement un objet métier dont un autre domaine est propriétaire ;
- contourner le contrat du fournisseur pour appliquer ses règles métier depuis le consommateur ;
- transporter un Model Eloquent ou un objet de présentation à travers une frontière ;
- créer une dépendance circulaire ou une transaction partagée implicite ;
- créer un contrat ou événement sans consommateur réel ;
- utiliser Reporting comme source d'autorité pour une décision métier ;
- dupliquer les référentiels maîtres Clients ou Inventory dans un autre domaine.

Toute exception éventuelle doit faire l'objet d'une décision d'architecture explicite ; elle ne peut pas être introduite par simple commodité d'implémentation.

## 8. Livrables attendus du Lot 2

- La présente matrice, complétée et qualifiée pour les 18 domaines.
- Une matrice synthétique orientée (consommateur → fournisseur) avec les statuts autorisé, conditionnel et interdit.
- Un registre détaillé reliant les dépendances retenues aux interactions INT et processus P du Lot 1 (`domain-dependency-register.md`, inventaire initial des 125 INT).
- Les règles de propriété des contrats et des références publiques.
- Des schémas de dépendances sans cycle, accompagnés des exceptions conditionnelles.
- Des exemples représentatifs couvrant au minimum : affaire/chantier, achats et engagement, stock/article, fabrication externe, temps/absences, avancement, qualité/réserves, sous-traitance dans les deux sens et clôture d'affaire.
- Une checklist de conformité documentaire par domaine.

## 9. Hors périmètre et garde-fous

Le Lot 2 reste documentaire. Il ne doit pas :

- créer de contrat PHP, DTO, événement, listener, job, provider ou service ;
- modifier les migrations, tables, modèles ou données ;
- implémenter les tests d'architecture (CHAN-31) ;
- modifier les conventions internes CHAN-27 ou réécrire CHAN-28 ;
- transformer les interactions métier en interfaces techniques sans qualification ;
- valider les propositions ou questions ouvertes du Lot 1 autres que les décisions déjà marquées V-01 à V-28.

## 10. Références

- [Lot 1 — Responsabilités des domaines](domain-responsibilities.md)
- [Lot 1 — Processus métier](business-processes.md)
- [Lot 1 — Objets métier](business-objects.md)
- [Lot 1 — Registre des interactions](domain-interactions-register.md)
- [Lot 1 — Arbitrages de frontières](domain-boundary-decisions.md)
- [CHAN-28 — Communication inter-domaines](domain-communication.md)
- [CHAN-27 — Conventions internes des domaines](domain-conventions.md)
- CHAN-31 — Tests d'architecture (ticket Jira)
- [AGENTS.md](../../AGENTS.md)
- [Organisation des domaines](../../app/Domains/README.md)
