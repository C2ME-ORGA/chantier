# Responsabilités et frontières métier des 18 domaines

Ce document constitue le catalogue de référence des responsabilités métier des 18 domaines de **C2ME Chantier**.

- Ticket : CHAN-29 — Documenter les frontières et dépendances autorisées.
- Lot : Lot 1 — Inventaire et cartographie des responsabilités métier.
- Ticket parent : CHAN-10 — Mettre en place l'architecture Modular Monolith.
- Portée : responsabilités, périmètres, objets métier, acteurs, règles, états, entrées, sorties et limites de chaque domaine.
- Hors portée : matrice technique définitive des dépendances autorisées et interdites (Lot 2 de CHAN-29), contrats et événements inter-domaines (CHAN-28), conventions internes de code (CHAN-27), tests d'architecture (CHAN-31), harmonisation de `AGENTS.md` (CHAN-30).

> **Statut du document — Lot 1.**
> Ce document décrit les responsabilités **cibles** des domaines. Il ne décrit pas un existant applicatif : à la date de rédaction, `app/Domains/` ne contient que des répertoires et des fichiers `.gitkeep`, sans aucune classe métier. Les responsabilités, règles et états présentés ici sont des propositions de cadrage métier, sauf lorsqu'ils sont explicitement marqués comme validés.

## 1. Objet, périmètre et méthode

### 1.1 Objet

Le document répond aux questions suivantes, pour chacun des 18 domaines :

- quelle responsabilité métier principale porte le domaine ;
- quel périmètre fonctionnel il couvre et quel périmètre il ne couvre pas ;
- quels objets métier lui appartiennent ;
- quelles informations il gère et quelles règles il applique ;
- quels acteurs métier interviennent ;
- quels états et transitions il contrôle ;
- quelles informations il reçoit des autres domaines ;
- quelles informations il fournit aux autres domaines ;
- quelles limites et quels chevauchements doivent être arbitrés.

### 1.2 Ce que ce document n'est pas

- Ce n'est pas une matrice technique de dépendances : les échanges sont décrits en langage métier, sans décision sur la forme du contrat, le transport ou le mécanisme d'événement.
- Ce n'est pas une spécification d'implémentation : aucune classe, aucun modèle, aucune migration, aucun service n'est défini ici.
- Ce n'est pas un inventaire de l'existant : le dépôt ne contient pas encore de code métier.
- Ce n'est pas une décision unilatérale sur les points ouverts : les ambiguïtés sont documentées et renvoyées à validation.

### 1.3 Niveaux de statut

| Statut | Signification |
| --- | --- |
| **Validé** | Décision explicitement fournie par le responsable du projet ou déjà actée dans un document d'architecture du dépôt. |
| **Constat** | Fait vérifiable dans le dépôt ou dans la documentation existante. |
| **Proposition** | Arbitrage recommandé dans ce lot, cohérent avec les décisions validées, mais qui reste à valider par le responsable du projet. |
| **Question ouverte** | Point que les informations disponibles ne permettent pas de trancher ; il doit être arbitré avant de figer la matrice du Lot 2. |

Une proposition n'est jamais présentée comme une décision validée. Les identifiants `BD-xx` renvoient aux analyses de chevauchement de [`domain-boundary-decisions.md`](domain-boundary-decisions.md) et `Q-xx` aux questions ouvertes du même document.

### 1.4 Sources

- [`AGENTS.md`](../../AGENTS.md) — règles générales du dépôt.
- [`app/Core/README.md`](../../app/Core/README.md) — périmètre du noyau technique.
- [`app/Domains/README.md`](../../app/Domains/README.md) — organisation des domaines.
- [`domain-conventions.md`](domain-conventions.md) — conventions internes CHAN-27.
- [`domain-communication.md`](domain-communication.md) — contrats synchrones CHAN-28.
- Cahier des charges CHAN-29 fourni pour ce lot.

## 2. Cadre validé

Les éléments suivants sont des décisions validées. Ils structurent l'ensemble du catalogue et ne sont pas rouverts par ce document.

### 2.1 Périmètre des activités

Le périmètre couvre toutes les activités de C2ME :

- bureau d'études et études techniques ;
- charpente métallique ;
- couverture ;
- bardage ;
- fabrication et assemblage métallique ;
- montage et installation de charpentes ;
- serrurerie ;
- menuiseries métalliques ;
- maçonnerie ;
- génie civil.

Aucun domaine supplémentaire n'est créé pour représenter ces activités. Elles sont prises en compte dans les responsabilités des 18 domaines existants, principalement :

| Activité | Domaines principalement concernés |
| --- | --- |
| Bureau d'études et études techniques | Projects, Workshop, Quality, Documents |
| Charpente métallique | Projects, Workshop, Quality, Logistics |
| Couverture | Projects, Procurement, Logistics, Quality |
| Bardage | Projects, Procurement, Logistics, Quality |
| Fabrication et assemblage métallique | Workshop, Inventory, Quality, Equipment |
| Montage et installation de charpentes | Projects, Planning, Logistics, Safety |
| Serrurerie | Projects, Workshop, Quality |
| Menuiseries métalliques | Projects, Workshop, Quality |
| Maçonnerie | Projects, Procurement, Logistics, Quality, Safety |
| Génie civil | Projects, Procurement, Logistics, Quality, Safety |

### 2.2 Cycle commercial mixte

Le logiciel doit couvrir deux parcours :

**Parcours commercial complet :**

```text
Prospect → Client → Étude → Devis → Acceptation / Commande → Affaire → Chantier
```

**Parcours direct :**

```text
Commande ou ordre de service déjà obtenu → Création de l'affaire → Préparation → Exécution
```

La cartographie tient compte des deux cas. Le parcours direct ne supprime pas la nécessité de qualifier le client, le donneur d'ordre, le périmètre, le prix, les délais et les risques ; il déplace simplement l'effort de préparation après l'obtention de la commande.

### 2.3 Atelier interne et externe

C2ME peut réaliser ses fabrications dans son propre atelier ou confier des fabrications ou opérations à des prestataires externes. Le domaine Workshop est étudié dans les deux configurations. Il ne prend pas en charge les responsabilités propres à Procurement ou Inventory :

- Procurement porte la relation fournisseur/sous-traitant, la commande et l'engagement commercial ;
- Inventory porte le stock, les mouvements et la traçabilité matière ;
- Workshop porte l'ordre de fabrication, le dossier technique, les opérations, l'exécution et l'acceptation technique de la fabrication.

### 2.4 Sous-traitance dans les deux sens

C2ME intervient dans deux situations distinctes :

| Situation | Rôle de C2ME | Responsabilités principales |
| --- | --- | --- |
| C2ME donneur d'ordre | Client d'un sous-traitant | Procurement porte la commande de sous-traitance et l'engagement ; Projects/Workshop portent le besoin technique et l'acceptation ; Quality contrôle ; Costing enregistre le coût. |
| C2ME sous-traitant | Intervenant pour un donneur d'ordre | Clients porte le donneur d'ordre et la relation commerciale ; Projects porte l'affaire et l'engagement reçu ; Procurement gère uniquement les achats propres de C2ME ; Handover porte la réception contractuelle par le donneur d'ordre. |

La distinction est structurante : elle évite de traiter une commande reçue comme un achat, et une commande passée comme une vente.

### 2.5 Stocks centralisés

Le référentiel principal de stock est centralisé. Les besoins à étudier comprennent :

- articles et références ;
- réceptions ;
- entrées et sorties ;
- affectations aux affaires ;
- consommations ;
- préparation des commandes ;
- livraisons vers les chantiers et l'atelier ;
- traçabilité des mouvements.

Ce document ne présume pas qu'un système complet de stock autonome par chantier existe déjà. Le stock de chantier est traité comme une question ouverte (Q-19), avec une hypothèse de stock temporaire sous contrôle d'Inventory, et non comme un domaine ou un stock autonome.

### 2.6 Paie externalisée

La production de la paie est externalisée. Workforce est étudié pour :

- les collaborateurs ;
- les informations administratives et contractuelles ;
- les qualifications et compétences ;
- les données RH utiles à l'organisation du travail ;
- les éléments variables nécessaires au prestataire de paie.

Workforce ne porte pas comme fonctionnalité interne obligatoire :

- le calcul des bulletins de paie ;
- les déclarations sociales ;
- le paiement des salaires.

TimeTracking reste responsable des événements de temps et des informations de pointage relevant de son périmètre.

### 2.7 Politique de dépendance

La décision validée pour la suite de CHAN-29 est une politique stricte :

- les échanges inter-domaines passeront par des contrats publics ou des événements ;
- aucun domaine n'accédera directement aux composants internes d'un autre domaine ;
- les Models, Actions, Services, DTO internes, Policies et tables d'un domaine ne sont pas importables par un autre domaine ;
- le fournisseur d'une donnée, d'un invariant ou d'une décision en reste propriétaire.

Ce Lot 1 identifie les **besoins d'échange métier**. Il ne définit pas la matrice technique détaillée, qui relève du Lot 2.

## 3. Convention de lecture du catalogue

### 3.1 Propriété métier

Un domaine **possède** un objet métier lorsqu'il est la seule autorité sur :

- sa définition et ses invariants ;
- ses états et transitions ;
- ses règles d'écriture et de suppression ;
- ses règles d'autorisation ;
- la décision de le rendre visible ou non aux autres domaines.

Un autre domaine peut **consommer** une information sans en être propriétaire. Il ne peut pas la modifier directement.

### 3.2 Objets et identifiants

Les objets métier sont identifiés par un code stable, par exemple `CLI-02 Client` ou `PRJ-01 Affaire`. Le catalogue détaillé, les définitions et les consommateurs figurent dans [`business-objects.md`](business-objects.md).

Les tableaux « Entrées et sorties » des fiches de domaine sont des **synthèses non exhaustives**. Le registre des interactions fait foi pour l'inventaire détaillé : une interaction peut exister sans être répétée dans chaque fiche, et une fiche peut mentionner un besoin qui n'a pas encore donné lieu à une ligne nominative dans le registre.

### 3.3 Acteurs

Les acteurs sont décrits en langage métier : direction, chargé d'affaires, chef de chantier, bureau d'études, atelier, magasin, acheteur, qualité, sécurité, RH, contrôle de gestion, client, donneur d'ordre, sous-traitant, fournisseur, transporteur. Les comptes et droits correspondants sont gérés par Identity ; les données de la personne sont gérées par Workforce lorsqu'il s'agit d'un collaborateur.

### 3.4 Glossaire de lecture

| Terme | Définition de travail |
| --- | --- |
| **Affaire** | Unité contractuelle et de pilotage d'un engagement client ; elle porte le périmètre, le prix, les délais et les jalons. |
| **Chantier** | Lieu physique d'exécution des travaux d'une affaire. |
| **Lot / phase** | Subdivision technique ou temporelle d'une affaire ou d'un chantier, utilisée comme axe de planification, de budget, de coût et de qualité. |
| **Avenant** | Modification contractuelle du périmètre, du prix ou des délais d'une affaire. |
| **Commande client / ordre de service** | Acte par lequel le client engage C2ME sur un périmètre et des conditions. |
| **Réserve** | Écart contractuel constaté à la réception, à lever avant la clôture contractuelle. |
| **DOE** | Dossier des ouvrages exécutés, remis au client à la réception. |
| **NCR** | Non-conformité technique constatée par Quality, distincte d'une réserve contractuelle. |
| **Sous-traitance donnée** | C2ME confie une fabrication ou une prestation à un tiers ; Procurement porte la commande. |
| **Sous-traitance reçue** | C2ME intervient pour un donneur d'ordre ; Projects porte l'affaire et Clients porte le donneur d'ordre. |
| **Atelier interne / fabrication externe** | Exécution d'une fabrication par C2ME ou par un prestataire, avec la même exigence de dossier technique et d'acceptation. |
| **Stock central** | Référentiel unique des articles et des mouvements ; le stock de chantier est un emplacement temporaire à valider. |
| **EAC** | *Estimate at Completion* : coût final estimé d'une affaire, porté par Costing. |
| **Élément variable de paie** | Donnée préparée par Workforce et transmise au prestataire de paie (heures, absences, primes, etc.). |
| **Habilitation / autorisation de travail** | Aptitude opérationnelle délivrée par Safety pour une tâche ou un site donné. |

## 4. Vue d'ensemble des 18 domaines

| ID | Domaine | Responsabilité principale | Objets emblématiques | Principaux consommateurs |
| --- | --- | --- | --- | --- |
| D01 | Identity | Identité, authentification et autorisation des acteurs | Utilisateur, Rôle, Permission, Périmètre | Tous |
| D02 | Clients | Prospects, clients, donneurs d'ordre et relation commerciale | Prospect, Client, Contact, RôleTiers | Projects, Handover, Reporting |
| D03 | Projects | Engagement contractuel, affaire, chantier et pilotage global | Affaire, Chantier, Devis, Avenant, Jalon | Planning, Budgets, Costing, Workshop, Procurement, Inventory, Quality, Safety, Handover |
| D04 | Planning | Organisation dans le temps et affectation des ressources | PlanDeCharge, Activité, Affectation | Projects, Workforce, Equipment, Logistics |
| D05 | Budgets | Enveloppe budgétaire, versions et contrôle de consommation | Budget, LigneBudgétaire, Révision | Projects, Costing, Procurement |
| D06 | Costing | Chiffrage, coûts, engagements, marge et écarts | Chiffrage, Coût, Engagement, Marge | Projects, Budgets, Reporting |
| D07 | Workforce | Collaborateurs, contrats, qualifications et variables de paie | Collaborateur, Contrat, Qualification | Planning, TimeTracking, Costing |
| D08 | TimeTracking | Pointages, temps de travail et imputations | Pointage, FeuilleDeTemps, Absence | Workforce, Costing, Planning |
| D09 | Workshop | Fabrication et assemblage internes ou externalisés | OrdreDeFabrication, Opération, Colis | Projects, Inventory, Logistics, Quality |
| D10 | Procurement | Achats, fournisseurs et sous-traitance donnée | Fournisseur, CommandeDAchat, CommandeDeSousTraitance | Inventory, Costing, Planning |
| D11 | Inventory | Stock central, réceptions, mouvements et traçabilité | Article, Réception, Mouvement, Réservation | Workshop, Projects, Costing |
| D12 | Equipment | Parc, disponibilité, maintenance et conformité des équipements | Équipement, Maintenance, Inspection | Planning, Logistics, Safety |
| D13 | Logistics | Transport, livraisons, réceptions chantier et retours | PlanDeTransport, Livraison, Retour | Inventory, Projects, Costing |
| D14 | Quality | Conformité technique, contrôles et non-conformités | PlanQualité, Contrôle, NonConformité | Projects, Workshop, Handover |
| D15 | Safety | Prévention, sécurité, incidents et autorisations | AnalyseDeRisques, Incident, Habilitation | Projects, Workshop, Workforce |
| D16 | Documents | Cycle de vie documentaire, versions et diffusion | Document, Version, Diffusion | Tous |
| D17 | Handover | Réception contractuelle, réserves, DOE et garanties | Réception, Réserve, DOE, Garantie | Projects, Clients, Quality |
| D18 | Reporting | Indicateurs, rapports et tableaux de bord consolidés | Rapport, Indicateur, Snapshot | Direction, tous les domaines |

## 5. Catalogue détaillé des domaines

### D01 — Identity

**Mission.** Garantir l'identité des acteurs, l'authentification et l'autorisation d'accès aux ressources et aux opérations de l'application.

| Rubrique | Contenu |
| --- | --- |
| Périmètre inclus | Comptes utilisateurs, rôles, permissions, périmètres d'accès, délégations, unités organisationnelles internes, journal d'authentification et d'autorisation. |
| Périmètre exclu | Données RH et contractuelles des collaborateurs (Workforce), contacts clients (Clients), fournisseurs et sous-traitants (Procurement), décision métier d'une opération (chaque domaine). |
| Objets métier | `IDN-01` Utilisateur, `IDN-02` Rôle, `IDN-03` Permission, `IDN-04` PérimètreDAccès, `IDN-05` Délégation, `IDN-06` UnitéOrganisationnelle. |
| Acteurs | Administrateur fonctionnel, responsable sécurité SI, manager, utilisateur, auditeur. |

**Règles métier portées par le domaine.**

| Règle | Statut |
| --- | --- |
| Un compte utilisateur est unique et rattaché à un acteur identifié. | Proposition |
| L'accès repose sur un rôle, une permission et un périmètre explicites. | Proposition |
| Le moindre privilège s'applique. | Validé par `AGENTS.md` |
| Un rôle métier n'est pas déduit automatiquement d'une donnée RH : il est attribué explicitement. | Proposition |
| La désactivation d'un compte est déclenchée par la fin de collaboration ou une décision de sécurité ; l'historique est conservé. | Proposition |
| Les opérations sensibles peuvent exiger une séparation des droits entre saisie et validation. | Question ouverte Q-35 |
| Un utilisateur externe (client, sous-traitant) ne dispose pas de compte par défaut ; son accès éventuel relève d'une décision spécifique. | Proposition |

**États et transitions.**

| Objet | États | Transitions principales |
| --- | --- | --- |
| Utilisateur | Invité, actif, suspendu, désactivé | Inviter → activer ; suspendre → réactiver ; désactiver définitivement. |
| Rôle / permission | Actif, expiré | Attribution datée, retrait, expiration. |
| Délégation | Planifiée, active, expirée, révoquée | Créer, activer, révoquer. |

**Entrées et sorties.**

| Sens | Domaine | Informations | Moment |
| --- | --- | --- | --- |
| Entrée | Workforce | Arrivée, départ, changement de poste ou d'unité d'un collaborateur | Cycle de vie RH |
| Entrée | Managers métier | Demande d'accès ou de rôle | Attribution des droits |
| Sortie | Tous les domaines | Identité de l'acteur, rôles, permissions, périmètre | Authentification et autorisation |
| Sortie | Reporting | Périmètre d'accès aux rapports | Consultation des rapports |

**Limites et chevauchements.** Identity ne porte pas les données de la personne (Workforce), ni la relation client (Clients), ni la relation fournisseur (Procurement). Il fournit l'identité et les droits ; chaque domaine applique ses propres Policies et invariants métier. Voir BD-18 et Q-35.

**Questions ouvertes.** Q-35 (cycle de vie des comptes et rôles), Q-36 (stratégie d'identifiants), Q-40 (confidentialité et conservation).

---

### D02 — Clients

**Mission.** Gérer les rôles commerciaux des tiers (prospect, client, donneur d'ordre), leurs contacts et la relation commerciale, sans présumer l'identité juridique unique du tiers (Q-05).

| Rubrique | Contenu |
| --- | --- |
| Périmètre inclus | Prospection, qualification, référence de tiers (selon Q-05), rôles commerciaux (prospect, client, donneur d'ordre, maître d'ouvrage, payeur, maître d'œuvre, prescripteur), contacts, relation commerciale, conditions commerciales cadre, statut et historique relationnel. |
| Périmètre exclu | Étude technique, devis, commande, affaire et chantier (Projects), rôles fournisseur et sous-traitant (Procurement), facturation et paiement (hors périmètre des 18 domaines), comptes utilisateurs (Identity). |
| Objets métier | `CLI-01` Prospect, `CLI-02` Client, `CLI-03` ContactClient, `CLI-04` RôleTiers, `CLI-05` RelationCommerciale, `CLI-06` ConditionsCommercialesCadre. |
| Acteurs | Direction commerciale, chargé d'affaires, assistant commercial, direction générale, client, donneur d'ordre, maître d'ouvrage. |

**Règles métier portées par le domaine.**

| Règle | Statut |
| --- | --- |
| Un client est identifié par une référence de tiers stable ; l'unicité et le portage de l'identité juridique restent à arbitrer dans Q-05. | Proposition |
| Un tiers peut porter un rôle commercial, un rôle fournisseur et un rôle sous-traitant ; ces rôles ne créent pas nécessairement des identités juridiques distinctes. | Proposition |
| Un prospect devient client à la première commande ou au premier contrat ; l'historique de prospection est conservé. | Proposition de travail — à arbitrer dans Q-04 |
| Un client avec des affaires actives ne peut pas être supprimé ; il peut être désactivé ou bloqué. | Proposition |
| Un client bloqué ne peut pas recevoir de nouvelle affaire sans dérogation autorisée. | Proposition, seuil et autorité à valider |
| Les conditions commerciales cadre ne remplacent pas les conditions contractuelles propres à une affaire. | Proposition |
| La relation commerciale est suivie par un responsable identifié ; elle ne se confond pas avec l'affaire. | Proposition |

**États et transitions.**

| Objet | États | Transitions principales |
| --- | --- | --- |
| Prospect | Nouveau, qualifié, en étude, perdu, converti | Qualifier, mettre en étude, convertir, clôturer comme perdu. |
| Client | Actif, suspendu, inactif | Activer, suspendre, réactiver, désactiver. |
| Relation commerciale | Active, en veille, terminée | Ouvrir, mettre en veille, clôturer. |
| RôleTiers | Actif, expiré | Attribuer, retirer, faire expirer. |

**Entrées et sorties.**

| Sens | Domaine | Informations | Moment |
| --- | --- | --- | --- |
| Entrée | Identity | Responsable commercial et acteurs autorisés | Attribution de la relation |
| Entrée | Projects | Ouverture, changement d'état ou clôture d'une affaire | Cycle de vie de l'affaire |
| Entrée | Handover | Réception, réserves, garanties | Réception et garantie |
| Sortie | Projects | Référence du tiers (selon Q-05), contacts, rôles, conditions cadre | Étude, devis, ouverture d'affaire |
| Sortie | Handover | Contacts et représentants du client pour la réception | Préparation de la réception |
| Sortie | Reporting | Portefeuille clients, prospects, relation commerciale | Analyse commerciale |

**Limites et chevauchements.** Clients porte les rôles commerciaux et la relation commerciale, sous réserve de Q-05. L'identité juridique de l'entité n'est pas arbitrée : elle peut être portée par Clients, par Procurement ou par un référentiel partagé à définir. Projects porte l'étude, le devis, la commande, l'affaire et le chantier. Un tiers peut être client, fournisseur ou sous-traitant sans que cela implique plusieurs identités juridiques. Voir BD-01 et BD-16.

**Questions ouvertes.** Q-02 (client, donneur d'ordre, maître d'ouvrage), Q-03 (opportunité commerciale), Q-04 (création du client), Q-05 (référentiel tiers partagé), Q-06 (conditions financières et crédit).

---

### D03 — Projects

**Mission.** Porter l'engagement contractuel et le pilotage global d'une affaire, depuis l'étude et le devis jusqu'à la clôture, et organiser ses chantiers.

| Rubrique | Contenu |
| --- | --- |
| Périmètre inclus | Étude d'affaire, devis, commande client ou ordre de service, contrat, affaire, chantier, lots et phases, avenants, jalons contractuels, acteurs de l'affaire, site, avancement contractuel, demande de clôture. |
| Périmètre exclu | Planning détaillé et affectations (Planning), budget (Budgets), chiffrage et coûts (Costing), fabrication (Workshop), achats (Procurement), stock (Inventory), qualité (Quality), sécurité (Safety), réception contractuelle et DOE (Handover), stockage documentaire (Documents). |
| Objets métier | `PRJ-01` Affaire, `PRJ-02` Chantier, `PRJ-03` LotPhase, `PRJ-04` Étude, `PRJ-05` Devis, `PRJ-06` CommandeClient, `PRJ-07` Avenant, `PRJ-08` Contrat, `PRJ-09` JalonContractuel, `PRJ-10` ActeurAffaire. |
| Acteurs | Direction, chargé d'affaires, conducteur de travaux, chef de chantier, bureau d'études, métreur/économiste, responsable juridique, client, donneur d'ordre. |

**Règles métier portées par le domaine.**

| Règle | Statut |
| --- | --- |
| Une affaire est ouverte après acceptation d'un devis ou réception d'une commande ou d'un ordre de service. | Validé par le cycle commercial du ticket |
| Le parcours direct peut ouvrir une affaire sans devis préalable, mais les données contractuelles manquantes doivent être identifiées et complétées. | Validé par le ticket ; modalités à préciser |
| Une affaire porte un numéro unique, un client, un donneur d'ordre et un périmètre contractuel. | Proposition |
| Une affaire peut couvrir un ou plusieurs chantiers ou lots ; un chantier appartient à une seule affaire. | Proposition, à valider Q-01 |
| Les travaux supplémentaires font l'objet d'un avenant validé avant exécution, sauf procédure d'urgence explicitement autorisée. | Proposition |
| Les jalons contractuels et les dates engagées sont la référence pour Planning ; toute modification est tracée. | Proposition |
| L'avancement contractuel est déclaré par lot ou phase ; il ne se confond pas avec l'avancement des activités planifiées. | Proposition |
| La clôture de l'affaire exige la réception contractuelle, la levée des réserves, le DOE et la finalisation des coûts. | Proposition, conditions à valider Q-53 |
| Une suspension ou une annulation exige un motif, une validation et une trace. | Proposition |

**États et transitions.**

| Objet | États | Transitions principales |
| --- | --- | --- |
| Étude | Brouillon, en revue, validée, abandonnée | Soumettre, valider, abandonner. |
| Devis | Brouillon, envoyé, accepté, refusé, expiré | Envoyer, accepter, refuser, expirer. |
| Affaire | Préparation, en cours, suspendue, réceptionnée, clôturée, annulée | Ouvrir, démarrer, suspendre, reprendre, réceptionner, clôturer, annuler. |
| Chantier | Préparé, démarré, en cours, suspendu, réceptionné, clôturé | Démarrer, suspendre, reprendre, réceptionner, clôturer. |
| Avenant | Proposé, validé, refusé | Proposer, valider, refuser. |

**Entrées et sorties.**

| Sens | Domaine | Informations | Moment |
| --- | --- | --- | --- |
| Entrée | Clients | Identité, contacts, rôles, conditions commerciales | Étude, devis, ouverture |
| Entrée | Budgets | Enveloppe validée, disponible, seuils | Ouverture et révision |
| Entrée | Costing | Chiffrage, coût final estimé, marge, alertes | Étude, devis, suivi |
| Entrée | Planning | Planning, dates prévisionnelles, conflits, avancement | Préparation et exécution |
| Entrée | Quality / Safety | Conformité, non-conformités, incidents, contraintes | Exécution et réception |
| Entrée | Handover | Réception, réserves, levées, PV | Réception et clôture |
| Sortie | Planning | Périmètre, lots, jalons, priorités, contraintes de site | Préparation et replanification |
| Sortie | Budgets | Périmètre, montant du contrat, avenants, besoin budgétaire | Ouverture et révision |
| Sortie | Costing | Affaire, lots, montants contractuels, avancement, avenants | Tout le cycle |
| Sortie | Procurement / Workshop / Inventory | Besoins, lots, dates, priorités | Préparation et exécution |
| Sortie | Quality / Safety | Périmètre, spécifications, sites, activités | Préparation et exécution |
| Sortie | Handover | Demande de réception, périmètre, lots, client, dates | Achèvement |
| Sortie | Reporting | Portefeuille, avancement, engagements, clôtures | Pilotage |

**Limites et chevauchements.** Projects est propriétaire de l'engagement et du pilotage contractuel, pas du planning détaillé, du budget, des coûts, de la fabrication, des achats, du stock, de la qualité, de la sécurité ni de la réception contractuelle. Voir BD-01, BD-02, BD-03, BD-17 et BD-19.

**Questions ouvertes.** Q-01 (relation affaire/chantier), Q-27 (avancement), Q-45 (avenants), Q-46 (suspension), Q-47 (annulation), Q-50 (bureau d'études), Q-51 (risques d'affaire), Q-52 (permis et autorisations), Q-53 (conditions de clôture).

---

### D04 — Planning

**Mission.** Organiser dans le temps les interventions et affecter les ressources disponibles aux activités des affaires et des chantiers.

| Rubrique | Contenu |
| --- | --- |
| Périmètre inclus | Plans de charge, activités planifiées, dépendances, affectations de ressources, calendriers de capacité, conflits, avancement des activités, prévision glissante, contraintes de site. |
| Périmètre exclu | Données RH et contrats (Workforce), disponibilité et maintenance des équipements (Equipment), capacité de production détaillée (Workshop), achats et délais fournisseurs (Procurement), pointages (TimeTracking), engagement contractuel (Projects), exécution des travaux (Projects). |
| Objets métier | `PLN-01` PlanDeCharge, `PLN-02` ActivitéPlanifiée, `PLN-03` AffectationRessource, `PLN-04` CalendrierCapacité, `PLN-05` ConflitPlanning, `PLN-06` AvancementActivité. |
| Acteurs | Planificateur, chargé d'affaires, conducteur de travaux, chef de chantier, responsable atelier, RH, responsable matériel, sous-traitants. |

**Règles métier portées par le domaine.**

| Règle | Statut |
| --- | --- |
| Toute activité planifiée est rattachée à une affaire, un chantier et, si possible, un lot ou une phase. | Proposition |
| Une ressource ne peut être affectée que si elle est disponible et, pour les tâches critiques, qualifiée. | Proposition |
| Les dépendances, contraintes de site, délais d'approvisionnement et capacités finies sont prises en compte. | Proposition |
| Une surcharge de capacité est signalée comme conflit ; elle n'est pas masquée par une affectation implicite. | Proposition |
| Le planning publié est la référence de coordination ; toute modification est tracée. | Proposition |
| L'avancement des activités est mis à jour à partir des faits d'exécution et des pointages, sans remplacer TimeTracking. | Proposition |
| Un horizon ferme et un horizon glissant sont définis ; leurs durées restent à valider. | Question ouverte Q-28 |
| L'arbitrage entre deux affaires en conflit de ressources relève d'une décision de direction, pas du planificateur seul. | Proposition, autorité à valider |

**États et transitions.**

| Objet | États | Transitions principales |
| --- | --- | --- |
| PlanDeCharge | Brouillon, publié, révisé, archivé | Publier, réviser, archiver. |
| ActivitéPlanifiée | Prévue, prête, en cours, terminée, annulée | Prête, démarrer, terminer, annuler. |
| AffectationRessource | Proposée, confirmée, libérée | Proposer, confirmer, libérer. |
| ConflitPlanning | Ouvert, résolu, accepté | Résoudre ou accepter avec justification. |
| AvancementActivité | Non démarré, en cours, terminé, en retard | Mettre à jour selon les faits. |

**Entrées et sorties.**

| Sens | Domaine | Informations | Moment |
| --- | --- | --- | --- |
| Entrée | Projects | Périmètre, lots, jalons contractuels, priorités, contraintes de site | Préparation et replanification |
| Entrée | Workforce | Collaborateurs, équipes, qualifications, disponibilité, contraintes contractuelles | Planification |
| Entrée | Equipment | Disponibilité, maintenance, inspections, affectations | Planification |
| Entrée | Workshop | Capacité atelier, durées d'OF, contraintes de production | Planification |
| Entrée | Procurement | Délais fournisseurs, dates de livraison prévues | Planification |
| Entrée | Inventory | Disponibilité et réservations de stock | Planification |
| Entrée | Logistics | Contraintes de transport et de livraison | Planification |
| Entrée | TimeTracking | Temps réels, absences, avancement constaté | Replanification |
| Sortie | Projects | Planning, dates prévisionnelles, conflits, avancement | Préparation et suivi |
| Sortie | Workforce | Besoins et affectations prévisionnelles | Planification RH |
| Sortie | Equipment | Besoins et réservations d'équipements | Planification matérielle |
| Sortie | Workshop | Créneaux, priorités et séquence de fabrication | Planification atelier |
| Sortie | Procurement / Inventory / Logistics | Besoins datés et contraintes de disponibilité | Préparation |
| Sortie | Reporting | Charge, respect des délais, conflits | Pilotage |

**Limites et chevauchements.** Planning organise les interventions ; Projects porte l'engagement contractuel et les jalons. Workforce possède les personnes et leurs contraintes ; Equipment possède les actifs ; Workshop possède la capacité de production. Voir BD-02, BD-13 et Q-27, Q-28.

**Questions ouvertes.** Q-24 (capacité atelier), Q-27 (avancement), Q-28 (horizon et arbitrage des conflits).

---

### D05 — Budgets

**Mission.** Définir, valider et réviser l'enveloppe budgétaire d'une affaire et en contrôler la consommation.

| Rubrique | Contenu |
| --- | --- |
| Périmètre inclus | Budget initial, versions, lignes budgétaires par lot et nature, enveloppe, contingence, révisions, validations, écarts budgétaires, prévision budgétaire. |
| Périmètre exclu | Chiffrage détaillé et estimation de coût (Costing), engagements et coûts constatés (Costing/Procurement), prix de vente (Projects), facturation et comptabilité générale (hors périmètre des 18 domaines). |
| Objets métier | `BUD-01` Budget, `BUD-02` VersionBudget, `BUD-03` LigneBudgétaire, `BUD-04` RévisionBudgétaire, `BUD-05` Contingence. |
| Acteurs | Direction générale, contrôle de gestion, chargé d'affaires, responsable financier, chef de projet. |

**Règles métier portées par le domaine.**

| Règle | Statut |
| --- | --- |
| Un budget est établi pour chaque affaire avant les engagements significatifs ; le parcours direct peut utiliser un budget provisoire. | Proposition |
| Une seule version de budget est active à un instant donné ; les versions antérieures sont conservées. | Proposition |
| Les lignes budgétaires sont rattachées à un lot, une nature et une période ; leur somme forme l'enveloppe. | Proposition |
| Une révision au-delà d'un seuil exige une validation de la direction. | Proposition, seuil à définir Q-08 |
| Un avenant validé entraîne une révision budgétaire tracée. | Proposition |
| Un engagement supérieur au disponible budgétaire est bloqué ou soumis à une dérogation explicite. | Proposition, à valider |
| Le budget ne se confond pas avec le prix de vente ; la marge cible est validée par la direction. | Proposition |
| Le budget ne contient pas les coûts constatés : il fixe l'enveloppe et analyse les écarts avec Costing. | Proposition, arbitrage BD-03 |
| La prévision budgétaire porte sur l'enveloppe et sa consommation ; le coût final estimé (EAC) est porté par Costing. | Proposition |
| La clôture budgétaire intervient après la clôture des coûts et la clôture contractuelle. | Proposition, Q-53 |

**États et transitions.**

| Objet | États | Transitions principales |
| --- | --- | --- |
| Budget | Brouillon, soumis, approuvé, remplacé, rejeté, clôturé | Soumettre, approuver, remplacer, rejeter, clôturer. |
| VersionBudget | Active, archivée | Activer, archiver. |
| RévisionBudgétaire | Proposée, validée, rejetée | Proposer, valider, rejeter. |

**Entrées et sorties.**

| Sens | Domaine | Informations | Moment |
| --- | --- | --- | --- |
| Entrée | Projects | Périmètre, lots, montant du contrat, avenants, besoin budgétaire | Ouverture et révision |
| Entrée | Costing | Chiffrage, engagements, coûts constatés, coût final estimé, écarts | Élaboration et suivi |
| Entrée | Procurement | Offres, commandes et engagements prévisionnels | Élaboration et suivi |
| Entrée | Workforce / Equipment / Workshop / Logistics | Taux, coûts et capacités prévisionnels | Élaboration |
| Entrée | Quality / Safety | Coûts de conformité et de prévention | Élaboration |
| Sortie | Projects | Enveloppe, validation, disponible, seuils, alerte | Ouverture et suivi |
| Sortie | Costing | Lignes budgétaires et enveloppe de référence | Suivi des écarts |
| Sortie | Procurement | Disponible budgétaire et autorisation d'engagement | Validation des commandes |
| Sortie | Reporting | Budget, consommation, écarts, prévisions | Pilotage |

**Limites et chevauchements.** Budgets porte l'enveloppe autorisée ; Costing porte le chiffrage, les engagements, les coûts constatés, le coût final estimé et la marge. Procurement porte l'acte commercial d'engagement ; Costing en assure le suivi financier. Voir BD-03.

**Questions ouvertes.** Q-08 (seuils et autorité de révision), Q-09 (reconnaissance des engagements), Q-10 (coût final estimé), Q-37 (unité monétaire et arrondis), Q-53 (clôture budgétaire).

---

### D06 — Costing

**Mission.** Estimer, enregistrer, imputer et analyser les coûts et engagements d'une affaire afin de produire le coût réel, le coût final estimé et la marge.

| Rubrique | Contenu |
| --- | --- |
| Périmètre inclus | Chiffrage prévisionnel, engagements, coûts constatés, imputations analytiques, allocations, valorisation, marge, écarts, provisions analytiques, périodes et axes analytiques. |
| Périmètre exclu | Budget et enveloppe (Budgets), commandes et fournisseurs (Procurement), temps et pointages (TimeTracking), stock physique (Inventory), production (Workshop), paie et contrats (Workforce), prix de vente (Projects), comptabilité générale et paiement (hors périmètre). |
| Objets métier | `CST-01` Chiffrage, `CST-02` Coût, `CST-03` Engagement, `CST-04` ImputationAnalytique, `CST-05` Marge, `CST-06` ÉcartCoût, `CST-07` ProvisionAnalytique, `CST-08` PériodeAnalytique. |
| Acteurs | Contrôleur de gestion, chargé d'affaires, direction financière, direction générale, acheteur, chef de chantier, responsable atelier. |

**Règles métier portées par le domaine.**

| Règle | Statut |
| --- | --- |
| Tout coût est imputé à une affaire, un chantier, un lot et une nature ; aucun coût ne reste orphelin. | Proposition |
| Un engagement est reconnu à la validation de la commande ou du contrat qui le crée ; le point exact est à valider. | Proposition, Q-09 |
| Un coût constaté provient d'un fait source : temps validé, sortie de stock, réception, production, transport, facture lorsqu'elle sera traitée. | Proposition |
| Un même coût n'est jamais compté deux fois ; tout ajustement est tracé et justifié. | Proposition |
| Le coût final estimé (EAC) combine coûts constatés, engagements et reste à engager estimé. | Proposition, Q-10 |
| La marge est calculée à partir du prix de vente contractuel et du coût ; l'unité, la devise et les arrondis restent à décider. | Proposition, Q-37 |
| Une période analytique clôturée ne peut plus recevoir d'écriture sans réouverture autorisée et tracée. | Proposition |
| Le chiffrage prévisionnel peut servir de base au budget après acceptation, sans devenir le budget lui-même. | Proposition, arbitrage BD-03 |

**États et transitions.**

| Objet | États | Transitions principales |
| --- | --- | --- |
| Chiffrage | Brouillon, validé, révisé, abandonné | Valider, réviser, abandonner. |
| Coût | Provisoire, validé, passé, annulé | Valider, passer, annuler avec trace. |
| Engagement | Ouvert, partiellement consommé, soldé, annulé | Ouvrir, consommer, solder, annuler. |
| PériodeAnalytique | Ouverte, clôturée, rouverte | Clôturer, rouvrir avec autorisation. |
| Marge | Prévisionnelle, réalisée, à terminaison | Recalculer selon les faits. |

**Entrées et sorties.**

| Sens | Domaine | Informations | Moment |
| --- | --- | --- | --- |
| Entrée | Projects | Affaire, lots, montants contractuels, avenants, avancement | Tout le cycle |
| Entrée | Budgets | Lignes budgétaires et enveloppe de référence | Suivi |
| Entrée | Procurement | Commandes, engagements, variations de prix | Engagement et suivi |
| Entrée | TimeTracking | Heures validées et imputations | Période de paie ou de coût |
| Entrée | Workforce | Taux horaires de référence et éléments de coût RH | Valorisation |
| Entrée | Inventory | Quantités consommées et valorisation matière | Sortie de stock |
| Entrée | Workshop | Heures de production, matière, rebuts, coûts atelier | Production |
| Entrée | Equipment | Utilisation, maintenance, pannes, location | Utilisation |
| Entrée | Logistics | Coûts de transport et de retour | Livraison |
| Entrée | Quality / Safety | Coûts de non-qualité, de prévention et d'incidents | Traitement |
| Sortie | Projects | Coût réel, EAC, marge, alertes | Suivi de l'affaire |
| Sortie | Budgets | Engagements, coûts constatés, écarts, EAC | Suivi budgétaire |
| Sortie | Reporting | Coûts, marges, écarts, tendances | Pilotage |

**Limites et chevauchements.** Costing ne possède pas les faits opérationnels : il les valorise. Il ne fixe pas le budget, n'approuve pas les achats, ne calcule pas la paie et ne remplace pas la comptabilité générale. Voir BD-03 et BD-21.

**Questions ouvertes.** Q-09, Q-10, Q-11, Q-37, Q-42.

---

### D07 — Workforce

**Mission.** Gérer les collaborateurs et les données RH nécessaires à l'organisation du travail et à l'alimentation du prestataire de paie.

| Rubrique | Contenu |
| --- | --- |
| Périmètre inclus | Collaborateurs, contrats de travail, postes, qualifications, compétences, formations, équipes, affectation organisationnelle, disponibilité RH, dossier RH, éléments variables de paie, taux horaires de référence. |
| Périmètre exclu | Pointages, temps de travail et absences constatées (TimeTracking), planning et affectations opérationnelles (Planning), calcul des bulletins, déclarations sociales et paiement des salaires (prestataire externe), sécurité opérationnelle (Safety), comptes utilisateurs (Identity), qualifications techniques de production (Quality). |
| Objets métier | `WKF-01` Collaborateur, `WKF-02` ContratDeTravail, `WKF-03` Poste, `WKF-04` Qualification, `WKF-05` Formation, `WKF-06` Équipe, `WKF-07` DisponibilitéRH, `WKF-08` ÉlémentVariableDePaie, `WKF-09` DossierRH. |
| Acteurs | RH, direction, manager, collaborateur, prestataire de paie, chef de chantier, responsable atelier. |

**Règles métier portées par le domaine.**

| Règle | Statut |
| --- | --- |
| Un collaborateur est identifié de façon unique. | Proposition |
| Ses données administratives et personnelles sont protégées et accessibles selon le moindre privilège. | Validé par `AGENTS.md` |
| Un contrat actif est requis pour affecter un collaborateur à une activité productive. | Proposition |
| Une qualification ou une formation requise doit être valide pour l'affectation correspondante. | Proposition |
| Un collaborateur peut appartenir à une équipe principale et être affecté temporairement à d'autres équipes. | Proposition |
| La sortie d'un collaborateur déclenche la désactivation du compte Identity et la clôture des affectations, avec conservation légale des données. | Proposition |
| Les éléments variables de paie sont préparés et validés à partir des temps, absences et données contractuelles ; Workforce ne calcule pas le bulletin. | Validé par le ticket |
| Le taux horaire de référence est un coût RH, pas un prix de vente ; sa validation relève de la direction financière. | Proposition |
| Les intérimaires et prestataires de main-d'œuvre relèvent d'un arbitrage entre Workforce et Procurement. | Question ouverte Q-15 |

**États et transitions.**

| Objet | États | Transitions principales |
| --- | --- | --- |
| Collaborateur | Actif, suspendu, en congé, sorti | Activer, suspendre, réintégrer, sortir. |
| ContratDeTravail | Brouillon, actif, terminé | Activer, terminer. |
| Qualification / formation | Valide, expirée, en cours | Obtenir, renouveler, expirer. |
| ÉlémentVariableDePaie | Saisi, validé, transmis | Valider, transmettre au prestataire. |

**Entrées et sorties.**

| Sens | Domaine | Informations | Moment |
| --- | --- | --- | --- |
| Entrée | Identity | Identité de l'acteur et périmètre | Création et mise à jour |
| Entrée | TimeTracking | Temps validés, absences constatées, heures supplémentaires | Cycle de paie et suivi |
| Entrée | Safety | Exigences de formation et d'habilitation sécurité | Affectation |
| Entrée | Quality | Exigences de qualification technique | Affectation critique |
| Entrée | Planning | Besoins en ressources et affectations prévisionnelles | Planification |
| Sortie | Identity | Arrivée, départ, changement de poste ou d'unité | Cycle de vie |
| Sortie | Planning | Collaborateurs, équipes, qualifications, disponibilité | Planification |
| Sortie | TimeTracking | Collaborateur, équipe, contrat, droits à absence | Saisie et validation |
| Sortie | Costing | Taux horaires et coûts RH de référence | Valorisation |
| Sortie | Budgets | Taux et hypothèses RH | Élaboration budgétaire |
| Sortie | Safety / Quality | Formations et qualifications RH disponibles (preuves) | Vérification des exigences |
| Sortie | Prestataire de paie | Éléments variables, absences, données contractuelles | Cycle de paie |
| Sortie | Reporting | Effectifs, qualifications, absences, masse salariale | Pilotage RH |

**Limites et chevauchements.** Workforce porte la relation contractuelle, les données RH et les qualifications RH (diplômes, formations). TimeTracking porte les événements de temps ; Planning porte les affectations opérationnelles. Les qualifications techniques de production (soudage, procédé, contrôle) relèvent de Quality, sous réserve de Q-16. La paie est produite par un prestataire externe. Voir BD-04, BD-09 et BD-15.

**Questions ouvertes.** Q-11 (taux horaires), Q-12 (absences), Q-13 (temps de trajet et astreintes), Q-14 (périmètre de paie), Q-15 (intérimaires), Q-16 (qualifications techniques), Q-35 (comptes), Q-40 (données personnelles).

---

### D08 — TimeTracking

**Mission.** Capturer, valider et consolider les événements de temps et de présence des collaborateurs, et les imputer aux affaires, chantiers et activités.

| Rubrique | Contenu |
| --- | --- |
| Périmètre inclus | Pointages, feuilles de temps, événements de temps, imputations, périodes de pointage, validations, corrections, absences constatées, verrouillage de période, temps de trajet et d'astreinte. |
| Périmètre exclu | Contrats, qualifications et données RH (Workforce), planning et affectations (Planning), calcul de paie (Workforce/prestataire externe), calcul des coûts (Costing), évaluation de la productivité (Reporting). |
| Objets métier | `TKT-01` Pointage, `TKT-02` FeuilleDeTemps, `TKT-03` ImputationDeTemps, `TKT-04` PériodeDePointage, `TKT-05` CorrectionDeTemps, `TKT-06` ÉvénementDAbsence. |
| Acteurs | Collaborateur, chef d'équipe, chef de chantier, responsable atelier, RH, contrôleur de gestion, manager. |

**Règles métier portées par le domaine.**

| Règle | Statut |
| --- | --- |
| Un événement de temps comporte un collaborateur, une date ou un horaire, une durée et une imputation. | Proposition |
| Les chevauchements, durées négatives et incohérences de période sont refusés. | Proposition |
| Toute correction est tracée avec un motif, un acteur et une date. | Proposition |
| Une période verrouillée ne peut plus être modifiée sans réouverture autorisée et tracée. | Proposition |
| Une imputation doit référencer une affaire, un chantier ou une activité valide ; les activités non productives sont autorisées et catégorisées. | Proposition |
| Le pointage hors connexion est idempotent et le serveur reste l'autorité. | Validé par `AGENTS.md` |
| TimeTracking constate le temps d'absence ; Workforce qualifie le motif contractuel et administratif. | Proposition, Q-12 |
| Les règles de temps de trajet, d'astreinte et d'heures supplémentaires restent à définir. | Question ouverte Q-13 |

**États et transitions.**

| Objet | États | Transitions principales |
| --- | --- | --- |
| Pointage | Brouillon, soumis, validé, rejeté, corrigé | Soumettre, valider, rejeter, corriger. |
| FeuilleDeTemps | Ouverte, soumise, validée, verrouillée | Soumettre, valider, verrouiller. |
| PériodeDePointage | Ouverte, verrouillée | Verrouiller, rouvrir avec autorisation. |
| ÉvénementDAbsence | Déclaré, constaté, justifié, clos | Constater, justifier, clore. |

**Entrées et sorties.**

| Sens | Domaine | Informations | Moment |
| --- | --- | --- | --- |
| Entrée | Workforce | Collaborateur, équipe, contrat, droits à absence | Saisie et validation |
| Entrée | Projects | Affaire, chantier, lot, activité | Imputation |
| Entrée | Planning | Activités planifiées et affectations | Saisie et rapprochement |
| Entrée | Identity | Acteur et périmètre | Authentification |
| Sortie | Workforce | Temps validés, absences, heures supplémentaires | Cycle de paie |
| Sortie | Costing | Heures validées par affaire, lot et nature | Valorisation |
| Sortie | Planning | Temps réels, avancement, absences | Replanification |
| Sortie | Projects | Temps par lot et avancement constaté | Suivi de l'affaire |
| Sortie | Reporting | Temps, absences, taux de présence | Pilotage |

**Limites et chevauchements.** TimeTracking porte les événements de temps ; Workforce porte les données RH et les variables de paie ; Planning porte les affectations prévisionnelles ; Costing valorise les heures. Voir BD-04.

**Questions ouvertes.** Q-12, Q-13, Q-14, Q-39 (hors connexion), Q-40 (confidentialité).

---

### D09 — Workshop

**Mission.** Industrialiser et exécuter les fabrications et assemblages métalliques, en atelier interne ou via des moyens externes, dans le respect des études, des délais et de la qualité.

| Rubrique | Contenu |
| --- | --- |
| Périmètre inclus | Ordres de fabrication, dossiers et gammes de fabrication, opérations, postes d'atelier, demandes et réservations matières, exécution, autocontrôles, rebuts et reprises, emballage, avancement, capacité d'atelier, dossiers de fabrication externe. |
| Périmètre exclu | Stock et mouvements physiques (Inventory), achats et commandes fournisseurs (Procurement), planning global (Planning), qualité normative et non-conformités (Quality), transport (Logistics), contrat d'affaire (Projects), maintenance des équipements (Equipment). |
| Objets métier | `WKS-01` OrdreDeFabrication, `WKS-02` DossierDeFabrication, `WKS-03` OpérationDeFabrication, `WKS-04` PosteDeFabrication, `WKS-05` DemandeMatière, `WKS-06` CompteRenduDeProduction, `WKS-07` ColisDeFabrication, `WKS-08` DossierDeFabricationExterne, `WKS-09` CapacitéAtelier. |
| Acteurs | Responsable atelier, bureau d'études atelier, chef d'atelier, opérateurs, soudeurs, magasinier, qualité, logistique. |

**Règles métier portées par le domaine.**

| Règle | Statut |
| --- | --- |
| Un ordre de fabrication est créé à partir d'un besoin validé, rattaché à une affaire, un lot ou une commande interne. | Proposition |
| La décision de fabriquer en interne ou de confier à un prestataire est formalisée avec Projects et Procurement. | Proposition |
| La matière consommée est demandée et sortie via Inventory ; Workshop ne décrémente jamais le stock directement. | Proposition |
| Les opérations critiques exigent une qualification valide du personnel et, si nécessaire, un contrôle Quality. | Proposition |
| Un autocontrôle atelier précède la sollicitation de Quality ; une non-conformité est traitée par Quality. | Proposition |
| Un OF est clôturé après production, contrôle, emballage et régularisation des mouvements matières. | Proposition |
| En cas de fabrication externe, Workshop porte le dossier technique et l'acceptation technique ; Procurement porte la commande. | Proposition |
| La capacité d'atelier est fournie à Planning ; Planning arbitre le planning global. | Proposition, Q-24 |
| Le bureau d'études atelier porte les plans d'exécution et nomenclatures de fabrication ; Projects porte les études contractuelles. | Proposition, Q-50 |

**États et transitions.**

| Objet | États | Transitions principales |
| --- | --- | --- |
| OrdreDeFabrication | Brouillon, lancé, en cours, suspendu, terminé, clôturé, annulé | Lancer, démarrer, suspendre, reprendre, terminer, clôturer. |
| OpérationDeFabrication | Planifiée, en cours, terminée, annulée | Démarrer, terminer, annuler. |
| DossierDeFabricationExterne | Préparé, envoyé, réceptionné, accepté, refusé | Envoyer, réceptionner, accepter ou refuser. |
| CompteRenduDeProduction | Brouillon, validé | Valider. |

**Entrées et sorties.**

| Sens | Domaine | Informations | Moment |
| --- | --- | --- | --- |
| Entrée | Projects | Besoin, lot, dossier technique, dates, priorités | Lancement |
| Entrée | Planning | Créneaux, séquence, priorités | Planification |
| Entrée | Inventory | Disponibilité, réservation, sortie matière | Exécution |
| Entrée | Procurement | Commande externe, statut, délais | Sous-traitance |
| Entrée | Quality | Plan de contrôle, exigences, NCR | Exécution |
| Entrée | Safety | Consignes, risques, autorisations | Exécution |
| Entrée | Equipment | Disponibilité des machines | Exécution |
| Entrée | Workforce | Opérateurs et qualifications | Exécution |
| Sortie | Projects | Avancement, disponibilité, contraintes | Suivi |
| Sortie | Inventory | Demandes, consommations, retours matière | Production |
| Sortie | Procurement | Besoin de fabrication externe, dossier technique | Sous-traitance |
| Sortie | Quality | Autocontrôles, demandes de contrôle, NCR | Production |
| Sortie | Logistics | Colis prêts, poids, dimensions, dates | Expédition |
| Sortie | Costing | Heures, matière, rebuts, coûts atelier | Valorisation |
| Sortie | Planning | Capacité, avancement, retards | Replanification |
| Sortie | Documents | Dossiers de fabrication, plans, PV | Production |

**Limites et chevauchements.** Workshop porte la fabrication ; Inventory porte le stock ; Procurement porte les achats et la sous-traitance ; Quality porte la conformité ; Planning porte le planning global. Voir BD-06, BD-10, BD-11 et BD-19.

**Questions ouvertes.** Q-16, Q-23, Q-24, Q-50.

---

### D10 — Procurement

**Mission.** Sourcer, contractualiser et suivre les achats de biens, services et sous-traitance nécessaires aux affaires, à l'atelier et au fonctionnement de C2ME, en portant les rôles fournisseur et sous-traitant des tiers.

| Rubrique | Contenu |
| --- | --- |
| Périmètre inclus | Rôles fournisseur et sous-traitant, demandes d'achat, consultations, offres, commandes d'achat, lignes de commande, commandes de sous-traitance, engagements, échéanciers, performance fournisseur, accords-cadres, références fournisseur, garanties fournisseurs et sous-traitants. |
| Périmètre exclu | Stock, réception physique et mouvements (Inventory), transport (Logistics), qualité technique (Quality), budget (Budgets), coûts (Costing), facturation et paiement (hors périmètre), sous-traitance reçue par C2ME (Projects/Clients). |
| Objets métier | `PRC-01` Fournisseur, `PRC-02` SousTraitant, `PRC-03` DemandeDAchat, `PRC-04` OffreFournisseur, `PRC-05` CommandeDAchat, `PRC-06` LigneDeCommande, `PRC-07` CommandeDeSousTraitance, `PRC-08` ÉvaluationFournisseur, `PRC-09` AccordCadre, `PRC-10` GarantieFournisseur. |
| Acteurs | Acheteur, responsable achats, chargé d'affaires, responsable atelier, magasinier, qualité, sécurité, direction. |

**Règles métier portées par le domaine.**

| Règle | Statut |
| --- | --- |
| Une demande d'achat précise le besoin, la quantité, la date, le lot, la nature et la référence budgétaire. | Proposition |
| Une commande est créée après validation du besoin, du disponible budgétaire et des seuils d'approbation. | Proposition, seuils Q-08 |
| Un fournisseur ou un sous-traitant est un rôle d'achat exercé par un tiers ; il ne présume pas une identité juridique autonome. Le rattachement au référentiel juridique dépend de Q-05. | Proposition |
| Un fournisseur ou sous-traitant est qualifié selon la criticité de la prestation, avec Quality et Safety. | Proposition |
| Une commande constitue un acte commercial qui crée un engagement financier, suivi par Costing ; ses versions, annulations et réceptions partielles sont tracées. | Proposition |
| La réception physique ne vaut pas acceptation qualité ; Inventory enregistre, Quality accepte ou refuse. | Proposition |
| Dans la sous-traitance donnée, Procurement porte la commande et le dossier contractuel ; C2ME reste responsable envers son client. | Proposition |
| Dans la sous-traitance reçue, Procurement ne crée pas de commande de vente : l'affaire est portée par Projects, le donneur d'ordre par Clients. | Proposition |
| L'évaluation fournisseur s'appuie sur les faits de délai, qualité, sécurité et prix fournis par les domaines concernés. | Proposition |
| Les garanties fournisseurs et sous-traitants sont suivies par Procurement ; Handover les reçoit pour constituer les garanties clientes. | Proposition, Q-44 |
| La facturation et le paiement fournisseur ne sont pas pris en charge par Procurement dans les 18 domaines. | Question ouverte Q-07 |

**États et transitions.**

| Objet | États | Transitions principales |
| --- | --- | --- |
| DemandeDAchat | Brouillon, soumise, validée, rejetée | Soumettre, valider, rejeter. |
| OffreFournisseur | Reçue, analysée, retenue, rejetée | Analyser, retenir, rejeter. |
| CommandeDAchat | Brouillon, approuvée, envoyée, partiellement livrée, livrée, clôturée, annulée | Approuver, envoyer, réceptionner, clôturer, annuler. |
| CommandeDeSousTraitance | Brouillon, approuvée, notifiée, en cours, terminée, clôturée, litige | Notifier, démarrer, terminer, clôturer, déclarer un litige. |
| ÉvaluationFournisseur | À jour, à réviser | Évaluer périodiquement. |

**Entrées et sorties.**

| Sens | Domaine | Informations | Moment |
| --- | --- | --- | --- |
| Entrée | Projects / Workshop / Inventory | Besoin, spécifications, quantité, date, lot, budget | Expression du besoin |
| Entrée | Budgets | Disponible et autorisation d'engagement | Validation |
| Entrée | Costing | Axe analytique et nature de coût | Commande |
| Entrée | Quality / Safety | Exigences de qualification et de conformité | Sélection |
| Entrée | Planning | Besoins datés, délais, priorités | Planification |
| Sortie | Inventory | Commande, quantités attendues, échéancier, fournisseur | Commande et livraison |
| Sortie | Costing | Engagements, prix, variations | Commande et suivi |
| Sortie | Budgets | Engagements et consommation | Suivi |
| Sortie | Planning | Délais et dates de livraison prévues | Planification |
| Sortie | Logistics | Enlèvements et livraisons à organiser | Expédition |
| Sortie | Quality / Safety | Fournisseurs et sous-traitants à qualifier ou contrôler | Sélection et suivi |
| Sortie | Workshop | Statut des commandes de fabrication externe | Sous-traitance |
| Sortie | Reporting | Achats, engagements, performance fournisseur | Pilotage |

**Limites et chevauchements.** Procurement porte les rôles d'achat et la relation fournisseur/sous-traitant, sans présumer l'identité juridique du tiers (Q-05). Inventory porte le stock et la réception ; Costing valorise ; Budgets autorise ; Quality et Safety qualifient. Voir BD-05, BD-10, BD-16 et BD-19.

**Questions ouvertes.** Q-05 (identité juridique et référentiel tiers), Q-07, Q-08, Q-17 (article), Q-18 (catalogue), Q-22 (qualification sous-traitant), Q-41 (sous-traitance dans les deux sens), Q-44 (garanties fournisseurs).

---

### D11 — Inventory

**Mission.** Tenir le référentiel central des articles et des stocks, et garantir la traçabilité des mouvements physiques depuis la réception jusqu'à la consommation ou la livraison.

| Rubrique | Contenu |
| --- | --- |
| Périmètre inclus | Articles, références, unités, entrepôts, emplacements, lots et numéros de série, réceptions, enregistrement des contrôles de réception, mouvements, réservations, affectations aux affaires, consommations, préparations, sorties et documents de livraison, inventaires, seuils, traçabilité. |
| Périmètre exclu | Achats et fournisseurs (Procurement), transport et réception sur site (Logistics), acceptation qualité (Quality), production et ordres de fabrication (Workshop), équipements (Equipment), valorisation comptable (Costing), comptabilité générale (hors périmètre). |
| Objets métier | `INV-01` Article, `INV-02` Entrepôt, `INV-03` Emplacement, `INV-04` LotDeStock, `INV-05` MouvementDeStock, `INV-06` RéceptionDeStock, `INV-07` RéservationDeStock, `INV-08` ConsommationMatière, `INV-09` BonDeSortie, `INV-10` InventairePhysique. |
| Acteurs | Magasinier, responsable magasin, acheteur, chef de chantier, responsable atelier, qualité, logistique, contrôleur de gestion. |

**Règles métier portées par le domaine.**

| Règle | Statut |
| --- | --- |
| Le stock central est la source de vérité des quantités disponibles. | Proposition, cohérent avec V-06 (référentiel de stock centralisé) |
| Tout mouvement possède un motif, une date, un acteur, une référence et une trace. | Proposition |
| Un stock négatif est interdit, sauf dérogation explicite et tracée. | Proposition |
| Une réception physique est enregistrée avant la mise à disposition ; un contrôle qualité peut bloquer la mise en stock. | Proposition |
| Une réservation est rattachée à une affaire ou à un ordre de fabrication ; la consommation la réduit. | Proposition |
| Une sortie vers chantier ou atelier s'appuie sur un bon de préparation et de sortie ; le transport est organisé par Logistics. | Proposition |
| Un inventaire physique périodique analyse et valide les écarts. | Proposition |
| La valorisation des quantités est fournie à Costing ; Inventory ne décide pas de la méthode comptable. | Proposition, Q-20 |
| Le stock de chantier est un emplacement temporaire sous contrôle d'Inventory, et non un stock autonome. | Proposition, Q-19 |
| La traçabilité lot/numéro de série est obligatoire pour les articles critiques. | Proposition |

**États et transitions.**

| Objet | États | Transitions principales |
| --- | --- | --- |
| LotDeStock (disponibilité) | Disponible, réservé, bloqué, quarantaine | Réserver, libérer, bloquer, mettre en quarantaine. |
| RéceptionDeStock | Attendue, partielle, complète, avec écart | Réceptionner, constater un écart, clôturer. |
| MouvementDeStock | Brouillon, validé, annulé | Valider, annuler avec trace. |
| RéservationDeStock | Active, consommée, libérée | Consommer, libérer. |
| InventairePhysique | Planifié, en cours, validé | Démarrer, compter, valider les écarts. |

**Entrées et sorties.**

| Sens | Domaine | Informations | Moment |
| --- | --- | --- | --- |
| Entrée | Procurement | Commandes, quantités attendues, fournisseur, échéancier | Réception |
| Entrée | Workshop / Projects | Besoins, réservations, consommations, retours | Production et chantier |
| Entrée | Quality | Acceptation, refus, mise en quarantaine | Réception et contrôle |
| Entrée | Logistics | Expédition, livraison, retour, écart | Transport |
| Entrée | Costing | Axe analytique et valorisation attendue | Mouvement |
| Entrée | Equipment | Besoins de pièces détachées | Maintenance |
| Sortie | Workshop | Disponibilité, réservation, sortie matière | Production |
| Sortie | Projects | Disponibilité et sortie pour chantier | Exécution |
| Sortie | Procurement | Besoins de réapprovisionnement, pénuries, écarts de réception | Réapprovisionnement |
| Sortie | Logistics | Colis, poids, dimensions, bon de sortie | Expédition |
| Sortie | Costing | Quantités consommées et valorisation | Coût |
| Sortie | Reporting | Stock, rotation, écarts, pénuries | Pilotage |

**Limites et chevauchements.** Inventory porte le stock et les mouvements ; Procurement porte la commande et le fournisseur ; Logistics porte le transport et la réception sur site ; Quality porte l'acceptation ; Costing valorise. Voir BD-05, BD-06, BD-12 et BD-21.

**Questions ouvertes.** Q-17, Q-18, Q-19, Q-20, Q-21, Q-43 (matériaux fournis par le client).

---

### D12 — Equipment

**Mission.** Gérer le parc d'équipements, machines et véhicules, leur disponibilité, leur maintenance et leur conformité d'utilisation.

| Rubrique | Contenu |
| --- | --- |
| Périmètre inclus | Équipements, catégories, affectations, maintenance préventive et curative, inspections, certificats, compteurs, pannes, location, disponibilité. |
| Périmètre exclu | Transport et tournées (Logistics), achats et contrats fournisseurs (Procurement), pièces détachées et stock (Inventory), sécurité opérationnelle (Safety), planning global (Planning), coûts (Costing), conduite des véhicules (Workforce). |
| Objets métier | `EQP-01` Équipement, `EQP-02` CatégorieÉquipement, `EQP-03` AffectationÉquipement, `EQP-04` PlanDeMaintenance, `EQP-05` InterventionDeMaintenance, `EQP-06` InspectionRéglementaire, `EQP-07` Panne. |
| Acteurs | Responsable matériel, responsable atelier, chef de chantier, logisticien, chauffeur, technicien de maintenance, préventeur sécurité. |

**Règles métier portées par le domaine.**

| Règle | Statut |
| --- | --- |
| Un équipement possède un identifiant unique et un historique complet d'affectation, de maintenance et d'incident. | Proposition |
| La disponibilité résulte de l'état, de la maintenance, des inspections et des affectations. | Proposition |
| Une maintenance préventive est planifiée ; une maintenance curative est tracée. | Proposition |
| Une inspection ou un certificat obligatoire conditionne l'utilisation ; un équipement non conforme est bloqué. | Proposition |
| Une affectation précise le chantier, l'atelier ou la location, la période et le responsable. | Proposition |
| Une panne déclenche une indisponibilité, une information à Planning et un coût pour Costing. | Proposition |
| La location externe relève de Procurement ; Equipment suit la disponibilité et l'état. | Proposition |
| La calibration des équipements de mesure est arbitrée avec Quality. | Question ouverte Q-25 |

**États et transitions.**

| Objet | États | Transitions principales |
| --- | --- | --- |
| Équipement | Disponible, affecté, en maintenance, immobilisé, réformé | Affecter, libérer, mettre en maintenance, immobiliser, réformer. |
| InterventionDeMaintenance | Planifiée, en cours, terminée, annulée | Démarrer, terminer, annuler. |
| InspectionRéglementaire | Valide, expirée, suspendue | Réaliser, renouveler, suspendre. |
| Panne | Déclarée, en cours de réparation, réparée, irréparable | Déclarer, réparer, clôturer. |

**Entrées et sorties.**

| Sens | Domaine | Informations | Moment |
| --- | --- | --- | --- |
| Entrée | Planning | Besoins et affectations prévisionnelles | Planification |
| Entrée | Projects | Sites et contraintes d'utilisation | Affectation |
| Entrée | Logistics | Besoins de véhicules et de moyens de levage | Transport |
| Entrée | Procurement | Achats, locations, contrats de maintenance | Acquisition |
| Entrée | Inventory | Pièces détachées et consommables | Maintenance |
| Entrée | Safety / Quality | Exigences d'inspection et de calibration | Conformité |
| Sortie | Planning | Disponibilité, maintenance, inspections | Planification |
| Sortie | Logistics | Véhicules et moyens disponibles | Transport |
| Sortie | Safety / Quality | Statut des inspections et certificats | Conformité |
| Sortie | Costing | Utilisation, maintenance, pannes, location | Coût |
| Sortie | Reporting | Disponibilité, taux d'utilisation, coûts | Pilotage |

**Limites et chevauchements.** Equipment porte l'actif ; Logistics organise le transport ; Procurement achète ou loue ; Safety et Quality portent les exigences de conformité ; Planning affecte. Voir BD-13, BD-14 et Q-25, Q-26.

**Questions ouvertes.** Q-25 (calibration des équipements de mesure), Q-26 (chauffeurs et affectation des véhicules).

---

### D13 — Logistics

**Mission.** Organiser et exécuter les flux physiques entre atelier, stock central, fournisseurs et chantiers, y compris le transport, la réception physique sur site et les retours.

| Rubrique | Contenu |
| --- | --- |
| Périmètre inclus | Demandes et plans de transport, tournées, transporteurs, expéditions et colis, livraisons, preuves de livraison, réceptions physiques sur site, retours, accès chantier, incidents de transport, coûts transport. |
| Périmètre exclu | Stock et mouvements (Inventory), achats et contrats fournisseurs (Procurement), production (Workshop), équipements (Equipment), réception contractuelle (Handover), qualité (Quality), planning global (Planning), exécution des travaux (Projects). |
| Objets métier | `LOG-01` DemandeDeTransport, `LOG-02` PlanDeTransport, `LOG-03` Tournée, `LOG-04` Livraison, `LOG-05` RéceptionChantier, `LOG-06` Retour, `LOG-07` AccèsChantier. |
| Acteurs | Logisticien, magasinier, chef de chantier, conducteur de travaux, transporteur, chauffeur, qualité, sécurité. |

**Règles métier portées par le domaine.**

| Règle | Statut |
| --- | --- |
| Une demande de transport est liée à une expédition, un OF ou une commande, et à un chantier ou un atelier. | Proposition |
| Le plan de transport est validé selon la date, le volume, les accès, les moyens et la qualification du transporteur. | Proposition |
| Le départ s'appuie sur un bon de sortie Inventory ; la réception sur site produit une preuve et un contrôle. | Proposition |
| Tout écart, avarie ou manque est déclaré et tracé, avec impact sur Inventory, Quality et Procurement. | Proposition |
| Les retours de matériel, d'emballage ou d'équipement sont tracés jusqu'à leur réception. | Proposition |
| L'accès au chantier et les règles de sécurité sont vérifiés avant le transport. | Proposition |
| Le coût de transport est imputé à l'affaire, au lot et à la nature de coût. | Proposition |
| Le transporteur est un fournisseur référencé par Procurement ; Logistics gère l'opération de transport. | Proposition |

**États et transitions.**

| Objet | États | Transitions principales |
| --- | --- | --- |
| DemandeDeTransport | Brouillon, validée, planifiée, annulée | Valider, planifier, annuler. |
| Tournée | Planifiée, en cours, terminée, annulée | Démarrer, terminer, annuler. |
| Livraison | Prévue, en transit, livrée, partielle, échouée | Expédier, livrer, constater un écart. |
| RéceptionChantier | Acceptée, avec réserve, refusée | Accepter, réserver, refuser. |
| Retour | Demandé, en transit, reçu, refusé | Expédier, réceptionner, refuser. |

**Entrées et sorties.**

| Sens | Domaine | Informations | Moment |
| --- | --- | --- | --- |
| Entrée | Inventory | Colis, poids, dimensions, bon de sortie, date | Expédition |
| Entrée | Workshop | Colis de fabrication, disponibilité, contraintes | Expédition |
| Entrée | Procurement | Commandes, fournisseurs, enlèvements, livraisons | Approvisionnement |
| Entrée | Projects | Accès chantier, contraintes, dates, destinataires | Livraison |
| Entrée | Planning | Besoins datés, priorités | Planification |
| Entrée | Equipment | Véhicules et moyens de levage disponibles | Transport |
| Entrée | Safety | Règles d'accès et de sécurité | Transport |
| Sortie | Inventory | Confirmation de livraison, retour, écart | Livraison |
| Sortie | Projects | Statut de livraison et réception sur site | Exécution |
| Sortie | Workshop | Statut d'enlèvement, livraison, retour | Expédition |
| Sortie | Procurement | Incidents et performance transporteur | Suivi fournisseur |
| Sortie | Quality | Réserves ou avaries constatées | Contrôle |
| Sortie | Costing | Coûts de transport | Coût |
| Sortie | Reporting | Délais, coûts, incidents | Pilotage |

**Limites et chevauchements.** Logistics organise le transport ; Inventory porte le stock et le bon de sortie ; Projects porte le chantier et l'exécution ; Equipment porte les véhicules ; Procurement porte le transporteur. Voir BD-12 et BD-14.

**Questions ouvertes.** Q-19, Q-21, Q-26.

---

### D14 — Quality

**Mission.** Garantir la conformité technique des ouvrages, fabrications et prestations aux exigences contractuelles, normatives et internes, et traiter les non-conformités.

| Rubrique | Contenu |
| --- | --- |
| Périmètre inclus | Plans qualité et de contrôle, points de contrôle, inspections, essais, mesures, non-conformités, actions correctives et préventives, audits, certificats, qualifications techniques, dossiers de conformité. |
| Périmètre exclu | Réception contractuelle, réserves, DOE et garanties (Handover), production (Workshop), achats (Procurement), sécurité (Safety), stockage documentaire (Documents), coûts (Costing). |
| Objets métier | `QUA-01` PlanQualité, `QUA-02` PlanDeContrôle, `QUA-03` ContrôleQualité, `QUA-04` NonConformité, `QUA-05` ActionCorrective, `QUA-06` AuditQualité, `QUA-07` CertificatQualité, `QUA-08` QualificationTechnique. |
| Acteurs | Responsable qualité, contrôleur qualité, chef de chantier, responsable atelier, soudeur, sous-traitant, client, organisme de contrôle. |

**Règles métier portées par le domaine.**

| Règle | Statut |
| --- | --- |
| Un plan qualité et un plan de contrôle sont définis avant l'exécution des travaux critiques. | Proposition |
| Chaque point de contrôle précise le critère, la méthode, la fréquence, le responsable et la preuve attendue. | Proposition |
| L'autocontrôle appartient à l'exécutant ; le contrôle Quality vérifie selon le plan. | Proposition |
| Une non-conformité suit un cycle containment, analyse de cause, action, vérification d'efficacité et clôture. | Proposition |
| Une non-conformité bloquante peut arrêter ou refuser une partie des travaux. | Proposition |
| Les certificats et qualifications techniques ont une validité et conditionnent les opérations critiques. | Proposition |
| Les audits fournisseurs et sous-traitants sont menés avec Procurement. | Proposition |
| Les preuves de conformité alimentent Handover et le DOE ; les réserves contractuelles restent portées par Handover. | Proposition |
| Le coût de la non-qualité est fourni à Costing. | Proposition |

**États et transitions.**

| Objet | États | Transitions principales |
| --- | --- | --- |
| PlanQualité | Brouillon, validé, révisé | Valider, réviser. |
| ContrôleQualité | Planifié, réalisé, conforme, non conforme | Réaliser, prononcer la conformité ou la non-conformité. |
| NonConformité | Ouverte, en analyse, action en cours, clôturée | Analyser, traiter, vérifier, clôturer. |
| AuditQualité | Planifié, en cours, clôturé | Démarrer, clôturer. |
| CertificatQualité | Valide, expiré | Renouveler, expirer. |

**Entrées et sorties.**

| Sens | Domaine | Informations | Moment |
| --- | --- | --- | --- |
| Entrée | Projects | Périmètre, spécifications, exigences contractuelles, jalons | Préparation et exécution |
| Entrée | Workshop | Autocontrôles, production, rebuts, demandes de contrôle | Production |
| Entrée | Procurement | Fournisseurs, sous-traitants, commandes, performance | Sélection et suivi |
| Entrée | Documents | Normes, procédures, plans contrôlés | Exécution |
| Entrée | Workforce | Formations et qualifications RH disponibles (preuves) | Affectation |
| Entrée | Equipment | Calibration et état des équipements de mesure | Contrôle |
| Entrée | Handover | Réserves nécessitant un traitement technique | Réception |
| Sortie | Projects | Conformité, NCR, blocages, certificats | Exécution |
| Sortie | Workshop | Résultats de contrôle, NCR, reprises, certificats et qualifications | Production |
| Sortie | Procurement | Performance qualité fournisseur/sous-traitant | Suivi |
| Sortie | Inventory | Acceptation, refus, mise en quarantaine | Réception |
| Sortie | Handover | Preuves de conformité, NCR clôturées | Réception |
| Sortie | Documents | Rapports, certificats, dossiers de conformité | Exécution |
| Sortie | Costing | Coûts de non-qualité | Traitement |
| Sortie | Reporting | Taux de conformité, NCR, audits | Pilotage |

**Limites et chevauchements.** Quality porte la conformité technique ; Handover porte la réception contractuelle et les réserves ; Workshop exécute et s'autocontrôle ; Procurement porte la relation fournisseur. Voir BD-07 et BD-19.

**Questions ouvertes.** Q-16, Q-23, Q-25, Q-30.

---

### D15 — Safety

**Mission.** Prévenir les risques professionnels et garantir la sécurité des intervenants sur les chantiers et en atelier.

| Rubrique | Contenu |
| --- | --- |
| Périmètre inclus | Analyses de risques, plans de prévention, inspections, constats, incidents et accidents, presqu'accidents, actions sécurité, habilitations et autorisations, EPI, inductions, plan d'urgence, conformité des sous-traitants. |
| Périmètre exclu | Données RH et contrats (Workforce), qualité technique (Quality), maintenance des équipements (Equipment), transport (Logistics), réception (Handover), assurances et contentieux (hors périmètre), données médicales individuelles (confidentialité). |
| Objets métier | `SAF-01` AnalyseDeRisques, `SAF-02` PlanDePrévention, `SAF-03` InspectionSécurité, `SAF-04` Incident, `SAF-05` ActionSécurité, `SAF-06` HabilitationSécurité, `SAF-07` AutorisationDeTravail, `SAF-08` InductionSécurité. |
| Acteurs | Responsable sécurité, préventeur, chef de chantier, responsable atelier, collaborateur, sous-traitant, médecin du travail (lien externe), client. |

**Règles métier portées par le domaine.**

| Règle | Statut |
| --- | --- |
| Une analyse de risques précède l'intervention ; un plan de prévention est établi en cas de co-activité ou de sous-traitance. | Proposition |
| Une induction et une autorisation d'accès sont requises avant l'intervention sur un site. | Proposition |
| Une habilitation de sécurité valide conditionne l'affectation à certaines tâches. | Proposition |
| Une inspection produit un constat et, si nécessaire, une action avec responsable et échéance. | Proposition |
| Tout incident est déclaré, analysé et suivi d'actions ; un accident grave déclenche un arrêt et une enquête. | Proposition |
| Les sous-traitants doivent fournir leurs documents de sécurité et respecter les exigences du site ; Procurement porte l'exigence contractuelle. | Proposition |
| Les EPI sont fournis, contrôlés et tracés ; leur gestion opérationnelle reste à préciser. | Question ouverte Q-29 |
| Safety ne porte pas la discipline RH, les soins médicaux ni les déclarations d'assurance. | Proposition |

**États et transitions.**

| Objet | États | Transitions principales |
| --- | --- | --- |
| AnalyseDeRisques | Brouillon, validée, révisée | Valider, réviser. |
| InspectionSécurité | Planifiée, réalisée, clôturée | Réaliser, clôturer. |
| Incident | Déclaré, en enquête, clôturé | Enquêter, clôturer. |
| ActionSécurité | Ouverte, en cours, clôturée | Traiter, vérifier, clôturer. |
| HabilitationSécurité | Valide, expirée, suspendue | Délivrer, renouveler, suspendre. |
| AutorisationDeTravail | Demandée, accordée, refusée, expirée | Accorder, refuser, expirer. |

**Entrées et sorties.**

| Sens | Domaine | Informations | Moment |
| --- | --- | --- | --- |
| Entrée | Projects | Sites, activités, planning, sous-traitants | Préparation et exécution |
| Entrée | Workshop | Opérations, risques atelier, personnel | Préparation et exécution |
| Entrée | Workforce | Collaborateurs, formations, qualifications | Affectation |
| Entrée | Equipment | Inspections, certificats, état des équipements | Utilisation |
| Entrée | Procurement | Sous-traitants, contrats, exigences de conformité | Sélection |
| Entrée | Logistics | Transports, accès, risques de manutention | Livraison |
| Sortie | Projects | Plan de prévention, consignes, incidents, blocages | Exécution |
| Sortie | Workshop | Consignes, inspections, autorisations | Exécution |
| Sortie | Planning | Autorisations et restrictions d'affectation | Planification |
| Sortie | Workforce | Exigences de formation, incidents, restrictions | RH |
| Sortie | Procurement | Conformité sécurité des sous-traitants | Suivi |
| Sortie | Documents | Analyses, inspections, incidents, actions | Traçabilité |
| Sortie | Costing | Coûts de prévention et d'incidents | Coût |
| Sortie | Reporting | Taux de fréquence, gravité, conformité | Pilotage |

**Limites et chevauchements.** Safety porte la prévention et les autorisations opérationnelles ; Workforce porte les contrats et formations ; Quality porte la conformité technique ; Equipment porte les inspections d'actifs. Voir BD-15 et Q-29.

**Questions ouvertes.** Q-15, Q-29, Q-40.

---

### D16 — Documents

**Mission.** Gérer le cycle de vie documentaire des documents produits ou reçus, sans se substituer à la responsabilité métier sur leur contenu.

| Rubrique | Contenu |
| --- | --- |
| Périmètre inclus | Documents, versions, dossiers, types, métadonnées, diffusion, accusés de réception, règles de conservation, archives, modèles, liens aux objets métier, droits d'accès. |
| Périmètre exclu | Contenu et validation métier (domaines propriétaires), propriété des contrats (Projects), des données RH (Workforce), de la réception contractuelle (Handover), de la conformité technique (Quality), décisions métier. |
| Objets métier | `DOC-01` Document, `DOC-02` VersionDocument, `DOC-03` DossierDocumentaire, `DOC-04` TypeDocument, `DOC-05` DiffusionDocument, `DOC-06` RègleDeConservation. |
| Acteurs | Gestionnaire documentaire, chargé d'affaires, bureau d'études, qualité, sécurité, RH, direction, client, sous-traitant. |

**Règles métier portées par le domaine.**

| Règle | Statut |
| --- | --- |
| Chaque document possède un propriétaire métier, un type, un statut, des métadonnées et un lien vers l'objet métier concerné. | Proposition |
| Une version publiée est immuable ; une nouvelle version crée une nouvelle entrée et conserve l'historique. | Proposition |
| La validation du fond appartient au domaine propriétaire ; Documents ne prononce pas la conformité métier. | Proposition |
| La diffusion est contrôlée et, si nécessaire, accusée réception. | Proposition |
| Les droits d'accès respectent Identity et les restrictions de confidentialité. | Validé par `AGENTS.md` |
| Les règles de conservation et d'archivage sont définies avec le métier et le juridique. | Question ouverte Q-33, Q-40 |
| Un document lié à un objet métier référence cet objet sans dupliquer ses données métier. | Proposition |
| Un document obsolète est remplacé ou archivé, jamais supprimé sans procédure. | Proposition |
| Un modèle documentaire n'est pas un document contractuel signé. | Proposition |

**États et transitions.**

| Objet | États | Transitions principales |
| --- | --- | --- |
| Document | Brouillon, en revue, approuvé, publié, remplacé, archivé | Soumettre, approuver, publier, remplacer, archiver. |
| VersionDocument | Courante, historique | Publier une nouvelle version, archiver l'ancienne. |
| DiffusionDocument | En attente, accusée, échouée | Diffuser, accuser réception, relancer. |
| Document (archivage) | Actif, restauré | Archiver, restaurer avec autorisation. |

**Entrées et sorties.**

| Sens | Domaine | Informations | Moment |
| --- | --- | --- | --- |
| Entrée | Tous les domaines | Document, métadonnées, propriétaire, classification | Production ou réception |
| Entrée | Identity | Droits et périmètres d'accès | Publication |
| Entrée | Clients | Documents reçus du client | Réception |
| Entrée | Handover | DOE, PV, garanties | Réception et clôture |
| Entrée | Quality / Safety | Preuves, certificats, rapports | Exécution |
| Sortie | Tous les domaines | Référence, version, statut, lien, diffusion | Consultation |
| Sortie | Handover | Complétude et versions des pièces du DOE | Réception |
| Sortie | Reporting | Volume, diffusion, archivage | Pilotage |

**Limites et chevauchements.** Documents porte le contenant et le cycle de vie documentaire ; chaque domaine porte le contenu, la validité métier et la décision. Handover porte la constitution contractuelle du DOE ; Quality porte la preuve de conformité. Voir BD-08, BD-07 et Q-31, Q-32.

**Questions ouvertes.** Q-31 (DOE), Q-32 (statut documentaire et validation métier), Q-33 (signature et archivage légal), Q-40 (confidentialité et conservation).

---

### D17 — Handover

**Mission.** Organiser la réception contractuelle des travaux, gérer les réserves, constituer le DOE et prononcer la clôture contractuelle des travaux.

| Rubrique | Contenu |
| --- | --- |
| Périmètre inclus | Réceptions partielles et finales, réserves, levées de réserves, procès-verbaux, DOE, garanties clientes, périodes de garantie, dossier de clôture, attestations. |
| Périmètre exclu | Conformité technique (Quality), exécution des travaux (Projects), budget et coûts (Budgets/Costing), stock (Inventory), stockage documentaire (Documents), propriété des garanties fournisseurs (Procurement), contentieux (hors périmètre). |
| Objets métier | `HND-01` Réception, `HND-02` Réserve, `HND-03` LevéeDeRéserve, `HND-04` DOE, `HND-05` GarantieClient, `HND-06` DossierDeClôture. |
| Acteurs | Responsable réception/handover, chargé d'affaires, chef de chantier, qualité, client, maître d'ouvrage, maître d'œuvre, gestionnaire documentaire. |

**Règles métier portées par le domaine.**

| Règle | Statut |
| --- | --- |
| Une réception est demandée après achèvement, autocontrôle et disponibilité des preuves qualité. | Proposition |
| Une réception partielle est possible par lot, zone ou phase. | Proposition |
| Une réserve est un écart contractuel décrit, localisé, daté, avec un responsable et un délai. | Proposition |
| La levée d'une réserve est vérifiée avec preuve ; elle peut être refusée. | Proposition |
| Le DOE doit être complet avant la clôture contractuelle ; les fichiers sont gérés par Documents. | Proposition |
| Le procès-verbal signé constitue le fait contractuel de réception et fixe les dates de garantie. | Proposition |
| La clôture contractuelle intervient après levée des réserves, DOE complet et garanties constituées. | Proposition |
| Les garanties clientes et les garanties fournisseurs/sous-traitants sont distinguées ; ces dernières relèvent de Procurement. | Proposition |
| Une réserve n'est pas une non-conformité : elle peut référencer une NCR Quality, sans fusionner les deux objets. | Proposition, Q-30 |

**États et transitions.**

| Objet | États | Transitions principales |
| --- | --- | --- |
| Réception | Demandée, planifiée, prononcée, avec réserves, acceptée, refusée | Planifier, prononcer, accepter, refuser. |
| Réserve | Ouverte, levée demandée, levée, refusée | Demander la levée, vérifier, lever ou refuser. |
| DOE | Incomplet, complet, validé | Compléter, valider. |
| GarantieClient | Active, expirée | Activer, expirer. |
| DossierDeClôture | En préparation, clos | Compléter, clore. |

**Entrées et sorties.**

| Sens | Domaine | Informations | Moment |
| --- | --- | --- | --- |
| Entrée | Projects | Demande de réception, périmètre, lots, client, dates | Achèvement |
| Entrée | Quality | Preuves de conformité, NCR clôturées, certificats | Réception |
| Entrée | Documents | Pièces du DOE, versions, complétude | Réception |
| Entrée | Clients | Représentants, coordonnées, exigences de réception | Réception |
| Entrée | Procurement | Garanties fournisseurs et sous-traitants | Clôture |
| Entrée | Costing | Situation finale des coûts | Clôture |
| Sortie | Projects | Statut de réception, réserves, levées, PV | Réception et clôture |
| Sortie | Quality | Réserves à traiter techniquement | Réception |
| Sortie | Documents | Pièces à compiler, diffuser, archiver | Réception |
| Sortie | Clients | PV, DOE, garanties clientes, attestations | Réception |
| Sortie | Costing | Dates de réception et de garantie | Clôture |
| Sortie | Reporting | Délais de réception, réserves, garanties | Pilotage |

**Limites et chevauchements.** Handover porte la réception contractuelle et les réserves ; Quality porte la conformité technique et les NCR ; Projects porte l'exécution et la clôture de l'affaire ; Documents stocke le DOE. Voir BD-07, BD-08 et BD-17.

**Questions ouvertes.** Q-30 (réserve vs NCR), Q-31 (DOE), Q-44 (garanties), Q-53 (conditions de clôture).

---

### D18 — Reporting

**Mission.** Produire des indicateurs, tableaux de bord et rapports consolidés à partir des données des domaines, sans devenir une source de vérité métier.

| Rubrique | Contenu |
| --- | --- |
| Périmètre inclus | Définitions d'indicateurs, rapports, tableaux de bord, snapshots, exports, seuils et alertes, abonnements, traçabilité de la donnée. |
| Périmètre exclu | Données source, règles métier, décisions, opérations, correction de données, écritures dans les domaines. |
| Objets métier | `RPT-01` Rapport, `RPT-02` TableauDeBord, `RPT-03` Indicateur, `RPT-04` Snapshot, `RPT-05` Export. |
| Acteurs | Direction générale, contrôle de gestion, chargé d'affaires, RH, qualité, sécurité, chef de chantier, auditeur. |

**Règles métier portées par le domaine.**

| Règle | Statut |
| --- | --- |
| Chaque indicateur possède une définition, une formule, une source, une période et un propriétaire métier. | Proposition |
| Reporting lit les données via les contrats ou événements des domaines ; il n'accède pas directement à leurs tables. | Validé par la politique de dépendance |
| Reporting n'écrit jamais dans les domaines et ne corrige pas une donnée source. | Proposition |
| Un snapshot est daté et distingue une valeur figée d'une valeur temps réel. | Proposition |
| Les droits d'accès aux rapports respectent Identity et la confidentialité des données RH, sécurité et financières. | Validé par `AGENTS.md` |
| La fraîcheur et la lignée de chaque indicateur sont documentées. | Proposition |
| En cas d'écart entre un rapport et sa source, la source fait foi. | Proposition |
| Aucun indicateur n'est créé sans propriétaire métier et sans consommateur identifié. | Proposition |

**États et transitions.**

| Objet | États | Transitions principales |
| --- | --- | --- |
| Indicateur | Brouillon, validé, déprécié | Valider, déprécier. |
| Rapport | Généré, publié, archivé | Publier, archiver. |
| Snapshot | Disponible, expiré | Régénérer, archiver. |

**Entrées et sorties.**

| Sens | Domaine | Informations | Moment |
| --- | --- | --- | --- |
| Entrée | Tous les domaines | Données, événements, indicateurs source | Génération |
| Entrée | Identity | Périmètre et droits d'accès | Consultation |
| Sortie | Direction et domaines | Rapports, tableaux de bord, alertes, exports | Pilotage |
| Sortie | Documents | Rapports archivés ou diffusés | Publication |

**Limites et chevauchements.** Reporting est un consommateur transversal en lecture seule. Il ne possède pas les données métier et ne doit pas devenir un modèle d'écriture parallèle. Voir BD-20 et Q-34.

**Questions ouvertes.** Q-34, Q-40.

## 6. Synthèse des responsabilités

### 6.1 Ce que chaque domaine possède

| Domaine | Possède | Ne possède pas |
| --- | --- | --- |
| Identity | Comptes, rôles, permissions, périmètres, délégations | Données RH, contacts clients, fournisseurs |
| Clients | Prospects, clients, contacts, rôles de tiers, relation commerciale | Étude, devis, affaire, chantier, fournisseurs |
| Projects | Étude, devis, commande, contrat, affaire, chantier, lots, avenants, jalons | Planning détaillé, budget, coûts, fabrication, achats, qualité, sécurité, réception |
| Planning | Plans, activités, affectations, capacité, conflits, avancement planning | Données RH, actifs, capacité atelier, pointages |
| Budgets | Budget, versions, lignes, enveloppe, contingence, révisions | Chiffrage détaillé, engagements, coûts constatés, prix de vente |
| Costing | Chiffrage, coûts, engagements, imputations, marge, écarts, EAC | Budget, commandes, temps, stock, production, paie |
| Workforce | Collaborateurs, contrats, postes, qualifications, équipes, variables de paie | Pointages, planning, calcul de paie, sécurité opérationnelle |
| TimeTracking | Pointages, feuilles de temps, imputations, périodes, corrections, absences constatées | Contrats, planning, calcul de paie, coûts |
| Workshop | OF, dossiers, gammes, opérations, postes, production, colis, capacité | Stock, achats, planning global, qualité normative, transport |
| Procurement | Fournisseurs, sous-traitants, demandes, offres, commandes, engagements, performance | Stock, réception, transport, qualité technique, paiement |
| Inventory | Articles, entrepôts, emplacements, lots, mouvements, réceptions, réservations, sorties, inventaires | Achats, transport, acceptation qualité, production |
| Equipment | Équipements, affectations, maintenance, inspections, certificats, pannes | Transport, achats, stock, sécurité, planning |
| Logistics | Demandes et plans de transport, tournées, livraisons, réceptions site, retours, accès | Stock, achats, production, réception contractuelle |
| Quality | Plans qualité, contrôles, essais, NCR, actions, audits, certificats, qualifications techniques | Réception contractuelle, réserves, DOE, production, sécurité |
| Safety | Analyses de risques, plans de prévention, inspections, incidents, actions, habilitations, autorisations | RH, qualité technique, maintenance, assurances |
| Documents | Documents, versions, dossiers, métadonnées, diffusion, conservation, archives | Contenu métier, validation de fond, décisions |
| Handover | Réceptions, réserves, levées, PV, DOE, garanties, clôture contractuelle | Conformité technique, exécution, budget, coûts |
| Reporting | Définitions d'indicateurs, rapports, tableaux de bord, snapshots, exports | Données source, règles métier, écritures |

### 6.2 Règles de propriété à retenir

1. Un domaine ne modifie jamais directement un objet d'un autre domaine.
2. Un domaine peut consommer une information nécessaire à sa responsabilité, via un contrat public ou un événement.
3. Un domaine qui a besoin d'une décision d'un autre domaine ne la reproduit pas localement.
4. Un domaine qui fournit une information reste responsable de sa validité et de ses invariants.
5. Une information dupliquée pour le confort d'affichage doit rester identifiée comme une copie et ne devient jamais la source de vérité.

## 7. Références

- [`business-processes.md`](business-processes.md) — cartographie des 12 processus métier.
- [`business-objects.md`](business-objects.md) — catalogue des objets métier et de leurs propriétaires.
- [`domain-interactions-register.md`](domain-interactions-register.md) — registre des interactions métier.
- [`domain-boundary-decisions.md`](domain-boundary-decisions.md) — chevauchements, arbitrages proposés et questions ouvertes.
- [`domain-conventions.md`](domain-conventions.md) — conventions internes CHAN-27.
- [`domain-communication.md`](domain-communication.md) — contrats synchrones CHAN-28.
- [`app/Domains/README.md`](../../app/Domains/README.md) — organisation des domaines.
- [`app/Core/README.md`](../../app/Core/README.md) — périmètre du noyau technique.
