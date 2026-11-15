# Catalogue des objets métier

Ce document recense les objets métier identifiés pour les 18 domaines de **C2ME Chantier**, leur propriétaire pressenti, leurs informations principales et leurs consommateurs potentiels.

- Ticket : CHAN-29 — Documenter les frontières et dépendances autorisées.
- Lot : Lot 1 — Inventaire et cartographie des responsabilités métier.
- Portée : définition, propriété, informations principales et consommateurs des objets métier.
- Hors portée : modèle de données, schéma de base, classes PHP, contrats techniques et événements.

> **Statut du document — Lot 1.**
> Le catalogue décrit des **objets métier cibles**, pas des tables ou des classes existantes. Aucun modèle Eloquent métier n'existe à ce jour dans `app/Domains/`. Les propriétaires indiqués sont des propositions de cadrage, sauf lorsque la propriété découle d'une décision validée.

## 1. Convention de lecture

### 1.1 Identifiants

| Élément | Convention | Exemple |
| --- | --- | --- |
| Domaine | `D01` à `D18` | `D11` Inventory |
| Objet | Préfixe du domaine + numéro | `INV-05` MouvementDeStock |
| Processus | `P01` à `P12` | `P05` Approvisionnement |
| Chevauchement | `BD-xx` | `BD-06` |
| Question ouverte | `Q-xx` | `Q-19` |

### 1.2 Propriété

Un objet est **possédé** par un domaine lorsque ce domaine est la seule autorité sur :

- sa définition et ses invariants ;
- ses états et transitions ;
- ses règles d'écriture, de correction et de suppression ;
- ses règles d'autorisation ;
- la décision de l'exposer ou non à d'autres domaines.

Un domaine consommateur peut lire ou utiliser une information via un contrat public ou un événement, mais ne modifie jamais l'objet directement.

### 1.3 Objets et données

Un objet métier n'est pas nécessairement une table. Il peut être :

- une entité persistée (Affaire, Client, Commande) ;
- un agrégat de plusieurs données (Budget, Dossier de fabrication) ;
- un fait ou un événement métier (Réception, Incident) ;
- un référentiel (Article, Qualification) ;
- un document ou un ensemble documentaire (DOE).

Le catalogue ne présume pas de la structure de persistance. Les décisions de modélisation relèvent des tickets d'implémentation.

### 1.4 Consommateurs

Les consommateurs listés sont **potentiels**. Un objet n'est exposé que si un consommateur réel en a besoin, conformément à CHAN-28. L'absence d'un consommateur dans le tableau ne signifie pas que l'objet est inutile ; elle signifie qu'aucun besoin inter-domaines n'a été identifié à ce stade.

Le catalogue n'est pas un dictionnaire exhaustif de chaque terme employé dans les fiches de domaine. Certains concepts — par exemple un échéancier, un plan d'urgence, un EPI ou un dossier de conformité — peuvent rester des attributs, des regroupements ou des objets internes tant qu'un besoin métier autonome n'est pas démontré. Ils ne doivent pas être transformés en objets persistés sans décision d'implémentation.

## 2. Vue d'ensemble

| Domaine | Nombre d'objets | Objets principaux |
| --- | ---: | --- |
| D01 Identity | 6 | Utilisateur, Rôle, Permission |
| D02 Clients | 6 | Prospect, Client, Contact, RôleTiers |
| D03 Projects | 10 | Affaire, Chantier, Devis, Avenant |
| D04 Planning | 6 | PlanDeCharge, Activité, Affectation |
| D05 Budgets | 5 | Budget, LigneBudgétaire, Révision |
| D06 Costing | 8 | Chiffrage, Coût, Engagement, Marge |
| D07 Workforce | 9 | Collaborateur, Contrat, Qualification |
| D08 TimeTracking | 6 | Pointage, FeuilleDeTemps, Absence |
| D09 Workshop | 9 | OrdreDeFabrication, Opération, Colis |
| D10 Procurement | 10 | Fournisseur, CommandeDAchat, CommandeDeSousTraitance |
| D11 Inventory | 10 | Article, Réception, Mouvement, Réservation |
| D12 Equipment | 7 | Équipement, Maintenance, Inspection |
| D13 Logistics | 7 | PlanDeTransport, Livraison, Retour |
| D14 Quality | 8 | PlanQualité, Contrôle, NonConformité |
| D15 Safety | 8 | AnalyseDeRisques, Incident, Habilitation |
| D16 Documents | 6 | Document, Version, Diffusion |
| D17 Handover | 6 | Réception, Réserve, DOE, GarantieClient |
| D18 Reporting | 5 | Rapport, Indicateur, Snapshot |
| **Total** | **132** | — |

## 3. Catalogue par domaine

### 3.1 D01 — Identity

| ID | Objet | Définition | Informations principales | Consommateurs potentiels |
| --- | --- | --- | --- | --- |
| IDN-01 | Utilisateur | Compte permettant à un acteur d'accéder à l'application. | Identifiant, acteur rattaché, statut, dates, moyens d'authentification. | Tous |
| IDN-02 | Rôle | Ensemble cohérent de permissions attribué à un utilisateur. | Code, libellé, permissions, périmètre, statut. | Tous |
| IDN-03 | Permission | Autorisation d'exécuter une action sur une ressource. | Code, ressource, ability, description. | Identity, domaines |
| IDN-04 | PérimètreDAccès | Limite organisationnelle ou fonctionnelle d'un droit. | Type, valeur, unités, affaires ou sites concernés. | Tous |
| IDN-05 | Délégation | Transfert temporaire de droits d'un acteur à un autre. | Délégant, délégataire, période, périmètre, statut. | Identity, domaines |
| IDN-06 | UnitéOrganisationnelle | Structure interne de C2ME (direction, agence, atelier, dépôt). | Code, libellé, parent, responsable, statut. | Identity, Workforce, Reporting |

### 3.2 D02 — Clients

| ID | Objet | Définition | Informations principales | Consommateurs potentiels |
| --- | --- | --- | --- | --- |
| CLI-01 | Prospect | Rôle commercial de prospect exercé par un tiers, en phase de qualification. | Référence du tiers (selon Q-05), contacts, origine, besoin, qualification, statut. | Projects, Reporting |
| CLI-02 | Client | Rôle commercial de client ou donneur d'ordre exercé par un tiers ; ne présume pas une identité juridique autonome. | Référence du tiers (selon Q-05), contacts, conditions, statut, responsable commercial. | Projects, Handover, Reporting |
| CLI-03 | ContactClient | Personne de contact chez un prospect ou un client. | Nom, fonction, coordonnées, préférences, statut. | Projects, Handover |
| CLI-04 | RôleTiers | Rôle exercé par un tiers dans une relation ou une affaire ; ne présume pas une identité juridique autonome. | Type de rôle, tiers, affaire, période, statut. | Projects, Handover |
| CLI-05 | RelationCommerciale | Suivi de la relation entre C2ME et un client ou prospect. | Responsable, segmentation, statut, historique, actions. | Projects, Reporting |
| CLI-06 | ConditionsCommercialesCadre | Conditions commerciales négociées au niveau du client. | Paiement, remises, validité, clauses particulières, statut. | Projects |

### 3.3 D03 — Projects

| ID | Objet | Définition | Informations principales | Consommateurs potentiels |
| --- | --- | --- | --- | --- |
| PRJ-01 | Affaire | Unité contractuelle et de pilotage d'un engagement client. | Numéro, client, donneur d'ordre, contrat, montant, dates, statut. | Tous |
| PRJ-02 | Chantier | Lieu physique d'exécution des travaux d'une affaire. | Adresse, accès, dates, responsable, statut, contraintes. | Planning, Logistics, Safety, Quality |
| PRJ-03 | LotPhase | Subdivision technique ou temporelle d'une affaire ou d'un chantier. | Code, description, quantité, montant, dates, statut. | Planning, Budgets, Costing, Quality |
| PRJ-04 | Étude | Dossier technique préalable à une offre ou à une exécution. | Périmètre, hypothèses, plans, calculs, statut, version. | Costing, Workshop, Documents |
| PRJ-05 | Devis | Proposition commerciale chiffrée adressée à un client. | Version, périmètre, prix, conditions, validité, statut. | Clients, Costing, Budgets, Documents |
| PRJ-06 | CommandeClient | Commande ou ordre de service reçu d'un client. | Référence, date, montant, périmètre, délais, statut. | Budgets, Costing, Planning |
| PRJ-07 | Avenant | Modification contractuelle du périmètre, du prix ou des délais. | Référence, objet, montant, délai, statut, validation. | Budgets, Costing, Planning, Handover |
| PRJ-08 | Contrat | Engagement juridique encadrant une affaire. | Parties, objet, montant, clauses, dates, documents. | Clients, Documents, Costing |
| PRJ-09 | JalonContractuel | Événement daté engageant contractuellement l'affaire. | Libellé, date, condition, statut, responsable. | Planning, Handover, Reporting |
| PRJ-10 | ActeurAffaire | Rôle d'un acteur sur une affaire. | Acteur, rôle, période, responsabilité, statut. | Identity, Projects, Reporting |

### 3.4 D04 — Planning

| ID | Objet | Définition | Informations principales | Consommateurs potentiels |
| --- | --- | --- | --- | --- |
| PLN-01 | PlanDeCharge | Plan global des activités et des ressources sur un horizon. | Horizon, version, statut, activités, charge. | Projects, Workforce, Equipment |
| PLN-02 | ActivitéPlanifiée | Tâche datée rattachée à une affaire, un lot ou un atelier. | Affaire, lot, dates, durée, dépendances, statut. | Projects, TimeTracking, Workshop |
| PLN-03 | AffectationRessource | Affectation d'une ressource à une activité. | Ressource, activité, période, charge, statut. | Workforce, Equipment, Workshop |
| PLN-04 | CalendrierCapacité | Disponibilité d'une ressource sur une période. | Ressource, capacité, exceptions, jours ouvrés. | Planning, Workforce, Equipment |
| PLN-05 | ConflitPlanning | Surcharge ou incompatibilité détectée dans le plan. | Ressource, période, cause, impact, statut. | Projects, direction |
| PLN-06 | AvancementActivité | État d'avancement d'une activité planifiée. | Prévu, réalisé, reste à faire, retard, statut. | Projects, Costing, Reporting |

### 3.5 D05 — Budgets

| ID | Objet | Définition | Informations principales | Consommateurs potentiels |
| --- | --- | --- | --- | --- |
| BUD-01 | Budget | Enveloppe budgétaire validée d'une affaire. | Affaire, version active, montant, marge cible, statut. | Projects, Costing, Procurement |
| BUD-02 | VersionBudget | Version datée d'un budget. | Numéro, date, auteur, motif, statut. | Budgets, Costing, Reporting |
| BUD-03 | LigneBudgétaire | Ligne de budget par lot, nature et période. | Code, libellé, lot, nature, montant, période. | Costing, Procurement |
| BUD-04 | RévisionBudgétaire | Modification de l'enveloppe ou des lignes. | Motif, montant, justification, validation, statut. | Projects, Costing |
| BUD-05 | Contingence | Réserve budgétaire pour aléas. | Montant, motif, consommation, statut. | Projects, Costing |

### 3.6 D06 — Costing

| ID | Objet | Définition | Informations principales | Consommateurs potentiels |
| --- | --- | --- | --- | --- |
| CST-01 | Chiffrage | Estimation prévisionnelle du coût d'une offre ou d'une affaire. | Périmètre, quantités, prix, marge, hypothèses, version. | Projects, Budgets |
| CST-02 | Coût | Coût constaté ou prévisionnel imputé à une affaire. | Nature, montant, date, source, affaire, lot. | Projects, Budgets, Reporting |
| CST-03 | Engagement | Engagement financier résultant d'une commande ou d'un contrat. | Source, montant, reste à consommer, statut. | Budgets, Procurement, Projects |
| CST-04 | ImputationAnalytique | Affectation d'un coût à un axe d'analyse. | Axe, affaire, lot, nature, clé de répartition. | Costing, Reporting |
| CST-05 | Marge | Écart entre prix de vente et coût. | Montant, taux, prévisionnel/réalisé, statut. | Projects, Budgets, Reporting |
| CST-06 | ÉcartCoût | Différence entre budget, engagement ou coût constaté. | Cause, montant, période, statut. | Budgets, Projects |
| CST-07 | ProvisionAnalytique | Provision pour risque ou coût à venir. | Motif, montant, période, statut. | Budgets, Reporting |
| CST-08 | PériodeAnalytique | Période de clôture des coûts. | Dates, statut, responsable, date de clôture. | Costing, Reporting |

### 3.7 D07 — Workforce

| ID | Objet | Définition | Informations principales | Consommateurs potentiels |
| --- | --- | --- | --- | --- |
| WKF-01 | Collaborateur | Personne employée par C2ME. | Identité, matricule, poste, statut, unité, dates. | Planning, TimeTracking, Identity, Safety |
| WKF-02 | ContratDeTravail | Contrat liant un collaborateur à C2ME. | Type, dates, durée, statut, conditions. | Workforce, Costing |
| WKF-03 | Poste | Emploi ou fonction occupée. | Libellé, classification, compétences requises, statut. | Workforce, Planning |
| WKF-04 | Qualification | Qualification RH reconnue d'un collaborateur (diplôme, formation). | Type, niveau, validité, preuve, statut. | Planning, Quality, Safety |
| WKF-05 | Formation | Action de formation suivie ou planifiée. | Intitulé, date, durée, organisme, validité. | Workforce, Safety, Quality |
| WKF-06 | Équipe | Groupe de travail organisé. | Code, responsable, membres, périmètre, statut. | Planning, TimeTracking |
| WKF-07 | DisponibilitéRH | Disponibilité ou indisponibilité d'un collaborateur. | Période, type, motif, statut. | Planning, TimeTracking |
| WKF-08 | ÉlémentVariableDePaie | Donnée variable transmise au prestataire de paie. | Type, période, quantité ou montant, statut. | Workforce, prestataire de paie |
| WKF-09 | DossierRH | Ensemble des données administratives et RH d'un collaborateur. | Documents, statut, confidentialité, historique. | Workforce |

### 3.8 D08 — TimeTracking

| ID | Objet | Définition | Informations principales | Consommateurs potentiels |
| --- | --- | --- | --- | --- |
| TKT-01 | Pointage | Événement de temps enregistré par un collaborateur. | Collaborateur, date, horaires, durée, type, imputation. | Workforce, Costing, Planning |
| TKT-02 | FeuilleDeTemps | Regroupement de pointages sur une période. | Collaborateur, période, total, statut. | Workforce, Costing |
| TKT-03 | ImputationDeTemps | Affectation d'un temps à une affaire, un lot ou une activité. | Affaire, lot, activité, type, durée. | Costing, Projects |
| TKT-04 | PériodeDePointage | Période de saisie et de verrouillage des temps. | Dates, statut, responsable, date de verrouillage. | TimeTracking, Workforce |
| TKT-05 | CorrectionDeTemps | Correction tracée d'un pointage ou d'une feuille. | Pointage, motif, acteur, date, ancienne/nouvelle valeur. | TimeTracking, audit |
| TKT-06 | ÉvénementDAbsence | Absence constatée d'un collaborateur. | Collaborateur, dates, type, justification, statut. | Workforce, Planning |

### 3.9 D09 — Workshop

| ID | Objet | Définition | Informations principales | Consommateurs potentiels |
| --- | --- | --- | --- | --- |
| WKS-01 | OrdreDeFabrication | Ordre de produire un ensemble ou un composant. | Numéro, affaire, lot, quantité, dates, statut. | Projects, Planning, Costing |
| WKS-02 | DossierDeFabrication | Dossier technique d'atelier. | Plans, nomenclatures, instructions, version, statut. | Workshop, Quality, Documents |
| WKS-03 | OpérationDeFabrication | Étape de la gamme de fabrication. | Libellé, poste, durée, ordre, statut. | Workshop, Planning, Costing |
| WKS-04 | PosteDeFabrication | Moyen de production de l'atelier. | Code, capacité, disponibilité, statut. | Planning, Workshop |
| WKS-05 | DemandeMatière | Besoin matière d'un ordre de fabrication. | Article, quantité, date, statut. | Inventory |
| WKS-06 | CompteRenduDeProduction | Compte rendu d'exécution d'un OF. | Quantités, heures, incidents, rebuts, statut. | Workshop, Costing, Quality |
| WKS-07 | ColisDeFabrication | Ensemble emballé prêt à expédier. | Référence, contenu, poids, dimensions, statut. | Logistics, Inventory |
| WKS-08 | DossierDeFabricationExterne | Dossier technique confié à un prestataire. | Périmètre, exigences, pièces, statut. | Procurement, Quality |
| WKS-09 | CapacitéAtelier | Capacité disponible par poste et période. | Poste, période, capacité, charge, statut. | Planning, Projects |

### 3.10 D10 — Procurement

| ID | Objet | Définition | Informations principales | Consommateurs potentiels |
| --- | --- | --- | --- | --- |
| PRC-01 | Fournisseur | Rôle de fournisseur exercé par un tiers ; ne présume pas une identité juridique autonome. Le rattachement au référentiel juridique dépend de Q-05. | Référence du tiers (selon Q-05), contacts, conditions d'achat, qualification, statut. | Procurement, Inventory, Costing |
| PRC-02 | SousTraitant | Rôle de sous-traitant exercé par un tiers ; ne présume pas une identité juridique autonome. Le rattachement au référentiel juridique dépend de Q-05. | Référence du tiers (selon Q-05), spécialité, qualification, conditions, statut. | Procurement, Workshop, Quality, Safety |
| PRC-03 | DemandeDAchat | Besoin d'achat exprimé par un domaine. | Article ou service, quantité, date, budget, statut. | Procurement, Budgets |
| PRC-04 | OffreFournisseur | Proposition reçue d'un fournisseur. | Fournisseur, prix, délai, validité, statut. | Procurement, Costing |
| PRC-05 | CommandeDAchat | Engagement d'achat auprès d'un fournisseur. | Numéro, fournisseur, lignes, montant, dates, statut. | Inventory, Costing, Budgets |
| PRC-06 | LigneDeCommande | Ligne d'article ou de service d'une commande. | Article, quantité, prix, date, statut. | Inventory, Costing |
| PRC-07 | CommandeDeSousTraitance | Engagement de sous-traitance auprès d'un prestataire. | Sous-traitant, périmètre, montant, dates, statut. | Workshop, Quality, Costing |
| PRC-08 | ÉvaluationFournisseur | Évaluation de la performance d'un fournisseur. | Critères, note, période, statut. | Procurement, Quality, Safety |
| PRC-09 | AccordCadre | Contrat cadre avec un fournisseur ou sous-traitant. | Fournisseur, conditions, validité, statut. | Procurement, Budgets |
| PRC-10 | GarantieFournisseur | Garantie accordée par un fournisseur ou un sous-traitant. | Fournisseur, objet, durée, conditions, preuve, statut. | Procurement, Handover |

### 3.11 D11 — Inventory

| ID | Objet | Définition | Informations principales | Consommateurs potentiels |
| --- | --- | --- | --- | --- |
| INV-01 | Article | Référence de stock. | Code, désignation, unité, catégorie, seuils, statut. | Procurement, Workshop, Costing |
| INV-02 | Entrepôt | Lieu de stockage central. | Code, adresse, responsable, statut. | Inventory, Logistics |
| INV-03 | Emplacement | Localisation dans un entrepôt. | Code, zone, capacité, statut. | Inventory |
| INV-04 | LotDeStock | Lot traçable d'un article. | Numéro, article, quantité, date, statut. | Workshop, Projects, Quality, Costing |
| INV-05 | MouvementDeStock | Entrée, sortie ou transfert de stock. | Type, article, quantité, date, motif, acteur. | Costing, Reporting |
| INV-06 | RéceptionDeStock | Réception physique d'une commande. | Commande, fournisseur, quantités, écarts, statut. | Procurement, Quality, Costing |
| INV-07 | RéservationDeStock | Stock réservé pour une affaire ou un OF. | Article, quantité, affaire/OF, statut. | Workshop, Projects |
| INV-08 | ConsommationMatière | Matière consommée par une affaire ou un OF. | Article, quantité, affaire/OF, date. | Costing |
| INV-09 | BonDeSortie | Document autorisant la sortie de stock. | Numéro, colis, destination, date, statut. | Logistics, Projects |
| INV-10 | InventairePhysique | Comptage physique du stock. | Entrepôt, date, écarts, statut. | Inventory, Costing |

### 3.12 D12 — Equipment

| ID | Objet | Définition | Informations principales | Consommateurs potentiels |
| --- | --- | --- | --- | --- |
| EQP-01 | Équipement | Actif matériel de C2ME (machine, véhicule, moyen de levage). | Code, catégorie, caractéristiques, statut. | Planning, Logistics, Costing |
| EQP-02 | CatégorieÉquipement | Famille d'équipements. | Code, libellé, exigences, statut. | Equipment, Planning |
| EQP-03 | AffectationÉquipement | Affectation d'un équipement à un chantier, atelier ou location. | Équipement, destination, période, responsable, statut. | Planning, Logistics |
| EQP-04 | PlanDeMaintenance | Plan de maintenance préventive. | Équipement, périodicité, opérations, prochaine date. | Equipment, Planning |
| EQP-05 | InterventionDeMaintenance | Intervention préventive ou curative. | Équipement, type, dates, coût, statut. | Equipment, Costing |
| EQP-06 | InspectionRéglementaire | Inspection ou contrôle réglementaire. | Équipement, organisme, date, validité, résultat. | Safety, Quality |
| EQP-07 | Panne | Indisponibilité d'un équipement. | Équipement, date, cause, réparation, statut. | Planning, Costing |

### 3.13 D13 — Logistics

| ID | Objet | Définition | Informations principales | Consommateurs potentiels |
| --- | --- | --- | --- | --- |
| LOG-01 | DemandeDeTransport | Besoin de transport exprimé par un domaine. | Expédition, destination, date, contraintes, statut. | Logistics, Inventory |
| LOG-02 | PlanDeTransport | Plan d'organisation des transports. | Tournées, moyens, transporteur, dates, statut. | Logistics, Projects |
| LOG-03 | Tournée | Séquence de livraisons ou d'enlèvements. | Véhicule, chauffeur, arrêts, horaires, statut. | Logistics, Equipment |
| LOG-04 | Livraison | Opération de livraison d'un colis ou d'un matériel. | Colis, destinataire, date, statut, preuve. | Projects, Inventory |
| LOG-05 | RéceptionChantier | Réception d'une livraison sur le chantier. | Livraison, quantités, état, réserves, statut. | Inventory, Quality, Projects |
| LOG-06 | Retour | Retour de matériel, d'emballage ou d'équipement. | Origine, destination, contenu, statut. | Inventory, Equipment |
| LOG-07 | AccèsChantier | Conditions d'accès et de circulation sur un site. | Site, horaires, autorisations, contraintes, statut. | Logistics, Safety |

### 3.14 D14 — Quality

| ID | Objet | Définition | Informations principales | Consommateurs potentiels |
| --- | --- | --- | --- | --- |
| QUA-01 | PlanQualité | Plan définissant les exigences et contrôles qualité d'une affaire. | Affaire, exigences, contrôles, responsabilités, statut. | Projects, Workshop |
| QUA-02 | PlanDeContrôle | Plan détaillé des points de contrôle. | Points, critères, méthodes, fréquences, statut. | Quality, Workshop |
| QUA-03 | ContrôleQualité | Contrôle, essai ou mesure réalisé. | Point, date, résultat, preuve, statut. | Quality, Workshop, Projects |
| QUA-04 | NonConformité | Écart constaté par rapport à une exigence. | Description, cause, gravité, traitement, statut. | Quality, Workshop, Procurement |
| QUA-05 | ActionCorrective | Action destinée à corriger ou prévenir une non-conformité. | Cause, action, responsable, échéance, statut. | Quality, Workshop, Procurement |
| QUA-06 | AuditQualité | Audit d'un processus, d'un fournisseur ou d'un site. | Périmètre, critères, résultats, statut. | Quality, Procurement |
| QUA-07 | CertificatQualité | Certificat attestant une conformité. | Objet, norme, validité, preuve, statut. | Quality, Handover |
| QUA-08 | QualificationTechnique | Qualification d'une personne ou d'un processus technique. | Titulaire/processus, norme, validité, preuve, statut. | Quality, Workshop |

### 3.15 D15 — Safety

| ID | Objet | Définition | Informations principales | Consommateurs potentiels |
| --- | --- | --- | --- | --- |
| SAF-01 | AnalyseDeRisques | Analyse des risques d'une activité ou d'un site. | Activité, risques, mesures, statut. | Safety, Projects, Workshop |
| SAF-02 | PlanDePrévention | Plan des mesures de prévention. | Site, intervenants, risques, mesures, statut. | Safety, Projects |
| SAF-03 | InspectionSécurité | Inspection des conditions de sécurité. | Lieu, date, constats, actions, statut. | Safety, Projects |
| SAF-04 | Incident | Incident, accident ou presqu'accident. | Date, lieu, gravité, causes, statut. | Safety, Projects, Workforce |
| SAF-05 | ActionSécurité | Action de correction ou de prévention. | Cause, action, responsable, échéance, statut. | Safety, Projects |
| SAF-06 | HabilitationSécurité | Autorisation d'exercer une tâche à risque. | Personne, type, validité, preuve, statut. | Safety, Workforce, Planning |
| SAF-07 | AutorisationDeTravail | Autorisation d'intervenir dans des conditions données. | Travail, lieu, période, conditions, statut. | Safety, Projects |
| SAF-08 | InductionSécurité | Accueil et sensibilisation sécurité sur un site. | Personne, site, date, contenu, statut. | Safety, Workforce |

### 3.16 D16 — Documents

| ID | Objet | Définition | Informations principales | Consommateurs potentiels |
| --- | --- | --- | --- | --- |
| DOC-01 | Document | Document produit ou reçu, identifié et classé. | Titre, type, propriétaire, statut, référence. | Tous |
| DOC-02 | VersionDocument | Version datée d'un document. | Numéro, date, auteur, fichier, statut. | Tous |
| DOC-03 | DossierDocumentaire | Ensemble organisé de documents. | Nom, classification, documents, droits. | Tous |
| DOC-04 | TypeDocument | Catégorie de document avec ses règles. | Code, libellé, règles, conservation. | Tous |
| DOC-05 | DiffusionDocument | Diffusion d'un document à un destinataire. | Document, destinataire, date, accusé, statut. | Tous |
| DOC-06 | RègleDeConservation | Règle de durée et de sort final d'un document. | Durée, déclencheur, archive, statut. | Documents |

### 3.17 D17 — Handover

| ID | Objet | Définition | Informations principales | Consommateurs potentiels |
| --- | --- | --- | --- | --- |
| HND-01 | Réception | Réception contractuelle totale ou partielle des travaux. | Affaire, lots, date, participants, statut, PV. | Projects, Clients |
| HND-02 | Réserve | Écart contractuel constaté à la réception. | Description, localisation, délai, responsable, statut. | Quality, Projects |
| HND-03 | LevéeDeRéserve | Preuve et décision de levée d'une réserve. | Réserve, preuve, date, vérificateur, statut. | Handover, Quality |
| HND-04 | DOE | Dossier des ouvrages exécutés remis au client. | Affaire, pièces, complétude, statut. | Clients, Documents |
| HND-05 | GarantieClient | Garantie cliente attachée à un ouvrage ou à une fourniture. | Type, objet, début, fin, conditions, statut. | Clients, Projects |
| HND-06 | DossierDeClôture | Ensemble des pièces et vérifications nécessaires à la clôture contractuelle. | Affaire, réception, réserves levées, DOE, garanties, statut. | Projects, Handover, Costing |

### 3.18 D18 — Reporting

| ID | Objet | Définition | Informations principales | Consommateurs potentiels |
| --- | --- | --- | --- | --- |
| RPT-01 | Rapport | Document de synthèse produit à partir de données consolidées. | Titre, périmètre, période, sources, statut. | Direction, domaines |
| RPT-02 | TableauDeBord | Ensemble d'indicateurs présentés pour un public et une période. | Indicateurs, filtres, période, audience. | Direction |
| RPT-03 | Indicateur | Mesure calculée à partir d'une ou plusieurs sources. | Définition, formule, source, valeur, période. | Direction |
| RPT-04 | Snapshot | Instantané daté de données ou d'indicateurs. | Date, périmètre, données figées, statut. | Reporting, audit |
| RPT-05 | Export | Extraction de données ou de rapports dans un format donné. | Format, périmètre, date, destinataire, statut. | Direction, Documents |

## 4. Objets transverses et concepts partagés

Certains concepts traversent plusieurs domaines. Ils ne doivent pas être dupliqués sous forme de copies autonomes : un domaine propriétaire est désigné, les autres domaines référencent son identifiant public.

| Concept | Propriétaire pressenti | Autres domaines concernés | Règle de partage |
| --- | --- | --- | --- |
| Acteur / utilisateur | Identity | Tous | Identity fournit l'identité et les droits ; les domaines ne stockent pas de copie faisant autorité. |
| Collaborateur | Workforce | Planning, TimeTracking, Costing, Safety | Workforce est la source RH ; Planning et TimeTracking référencent le collaborateur. |
| Rôle commercial (prospect/client) | Clients (sous réserve Q-05) | Projects, Handover, Reporting | Clients porte le rôle commercial et la relation ; l'identité juridique reste à arbitrer. |
| Donneur d'ordre | Clients | Projects, Handover | Le rôle est porté par Clients, contextualisé par affaire dans Projects ; le périmètre exact des rôles reste à valider Q-02. |
| Rôle fournisseur / sous-traitant | Procurement (sous réserve Q-05) | Inventory, Workshop, Quality, Safety, Costing | Procurement porte les rôles d'achat et la relation ; l'identité juridique reste à arbitrer. |
| Affaire | Projects | Tous | Projects est la source de l'affaire, de ses lots et de ses jalons. |
| Chantier | Projects | Planning, Logistics, Safety, Quality, Handover | Projects est la source du site et de son cycle de vie. |
| Lot / phase | Projects | Planning, Budgets, Costing, Quality, Handover | Projects est la source de la structure contractuelle ; les autres domaines l'utilisent comme axe. |
| Article / référence | Inventory | Procurement, Workshop, Costing | Inventory est la source de l'article et du stock ; Procurement gère les références fournisseur. |
| Équipement | Equipment | Planning, Logistics, Safety, Quality, Costing | Equipment est la source de l'actif et de sa disponibilité. |
| Document | Documents | Tous | Documents porte le contenant et la version ; le domaine propriétaire porte le contenu et la validité métier. |
| Réception contractuelle | Handover | Projects, Clients, Quality | Handover est la source du fait contractuel ; Quality fournit les preuves techniques. |
| Coût / engagement | Costing | Projects, Budgets, Procurement, Reporting | Costing est la source des coûts et engagements financiers ; Procurement reste propriétaire de la commande et de l'acte commercial. |
| Budget | Budgets | Projects, Costing, Procurement | Budgets est la source de l'enveloppe autorisée. |
| Planning | Planning | Projects, Workforce, Equipment, Workshop | Planning est la source des activités et affectations datées. |
| Indicateur | Reporting | Direction, domaines | Reporting calcule et expose ; la source reste le domaine producteur. |

### 4.1 Règles de référence entre objets

1. Une référence inter-domaines utilise un identifiant public stable, pas un Model Eloquent.
2. Un domaine ne stocke pas une copie complète d'un objet d'un autre domaine ; il stocke au besoin une référence et les attributs strictement nécessaires à sa responsabilité.
3. Une copie d'affichage ou un cache ne devient jamais la source de vérité.
4. Une donnée dupliquée doit être identifiée comme telle et rafraîchie selon une règle explicite.
5. Une suppression dans le domaine propriétaire ne doit pas laisser les consommateurs dans un état incohérent ; les règles de conservation et de désactivation restent à définir.

### 4.2 Référentiel des tiers

Un même tiers peut cumuler plusieurs rôles. Le catalogue distingue cinq dimensions qui ne doivent pas être confondues :

| Dimension | Propriétaire ou statut | Objets concernés | Règle de lecture |
| --- | --- | --- | --- |
| Identité juridique de l'entité | **Non arbitré — Q-05** | Aucun objet dédié dans ce lot | Peut être portée par Clients, par Procurement ou par un référentiel partagé. Aucune option n'est choisie. |
| Rôle commercial de prospect, client ou donneur d'ordre | Clients | `CLI-01`, `CLI-02`, `CLI-04` | Le rôle décrit la relation commerciale ; il ne prouve pas à lui seul l'identité juridique. |
| Rôle de fournisseur | Procurement | `PRC-01` | Le rôle décrit la relation d'achat ; il ne prouve pas à lui seul l'identité juridique. |
| Rôle de sous-traitant | Procurement | `PRC-02` | Le rôle décrit la relation de sous-traitance ; il ne prouve pas à lui seul l'identité juridique. |
| Qualification métier ou achat du tiers | Procurement, avec Quality et Safety selon le domaine | `PRC-02`, `PRC-08`, qualification fournisseur | La qualification porte sur l'aptitude à réaliser une prestation, pas sur l'identité juridique. |

La présence simultanée de `CLI-02 Client`, `PRC-01 Fournisseur` et `PRC-02 SousTraitant` ne signifie donc pas que le même tiers possède trois identités juridiques. Ces objets représentent des rôles métier. Le portage définitif du référentiel juridique — option A, option B ou autre solution — reste explicitement ouvert tant que Q-05 n'est pas tranchée.

## 5. Objets non retenus ou à confirmer

Les objets suivants ne sont pas retenus comme objets autonomes dans ce lot, faute de décision métier suffisante. Ils sont documentés comme questions ouvertes.

| Sujet | Pourquoi il n'est pas autonome | Question |
| --- | --- | --- |
| Opportunité commerciale | Peut être un prospect qualifié, une étude ou un objet spécifique selon l'organisation commerciale. | Q-03 |
| Stock de chantier autonome | Le ticket ne présume pas d'un stock complet par chantier ; le stock temporaire doit être arbitré. | Q-19 |
| Facture client / fournisseur | Aucun domaine financier parmi les 18 ; le périmètre de facturation et de paiement n'est pas défini. | Q-07 |
| Réclamation client | Peut relever de Handover, Quality ou Projects selon la nature. | Q-49 |
| Risque d'affaire | Peut être un attribut de l'étude/de l'affaire, un registre séparé ou un objet Reporting. | Q-51 |
| Permis et autorisations administratives | Souvent portés par le client ou la collectivité ; leur suivi peut être un attribut de l'affaire. | Q-52 |
| Contrat de sous-traitance reçu | Dans la sous-traitance reçue, l'engagement est une affaire ; dans la sous-traitance donnée, c'est une commande Procurement. | Q-41 |
| Contrat de travail intérimaire | Peut relever de Workforce ou de Procurement selon la nature de la relation. | Q-15 |
| Calibration des équipements de mesure | Peut relever d'Equipment ou de Quality. | Q-25 |

## 6. Règles de propriété et de cycle de vie

### 6.1 Création

- Un objet est créé par son domaine propriétaire, à la suite d'une opération métier autorisée.
- Un domaine consommateur ne crée pas un objet d'un autre domaine « par commodité ».
- Lorsqu'un besoin inter-domaines nécessite une création, le fournisseur expose une commande explicite, avec ses invariants et son autorisation.

### 6.2 Modification

- Seul le domaine propriétaire modifie l'objet.
- Une modification demandée par un autre domaine passe par un contrat ou un événement, jamais par une écriture directe.
- Les corrections et ajustements sont tracés.

### 6.3 Suppression et désactivation

- Un objet référencé par un autre domaine ne doit pas être supprimé sans règle de conservation.
- La désactivation ou l'archivage est préféré à la suppression lorsque l'historique est nécessaire.
- Les règles de conservation légale (RH, paie, sécurité, documents, garanties) restent à définir.

### 6.4 États

- Les états et transitions sont définis par le domaine propriétaire.
- Un consommateur ne déduit pas un état métier à partir d'un champ technique ou d'une date, sauf contrat explicite.
- Un état partagé doit être exposé comme une information stable, pas comme un enum interne non documenté.

## 7. Références

- [`domain-responsibilities.md`](domain-responsibilities.md) — responsabilités des 18 domaines.
- [`business-processes.md`](business-processes.md) — processus métier.
- [`domain-interactions-register.md`](domain-interactions-register.md) — interactions.
- [`domain-boundary-decisions.md`](domain-boundary-decisions.md) — chevauchements et questions ouvertes.
- [`domain-conventions.md`](domain-conventions.md) — conventions internes CHAN-27.
- [`domain-communication.md`](domain-communication.md) — contrats synchrones CHAN-28.
