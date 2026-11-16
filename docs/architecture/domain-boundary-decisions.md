# Chevauchements, arbitrages et décisions de frontières

Ce document analyse les chevauchements de responsabilité entre les 18 domaines de **C2ME Chantier**, propose des arbitrages et recense les décisions restant à valider.

- Ticket : CHAN-29 — Documenter les frontières et dépendances autorisées.
- Lot : Lot 1 — Inventaire et cartographie des responsabilités métier.
- Portée : chevauchements métier, séparations recommandées, informations échangées, décisions proposées et questions ouvertes.
- Hors portée : matrice technique définitive des dépendances (Lot 2), contrats et événements (CHAN-28), conventions internes de code (CHAN-27), tests d'architecture (CHAN-31).

> **Statut du document — Lot 1 / préparation du Lot 2.**
> Les décisions validées sont listées en section 2 et dans la section 6.4. Les questions bloquantes du Lot 1 (V-15 à V-28) et les 31 arbitrages du questionnaire métier du Lot 2 (V-29 à V-59) ont été validés le 16/11/2026. Les autres propositions et questions restent ouvertes et ne doivent pas être considérées comme validées.

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
| V-15 | Clients est propriétaire du référentiel maître unique des tiers (identité juridique et données communes). Procurement reste propriétaire de la relation d'achat, des données fournisseurs propres aux achats et des références fournisseur liées aux articles Inventory. | Arbitrage responsable projet, 16/11/2026 (Q-05) |
| V-16 | Les références publiques inter-domaines utilisent des UUID stables. La version et le format précis de génération restent à préciser au niveau des conventions techniques d'implémentation. | Arbitrage responsable projet, 16/11/2026 (Q-36) |
| V-17 | Une affaire peut regrouper plusieurs chantiers ; chaque chantier appartient à une seule affaire. | Arbitrage responsable projet, 16/11/2026 (Q-01) |
| V-18 | Un tiers peut cumuler plusieurs rôles dans une même affaire (client, donneur d'ordre, maître d'ouvrage, payeur), ces rôles étant explicitement distingués. | Arbitrage responsable projet, 16/11/2026 (Q-02) |
| V-19 | Un engagement financier est reconnu à l'approbation de la commande fournisseur. | Arbitrage responsable projet, 16/11/2026 (Q-09) |
| V-20 | Costing est propriétaire de l'EAC, calculé à partir des faits opérationnels et des engagements. | Arbitrage responsable projet, 16/11/2026 (Q-10) |
| V-21 | TimeTracking constate les événements et durées d'absence ; Workforce qualifie le motif RH. | Arbitrage responsable projet, 16/11/2026 (Q-12) |
| V-22 | Inventory est propriétaire du référentiel maître des articles ; Procurement porte les références et données d'achat propres aux fournisseurs. | Arbitrage responsable projet, 16/11/2026 (Q-17) |
| V-23 | Le stock de chantier est un emplacement temporaire du stock central, géré par Inventory, et non un référentiel autonome. | Arbitrage responsable projet, 16/11/2026 (Q-19) |
| V-24 | Pour une fabrication externe, Workshop porte l'acceptation technique, Quality statue sur la conformité et Procurement clôt l'aspect commercial. | Arbitrage responsable projet, 16/11/2026 (Q-23) |
| V-25 | Projects porte l'avancement contractuel ; Planning porte l'avancement des activités ; TimeTracking porte les temps réalisés. | Arbitrage responsable projet, 16/11/2026 (Q-27) |
| V-26 | Une réserve documentaire peut être clôturée sans NCR ; une réserve ayant une cause technique nécessite le traitement de la non-conformité correspondante avant sa clôture. | Arbitrage responsable projet, 16/11/2026 (Q-30) |
| V-27 | La sous-traitance confiée par C2ME suit le parcours Procurement ; la sous-traitance reçue par C2ME suit le parcours commercial Projects/Clients. Les deux parcours restent distincts. | Arbitrage responsable projet, 16/11/2026 (Q-41) |
| V-28 | La clôture d'une affaire intervient après réception, levée des réserves, constitution du DOE, clôture des coûts et clôture du budget. | Arbitrage responsable projet, 16/11/2026 (Q-53) |

## 3. Chevauchements obligatoires

### 3.1 BD-01 — Clients / Projects

**Question.** Où s'arrête la relation commerciale et où commence l'engagement contractuel ?

| Responsabilités candidates | Domaine | Analyse |
| --- | --- | --- |
| Rôles commerciaux (prospect, client, donneur d'ordre), contacts, relation commerciale, conditions cadre | D02 Clients | Ces éléments décrivent la relation durable et les rôles du tiers. |
| Devis complet et conditions commerciales cadre | D02 Clients | Le devis est produit et possédé par Clients jusqu'à sa signature. |
| Étude technique, commande/ordre de service, contrat, affaire, chantier, avenants, jalons | D03 Projects | L'étude technique est distincte du devis ; les autres éléments décrivent l'engagement et son exécution après signature. |
| Opportunité commerciale et pipeline | D02 ou D03 | La frontière dépend de l'organisation commerciale ; Q-03. |
| Conditions commerciales générales/cadre et prix du devis | D02 Clients | Clients construit et possède le devis complet. |
| Conditions contractuelles propres à l'affaire | D03 Projects | Projects prend le relais après signature. |

**Séparation recommandée.**

- **Clients** est propriétaire du référentiel maître des tiers (V-15), des rôles commerciaux, des contacts, de la relation commerciale, des conditions commerciales cadre et du devis complet (V-29, V-31, V-35, V-40).
- **Projects** prend le relais après signature ; il est propriétaire de la commande ou de l'ordre de service reçu, du contrat, de l'affaire, du chantier, des lots, des avenants, des jalons et des conditions contractuelles propres à l'affaire.
- L'ouverture d'une affaire à partir d'un devis accepté exige une validation explicite ; elle n'est pas automatique (V-30). Projects référence le tiers et le devis exposés par Clients, sans dupliquer leurs données maîtres.
- Un prospect peut être étudié avant d'être converti en client ; le moment exact de conversion reste à arbitrer dans Q-04 (proposition de travail : première commande ou premier contrat).
- La relation commerciale est mise à jour par les faits de Projects (ouverture, réception, clôture), sans que Projects modifie directement la fiche client.

**Informations échangées.**

| Sens | Informations | Moment |
| --- | --- | --- |
| Clients → Projects | Référence du tiers, contacts, rôles, conditions cadre, devis accepté et éléments commerciaux signés | Après signature et validation explicite d'ouverture |
| Projects → Clients | Affaire ouverte, commande, réception, clôture, incident relationnel | Cycle de vie |
| Clients → Projects | Prospect qualifié, besoin, échéance | Prospection |
| Projects → Clients | Statut de l'affaire, commande, réception, clôture | Exécution et relation commerciale |

**Points restant à qualifier.** Q-03 (opportunité commerciale), Q-04 (moment de conversion du prospect), Q-06 (conditions financières et crédit). Q-02 et Q-05 sont arbitrées par V-18 et V-15 ; la frontière devis/affaire est arbitrée par V-29 à V-35 et V-40.

**Statut.** Remplacé par les décisions validées V-29, V-31 et V-35 : Clients possède le devis complet et les conditions cadre ; Projects prend le relais après signature et possède les conditions propres à l'affaire.

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

**Points à qualifier.** Q-28 (horizon ferme, arbitrage des conflits). La relation affaire/chantier est arbitrée par V-17 et la distinction des avancements est validée par V-25.

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
| Coût final estimé (EAC) | D06 Costing | Projects, Budgets | Propriété et calcul par Costing validés (V-20, V-34, V-39). |
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

**Points à qualifier.** Q-08 (seuils et autorité de révision), Q-37 (unité monétaire, devise, arrondis). La reconnaissance des engagements (V-19) et la propriété/calcul de l'EAC (V-20, V-34, V-39) sont validés.

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
- TimeTracking constate les événements et durées d'absence ; Workforce qualifie le motif RH (V-21).
- Les règles de trajet, d'astreinte et d'heures supplémentaires restent à définir (Q-13).
- Le calcul du bulletin, les déclarations sociales et le paiement restent au prestataire externe (BD-09).

**Informations échangées.**

| Sens | Informations | Moment |
| --- | --- | --- |
| Workforce → TimeTracking | Collaborateur, équipe, contrat, droits à absence | Saisie et validation |
| TimeTracking → Workforce | Temps validés, absences, heures supplémentaires | Cycle de paie |
| TimeTracking → Costing | Heures validées et imputations | Valorisation |
| TimeTracking → Planning | Temps réels, absences | Replanification |

**Points à qualifier.** Q-11 (taux horaires), Q-13 (trajets/astreintes), Q-14 (périmètre de paie), Q-40 (données personnelles). La répartition des responsabilités sur les absences est validée (V-21).

**Statut.** Proposition.

---

### 3.5 BD-05 — Procurement / Inventory

**Question.** Qui porte la commande fournisseur et qui porte le stock physique ?

| Responsabilités candidates | Domaine | Analyse |
| --- | --- | --- |
| Fournisseur, consultation, commande, engagement, échéancier, performance | D10 Procurement | Relation commerciale et engagement d'achat. |
| Article, entrepôt, réception, mouvement, réservation, stock, inventaire | D11 Inventory | Référentiel et physique du stock. |
| Réception | D11 Inventory | Inventory constate la réception physique ; Quality contrôle ; Procurement traite l'écart commercial. |
| Article master | D11 Inventory | Propriété validée par V-22. |
| Référence fournisseur | D10 Procurement | Référence propre au fournisseur, liée à l'article. |

**Séparation recommandée.**

- **Procurement** possède le fournisseur, la demande d'achat, la consultation, l'offre, la commande, les lignes, l'engagement, l'échéancier, l'accord-cadre et l'évaluation fournisseur.
- **Inventory** possède l'article, l'entrepôt, l'emplacement, le lot, le mouvement, la réception physique, la réservation, la consommation, le bon de sortie et l'inventaire.
- Procurement ne modifie jamais une quantité en stock. Inventory ne crée jamais une commande fournisseur.
- La réception physique est enregistrée par Inventory ; Quality accepte ou refuse ; Procurement gère la réclamation fournisseur et la commande.
- Le stock est centralisé (V-06). Le stock de chantier est un emplacement temporaire du stock central sous contrôle d'Inventory (V-23).
- La valorisation financière est assurée par Costing ; Inventory fournit les quantités et la traçabilité (BD-21).

**Informations échangées.**

| Sens | Informations | Moment |
| --- | --- | --- |
| Procurement → Inventory | Commande, article, quantité, fournisseur, date, échéancier | Commande et approvisionnement |
| Inventory → Procurement | Stock, pénurie, réception, écart, retour | Réception et réapprovisionnement |
| Inventory → Quality | Demande de contrôle à réception | Réception |
| Quality → Inventory | Acceptation, refus, quarantaine | Réception |
| Procurement → Costing | Engagement, prix, variation | Commande |

**Points à qualifier.** Q-18 (catalogue fournisseur), Q-20 (valorisation), Q-21 (livraison directe). La propriété de l'article et le statut du stock de chantier sont arbitrés (V-22, V-23).

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
- Pour une fabrication externe, Procurement porte la commande et clôt l'aspect commercial ; Workshop porte le dossier et l'acceptation technique ; Quality statue sur la conformité (V-24). Inventory enregistre les mouvements physiques relevant de son périmètre.

**Informations échangées.**

| Sens | Informations | Moment |
| --- | --- | --- |
| Workshop → Inventory | Article, quantité, OF, date, besoin | Lancement et exécution |
| Inventory → Workshop | Disponibilité, réservation, sortie, pénurie | Exécution |
| Workshop → Costing | Heures, matière, rebuts | Production |
| Inventory → Costing | Quantité consommée, valorisation | Mouvement |

**Points à qualifier.** Q-20 (valorisation), Q-24 (capacité atelier). Le stock de chantier (V-23) et les responsabilités de fabrication externe (V-24) sont arbitrés.

**Statut.** Proposition.

---

### 3.7 BD-07 — Quality / Handover

**Question.** Qui décide de la conformité technique et qui décide de la réception contractuelle ?

| Responsabilités candidates | Domaine | Analyse |
| --- | --- | --- |
| Plan qualité, contrôles, essais, NCR, actions, certificats, qualifications techniques | D14 Quality | Conformité technique aux exigences. |
| Préparation documentaire de réception, centralisation des livrables, réserves documentaires, DOE et garanties | D17 Handover | Préparation et suivi documentaire ; Projects porte la responsabilité contractuelle. |
| Réserve | D17 Handover | Écart contractuel constaté à la réception. |
| Non-conformité | D14 Quality | Écart technique à une exigence. |

**Séparation recommandée.**

- **Quality** prononce la conformité technique, ouvre et clôt les NCR, délivre les certificats et fournit les preuves.
- **Projects** organise et porte la réception contractuelle. **Handover** prépare et centralise les documents et livrables, le DOE et le suivi documentaire des réserves et garanties (V-55).
- Une réserve peut exister sans NCR (par exemple un document contractuel manquant) et une NCR peut exister sans réserve (par exemple un écart corrigé avant réception).
- Une réserve documentaire peut être clôturée sans NCR ; une réserve ayant une cause technique nécessite le traitement de la NCR correspondante avant sa clôture. Les objets Réserve et NCR restent distincts (V-26).
- Projects porte la responsabilité de la réception contractuelle ; Handover ne prononce pas l'acceptation contractuelle. Quality statue sur la conformité technique.
- Handover prépare et centralise le DOE ; Documents stocke et versionne les pièces. Projects conserve la responsabilité contractuelle de la réception (V-55).

**Informations échangées.**

| Sens | Informations | Moment |
| --- | --- | --- |
| Quality → Handover | Contrôles, essais, certificats, NCR clôturées | Réception |
| Handover → Quality | Réserves à traiter techniquement | Réception |
| Handover → Projects | Réception, réserves, levées, PV | Réception et clôture |
| Handover → Documents | Pièces du DOE à compiler et diffuser | Réception |

**Points à qualifier.** Q-31 (DOE), Q-44 (garanties). Le traitement des réserves/NCR est validé par V-26 ; la répartition Projects/Handover est validée par V-55.

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

**Points à qualifier.** Q-11, Q-13, Q-14, Q-40. La répartition TimeTracking / Workforce pour les absences est validée par V-21.

**Statut.** Proposition, conforme à la décision validée V-07.

## 4. Chevauchements complémentaires

### 4.1 BD-10 — Procurement / Workshop

**Responsabilités candidates.**

| Domaine | Responsabilité |
| --- | --- |
| Procurement | Fournisseur/sous-traitant, consultation, commande, prix, engagement, performance. |
| Workshop | Dossier technique, besoin de fabrication externe, acceptation technique, intégration à la production. |
| Quality | Contrôle de conformité et NCR. |

**Séparation validée.** Procurement porte la relation commerciale et l'engagement ; Workshop porte le dossier technique et l'acceptation technique ; Quality prononce la conformité (V-24). Procurement ne décide pas de la conformité technique ; Workshop ne négocie pas le prix ni les conditions.

**Informations échangées.** Dossier technique, commande, délais, réception, NCR, performance.

**À qualifier.** Q-22 (qualification du sous-traitant). La répartition des responsabilités de fabrication externe est validée par V-24.

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

**À qualifier.** Q-50 (frontière des études bureau d'études), Q-24 (capacité atelier). La fabrication externe suit V-24.

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

**À qualifier.** Q-21 (livraison directe). Le stock de chantier est traité par V-23.

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
| Identité juridique de l'entité | **Clients — validé V-15.** Clients porte le référentiel maître unique des tiers. |
| Clients | Rôle commercial de prospect, client ou donneur d'ordre ; contacts et relation commerciale. |
| Procurement | Rôle de fournisseur, rôle de sous-traitant, relation d'achat et commande. |
| Procurement avec Quality et Safety | Qualification métier ou achat du tiers, selon la criticité de la prestation. |

**Séparation validée par V-15.** Le référentiel maître unique des tiers est détenu par Clients. La séparation distingue :

- l'**identité juridique et les données communes de l'entité**, détenues par Clients ;
- le **rôle commercial** de prospect, client ou donneur d'ordre, porté par Clients ;
- le **rôle de fournisseur**, porté par Procurement ;
- le **rôle de sous-traitant**, porté par Procurement ;
- la **qualification métier ou achat**, portée par Procurement avec Quality et Safety selon le domaine.

Un même tiers peut cumuler ces rôles sans créer plusieurs identités juridiques. Clients reste la source de vérité de l'identité et des données communes ; Procurement conserve les données propres à la relation d'achat et les références fournisseur associées aux articles Inventory (V-15, V-22).

**Informations échangées.** Identifiant public du tiers, rôle commercial, rôle fournisseur ou sous-traitant, contacts, qualification, statut et conditions propres à chaque relation.

**À qualifier.** Les détails des données propres aux relations d'achat et des qualifications métier restent à préciser ; la propriété du référentiel maître est validée par V-15.

**Statut.** Référentiel maître validé par V-15 ; les détails des données propres aux relations d'achat et des qualifications restent à qualifier.

---

### 4.8 BD-17 — Projects / Handover / Costing

**Responsabilités candidates.**

| Domaine | Responsabilité |
| --- | --- |
| Projects | Organisation et responsabilité de la réception contractuelle, statut contractuel et décision de clôture de l'affaire. |
| Handover | Préparation et centralisation des documents et livrables de réception, suivi documentaire des réserves, DOE et garanties clientes. |
| Costing | Coût final, marge, clôture de la période analytique. |
| Budgets | Écart final, clôture budgétaire. |

**Séparation retenue.** Projects organise et porte la réception contractuelle, puis clôt l'affaire lorsque les conditions de V-28 sont réunies. Handover prépare et centralise les documents et livrables de réception, le DOE et le suivi documentaire des réserves et garanties ; il ne se substitue pas à Projects pour la responsabilité contractuelle. Costing clôt les coûts et calcule la marge finale ; Budgets clôt le budget. Les confirmations des domaines concernés précèdent la clôture de l'affaire.

**Informations échangées.** Réception, réserves, DOE, garanties clientes, coûts finaux, marge, écarts.

**À qualifier.** Q-44 (garanties). Le traitement des réserves/NCR est validé par V-26 ; les conditions de clôture de l'affaire sont validées par V-28.

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

Une seule décision ne remplace pas les autres. Une acceptation technique ne vaut pas acceptation qualité ; une réception commerciale ne vaut pas conformité. Cette répartition est validée par V-24.

**Informations échangées.** Dossier, contrôle, NCR, acceptation, réception, clôture.

**À qualifier.** Q-22 (qualification du sous-traitant). La répartition des responsabilités de fabrication externe est validée par V-24.

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

**Statut.** Responsabilité de clôture validée par V-28 ; la répartition opérationnelle entre Projects et Handover est validée par V-55.

## 5. Décisions proposées et propositions historiques

Le tableau conserve les identifiants PD historiques pour assurer la traçabilité. PD-01 et PD-02 sont remplacées par des décisions validées ; PD-15 est partiellement remplacée par V-15 et V-24. Les autres lignes restent des propositions de cadrage, sauf lorsqu'une décision V ultérieure en précise déjà une partie. Les décisions V prévalent toujours sur les propositions antérieures.

| ID | Décision proposée | Justification | Questions liées |
| --- | --- | --- | --- |
| PD-01 | Clients porte le référentiel maître des tiers, les rôles commerciaux, la relation commerciale et le devis complet ; Projects porte l'étude technique, la commande/contrat après signature, l'affaire et le chantier. | Décision remplacée et précisée par V-15, V-18 et V-29 à V-40. | V-15, V-18, V-29 à V-40 |
| PD-02 | Une affaire peut regrouper plusieurs chantiers ; chaque chantier appartient à une seule affaire. | Décision désormais validée par V-17 ; cette proposition historique est remplacée. | V-17 |
| PD-03 | Budgets porte l'enveloppe autorisée ; Costing porte les coûts constatés, l'EAC et la marge, ainsi que le suivi des engagements. | La reconnaissance de l'engagement à l'approbation de la commande et la propriété de l'EAC sont validées par V-19 et V-20 ; les seuils budgétaires restent à définir. | Q-08, Q-37, V-19, V-20 |
| PD-04 | Procurement porte la commande et l'acte commercial ; Costing enregistre l'engagement financier ; Inventory porte la réception, le stock et les mouvements. | Sépare l'acte commercial, le suivi financier et le fait physique ; l'engagement à l'approbation est validé par V-19 et le référentiel article par V-22. | Q-18, V-19, V-22 |
| PD-05 | Workshop porte l'OF et la production ; Inventory porte la réservation, la sortie et la consommation matière. | Évite que l'atelier écrive directement dans le stock ; le stock de chantier est un emplacement temporaire (V-23). | V-23, Q-20 |
| PD-06 | Quality porte la conformité technique ; Projects organise la réception contractuelle ; Handover prépare et centralise les documents et livrables de réception, le DOE et le suivi documentaire des réserves. | Sépare la conformité technique, la responsabilité contractuelle et la préparation documentaire ; la clôture de l'affaire suit V-28. | V-26, V-28, V-55, Q-31 |
| PD-07 | Documents porte le contenant, la version et la diffusion ; chaque domaine porte le contenu et la validité métier. | Évite un domaine documentaire qui déciderait du métier. | Q-31, Q-32, Q-33 |
| PD-08 | Workforce porte les données RH et les variables de paie ; TimeTracking porte les événements de temps et d'absence ; le prestataire externe produit la paie. | Conforme à V-07, V-08 et V-21. | Q-11, Q-13, Q-14, V-21 |
| PD-09 | La sous-traitance donnée est portée par Procurement ; la sous-traitance reçue est portée par Projects et Clients. | Distinction validée par V-27 entre achat de prestation et vente de prestation. | V-27 |
| PD-10 | Planning porte les activités et leur avancement ; Workforce décide des affectations à partir des besoins de Planning ; Projects porte les jalons et l'avancement contractuel. | La distinction des avancements est validée par V-25 ; les modalités de planification restent à qualifier. | Q-28, V-25 |
| PD-11 | Le stock central est la source de vérité ; le stock de chantier est un emplacement temporaire sous contrôle d'Inventory. | Conforme à V-06 et V-23 ; aucun stock autonome de chantier n'est créé. | V-23 |
| PD-12 | Reporting est un consommateur en lecture seule, sans écriture ni correction dans les domaines. | Évite un modèle d'écriture parallèle. | Q-34 |
| PD-13 | Identity porte les comptes et droits ; Workforce porte les collaborateurs et contrats. | Sépare sécurité et RH. | Q-35 |
| PD-14 | Safety porte les habilitations opérationnelles et autorisations ; Workforce porte les formations et qualifications RH ; Quality porte les qualifications techniques. | Évite trois sources concurrentes pour une même aptitude. | Q-16, Q-29 |
| PD-15 | Procurement porte la relation d'achat et les données fournisseur ; Clients porte l'identité maître du tiers ; Quality et Safety interviennent sur la qualification et l'aptitude selon leur périmètre. | La propriété du tiers est validée par V-15 ; l'acceptation technique externe et la conformité sont réparties selon V-24. Les détails de qualification restent à instruire. | V-15, V-24, Q-22 |
| PD-16 | Costing valorise les faits produits par les domaines opérationnels ; il ne les possède pas. | Évite la duplication des faits. La reconnaissance des engagements et la propriété de l'EAC sont validées par V-19 et V-20 ; la valorisation des stocks reste à qualifier. | V-19, V-20, Q-20 |
| PD-17 | Les références inter-domaines utilisent des identifiants publics stables, jamais des Models Eloquent. | Les références publiques utilisent des UUID stables selon V-16 ; le format précis de génération reste à définir dans les conventions d'implémentation. | V-16 |
| PD-18 | Aucune transaction partagée n'est introduite par défaut ; le fournisseur d'une opération porte ses invariants et sa transaction. | Conforme à V-12 et aux règles de communication CHAN-28. | — |
| PD-19 | Un échange n'est créé que pour un consommateur réel ; le registre est un besoin, pas une autorisation technique. | Conforme à V-11 ; les interactions restent à qualifier individuellement avant toute autorisation. | — |
| PD-20 | Les interactions prioritaires de la section 2.2 du registre sont arbitrées avant la matrice du Lot 2. | Réduit le risque de matrice incomplète. | Q-01 à Q-53 (références historiques ; plusieurs questions sont désormais arbitrées) |

## 6. Questions ouvertes

### 6.1 Questions structurantes

| ID | Question | Pourquoi elle compte | Proposition de travail | Priorité |
| --- | --- | --- | --- | --- |
| Q-01 | Une affaire peut-elle couvrir plusieurs chantiers ou lots ? Un chantier peut-il appartenir à plusieurs affaires ? | Détermine les axes échangés entre Projects, Planning, Budgets, Costing, Handover. | Affaire 1..N chantiers ; chantier 1..1 affaire. | Validé — V-17 |
| Q-02 | Quelles différences entre client, donneur d'ordre, maître d'ouvrage, maître d'œuvre et payeur ? | Détermine les rôles portés par Clients et les destinataires de Handover. | Rôles multiples par tiers et par affaire. | Validé — V-18 |
| Q-03 | L'opportunité commerciale et le pipeline appartiennent-ils à Clients ou à Projects ? | Détermine qui pilote l'étude initiale et les échanges Clients ↔ Projects. | Clients qualifie le prospect ; Projects ouvre l'étude. | Important |
| Q-04 | À quel moment un prospect devient-il client ? | Détermine la création et la conversion dans Clients. | À la première commande ou au premier contrat — proposition de travail, non validée. | Important |
| Q-05 | Existe-t-il un référentiel unique de tiers (client, fournisseur, sous-traitant) ? | Détermine le portage de l'identité juridique ; les rôles commerciaux et d'achat peuvent coexister. | Clients est le référentiel maître unique ; Procurement conserve les données de relation d'achat et les références fournisseur spécifiques. | Validé — V-15 |
| Q-06 | Les conditions de paiement, remises et limites de crédit relèvent-elles de Clients, Projects ou d'un traitement externe ? | Détermine le périmètre financier des domaines. | Conditions cadre dans Clients, conditions contractuelles dans Projects. | Important |
| Q-07 | La facturation, les règlements et la comptabilité générale sont-ils hors périmètre des 18 domaines ? | Aucun domaine financier n'existe parmi les 18. | Documenter comme hors périmètre ou intégration externe. | Important |
| Q-08 | Quels sont les seuils d'approbation budgétaire et d'engagement ? | Détermine les décisions de Budgets et Procurement. | Seuils par montant et par nature, à fixer par la direction. | Important |
| Q-09 | À quel moment un engagement est-il reconnu : demande, commande, réception ou facture ? | Détermine le moment de l'échange Procurement → Costing. | À la validation de la commande. | Validé — V-19 |
| Q-10 | Qui possède le coût final estimé (EAC) : Budgets, Costing ou Projects ? | Détermine la source de la prévision économique. | Costing, à partir des faits et des engagements. | Validé — V-20 |
| Q-11 | Qui porte les taux horaires de référence : Workforce, Costing ou Budgets ? | Détermine la valorisation de la main-d'œuvre. | Workforce fournit le taux RH ; Costing l'utilise. | Important |
| Q-12 | Qui qualifie une absence : Workforce ou TimeTracking ? | Détermine la frontière RH / temps. | TimeTracking constate ; Workforce qualifie. | Validé — V-21 |
| Q-13 | Quelles règles pour les temps de trajet, astreintes et heures supplémentaires ? | Détermine les événements de temps et les variables de paie. | À définir avec les conventions collectives et le prestataire. | Important |
| Q-14 | Quel est le périmètre exact transmis au prestataire de paie ? | Détermine les données RH, temps et paie échangées. | Variables, absences, contrats, centres de coût ; pas de calcul interne. | Important |
| Q-15 | Les intérimaires et prestataires de main-d'œuvre relèvent-ils de Workforce ou de Procurement ? | Détermine la relation contractuelle et le suivi des heures. | À arbitrer ; envisager Workforce pour la personne, Procurement pour le contrat. | Important |
| Q-16 | Qui porte les qualifications techniques (soudeur, procédé, contrôle) ? | Détermine la frontière Workforce / Quality / Safety. | Quality pour la qualification technique ; Workforce pour la formation RH. | Important |
| Q-17 | Qui est propriétaire de l'article : Inventory ou Procurement ? | Détermine le référentiel de stock et les achats. | Inventory porte l'article ; Procurement porte la référence fournisseur. | Validé — V-22 |
| Q-18 | Qui porte le catalogue fournisseur et les références achetées ? | Détermine la relation article ↔ fournisseur. | Procurement, avec lien vers l'article Inventory. | Important |
| Q-19 | Existe-t-il un stock de chantier autonome ou un simple emplacement temporaire ? | Détermine les mouvements, la responsabilité et la traçabilité. | Emplacement temporaire sous contrôle d'Inventory. | Validé — V-23 |
| Q-20 | Quelle méthode de valorisation du stock : FIFO, coût moyen, coût standard ? | Détermine la valeur des sorties et le coût matière. | À fixer avec la comptabilité ; Costing applique. | Important |
| Q-21 | Comment traiter les livraisons directes fournisseur sur chantier ? | Détermine la frontière Procurement / Inventory / Logistics. | Inventory enregistre la réception ; Logistics constate ; Quality contrôle. | Important |
| Q-22 | Qui qualifie un sous-traitant : Procurement, Quality ou Safety ? | Détermine les exigences et les échanges de qualification. | Procurement porte la relation ; Quality et Safety prononcent leurs conformités. | Important |
| Q-23 | Qui accepte techniquement une fabrication externe ? | Détermine la frontière Workshop / Quality / Procurement. | Quality prononce la conformité ; Workshop l'acceptation technique ; Procurement clôture. | Validé — V-24 |
| Q-24 | Qui possède la capacité d'atelier : Workshop ou Planning ? | Détermine la planification de la production. | Workshop fournit la capacité ; Planning arbitre le planning. | Important |
| Q-25 | La calibration des équipements de mesure relève-t-elle d'Equipment ou de Quality ? | Détermine la conformité métrologique. | À arbitrer ; Equipment porte l'actif, Quality l'exigence. | Différé |
| Q-26 | Qui gère les chauffeurs et l'affectation des véhicules ? | Détermine la frontière Equipment / Logistics / Workforce. | Workforce chauffeur ; Equipment véhicule ; Logistics tournée. | Important |
| Q-27 | Qui déclare l'avancement : Projects, Planning ou TimeTracking ? | Détermine la source de l'avancement contractuel et opérationnel. | Projects contractuel ; Planning activités ; TimeTracking temps. | Validé — V-25 |
| Q-28 | Quel horizon de planning est ferme et qui arbitre les conflits ? | Détermine la stabilité du planning et les responsabilités. | Horizon à définir ; arbitrage direction. | Important |
| Q-29 | Qui gère les EPI et les autorisations de travail : Safety ou Workforce ? | Détermine la frontière sécurité / RH. | Safety pour l'opérationnel ; Workforce pour la formation. | Important |
| Q-30 | Une réserve peut-elle être levée sans clôture d'une NCR ? | Détermine le lien Handover ↔ Quality. | Non si la réserve a une cause technique ; oui si elle est documentaire. | Validé — V-26 |
| Q-31 | Qui possède le DOE : Handover ou Documents ? | Détermine la constitution et le stockage du DOE. | Handover pour la complétude contractuelle ; Documents pour le stockage. | Important |
| Q-32 | Comment distinguer le statut métier et le statut documentaire ? | Évite deux validations concurrentes. | Deux dimensions distinctes, propriétaires différents. | Important |
| Q-33 | Quelle valeur légale donner à la signature électronique et à l'archivage ? | Détermine les exigences de preuve et de conservation. | À définir avec le juridique. | Différé |
| Q-34 | Quelles exigences de fraîcheur, de lignée et d'accès pour Reporting ? | Détermine le modèle de reporting et les contrats de lecture. | Documenter source, formule, période, propriétaire. | Important |
| Q-35 | Quels rôles, périmètres et comptes externes pour Identity ? | Détermine l'autorisation et les accès clients/fournisseurs. | Rôles explicites, comptes externes sur décision. | Important |
| Q-36 | Quelle stratégie d'identifiants : auto-incrément, UUID, ULID ? | Détermine les références inter-domaines. | UUID stables pour les références publiques ; version et format de génération à préciser dans les conventions techniques. | Validé — V-16 |
| Q-37 | Quelle unité monétaire, devise et règle d'arrondi ? | Détermine tous les échanges financiers. | Montants en unité entière ou décimale fixe, devise EUR. | Important |
| Q-38 | C2ME est-elle une seule entité juridique ou plusieurs établissements ? | Détermine les périmètres et les rapports. | À clarifier avec la direction. | Différé |
| Q-39 | Quel périmètre hors connexion et quelle stratégie de conflit ? | Détermine les interactions de saisie et d'idempotence. | Serveur autorité ; conflits explicites. | Important |
| Q-40 | Quelles règles de confidentialité et de conservation pour RH, paie, sécurité et documents ? | Détermine les accès et la rétention. | À définir avec le juridique et la direction. | Important |
| Q-41 | Comment formaliser la sous-traitance dans les deux sens ? | Détermine les objets et les flux Clients/Projects/Procurement/Handover. | Deux parcours distincts, sans objet unique ambigu. | Validé — V-27 |
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
| Q-53 | Quelles conditions exactes autorisent la clôture d'une affaire et dans quel ordre ? | Détermine l'enchaînement Handover / Costing / Budgets / Projects. | Réception, réserves levées, DOE, coûts et budget clôturés, puis affaire clôturée. | Validé — V-28 |

### 6.2 Questions à traiter avant le Lot 2

Les questions suivantes étaient bloquantes pour la matrice technique ; elles ont toutes été arbitrées et validées (voir section 6.4) :

- Q-01, Q-02, Q-05, Q-09, Q-10, Q-12, Q-17, Q-19, Q-23, Q-27, Q-30, Q-36, Q-41 et Q-53 sont désormais arbitrées (section 6.4).

### 6.3 Questions pouvant être différées

- Q-25 : calibration des équipements de mesure ;
- Q-33 : signature électronique et archivage légal ;
- Q-38 : structure juridique multi-établissements ;
- Q-48 : données de santé et restrictions d'aptitude.

### 6.4 Arbitrages des 14 questions bloquantes — validés le 16/11/2026

| Question | Décision validée | Décision |
| --- | --- | --- |
| Q-01 | Une affaire peut regrouper plusieurs chantiers ; chaque chantier appartient à une seule affaire. | V-17 |
| Q-02 | Un même tiers peut cumuler plusieurs rôles par affaire : client, donneur d'ordre, maître d'ouvrage et/ou payeur. | V-18 |
| Q-05 | Clients est propriétaire du référentiel maître unique des tiers. Procurement conserve la relation d'achat et les données fournisseur spécifiques, sans dupliquer l'identité du tiers. | V-15 |
| Q-09 | L'engagement financier est reconnu à l'approbation de la commande fournisseur. | V-19 |
| Q-10 | Costing possède l'EAC et le calcule à partir des faits opérationnels et engagements. | V-20 |
| Q-12 | TimeTracking constate les événements et durées ; Workforce qualifie le motif RH. | V-21 |
| Q-17 | Inventory possède le référentiel maître des articles ; Procurement possède les références d'achat propres aux fournisseurs. | V-22 |
| Q-19 | Le stock de chantier est un emplacement temporaire du stock central sous contrôle d'Inventory. | V-23 |
| Q-23 | Workshop porte l'acceptation technique ; Quality statue sur la conformité ; Procurement clôt l'aspect commercial. | V-24 |
| Q-27 | Projects porte l'avancement contractuel ; Planning l'avancement des activités ; TimeTracking les temps réalisés. | V-25 |
| Q-30 | Une réserve documentaire peut être clôturée sans NCR ; une réserve technique requiert le traitement de la NCR correspondante. | V-26 |
| Q-36 | Les références publiques inter-domaines utilisent des UUID stables ; la version de génération reste à préciser lors de l'implémentation. | V-16 |
| Q-41 | Sous-traitance confiée : Procurement ; sous-traitance reçue : Projects/Clients. | V-27 |
| Q-53 | Clôture après réception, levée des réserves, DOE, clôture des coûts et clôture du budget. | V-28 |

**Contrôle de cohérence.** Ces arbitrages ne créent aucun domaine supplémentaire et respectent les 18 domaines figés (V-01). Le choix Clients comme référentiel maître des tiers ne transfère pas à Clients les commandes fournisseurs : Procurement conserve la relation d'achat, les conditions et références spécifiques. L'identité du tiers est référencée par UUID public. Le stock de chantier reste dans le référentiel central Inventory. Les responsabilités d'avancement et de sous-traitance restent séparées selon leur nature métier. Aucun arbitrage ne crée à lui seul un contrat, un événement, une transaction partagée ou un composant applicatif.

## 6.5 Arbitrages métier complémentaires — questionnaire Lot 2 (16/11/2026)

Les décisions V-29 à V-59 ci-dessous proviennent des réponses explicites du responsable du projet au questionnaire de clarification métier (31 réponses). Elles complètent les décisions V-01 à V-28. Lorsqu'elles contredisent une ancienne proposition du Lot 1, la décision validée ci-dessous prévaut. Elles définissent des responsabilités métier et des règles de processus ; elles ne valent pas autorisation technique d'accès direct.

| ID | Question | Décision validée |
| --- | --- | --- |
| V-29 | Q1 — Fin du cycle commercial | Clients porte le cycle commercial jusqu'à la signature du devis accepté ; Projects prend le relais après signature. |
| V-30 | Q2 — Ouverture d'affaire | La transformation d'un devis accepté en affaire exige une validation explicite de l'utilisateur ; elle n'est pas automatique. |
| V-31 | Q3 — Conditions | Clients possède les conditions commerciales générales/cadre ; Projects possède les conditions contractuelles propres à l'affaire. |
| V-32 | Q4 — Budget initial | Le budget initial est créé à partir du devis accepté, avec répartition automatique des lignes du devis. |
| V-33 | Q5 — Dépassement d'achat | Une commande fournisseur dépassant le disponible budgétaire déclenche une alerte Budgets ; aucun blocage automatique de Procurement n'est imposé. |
| V-34 | Q6 — EAC | Costing calcule automatiquement et actualise continuellement l'EAC à partir des faits opérationnels et engagements disponibles. |
| V-35 | Q7 — Propriété du devis | Clients produit et possède le devis complet, y compris les prix et les lignes de travaux. |
| V-36 | Q8 — Structure du budget | Le budget est structuré par lignes de travaux du devis accepté. |
| V-37 | Q9 — Avenant | Un avenant accepté révise automatiquement le budget initial, en conservant l'historique des versions et modifications. |
| V-38 | Q10 — Alerte budgétaire | L'alerte budgétaire retenue concerne le dépassement du disponible par une commande fournisseur. |
| V-39 | Q11 — Sources EAC | L'EAC prend en compte les commandes et factures, les temps et coûts de main-d'œuvre, les consommations de stock, l'avancement et le reste à faire. |
| V-40 | Q12 — Construction du devis | Clients construit manuellement le devis ; Costing ne produit pas le devis et intervient sur le suivi économique/rentabilité. |
| V-41 | Q13 — Chantier principal | Le chantier principal est créé automatiquement lors de la création de l'affaire. |
| V-42 | Q14 — Avancement contractuel | Seul Projects peut modifier l'avancement contractuel, après validation d'un responsable. |
| V-43 | Q15 — Avenant et notifications | Un avenant accepté notifie les domaines concernés par les changements de périmètre, selon les besoins réels ; pas de diffusion systématique à tous. |
| V-44 | Q16 — Planning initial | Le planning initial est créé automatiquement lors de la création de l'affaire. |
| V-45 | Q17 — Affectation des salariés | Workforce décide des affectations ; Planning fournit les besoins opérationnels. |
| V-46 | Q18 — Saisie des temps | Les salariés et les chefs d'équipe peuvent tous deux saisir les temps. |
| V-47 | Q19 — Validation des temps | Le service administratif/RH valide les temps avant leur utilisation dans les processus aval. |
| V-48 | Q20 — Ordres de fabrication | Les ordres de fabrication sont créés manuellement par le bureau d'études ou le responsable atelier. |
| V-49 | Q21 — Validation technique atelier | Le responsable atelier (Workshop) valide techniquement les fabrications. |
| V-50 | Q22 — Demande d'achat | Le responsable travaux ou atelier crée la demande ; Procurement la transforme en commande fournisseur. |
| V-51 | Q23 — Mouvements de stock | Tout salarié disposant des droits requis peut enregistrer un mouvement de stock ; l'auteur doit être traçable. |
| V-52 | Q24 — Déclaration NCR | Tout salarié autorisé peut déclarer une non-conformité ; Quality en assure la qualification et le suivi. |
| V-53 | Q25 — Clôture NCR | Le responsable travaux ou atelier, selon l'origine, clôture la non-conformité avec validation de Quality. |
| V-54 | Q26 — Contrôles sécurité | Safety définit les règles et contrôles ; les responsables de chantier les exécutent et déclarent les écarts. |
| V-55 | Q27 — Réception | Projects organise la réception contractuelle ; Handover prépare et centralise les livrables et documents de réception. |
| V-56 | Q28 — Dépôt documentaire | Tout salarié autorisé peut déposer des documents, avec classement et métadonnées obligatoires. |
| V-57 | Q29 — Validation documentaire | Le domaine métier propriétaire valide le contenu ; le responsable de l'affaire donne l'approbation finale. |
| V-58 | Q30 — Reporting | Reporting combine les publications de données/indicateurs des domaines et les consultations via leurs contrats publics. Tout accès direct aux tables internes est interdit. |
| V-59 | Q31 — Clôture administrative | Le service administratif vérifie les conditions et prononce la clôture après confirmation des domaines concernés. Projects conserve la responsabilité du cycle de vie de l'affaire. |

**Contrôle de cohérence.** V-29, V-35 et V-40 remplacent la proposition antérieure qui attribuait le devis à Projects : Clients est désormais propriétaire du devis complet. Projects conserve l'affaire, le contrat, le chantier et l'avancement contractuel. V-58 confirme l'interdiction d'accès direct aux bases des domaines et reste conforme à V-09/V-10 et CHAN-28. V-59 attribue la décision administrative finale au service administratif, sans transférer à celui-ci la propriété du cycle de vie de l'affaire. Les décisions de création automatique d'un chantier et d'un planning définissent des déclenchements métier ; elles n'autorisent aucun accès direct aux composants internes des domaines concernés.

## 7. Décisions et points restant à qualifier

### 7.1 Décisions structurantes

| Décision | Options | Recommandation | Impact |
| --- | --- | --- | --- |
| Référentiel tiers | Clients maître / Procurement maître / deux référentiels reliés | Clients est le référentiel maître unique (V-15). | Détermine les échanges Clients ↔ Procurement et la qualité des données. |
| Relation affaire/chantier | 1–1 / 1–N / N–N | Affaire 1–N chantiers (V-17). | Détermine les axes de Planning, Budgets, Costing. |
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
- [x] Le stock central est la référence ; le stock de chantier est un emplacement temporaire sous contrôle d'Inventory.
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
