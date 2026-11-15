# Chevauchements, arbitrages et décisions de frontières

Ce document analyse les chevauchements de responsabilité entre les 18 domaines de **C2ME Chantier**, propose des arbitrages et recense les décisions restant à valider.

- Ticket : CHAN-29 — Documenter les frontières et dépendances autorisées.
- Lot : Lot 1 — Inventaire et cartographie des responsabilités métier.
- Portée : chevauchements métier, séparations recommandées, informations échangées, décisions proposées et questions ouvertes.
- Hors portée : matrice technique définitive des dépendances (Lot 2), contrats et événements (CHAN-28), conventions internes de code (CHAN-27), tests d'architecture (CHAN-31).

> **Statut du document — Lot 1.**
> Les arbitrages présentés sont des **propositions**. Seules les décisions listées en section 2 sont validées. Les questions ouvertes ne sont pas tranchées artificiellement : elles doivent être arbitrées par le responsable du projet avant de figer la matrice du Lot 2.

## 1. Méthode

### 1.1 Démarche

Pour chaque chevauchement, le document examine :

1. les responsabilités candidates de chaque domaine ;
2. la séparation recommandée, avec le critère de décision ;
3. les informations échangées ;
4. les points nécessitant une validation métier ;
5. le statut de l'arbitrage.

### 1.2 Niveaux de décision

| Niveau | Signification |
| --- | --- |
| **Validé** | Décision explicitement fournie par le responsable du projet ou déjà actée dans la documentation d'architecture. |
| **Proposition** | Arbitrage recommandé dans ce lot, cohérent avec les décisions validées, mais non encore validé. |
| **Question ouverte** | Point non tranché, documenté avec les options et l'impact. |

### 1.3 Identifiants

| Élément | Convention | Exemple |
| --- | --- | --- |
| Chevauchement | `BD-xx` | `BD-03` |
| Décision proposée | `PD-xx` | `PD-03` |
| Décision validée | `V-xx` | `V-06` |
| Question ouverte | `Q-xx` | `Q-09` |
| Domaine | `D01` à `D18` | `D06` Costing |
| Objet | Préfixe du domaine + numéro | `CST-03` Engagement |

## 2. Décisions validées

Les décisions suivantes sont validées. Elles ne sont pas rouvertes par ce document.

| ID | Décision | Source |
| --- | --- | --- |
| V-01 | Les 18 domaines sont figés : aucune fusion, suppression, scission ou création de domaine. | Ticket CHAN-29 |
| V-02 | Le périmètre couvre toutes les activités de C2ME : bureau d'études, charpente métallique, couverture, bardage, fabrication et assemblage, montage, serrurerie, menuiseries métalliques, maçonnerie, génie civil. | Ticket CHAN-29 |
| V-03 | Le logiciel couvre le parcours commercial complet et le parcours direct par commande ou ordre de service. | Ticket CHAN-29 |
| V-04 | Workshop est étudié en configuration atelier interne et fabrication externe, sans absorber Procurement ni Inventory. | Ticket CHAN-29 |
| V-05 | La sous-traitance est étudiée dans les deux sens : C2ME donneur d'ordre et C2ME sous-traitant. | Ticket CHAN-29 |
| V-06 | Le référentiel principal de stock est centralisé. | Ticket CHAN-29 |
| V-07 | La paie est externalisée : Workforce ne calcule pas les bulletins, ne produit pas les déclarations sociales et ne paie pas les salaires comme fonctionnalité interne obligatoire. | Ticket CHAN-29 |
| V-08 | TimeTracking reste responsable des événements de temps et des informations de pointage relevant de son périmètre. | Ticket CHAN-29 |
| V-09 | Les échanges inter-domaines passent par des contrats publics ou des événements ; aucun domaine n'accède directement aux composants internes d'un autre domaine. | Ticket CHAN-29 |
| V-10 | Les Models, Actions, Services, DTO internes, Policies et tables d'un domaine ne sont pas importables ou accessibles directement par un autre domaine. | `domain-communication.md`, CHAN-28 |
| V-11 | Un contrat public est créé uniquement pour un consommateur réel ; aucun contrat n'est anticipé. | `domain-communication.md`, CHAN-28 |
| V-12 | Aucune transaction partagée entre domaines n'est introduite sans décision explicite. | `domain-communication.md`, CHAN-28 |
| V-13 | Le Lot 1 est documentaire : aucun code, modèle, service, action, événement, migration, dépendance ou workflow CI/CD n'est modifié. | Ticket CHAN-29 |
| V-14 | La matrice technique détaillée des dépendances autorisées et interdites relève du Lot 2. | Ticket CHAN-29 |

## 3. Chevauchements obligatoires

### 3.1 BD-01 — Clients / Projects

**Question.** Où s'arrête la relation commerciale et où commence l'engagement contractuel ?

| Responsabilités candidates | Domaine | Analyse |
| --- | --- | --- |
| Rôles commerciaux (prospect, client, donneur d'ordre), contacts, relation commerciale, conditions cadre | D02 Clients | Ces éléments décrivent la relation durable et les rôles du tiers. |
| Étude, devis, commande, contrat, affaire, chantier, avenants, jalons | D03 Projects | Ces éléments décrivent l'engagement et son exécution. |
| Opportunité commerciale et pipeline | D02 ou D03 | La frontière dépend de l'organisation commerciale ; Q-03. |
| Négociation du prix et des conditions de l'affaire | D02 et D03 | Clients porte la relation ; Projects porte l'offre et le contrat. |

**Séparation recommandée.**

- **Clients** est propriétaire des rôles commerciaux (prospect, client, donneur d'ordre), des contacts, de la relation commerciale et des conditions cadre, sous réserve de Q-05. Il ne présume pas l'identité juridique du tiers.
- **Projects** est propriétaire de l'étude, du devis, de la commande ou de l'ordre de service, du contrat, de l'affaire, du chantier, des lots, des avenants et des jalons contractuels.
- Clients ne porte pas le devis ni l'affaire. Projects ne duplique pas la fiche client ; il référence le client et les rôles exposés par Clients.
- Un prospect peut être étudié avant d'être converti en client ; le moment exact de conversion reste à arbitrer dans Q-04 (proposition de travail : première commande ou premier contrat).
- La relation commerciale est mise à jour par les faits de Projects (ouverture, réception, clôture), sans que Projects modifie directement la fiche client.

**Informations échangées.**

| Sens | Informations | Moment |
| --- | --- | --- |
| Clients → Projects | Référence du tiers (selon Q-05), contacts, rôles, conditions cadre, statut | Étude, devis, ouverture |
| Projects → Clients | Affaire ouverte, commande, réception, clôture, incident relationnel | Cycle de vie |
| Clients → Projects | Prospect qualifié, besoin, échéance | Prospection |
| Projects → Clients | Devis, commande, affaire, statut | Négociation et exécution |

**Points à valider.** Q-02 (client, donneur d'ordre, maître d'ouvrage), Q-03 (opportunité), Q-04 (création du client), Q-05 (référentiel tiers), Q-06 (conditions financières et crédit).

**Statut.** Proposition.

---

### 3.2 BD-02 — Projects / Planning

**Question.** Qui est responsable de l'affaire et qui est responsable de l'organisation des interventions ?

| Responsabilités candidates | Domaine | Analyse |
| --- | --- | --- |
| Périmètre contractuel, jalons, priorités, engagement client | D03 Projects | Ces éléments engagent C2ME contractuellement. |
| Activités, dépendances, affectations, calendrier, conflits | D04 Planning | Ces éléments organisent les ressources dans le temps. |
| Avancement contractuel | D03 Projects | Il est déclaré par lot ou phase et engage la relation client. |
| Avancement des activités planifiées | D04 Planning | Il alimente la replanification et le suivi opérationnel. |

**Séparation recommandée.**

- **Projects** possède l'affaire, les lots, les jalons contractuels, les priorités et l'avancement contractuel.
- **Planning** possède les activités datées, les dépendances, les affectations, les calendriers de capacité, les conflits et l'avancement des activités.
- Planning ne décide pas d'un changement de périmètre ou d'un engagement client ; Projects ne décide pas seul d'une affectation de ressource.
- Les conflits de ressources entre affaires sont arbitrés par la direction, sur la base des informations de Planning et des priorités de Projects.
- Un changement de planning qui affecte un jalon contractuel est validé par Projects.

**Informations échangées.**

| Sens | Informations | Moment |
| --- | --- | --- |
| Projects → Planning | Périmètre, lots, jalons, priorités, contraintes de site | Préparation et replanification |
| Planning → Projects | Planning, dates prévisionnelles, avancement, conflits | Préparation et suivi |
| Projects → Planning | Avenants et changements de priorité | Révision |
| Planning → Projects | Impact des aléas sur les dates | Aléa |

**Points à valider.** Q-27 (avancement contractuel vs planning), Q-28 (horizon ferme, arbitrage des conflits), Q-01 (relation affaire/chantier).

**Statut.** Proposition.

---

### 3.3 BD-03 — Budgets / Costing

**Question.** Qui porte le prévisionnel, les engagements et les coûts constatés ?

| Objet ou responsabilité | Propriétaire recommandé | Consommateur | Règle |
| --- | --- | --- | --- |
| Budget, versions, lignes, enveloppe, contingence | D05 Budgets | Projects, Costing, Procurement | Enveloppe autorisée et révisée par Budgets. |
| Chiffrage prévisionnel d'une offre | D06 Costing | Projects, Budgets | Estimation de coût, base du prix et du budget. |
| Engagements financiers | D06 Costing (enregistrement et suivi) / D10 Procurement (acte commercial) | Budgets, Projects | Procurement crée la commande ; Costing enregistre et suit l'engagement financier. |
| Coûts constatés | D06 Costing | Projects, Budgets, Reporting | Costing valorise les faits opérationnels. |
| Coût final estimé (EAC) | D06 Costing | Projects, Budgets | Projection de coût, à valider Q-10. |
| Marge | D06 Costing | Projects, Budgets, Reporting | Prix de vente - coût. |
| Prix de vente | D03 Projects | Costing, Budgets | Prix contractuel, pas un coût. |
| Révision budgétaire | D05 Budgets | Projects, Costing | Décision de Budgets, avec validation direction. |

**Séparation recommandée.**

- **Budgets** porte l'enveloppe autorisée, les versions, les lignes, la contingence, les révisions et le contrôle du disponible. Il ne contient pas les coûts constatés.
- **Costing** porte le chiffrage, les engagements, les coûts constatés, les imputations, l'EAC, la marge et les écarts. Il ne fixe pas l'enveloppe et n'approuve pas les achats.
- **Procurement** porte l'acte commercial de la commande et la relation fournisseur. Costing enregistre et suit l'engagement financier.
- **Projects** porte le prix de vente et les montants contractuels. Il ne fixe ni le budget interne ni le coût.
- Une révision budgétaire est décidée par Budgets ; un engagement est créé par Procurement ; un coût est constaté par Costing. Aucun domaine ne fait le travail des deux autres.

**Informations échangées.**

| Sens | Informations | Moment |
| --- | --- | --- |
| Projects → Budgets | Périmètre, lots, montant, avenants, besoin | Ouverture et révision |
| Budgets → Costing | Enveloppe, lignes, seuils | Élaboration et suivi |
| Costing → Budgets | Engagements, coûts, EAC, écarts | Suivi |
| Procurement → Costing | Commandes, montants, variations | Engagement |
| Costing → Projects | Marge, EAC, alertes | Suivi |

**Points à valider.** Q-08 (seuils et autorité de révision), Q-09 (reconnaissance des engagements), Q-10 (propriété de l'EAC), Q-37 (unité monétaire, devise, arrondis).

**Statut.** Proposition.

---

### 3.4 BD-04 — Workforce / TimeTracking

**Question.** Qui porte les données RH et qui porte les événements de temps ?

| Responsabilités candidates | Domaine | Analyse |
| --- | --- | --- |
| Collaborateur, contrat, poste, qualification, équipe, disponibilité RH | D07 Workforce | Données de la relation de travail. |
| Pointage, feuille de temps, imputation, validation, verrouillage | D08 TimeTracking | Faits de temps et de présence. |
| Absence | D07 et D08 | Workforce qualifie le motif contractuel ; TimeTracking constate le temps non travaillé. |
| Éléments variables de paie | D07 Workforce | Workforce les prépare et les transmet ; le prestataire produit la paie. |
| Heures supplémentaires, trajets, astreintes | D08 TimeTracking | Événements de temps, avec règles à définir. |

**Séparation recommandée.**

- **Workforce** possède le collaborateur, le contrat, le poste, les qualifications, les formations, l'équipe, la disponibilité RH, le dossier RH et les éléments variables de paie.
- **TimeTracking** possède les pointages, feuilles de temps, imputations, périodes, validations, corrections, verrouillages et événements d'absence constatée.
- TimeTracking fournit les temps validés à Workforce pour les variables de paie et à Costing pour la valorisation. Workforce ne recalcule pas les temps.
- Workforce qualifie une absence (congé, maladie, absence autorisée) ; TimeTracking en constate la durée et l'impact planning. Q-12.
- Les règles de trajet, d'astreinte et d'heures supplémentaires restent à définir (Q-13).
- Le calcul du bulletin, les déclarations sociales et le paiement restent au prestataire externe (BD-09).

**Informations échangées.**

| Sens | Informations | Moment |
| --- | --- | --- |
| Workforce → TimeTracking | Collaborateur, équipe, contrat, droits à absence | Saisie et validation |
| TimeTracking → Workforce | Temps validés, absences, heures supplémentaires | Cycle de paie |
| TimeTracking → Costing | Heures validées et imputations | Valorisation |
| TimeTracking → Planning | Temps réels, absences | Replanification |

**Points à valider.** Q-11 (taux horaires), Q-12 (absences), Q-13 (trajets/astreintes), Q-14 (périmètre de paie), Q-40 (données personnelles).

**Statut.** Proposition.

---

### 3.5 BD-05 — Procurement / Inventory

**Question.** Qui porte la commande fournisseur et qui porte le stock physique ?

| Responsabilités candidates | Domaine | Analyse |
| --- | --- | --- |
| Fournisseur, consultation, commande, engagement, échéancier, performance | D10 Procurement | Relation commerciale et engagement d'achat. |
| Article, entrepôt, réception, mouvement, réservation, stock, inventaire | D11 Inventory | Référentiel et physique du stock. |
| Réception | D11 Inventory | Inventory constate la réception physique ; Quality contrôle ; Procurement traite l'écart commercial. |
| Article master | D11 Inventory | Proposition ; Q-17. |
| Référence fournisseur | D10 Procurement | Référence propre au fournisseur, liée à l'article. |

**Séparation recommandée.**

- **Procurement** possède le fournisseur, la demande d'achat, la consultation, l'offre, la commande, les lignes, l'engagement, l'échéancier, l'accord-cadre et l'évaluation fournisseur.
- **Inventory** possède l'article, l'entrepôt, l'emplacement, le lot, le mouvement, la réception physique, la réservation, la consommation, le bon de sortie et l'inventaire.
- Procurement ne modifie jamais une quantité en stock. Inventory ne crée jamais une commande fournisseur.
- La réception physique est enregistrée par Inventory ; Quality accepte ou refuse ; Procurement gère la réclamation fournisseur et la commande.
- Le stock est centralisé (V-06). Le stock de chantier est un emplacement temporaire sous contrôle d'Inventory, à valider Q-19.
- La valorisation financière est assurée par Costing ; Inventory fournit les quantités et la traçabilité (BD-21).

**Informations échangées.**

| Sens | Informations | Moment |
| --- | --- | --- |
| Procurement → Inventory | Commande, article, quantité, fournisseur, date, échéancier | Commande et approvisionnement |
| Inventory → Procurement | Stock, pénurie, réception, écart, retour | Réception et réapprovisionnement |
| Inventory → Quality | Demande de contrôle à réception | Réception |
| Quality → Inventory | Acceptation, refus, quarantaine | Réception |
| Procurement → Costing | Engagement, prix, variation | Commande |

**Points à valider.** Q-17 (article master), Q-18 (catalogue fournisseur), Q-19 (stock chantier), Q-20 (valorisation), Q-21 (livraison directe).

**Statut.** Proposition.

---

### 3.6 BD-06 — Workshop / Inventory

**Question.** Qui porte l'ordre de fabrication et qui porte les mouvements de matière ?

| Responsabilités candidates | Domaine | Analyse |
| --- | --- | --- |
| OF, dossier, gamme, opérations, postes, production, autocontrôle, colis | D09 Workshop | Fabrication et exécution atelier. |
| Article, stock, réservation, sortie, mouvement, consommation, traçabilité, inventaire | D11 Inventory | Physique du stock et traçabilité. |
| Demande matière | D09 Workshop | Besoin exprimé par l'OF. |
| Réservation et sortie matière | D11 Inventory | Décision et mouvement de stock. |

**Séparation recommandée.**

- **Workshop** possède l'OF, le dossier de fabrication, les opérations, les postes, le compte rendu de production, l'autocontrôle, le rebut, le colis, le dossier de fabrication externe et la capacité d'atelier.
- **Inventory** possède l'article, la réservation, la sortie, le mouvement, la consommation et la traçabilité.
- Workshop exprime une demande matière ; Inventory réserve, sort et enregistre. Workshop ne décrémente jamais le stock directement.
- Le rebut et la reprise sont constatés par Workshop, régularisés par Inventory et valorisés par Costing.
- Une fabrication externe ne change pas la responsabilité : Procurement commande, Workshop porte le dossier technique et l'acceptation technique, Inventory réceptionne la matière ou le composant selon le contrat, Quality contrôle.

**Informations échangées.**

| Sens | Informations | Moment |
| --- | --- | --- |
| Workshop → Inventory | Article, quantité, OF, date, besoin | Lancement et exécution |
| Inventory → Workshop | Disponibilité, réservation, sortie, pénurie | Exécution |
| Workshop → Costing | Heures, matière, rebuts | Production |
| Inventory → Costing | Quantité consommée, valorisation | Mouvement |

**Points à valider.** Q-19, Q-20, Q-23 (acceptation externe), Q-24 (capacité atelier).

**Statut.** Proposition.

---

### 3.7 BD-07 — Quality / Handover

**Question.** Qui décide de la conformité technique et qui décide de la réception contractuelle ?

| Responsabilités candidates | Domaine | Analyse |
| --- | --- | --- |
| Plan qualité, contrôles, essais, NCR, actions, certificats, qualifications techniques | D14 Quality | Conformité technique aux exigences. |
| Réception, réserves, levées, PV, DOE, garanties, clôture contractuelle | D17 Handover | Acceptation contractuelle par le client. |
| Réserve | D17 Handover | Écart contractuel constaté à la réception. |
| Non-conformité | D14 Quality | Écart technique à une exigence. |

**Séparation recommandée.**

- **Quality** prononce la conformité technique, ouvre et clôt les NCR, délivre les certificats et fournit les preuves.
- **Handover** organise la réception, constate les réserves, prononce la levée, établit le PV, compile le DOE et suit les garanties.
- Une réserve peut exister sans NCR (par exemple un document contractuel manquant) et une NCR peut exister sans réserve (par exemple un écart corrigé avant réception).
- Une réserve peut référencer une NCR, mais les deux objets restent distincts et ont des propriétaires différents. Q-30.
- Handover ne prononce pas la conformité technique ; Quality ne prononce pas l'acceptation contractuelle.
- Le DOE est porté contractuellement par Handover ; Documents stocke et versionne les pièces. Q-31.

**Informations échangées.**

| Sens | Informations | Moment |
| --- | --- | --- |
| Quality → Handover | Contrôles, essais, certificats, NCR clôturées | Réception |
| Handover → Quality | Réserves à traiter techniquement | Réception |
| Handover → Projects | Réception, réserves, levées, PV | Réception et clôture |
| Handover → Documents | Pièces du DOE à compiler et diffuser | Réception |

**Points à valider.** Q-30 (réserve vs NCR), Q-31 (DOE), Q-44 (garanties).

**Statut.** Proposition.

---

### 3.8 BD-08 — Documents / autres domaines

**Question.** Qui possède le contenu métier et qui gère le document ?

| Responsabilités candidates | Domaine | Analyse |
| --- | --- | --- |
| Contenu, validité métier, décision de publier | Domaine propriétaire | Le document n'a de sens que rattaché à un objet métier. |
| Stockage, version, métadonnées, classification, diffusion, conservation, archive | D16 Documents | Gestion documentaire transverse. |
| Validation de conformité d'un document | D14 Quality | Quality valide la conformité technique, pas le stockage. |
| Réception contractuelle et DOE | D17 Handover | Handover décide de la complétude contractuelle. |

**Séparation recommandée.**

- Chaque domaine reste propriétaire du **contenu** et de la **validité métier** de ses documents.
- **Documents** possède le contenant : fichier, version, métadonnées, type, dossier, diffusion, accusé de réception, règle de conservation, archive.
- Documents ne prononce jamais la validité métier d'un document. Il peut vérifier des métadonnées obligatoires et la complétude d'un dossier.
- Le statut métier (approuvé, refusé, conforme) et le statut documentaire (brouillon, publié, remplacé, archivé) sont deux dimensions distinctes. Q-32.
- Handover porte la constitution contractuelle du DOE ; Documents stocke, versionne et diffuse les pièces.
- Quality porte les preuves de conformité ; Documents les conserve.
- L'accès aux documents sensibles (RH, paie, sécurité, contrats) est contrôlé par Identity et les règles du domaine propriétaire.

**Informations échangées.**

| Sens | Informations | Moment |
| --- | --- | --- |
| Domaine → Documents | Contenu, type, métadonnées, propriétaire, liens | Production ou réception |
| Documents → Domaine | Référence, version, statut, diffusion, accusé | Consultation |
| Handover → Documents | Pièces et ordre du DOE | Réception |
| Documents → Handover | Complétude, versions, diffusion | Réception |

**Points à valider.** Q-31 (DOE), Q-32 (statut documentaire vs métier), Q-33 (signature et archivage légal), Q-40 (confidentialité).

**Statut.** Proposition.

---

### 3.9 BD-09 — Workforce / paie externalisée

**Question.** Où s'arrête Workforce et où commence le prestataire de paie ?

| Responsabilités candidates | Domaine | Analyse |
| --- | --- | --- |
| Collaborateur, contrat, poste, qualification, élément variable | D07 Workforce | Données RH et variables nécessaires. |
| Pointage, temps, absence constatée | D08 TimeTracking | Événements de temps. |
| Calcul du bulletin, cotisations, déclarations sociales, paiement | Prestataire externe | Production de la paie externalisée. |
| Contrôle et transmission des variables | D07 Workforce | Préparation, validation et réconciliation. |

**Séparation recommandée.**

- **Workforce** prépare, valide et transmet les données de paie : contrat, éléments variables, absences qualifiées, primes, heures supplémentaires validées.
- **TimeTracking** fournit les temps et absences constatés, sans calcul de paie.
- Le **prestataire externe** produit les bulletins, les déclarations sociales et les paiements. L'application ne réalise pas ces traitements comme fonctionnalité interne obligatoire.
- Workforce contrôle la cohérence des données transmises et conserve la trace des envois et corrections.
- Les données de paie sont sensibles : minimisation, accès restreint, conservation et traçabilité. Q-14, Q-40.
- Aucun bulletin ni détail de rémunération individuelle ne doit être exposé dans les rapports généraux sans autorisation.

**Informations échangées.**

| Sens | Informations | Moment |
| --- | --- | --- |
| TimeTracking → Workforce | Temps validés, absences, heures supplémentaires | Cycle de paie |
| Workforce → prestataire | Contrat, variables, absences qualifiées, centres de coût | Cycle de paie |
| Prestataire → Workforce | Retour de paie, anomalies, confirmations | Cycle de paie |
| Workforce → Costing | Taux et coûts RH agrégés | Valorisation |

**Points à valider.** Q-11, Q-12, Q-13, Q-14, Q-40.

**Statut.** Proposition, conforme à la décision validée V-07.

## 4. Chevauchements complémentaires

### 4.1 BD-10 — Procurement / Workshop

**Responsabilités candidates.**

| Domaine | Responsabilité |
| --- | --- |
| Procurement | Fournisseur/sous-traitant, consultation, commande, prix, engagement, performance. |
| Workshop | Dossier technique, besoin de fabrication externe, acceptation technique, intégration à la production. |
| Quality | Contrôle de conformité et NCR. |

**Séparation recommandée.** Procurement porte la relation commerciale et l'engagement ; Workshop porte le dossier technique et l'acceptation technique ; Quality prononce la conformité. Procurement ne décide pas de la conformité technique ; Workshop ne négocie pas le prix ni les conditions.

**Informations échangées.** Dossier technique, commande, délais, réception, NCR, performance.

**À valider.** Q-22, Q-23.

**Statut.** Proposition.

---

### 4.2 BD-11 — Projects / Workshop

**Responsabilités candidates.**

| Domaine | Responsabilité |
| --- | --- |
| Projects | Étude contractuelle, solution technique globale, périmètre, jalons, relation client. |
| Workshop | Études d'exécution atelier, plans de fabrication, nomenclatures, gammes, capacité, production. |
| Procurement | Achat ou sous-traitance de la fabrication. |

**Séparation recommandée.** Projects porte l'étude contractuelle et la coordination technique de l'affaire ; Workshop porte l'ingénierie de fabrication et l'exécution atelier. Le bureau d'études est une capacité partagée : Projects porte les livrables contractuels, Workshop les livrables d'atelier. Q-50.

**Informations échangées.** Périmètre, plans, hypothèses, nomenclatures, faisabilité, capacité, avancement.

**À valider.** Q-50, Q-23, Q-24.

**Statut.** Proposition.

---

### 4.3 BD-12 — Inventory / Logistics

**Responsabilités candidates.**

| Domaine | Responsabilité |
| --- | --- |
| Inventory | Stock, réservation, préparation, bon de sortie, mouvement, traçabilité. |
| Logistics | Plan de transport, tournée, transporteur, livraison, réception site, retour. |

**Séparation recommandée.** Inventory porte le stock et le bon de sortie ; Logistics porte le transport et la preuve de livraison. La réception sur site est constatée par Logistics avec Projects et, si nécessaire, Quality ; Inventory met à jour la localisation et le mouvement. Une livraison directe fournisseur est enregistrée par Inventory et coordonnée par Logistics. Q-21.

**Informations échangées.** Colis, bon de sortie, plan de transport, statut, réception, retour, écart.

**À valider.** Q-19, Q-21.

**Statut.** Proposition.

---

### 4.4 BD-13 — Equipment / Planning

**Responsabilités candidates.**

| Domaine | Responsabilité |
| --- | --- |
| Equipment | Actif, disponibilité, maintenance, inspections, affectation. |
| Planning | Activités, besoins, affectation prévisionnelle, conflits. |

**Séparation recommandée.** Equipment possède l'actif et sa disponibilité ; Planning décide de l'affectation dans le plan, après confirmation d'Equipment. Une maintenance ou une inspection bloque la disponibilité ; Planning intègre la fenêtre. Equipment ne planifie pas seul l'utilisation opérationnelle ; Planning ne modifie pas l'état de l'actif.

**Informations échangées.** Disponibilité, maintenance, inspections, besoins, affectations, pannes.

**À valider.** Q-25, Q-28.

**Statut.** Proposition.

---

### 4.5 BD-14 — Equipment / Logistics

**Responsabilités candidates.**

| Domaine | Responsabilité |
| --- | --- |
| Equipment | Véhicule, état, maintenance, inspection, disponibilité. |
| Logistics | Tournée, affectation du véhicule, transport, livraison. |
| Workforce | Chauffeur, contrat, qualification, temps. |

**Séparation recommandée.** Equipment possède le véhicule et enregistre son affectation ; Logistics organise la tournée et demande l'usage du véhicule ; Workforce fournit le chauffeur. Une panne ou un défaut d'inspection bloque l'affectation. Q-26.

**Informations échangées.** Disponibilité, affectation, usage, retour, panne, temps du chauffeur.

**À valider.** Q-26.

**Statut.** Proposition.

---

### 4.6 BD-15 — Safety / Workforce

**Responsabilités candidates.**

| Domaine | Responsabilité |
| --- | --- |
| Workforce | Contrat, formation, qualification RH, disponibilité. |
| Safety | Analyse de risques, plan de prévention, habilitation opérationnelle, autorisation, incident. |
| Quality | Qualification technique de production. |

**Séparation recommandée.** Workforce porte la formation et le dossier RH ; Safety porte l'habilitation opérationnelle et l'autorisation de travail ; Quality porte la qualification technique (soudage, procédé, contrôle). Une formation suivie ne vaut pas automatiquement autorisation : Safety vérifie l'aptitude et délivre l'autorisation. Q-16, Q-29.

**Informations échangées.** Formations, qualifications, habilitations, restrictions, incidents, exigences.

**À valider.** Q-16, Q-29, Q-40.

**Statut.** Proposition.

---

### 4.7 BD-16 — Clients / Procurement

**Responsabilités candidates.**

| Domaine ou statut | Responsabilité |
| --- | --- |
| Identité juridique de l'entité | **Non arbitrée — Q-05.** Peut être portée par Clients, par Procurement ou par un référentiel partagé. |
| Clients | Rôle commercial de prospect, client ou donneur d'ordre ; contacts et relation commerciale. |
| Procurement | Rôle de fournisseur, rôle de sous-traitant, relation d'achat et commande. |
| Procurement avec Quality et Safety | Qualification métier ou achat du tiers, selon la criticité de la prestation. |

**Séparation recommandée.** La séparation ne choisit pas le portage de l'identité juridique. Elle distingue :

- l'**identité juridique de l'entité**, dont le propriétaire reste à arbitrer (Q-05) ;
- le **rôle commercial** de prospect, client ou donneur d'ordre, porté par Clients ;
- le **rôle de fournisseur**, porté par Procurement ;
- le **rôle de sous-traitant**, porté par Procurement ;
- la **qualification métier ou achat**, portée par Procurement avec Quality et Safety selon le domaine.

Un même tiers peut cumuler ces rôles. La présence de `CLI-02 Client`, `PRC-01 Fournisseur` et `PRC-02 SousTraitant` ne signifie pas qu'il existe trois entités juridiques distinctes : ce sont des rôles métier. Deux options restent ouvertes, sans nouveau domaine :

- **Option A** : Clients porte le référentiel de l'entité légale (tiers), Procurement ajoute le rôle fournisseur/sous-traitant et ses données d'achat.
- **Option B** : Clients et Procurement ont chacun leur référentiel, reliés par un identifiant légal (SIREN/SIRET) et une procédure de rapprochement.

L'option A réduit les doublons mais élargit Clients au-delà de la relation commerciale. L'option B préserve l'autonomie mais impose une réconciliation. **Aucune option n'est tranchée.** Q-05.

**Informations échangées.** Identité juridique (selon Q-05), rôle commercial, rôle fournisseur ou sous-traitant, contacts, qualification, statut, conditions.

**À valider.** Q-05, Q-02.

**Statut.** Question ouverte.

---

### 4.8 BD-17 — Projects / Handover / Costing

**Responsabilités candidates.**

| Domaine | Responsabilité |
| --- | --- |
| Projects | Décision de clôture de l'affaire, statut contractuel, synthèse. |
| Handover | Réception contractuelle, réserves, DOE, garanties clientes. |
| Costing | Coût final, marge, clôture de la période analytique. |
| Budgets | Écart final, clôture budgétaire. |

**Séparation recommandée.** Handover prononce la réception et la clôture contractuelle ; Projects clôt l'affaire lorsque les conditions sont réunies ; Costing clôt les coûts et calcule la marge finale ; Budgets analyse l'écart final et clôt le budget. Aucun domaine ne peut clôturer seul l'ensemble : une orchestration ou une décision explicite est nécessaire. Q-53.

**Informations échangées.** Réception, réserves, DOE, garanties clientes, coûts finaux, marge, écarts.

**À valider.** Q-53, Q-30, Q-44.

**Statut.** Proposition.

---

### 4.9 BD-18 — Identity / Workforce

**Responsabilités candidates.**

| Domaine | Responsabilité |
| --- | --- |
| Identity | Compte, authentification, rôles, permissions, périmètre. |
| Workforce | Collaborateur, contrat, poste, qualification, données RH. |

**Séparation recommandée.** Identity porte le compte et les droits ; Workforce porte la personne et la relation de travail. Le lien se fait par un identifiant d'acteur. La création ou la désactivation d'un compte est déclenchée par la vie du collaborateur, mais Identity reste responsable de la décision de sécurité. Q-35.

**Informations échangées.** Arrivée, départ, changement de poste, unité, demande d'accès.

**À valider.** Q-35, Q-40.

**Statut.** Proposition.

---

### 4.10 BD-19 — Quality / Workshop / Procurement (fabrication externe)

**Responsabilités candidates.**

| Domaine | Responsabilité |
| --- | --- |
| Procurement | Commande, prix, délai, relation sous-traitant, clôture commerciale. |
| Workshop | Dossier technique, acceptation technique du livrable, intégration. |
| Quality | Plan de contrôle, inspection, NCR, certificat. |

**Séparation recommandée.** Trois décisions distinctes :

1. **Qualité** : le livrable est-il conforme aux exigences ? Quality prononce.
2. **Technique** : le livrable est-il utilisable/intégrable selon le dossier ? Workshop prononce.
3. **Commerciale** : la commande est-elle soldée ? Procurement prononce.

Une seule décision ne remplace pas les autres. Une acceptation technique ne vaut pas acceptation qualité ; une réception commerciale ne vaut pas conformité. Q-23.

**Informations échangées.** Dossier, contrôle, NCR, acceptation, réception, clôture.

**À valider.** Q-22, Q-23.

**Statut.** Proposition.

---

### 4.11 BD-20 — Reporting / tous les domaines

**Responsabilités candidates.**

| Domaine | Responsabilité |
| --- | --- |
| Reporting | Définitions d'indicateurs, rapports, tableaux de bord, snapshots, exports. |
| Domaines sources | Données, règles, états, événements, autorisations. |

**Séparation recommandée.** Reporting est un consommateur transversal en lecture seule. Il ne possède pas les données source, n'écrit pas dans les domaines et ne corrige pas une donnée. Il peut calculer des indicateurs dérivés, à condition de documenter la formule, la source, la période et le propriétaire métier. En cas d'écart, la source fait foi. Q-34.

**Informations échangées.** Données, événements, indicateurs, rapports, alertes.

**À valider.** Q-34, Q-40.

**Statut.** Proposition.

---

### 4.12 BD-21 — Inventory / Costing

**Responsabilités candidates.**

| Domaine | Responsabilité |
| --- | --- |
| Inventory | Quantités, mouvements, lots, traçabilité, valorisation des entrées/sorties selon méthode à définir. |
| Costing | Valeur financière, imputation, coût de consommation, provision, écart. |

**Séparation recommandée.** Inventory porte la quantité et la traçabilité ; Costing porte la valeur financière et l'imputation. Inventory fournit les mouvements et, si nécessaire, une base de valorisation ; Costing applique la méthode de valorisation et produit le coût. Une valeur de stock ne doit pas être calculée deux fois. Q-20.

**Informations échangées.** Article, quantité, lot, date, mouvement, valorisation, coût.

**À valider.** Q-20, Q-37.

**Statut.** Proposition.

## 5. Décisions proposées

Les décisions suivantes sont des propositions de cadrage. Elles ne sont pas validées.

| ID | Décision proposée | Justification | Questions liées |
| --- | --- | --- | --- |
| PD-01 | Clients porte les rôles commerciaux et la relation commerciale, sous réserve de Q-05 ; Projects porte l'étude, le devis, la commande, l'affaire et le chantier. | Évite de confondre relation durable et engagement contractuel. | Q-02, Q-03, Q-04, Q-05 |
| PD-02 | Une affaire peut couvrir plusieurs chantiers ou lots ; un chantier appartient à une seule affaire. | Reflète les affaires multi-sites ou multi-lots, sans imposer un modèle rigide. | Q-01 |
| PD-03 | Budgets porte l'enveloppe autorisée ; Costing porte le chiffrage, les engagements financiers, les coûts constatés, l'EAC et la marge. | Sépare la décision budgétaire de la mesure économique. | Q-08, Q-09, Q-10 |
| PD-04 | Procurement porte la commande et l'acte commercial ; Costing enregistre l'engagement financier ; Inventory porte la réception, le stock et les mouvements. | Sépare l'acte commercial, le suivi financier et le fait physique. | Q-17, Q-18, Q-19 |
| PD-05 | Workshop porte l'OF et la production ; Inventory porte la réservation, la sortie et la consommation matière. | Évite que l'atelier écrive directement dans le stock. | Q-19, Q-20 |
| PD-06 | Quality porte la conformité technique ; Handover porte la réception contractuelle, les réserves et le DOE. | Sépare la norme technique de l'acceptation client. | Q-30, Q-31 |
| PD-07 | Documents porte le contenant, la version et la diffusion ; chaque domaine porte le contenu et la validité métier. | Évite un domaine documentaire qui déciderait du métier. | Q-31, Q-32, Q-33 |
| PD-08 | Workforce porte les données RH et les variables de paie ; TimeTracking porte les événements de temps ; le prestataire externe produit la paie. | Conforme à V-07 et V-08. | Q-11, Q-12, Q-13, Q-14 |
| PD-09 | La sous-traitance donnée est portée par Procurement ; la sous-traitance reçue est portée par Projects et Clients. | Distingue l'achat de la vente de prestation. | Q-41 |
| PD-10 | Planning porte les activités, affectations et l'avancement planning ; Projects porte les jalons et l'avancement contractuel. | Sépare l'organisation de l'engagement. | Q-27, Q-28 |
| PD-11 | Le stock central est la source de vérité ; le stock de chantier est un emplacement temporaire sous contrôle d'Inventory. | Conforme à V-06 et évite un stock autonome non décidé. | Q-19 |
| PD-12 | Reporting est un consommateur en lecture seule, sans écriture ni correction dans les domaines. | Évite un modèle d'écriture parallèle. | Q-34 |
| PD-13 | Identity porte les comptes et droits ; Workforce porte les collaborateurs et contrats. | Sépare sécurité et RH. | Q-35 |
| PD-14 | Safety porte les habilitations opérationnelles et autorisations ; Workforce porte les formations et qualifications RH ; Quality porte les qualifications techniques. | Évite trois sources concurrentes pour une même aptitude. | Q-16, Q-29 |
| PD-15 | Procurement porte les rôles fournisseur/sous-traitant et la relation d'achat, sous réserve de Q-05 ; Quality et Safety prononcent la conformité et l'aptitude. | Sépare relation commerciale et décision technique. | Q-05, Q-22, Q-23 |
| PD-16 | Costing valorise les faits produits par les domaines opérationnels ; il ne les possède pas. | Évite la duplication des faits. | Q-09, Q-10, Q-20 |
| PD-17 | Les références inter-domaines utilisent des identifiants publics stables, jamais des Models Eloquent. | Conforme à V-09 et V-10. | Q-36 |
| PD-18 | Aucune transaction partagée n'est introduite par défaut ; le fournisseur d'une opération porte ses invariants et sa transaction. | Conforme à V-12. | — |
| PD-19 | Un échange n'est créé que pour un consommateur réel ; le registre est un besoin, pas une autorisation technique. | Conforme à V-11. | — |
| PD-20 | Les interactions prioritaires de la section 2.2 du registre sont arbitrées avant la matrice du Lot 2. | Réduit le risque de matrice incomplète. | Q-01 à Q-53 |

## 6. Questions ouvertes

### 6.1 Questions structurantes

| ID | Question | Pourquoi elle compte | Proposition de travail | Priorité |
| --- | --- | --- | --- | --- |
| Q-01 | Une affaire peut-elle couvrir plusieurs chantiers ou lots ? Un chantier peut-il appartenir à plusieurs affaires ? | Détermine les axes échangés entre Projects, Planning, Budgets, Costing, Handover. | Affaire 1..N chantiers ; chantier 1..1 affaire. | Bloquant Lot 2 |
| Q-02 | Quelles différences entre client, donneur d'ordre, maître d'ouvrage, maître d'œuvre et payeur ? | Détermine les rôles portés par Clients et les destinataires de Handover. | Rôles multiples par tiers et par affaire. | Bloquant Lot 2 |
| Q-03 | L'opportunité commerciale et le pipeline appartiennent-ils à Clients ou à Projects ? | Détermine qui pilote l'étude initiale et les échanges Clients ↔ Projects. | Clients qualifie le prospect ; Projects ouvre l'étude. | Important |
| Q-04 | À quel moment un prospect devient-il client ? | Détermine la création et la conversion dans Clients. | À la première commande ou au premier contrat — proposition de travail, non validée. | Important |
| Q-05 | Existe-t-il un référentiel unique de tiers (client, fournisseur, sous-traitant) ? | Détermine le portage de l'identité juridique ; les rôles commerciaux et d'achat peuvent coexister. | Option A ou B de BD-16, à arbitrer ; aucune identité juridique n'est présumée par les objets de rôle. | Bloquant Lot 2 |
| Q-06 | Les conditions de paiement, remises et limites de crédit relèvent-elles de Clients, Projects ou d'un traitement externe ? | Détermine le périmètre financier des domaines. | Conditions cadre dans Clients, conditions contractuelles dans Projects. | Important |
| Q-07 | La facturation, les règlements et la comptabilité générale sont-ils hors périmètre des 18 domaines ? | Aucun domaine financier n'existe parmi les 18. | Documenter comme hors périmètre ou intégration externe. | Important |
| Q-08 | Quels sont les seuils d'approbation budgétaire et d'engagement ? | Détermine les décisions de Budgets et Procurement. | Seuils par montant et par nature, à fixer par la direction. | Important |
| Q-09 | À quel moment un engagement est-il reconnu : demande, commande, réception ou facture ? | Détermine le moment de l'échange Procurement → Costing. | À la validation de la commande. | Bloquant Lot 2 |
| Q-10 | Qui possède le coût final estimé (EAC) : Budgets, Costing ou Projects ? | Détermine la source de la prévision économique. | Costing, à partir des faits et des engagements. | Bloquant Lot 2 |
| Q-11 | Qui porte les taux horaires de référence : Workforce, Costing ou Budgets ? | Détermine la valorisation de la main-d'œuvre. | Workforce fournit le taux RH ; Costing l'utilise. | Important |
| Q-12 | Qui qualifie une absence : Workforce ou TimeTracking ? | Détermine la frontière RH / temps. | TimeTracking constate ; Workforce qualifie. | Bloquant Lot 2 |
| Q-13 | Quelles règles pour les temps de trajet, astreintes et heures supplémentaires ? | Détermine les événements de temps et les variables de paie. | À définir avec les conventions collectives et le prestataire. | Important |
| Q-14 | Quel est le périmètre exact transmis au prestataire de paie ? | Détermine les données RH, temps et paie échangées. | Variables, absences, contrats, centres de coût ; pas de calcul interne. | Important |
| Q-15 | Les intérimaires et prestataires de main-d'œuvre relèvent-ils de Workforce ou de Procurement ? | Détermine la relation contractuelle et le suivi des heures. | À arbitrer ; envisager Workforce pour la personne, Procurement pour le contrat. | Important |
| Q-16 | Qui porte les qualifications techniques (soudeur, procédé, contrôle) ? | Détermine la frontière Workforce / Quality / Safety. | Quality pour la qualification technique ; Workforce pour la formation RH. | Important |
| Q-17 | Qui est propriétaire de l'article : Inventory ou Procurement ? | Détermine le référentiel de stock et les achats. | Inventory porte l'article ; Procurement porte la référence fournisseur. | Bloquant Lot 2 |
| Q-18 | Qui porte le catalogue fournisseur et les références achetées ? | Détermine la relation article ↔ fournisseur. | Procurement, avec lien vers l'article Inventory. | Important |
| Q-19 | Existe-t-il un stock de chantier autonome ou un simple emplacement temporaire ? | Détermine les mouvements, la responsabilité et la traçabilité. | Emplacement temporaire sous contrôle d'Inventory. | Bloquant Lot 2 |
| Q-20 | Quelle méthode de valorisation du stock : FIFO, coût moyen, coût standard ? | Détermine la valeur des sorties et le coût matière. | À fixer avec la comptabilité ; Costing applique. | Important |
| Q-21 | Comment traiter les livraisons directes fournisseur sur chantier ? | Détermine la frontière Procurement / Inventory / Logistics. | Inventory enregistre la réception ; Logistics constate ; Quality contrôle. | Important |
| Q-22 | Qui qualifie un sous-traitant : Procurement, Quality ou Safety ? | Détermine les exigences et les échanges de qualification. | Procurement porte la relation ; Quality et Safety prononcent leurs conformités. | Important |
| Q-23 | Qui accepte techniquement une fabrication externe ? | Détermine la frontière Workshop / Quality / Procurement. | Quality prononce la conformité ; Workshop l'acceptation technique ; Procurement clôture. | Bloquant Lot 2 |
| Q-24 | Qui possède la capacité d'atelier : Workshop ou Planning ? | Détermine la planification de la production. | Workshop fournit la capacité ; Planning arbitre le planning. | Important |
| Q-25 | La calibration des équipements de mesure relève-t-elle d'Equipment ou de Quality ? | Détermine la conformité métrologique. | À arbitrer ; Equipment porte l'actif, Quality l'exigence. | Différé |
| Q-26 | Qui gère les chauffeurs et l'affectation des véhicules ? | Détermine la frontière Equipment / Logistics / Workforce. | Workforce chauffeur ; Equipment véhicule ; Logistics tournée. | Important |
| Q-27 | Qui déclare l'avancement : Projects, Planning ou TimeTracking ? | Détermine la source de l'avancement contractuel et opérationnel. | Projects contractuel ; Planning activités ; TimeTracking temps. | Bloquant Lot 2 |
| Q-28 | Quel horizon de planning est ferme et qui arbitre les conflits ? | Détermine la stabilité du planning et les responsabilités. | Horizon à définir ; arbitrage direction. | Important |
| Q-29 | Qui gère les EPI et les autorisations de travail : Safety ou Workforce ? | Détermine la frontière sécurité / RH. | Safety pour l'opérationnel ; Workforce pour la formation. | Important |
| Q-30 | Une réserve peut-elle être levée sans clôture d'une NCR ? | Détermine le lien Handover ↔ Quality. | Non si la réserve a une cause technique ; oui si elle est documentaire. | Bloquant Lot 2 |
| Q-31 | Qui possède le DOE : Handover ou Documents ? | Détermine la constitution et le stockage du DOE. | Handover pour la complétude contractuelle ; Documents pour le stockage. | Important |
| Q-32 | Comment distinguer le statut métier et le statut documentaire ? | Évite deux validations concurrentes. | Deux dimensions distinctes, propriétaires différents. | Important |
| Q-33 | Quelle valeur légale donner à la signature électronique et à l'archivage ? | Détermine les exigences de preuve et de conservation. | À définir avec le juridique. | Différé |
| Q-34 | Quelles exigences de fraîcheur, de lignée et d'accès pour Reporting ? | Détermine le modèle de reporting et les contrats de lecture. | Documenter source, formule, période, propriétaire. | Important |
| Q-35 | Quels rôles, périmètres et comptes externes pour Identity ? | Détermine l'autorisation et les accès clients/fournisseurs. | Rôles explicites, comptes externes sur décision. | Important |
| Q-36 | Quelle stratégie d'identifiants : auto-incrément, UUID, ULID ? | Détermine les références inter-domaines. | À trancher avant les premiers contrats. | Bloquant Lot 2 |
| Q-37 | Quelle unité monétaire, devise et règle d'arrondi ? | Détermine tous les échanges financiers. | Montants en unité entière ou décimale fixe, devise EUR. | Important |
| Q-38 | C2ME est-elle une seule entité juridique ou plusieurs établissements ? | Détermine les périmètres et les rapports. | À clarifier avec la direction. | Différé |
| Q-39 | Quel périmètre hors connexion et quelle stratégie de conflit ? | Détermine les interactions de saisie et d'idempotence. | Serveur autorité ; conflits explicites. | Important |
| Q-40 | Quelles règles de confidentialité et de conservation pour RH, paie, sécurité et documents ? | Détermine les accès et la rétention. | À définir avec le juridique et la direction. | Important |
| Q-41 | Comment formaliser la sous-traitance dans les deux sens ? | Détermine les objets et les flux Clients/Projects/Procurement/Handover. | Deux parcours distincts, sans objet unique ambigu. | Bloquant Lot 2 |
| Q-42 | Comment imputer les coûts de qualité, de sécurité et de non-qualité ? | Détermine les échanges Quality/Safety → Costing. | Axes analytiques dédiés, à valider. | Important |
| Q-43 | Comment traiter les matériaux fournis par le client ? | Détermine la propriété, le stock et la responsabilité. | À arbitrer : stock sous contrôle, hors valorisation ou valorisation spécifique. | Important |
| Q-44 | Comment distinguer les garanties clientes et les garanties fournisseurs ? | Détermine la frontière Handover / Procurement. | Handover pour les garanties clientes ; Procurement pour les garanties fournisseurs. | Important |
| Q-45 | Quel processus pour les avenants et travaux supplémentaires urgents ? | Détermine les validations Projects/Budgets/Costing. | Avenant avant exécution, sauf urgence autorisée. | Important |
| Q-46 | Comment gérer la suspension et la reprise d'une affaire ou d'un chantier ? | Détermine les états et les impacts. | Motif, validation, impact planning/coût. | Important |
| Q-47 | Comment gérer l'annulation ou l'abandon d'une affaire ? | Détermine les états et les coûts engagés. | Décision direction, clôture des engagements, analyse de coût. | Important |
| Q-48 | Quelles données de santé et restrictions d'aptitude peuvent être stockées ? | Détermine la confidentialité et les accès. | Minimisation, stockage restreint, pas de détail médical. | Différé |
| Q-49 | Comment gérer les réclamations et litiges ? | Aucun domaine dédié parmi les 18. | À orienter vers Handover, Quality ou un traitement externe. | Important |
| Q-50 | Le bureau d'études relève-t-il de Projects, de Workshop ou des deux ? | Détermine la propriété des études et des plans. | Projects pour les études contractuelles ; Workshop pour l'exécution atelier. | Important |
| Q-51 | Le registre des risques d'affaire est-il un objet de Projects, de Reporting ou un attribut de l'étude ? | Détermine la propriété et le suivi des risques. | À arbitrer ; envisager un attribut de l'étude et de l'affaire. | Important |
| Q-52 | Qui suit les permis et autorisations administratives nécessaires aux travaux ? | Détermine la responsabilité et les échéances. | À arbitrer ; souvent porté par le client, avec suivi par Projects. | Important |
| Q-53 | Quelles conditions exactes autorisent la clôture d'une affaire et dans quel ordre ? | Détermine l'enchaînement Handover / Costing / Budgets / Projects. | Réception, réserves levées, DOE, coûts et budget clôturés, puis affaire clôturée. | Bloquant Lot 2 |

### 6.2 Questions à traiter avant le Lot 2

Les questions suivantes sont considérées comme bloquantes pour la matrice technique :

- Q-01 : relation affaire/chantier ;
- Q-02 : rôles client/donneur d'ordre ;
- Q-05 : référentiel tiers ;
- Q-09 : reconnaissance des engagements ;
- Q-10 : propriété de l'EAC ;
- Q-12 : qualification des absences ;
- Q-17 : propriétaire de l'article ;
- Q-19 : stock de chantier ;
- Q-23 : acceptation technique externe ;
- Q-27 : source de l'avancement ;
- Q-30 : réserve vs NCR ;
- Q-36 : stratégie d'identifiants ;
- Q-41 : sous-traitance dans les deux sens ;
- Q-53 : conditions de clôture d'une affaire.

### 6.3 Questions pouvant être différées

- Q-25 : calibration des équipements de mesure ;
- Q-33 : signature électronique et archivage légal ;
- Q-38 : structure juridique multi-établissements ;
- Q-48 : données de santé et restrictions d'aptitude.

## 7. Décisions restant à valider

### 7.1 Décisions structurantes

| Décision | Options | Recommandation | Impact |
| --- | --- | --- | --- |
| Référentiel tiers | Clients maître / Procurement maître / deux référentiels reliés | À arbitrer, sans nouveau domaine ; les rôles commerciaux et d'achat restent distincts de l'identité juridique. | Détermine les échanges Clients ↔ Procurement et la qualité des données. |
| Relation affaire/chantier | 1–1 / 1–N / N–N | Affaire 1–N chantiers | Détermine les axes de Planning, Budgets, Costing. |
| Bureau d'études | Projects / Workshop / partagé | Projects contractuel, Workshop atelier | Détermine la propriété des études et plans. |
| Sous-traitance reçue | Affaire Projects / commande Procurement | Affaire Projects | Détermine le parcours commercial et la réception. |
| Sous-traitance donnée | Commande Procurement / OF Workshop | Commande Procurement, dossier Workshop | Détermine la frontière achat/fabrication. |

### 7.2 Décisions financières

| Décision | Options | Recommandation | Impact |
| --- | --- | --- | --- |
| Propriété de l'EAC | Budgets / Costing / Projects | Costing | Source de la prévision économique. |
| Reconnaissance des engagements | Commande / réception / facture | Commande | Moment de l'échange Procurement → Costing. |
| Seuils d'approbation | Direction / contrôle de gestion | À fixer | Détermine les validations. |
| Valorisation du stock | FIFO / coût moyen / standard | À fixer avec la comptabilité | Détermine le coût matière. |
| Unité monétaire | Entier / décimal / devise | À fixer | Détermine les contrats. |

### 7.3 Décisions RH et temps

| Décision | Options | Recommandation | Impact |
| --- | --- | --- | --- |
| Qualification des absences | Workforce / TimeTracking | TimeTracking constate, Workforce qualifie | Frontière RH/temps. |
| Taux horaires | Workforce / Costing / Budgets | Workforce fournit, Costing utilise | Valorisation. |
| Intérimaires | Workforce / Procurement | À arbitrer | Relation contractuelle et suivi. |
| Habilitation sécurité | Safety / Workforce | Safety opérationnel, Workforce formation | Conformité et affectation. |
| Périmètre de paie | Interne / externe | Externe | Conforme à V-07. |

### 7.4 Décisions stock et logistique

| Décision | Options | Recommandation | Impact |
| --- | --- | --- | --- |
| Article master | Inventory / Procurement | Inventory | Référentiel unique. |
| Stock de chantier | Autonome / emplacement temporaire | Emplacement temporaire | Traçabilité et responsabilité. |
| Livraison directe | Inventory / Logistics / Procurement | Inventory enregistre, Logistics constate | Réception et coût. |
| Chauffeurs | Workforce / Logistics | Workforce | Contrat et temps. |

### 7.5 Décisions qualité et réception

| Décision | Options | Recommandation | Impact |
| --- | --- | --- | --- |
| Réserve vs NCR | Fusion / distinction | Distinction avec lien | Deux responsabilités distinctes. |
| DOE | Handover / Documents | Handover contractuel, Documents stockage | Complétude et preuve. |
| Acceptation externe | Quality / Workshop / Procurement | Quality conformité, Workshop technique, Procurement commercial | Trois décisions distinctes. |
| Garanties fournisseurs | Procurement / Handover | Procurement | Frontière achat/client. |

## 8. Ce que le Lot 1 ne tranche pas

Le Lot 1 ne définit pas :

- la matrice technique des dépendances autorisées et interdites ;
- la liste des contrats publics et des événements ;
- le format des DTO, des identifiants et des montants ;
- les choix de persistance, de tables et de migrations ;
- les rôles et permissions détaillés ;
- les règles de facturation, de paiement et de comptabilité générale ;
- les règles de conservation légale et de signature électronique ;
- l'ordre d'implémentation des domaines ;
- les tests d'architecture ;
- les mécanismes hors connexion et d'idempotence.

Ces sujets relèvent du Lot 2, de CHAN-28, de CHAN-30, de CHAN-31 ou de tickets d'implémentation dédiés.

## 9. Checklist de revue

- [ ] Les 18 domaines sont présents et aucun n'a été fusionné, supprimé, scindé ou créé.
- [ ] Les activités de C2ME sont couvertes par les responsabilités existantes.
- [ ] Les deux parcours commerciaux sont documentés.
- [ ] L'atelier interne et la fabrication externe sont distingués.
- [ ] La sous-traitance dans les deux sens est distinguée.
- [ ] Le stock central est la référence ; le stock de chantier reste une question ouverte.
- [ ] La paie externalisée est respectée ; Workforce ne calcule pas les bulletins.
- [ ] TimeTracking reste propriétaire des événements de temps.
- [ ] Les chevauchements obligatoires sont analysés.
- [ ] Les propositions sont distinguées des décisions validées.
- [ ] Les questions ouvertes sont documentées avec leur impact.
- [ ] Aucune matrice technique de dépendances n'est définie.
- [ ] Aucun contrat, événement ou composant de code n'est créé.
- [ ] Les documents sont cohérents entre eux et avec CHAN-27/CHAN-28.

## 10. Références

- [`domain-responsibilities.md`](domain-responsibilities.md) — responsabilités des 18 domaines.
- [`business-processes.md`](business-processes.md) — processus métier.
- [`business-objects.md`](business-objects.md) — objets métier.
- [`domain-interactions-register.md`](domain-interactions-register.md) — registre des interactions.
- [`domain-conventions.md`](domain-conventions.md) — conventions internes CHAN-27.
- [`domain-communication.md`](domain-communication.md) — contrats synchrones CHAN-28.
- [`app/Domains/README.md`](../../app/Domains/README.md) — organisation des domaines.
- [`AGENTS.md`](../../AGENTS.md) — règles générales du dépôt.
