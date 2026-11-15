# Registre des interactions métier entre domaines

Ce document recense les interactions métier nécessaires entre les 18 domaines de **C2ME Chantier**.

- Ticket : CHAN-29 — Documenter les frontières et dépendances autorisées.
- Lot : Lot 1 — Inventaire et cartographie des responsabilités métier.
- Portée : besoins d'échange métier, source, destinataire, motif, informations, moment et nature pressentie.
- Hors portée : matrice technique des dépendances autorisées/interdites (Lot 2), choix contrat/événement (CHAN-28), format des DTO, transport, idempotence technique.

> **Statut du document — Lot 1.**
> Ce registre décrit des **besoins d'échange métier**, pas des dépendances techniques autorisées. Une ligne du registre ne crée aucun contrat, aucun événement et aucun accès direct. La forme technique de chaque échange relève de CHAN-28 et du Lot 2 de CHAN-29.

## 1. Objet et principes

### 1.1 Objet

Le registre permet de répondre aux questions suivantes :

- quel domaine a besoin d'une information produite par un autre domaine ;
- pourquoi cette information est nécessaire ;
- à quel moment elle est nécessaire ;
- quelles données minimelles doivent circuler ;
- si l'échange est une consultation, une notification, une demande, une décision ou un document ;
- quels processus métier dépendent de cet échange.

### 1.2 Principes

1. **Le fournisseur est propriétaire.** Le domaine qui produit l'information reste responsable de sa validité, de ses invariants et de son autorisation.
2. **Le consommateur ne modifie pas.** Il utilise l'information sans écrire dans le domaine fournisseur.
3. **Pas de dépendance aux composants internes.** Aucun Model, Action, Service, DTO interne, Policy ou table d'un autre domaine ne traverse la frontière.
4. **Pas de transaction partagée implicite.** Une interaction ne doit pas créer une atomicité inter-domaines non décidée.
5. **Pas d'anticipation.** Un échange n'est retenu que si un consommateur réel et un besoin métier sont identifiés.
6. **Le registre ne décide pas de la forme.** Une ligne « Notification » peut être couverte par un événement ou un contrat de lecture ; le choix appartient à CHAN-28 et au Lot 2.
7. **Les documents ne sont pas des données métier.** Un échange documentaire transporte un contenu et des métadonnées ; il ne transfère pas la propriété du contenu.

### 1.3 Nature des interactions

| Nature | Signification | Réponse attendue |
| --- | --- | --- |
| **Référentiel** | Donnée de référence relativement stable, nécessaire à l'identification ou au rattachement. | Lecture ou synchronisation contrôlée. |
| **Consultation** | Lecture d'une information à la demande. | Réponse immédiate ou rapport. |
| **Notification** | Fait accompli qu'un autre domaine doit connaître. | Aucune réponse métier obligatoire ; le consommateur peut réagir. |
| **Demande** | Besoin d'une action, d'une vérification ou d'une production. | Réponse ou exécution par le fournisseur. |
| **Décision** | Validation, autorisation ou arbitrage. | Résultat explicite : accordé, refusé, conditionnel. |
| **Document** | Échange d'un document versionné et de ses métadonnées. | Accusé de réception ou diffusion contrôlée. |

Les natures sont métier. Elles ne préjugent pas du mécanisme technique : contrat synchrone, événement, file d'attente, export ou document.

## 2. Vue d'ensemble

### 2.1 Volume par section

| Section (domaine directeur) | Nombre d'interactions | Identifiants |
| --- | ---: | --- |
| D01 Identity | 5 | INT-001 à INT-005 |
| D02 Clients | 6 | INT-006 à INT-011 |
| D03 Projects | 25 | INT-012 à INT-036 |
| D04 Planning | 16 | INT-037 à INT-052 |
| D05 Budgets | 5 | INT-053 à INT-057 |
| D06 Costing | 10 | INT-058 à INT-067 |
| D07 Workforce | 8 | INT-068 à INT-075 |
| D08 TimeTracking | 1 | INT-076 |
| D09 Workshop | 11 | INT-077 à INT-087 |
| D10 Procurement | 8 | INT-088 à INT-095 |
| D11 Inventory | 5 | INT-096 à INT-100 |
| D12 Equipment | 6 | INT-101 à INT-106 |
| D13 Logistics | 1 | INT-107 |
| D14 Quality | 3 | INT-108 à INT-110 |
| D15 Safety | 3 | INT-111 à INT-113 |
| D16 Documents | 4 | INT-114 à INT-117 |
| D17 Handover | 5 | INT-118 à INT-122 |
| D18 Reporting | 3 | INT-123 à INT-125 |
| **Total** | **125** | — |

> **Lecture.** Les sections sont organisées par domaine directeur du registre ; elles contiennent des interactions entrantes et sortantes. Le nombre d'interactions d'une section ne mesure donc pas l'importance du domaine. Projects, Planning et Workshop concentrent naturellement les besoins de coordination d'exécution. Le tableau des interactions reçues, en section 4, donne la lecture par destinataire.

### 2.2 Interactions prioritaires pour le Lot 2

Les interactions suivantes structurent les frontières et doivent être arbitrées en priorité :

| Priorité | Interaction | Enjeu |
| --- | --- | --- |
| 1 | Clients → Projects / Projects → Clients | Frontière entre relation commerciale et engagement contractuel. |
| 2 | Projects → Planning / Planning → Projects | Frontière entre engagement contractuel et organisation des interventions. |
| 3 | Budgets ↔ Costing | Frontière entre enveloppe autorisée, chiffrage, engagements et coûts constatés. |
| 4 | Procurement ↔ Inventory | Frontière entre commande, réception et stock. |
| 5 | Workshop ↔ Inventory | Frontière entre ordre de fabrication et mouvements de matière. |
| 6 | Quality ↔ Handover | Frontière entre conformité technique et réception contractuelle. |
| 7 | Workforce ↔ TimeTracking | Frontière entre données RH, temps et variables de paie. |
| 8 | Documents ↔ tous | Frontière entre contenu métier et gestion documentaire. |
| 9 | Procurement ↔ Workshop | Frontière entre sous-traitance donnée, dossier technique et acceptation. |
| 10 | Projects ↔ Handover | Frontière entre achèvement, réception, clôture contractuelle et clôture d'affaire. |

## 3. Registre détaillé

### 3.1 D01 — Identity

| ID | Source | Destinataire | Motif | Informations concernées | Moment | Nature | Processus |
| --- | --- | --- | --- | --- | --- | --- | --- |
| INT-001 | D01 Identity | Tous les domaines | Identifier l'acteur et vérifier ses droits | Identifiant d'acteur, rôles, permissions, périmètre, statut | Authentification et chaque opération autorisée | Référentiel | P01–P12 |
| INT-002 | D01 Identity | D18 Reporting | Restreindre l'accès aux rapports | Périmètre, rôles, droits de consultation | Consultation d'un rapport | Référentiel | P10 |
| INT-003 | D07 Workforce | D01 Identity | Aligner le compte avec la vie du collaborateur | Arrivée, départ, changement de poste ou d'unité, date d'effet | Cycle de vie RH | Notification | P03, P09 |
| INT-004 | D02 Clients | D01 Identity | Ouvrir un accès externe éventuel à un contact client | Identité du contact, client, périmètre, demande du client | Si un portail client est décidé | Demande | P12 |
| INT-005 | D10 Procurement | D01 Identity | Ouvrir un accès externe éventuel à un fournisseur ou sous-traitant | Identité du tiers, contact, périmètre, demande | Si un portail fournisseur est décidé | Demande | P05, P07 |

> **Point ouvert.** INT-004 et INT-005 sont conditionnelles : aucun portail externe n'est présumé existant. La décision d'ouvrir des comptes externes relève de Q-35 et d'une décision de sécurité.

### 3.2 D02 — Clients

| ID | Source | Destinataire | Motif | Informations concernées | Moment | Nature | Processus |
| --- | --- | --- | --- | --- | --- | --- | --- |
| INT-006 | D02 Clients | D03 Projects | Identifier le client, le donneur d'ordre et les conditions | Identité légale, contacts, rôles, adresses, conditions cadre, statut | Étude, devis, ouverture d'affaire | Référentiel | P01, P02 |
| INT-007 | D03 Projects | D02 Clients | Mettre à jour la relation et le statut du client | Affaire ouverte, commande, réception, clôture, incident relationnel | Cycle de vie de l'affaire | Notification | P01, P02, P12 |
| INT-008 | D02 Clients | D03 Projects | Lancer une étude à partir d'un prospect qualifié | Besoin, contacts, maturité, échéance, documents disponibles | Qualification commerciale | Demande | P01 |
| INT-009 | D02 Clients | D17 Handover | Identifier les représentants du client à la réception | Contacts, rôles, coordonnées, pouvoirs de réception | Préparation de la réception | Référentiel | P12 |
| INT-010 | D17 Handover | D02 Clients | Mettre à jour la relation avec la réception et les garanties | PV, réserves, levées, DOE, dates de garantie | Réception et clôture | Notification | P12 |
| INT-011 | D02 Clients | D18 Reporting | Analyser le portefeuille et la relation commerciale | Prospects, clients, affaires, chiffre d'affaires, statut relationnel | Reporting commercial | Consultation | P10 |

### 3.3 D03 — Projects

| ID | Source | Destinataire | Motif | Informations concernées | Moment | Nature | Processus |
| --- | --- | --- | --- | --- | --- | --- | --- |
| INT-012 | D03 Projects | D04 Planning | Fournir le périmètre et les jalons à planifier | Affaire, chantier, lots, jalons contractuels, priorités, contraintes de site | Préparation et replanification | Référentiel | P03, P04, P09 |
| INT-013 | D04 Planning | D03 Projects | Alimenter le pilotage contractuel | Planning, dates prévisionnelles, avancement des activités, conflits | Préparation et suivi | Notification | P04, P10 |
| INT-014 | D03 Projects | D05 Budgets | Établir ou réviser l'enveloppe budgétaire | Périmètre, lots, montant du contrat, avenants, besoin budgétaire | Ouverture et révision | Demande | P01, P03 |
| INT-015 | D05 Budgets | D03 Projects | Valider et suivre l'enveloppe | Budget validé, disponible, seuils, écarts, alertes | Ouverture et suivi | Décision | P01, P03, P10 |
| INT-016 | D03 Projects | D06 Costing | Fournir la référence contractuelle et analytique | Affaire, lots, montants contractuels, avenants, avancement, événements | Tout le cycle | Référentiel | P01–P12 |
| INT-017 | D06 Costing | D03 Projects | Alerter sur la marge et les dérives | Coût réel, EAC, marge, écarts, alertes | Suivi et clôture | Notification | P10, P12 |
| INT-018 | D03 Projects | D09 Workshop | Demander une fabrication ou une étude d'atelier | Besoin, lot, dossier technique, dates, priorités | Préparation et lancement | Demande | P03, P06 |
| INT-019 | D09 Workshop | D03 Projects | Informer sur la fabrication | Avancement, disponibilité, contraintes, retards, achèvement | Exécution | Notification | P06, P09 |
| INT-020 | D03 Projects | D10 Procurement | Exprimer un besoin d'achat ou de sous-traitance non couvert par l'atelier | Prestation, spécifications, quantité, date, lot, budget | Préparation et exécution | Demande | P03, P09 |
| INT-021 | D10 Procurement | D03 Projects | Informer sur les engagements et livraisons | Commande, fournisseur, montant, dates, statut, retards | Approvisionnement | Notification | P05, P09 |
| INT-022 | D03 Projects | D14 Quality | Fournir les exigences de conformité | Périmètre, spécifications, exigences contractuelles, jalons, points d'arrêt | Préparation et exécution | Référentiel | P03, P11 |
| INT-023 | D14 Quality | D03 Projects | Informer sur la conformité et les blocages | Résultats de contrôle, NCR, gravité, blocage, certificats | Exécution et réception | Notification | P11 |
| INT-024 | D03 Projects | D15 Safety | Fournir les sites, activités et intervenants à couvrir | Sites, activités, planning, sous-traitants, risques connus | Préparation et exécution | Référentiel | P03, P09 |
| INT-025 | D15 Safety | D03 Projects | Informer sur la prévention et les incidents | Plan de prévention, consignes, inspections, incidents, autorisations | Exécution et réception | Notification | P09, P11 |
| INT-026 | D03 Projects | D16 Documents | Verser les documents contractuels et d'exécution | Contrats, études, devis, plans, PV, documents de site | Tout le cycle | Document | P01–P12 |
| INT-027 | D16 Documents | D03 Projects | Fournir les références documentaires contrôlées | Référence, version, statut, diffusion, liens | Tout le cycle | Référentiel | P01–P12 |
| INT-028 | D03 Projects | D17 Handover | Demander la réception d'un lot ou de l'affaire | Périmètre, lots, client, dates, achèvement, documents | Achèvement | Demande | P12 |
| INT-029 | D17 Handover | D03 Projects | Informer sur la réception et les réserves | Réception, réserves, levées, PV, conditions de clôture | Réception et clôture | Notification | P12 |
| INT-030 | D03 Projects | D13 Logistics | Fournir les contraintes d'accès et de livraison | Site, adresse, accès, horaires, destinataires, contraintes | Préparation logistique | Référentiel | P08, P09 |
| INT-031 | D13 Logistics | D03 Projects | Informer sur les livraisons | Statut, date, réception, écarts, avaries | Livraison | Notification | P08, P09 |
| INT-032 | D03 Projects | D08 TimeTracking | Fournir les axes d'imputation du temps | Affaire, chantier, lot, activité, centre de coût | Saisie et validation | Référentiel | P10 |
| INT-033 | D08 TimeTracking | D03 Projects | Alimenter l'avancement contractuel | Temps par lot, avancement constaté, absences | Suivi | Notification | P10 |
| INT-034 | D03 Projects | D11 Inventory | Exprimer un besoin de matériel pour le chantier | Article, quantité, date, lot, destination | Préparation et exécution | Demande | P05, P09 |
| INT-035 | D11 Inventory | D03 Projects | Informer sur la disponibilité et les sorties | Disponibilité, réservation, sortie, pénurie | Exécution | Notification | P05, P09 |
| INT-036 | D03 Projects | D18 Reporting | Alimenter le pilotage des affaires | Portefeuille, avancement, engagements, réception, clôture | Reporting | Consultation | P10, P12 |

### 3.4 D04 — Planning

| ID | Source | Destinataire | Motif | Informations concernées | Moment | Nature | Processus |
| --- | --- | --- | --- | --- | --- | --- | --- |
| INT-037 | D04 Planning | D07 Workforce | Exprimer les besoins en ressources humaines | Activités, périodes, qualifications, charge, lieu | Planification | Demande | P04 |
| INT-038 | D07 Workforce | D04 Planning | Fournir la disponibilité et les contraintes RH | Collaborateurs, équipes, qualifications, disponibilité, contrat | Planification | Référentiel | P04 |
| INT-039 | D04 Planning | D12 Equipment | Exprimer les besoins en équipements | Équipement, activité, période, site, conditions | Planification | Demande | P04 |
| INT-040 | D12 Equipment | D04 Planning | Fournir la disponibilité des équipements | Disponibilité, maintenance, inspections, affectations | Planification | Référentiel | P04 |
| INT-041 | D04 Planning | D09 Workshop | Réserver des créneaux d'atelier | OF, activité, période, priorité, contraintes | Planification | Demande | P04, P06 |
| INT-042 | D09 Workshop | D04 Planning | Fournir la capacité et l'avancement atelier | Capacité, durées, charge, avancement, retards | Planification et suivi | Référentiel | P04, P06 |
| INT-043 | D04 Planning | D10 Procurement | Exprimer les besoins datés et les délais critiques | Articles, services, dates, quantités, priorités | Planification | Demande | P04, P05 |
| INT-044 | D10 Procurement | D04 Planning | Fournir les délais et dates de livraison | Délais, dates prévues, retards, alternatives | Planification | Référentiel | P04, P05 |
| INT-045 | D04 Planning | D11 Inventory | Vérifier la disponibilité matière | Articles, quantités, dates, réservations | Planification | Demande | P04, P05 |
| INT-046 | D11 Inventory | D04 Planning | Signaler les pénuries et disponibilités | Disponibilité, pénurie, réservation, réapprovisionnement | Planification et suivi | Notification | P04, P05 |
| INT-047 | D04 Planning | D13 Logistics | Exprimer les besoins de transport | Colis, dates, destinations, contraintes | Planification logistique | Demande | P04, P08 |
| INT-048 | D13 Logistics | D04 Planning | Fournir les contraintes et dates de transport | Délais, capacités, accès, incidents | Planification | Référentiel | P04, P08 |
| INT-049 | D04 Planning | D08 TimeTracking | Fournir les activités à pointer | Activité, affaire, lot, période, responsable | Saisie des temps | Référentiel | P10 |
| INT-050 | D08 TimeTracking | D04 Planning | Alimenter la replanification | Temps réels, absences, avancement, écarts | Replanification | Notification | P04, P10 |
| INT-051 | D15 Safety | D04 Planning | Signaler les restrictions d'affectation | Habilitation, autorisation, restriction, expiration | Planification | Notification | P04, P09 |
| INT-052 | D04 Planning | D18 Reporting | Alimenter le pilotage de la charge | Charge, planning, conflits, respect des délais | Reporting | Consultation | P10 |

### 3.5 D05 — Budgets

| ID | Source | Destinataire | Motif | Informations concernées | Moment | Nature | Processus |
| --- | --- | --- | --- | --- | --- | --- | --- |
| INT-053 | D05 Budgets | D06 Costing | Fournir la référence budgétaire | Enveloppe, lignes, lots, natures, période | Élaboration et suivi | Référentiel | P03, P10 |
| INT-054 | D06 Costing | D05 Budgets | Alimenter l'analyse budgétaire | Engagements, coûts constatés, EAC, écarts | Suivi et clôture | Notification | P10 |
| INT-055 | D05 Budgets | D10 Procurement | Autoriser un engagement dans le disponible | Disponible, seuil, nature, lot, conditions | Validation d'achat | Décision | P05 |
| INT-056 | D10 Procurement | D05 Budgets | Informer sur la consommation de l'enveloppe | Commande, montant, engagement, annulation, variation | Commande et suivi | Notification | P05 |
| INT-057 | D05 Budgets | D18 Reporting | Alimenter le pilotage budgétaire | Budget, consommation, écarts, prévisions | Reporting | Consultation | P10 |

### 3.6 D06 — Costing

| ID | Source | Destinataire | Motif | Informations concernées | Moment | Nature | Processus |
| --- | --- | --- | --- | --- | --- | --- | --- |
| INT-058 | D08 TimeTracking | D06 Costing | Valoriser la main-d'œuvre | Heures validées, affaire, lot, nature, taux | Période de coût | Notification | P10 |
| INT-059 | D11 Inventory | D06 Costing | Valoriser la matière consommée | Article, quantité, lot, valorisation, affaire | Mouvement de stock | Notification | P05, P10 |
| INT-060 | D10 Procurement | D06 Costing | Enregistrer les engagements et offres | Commande, montant, fournisseur, variations, offres | Étude, commande et suivi | Notification | P01, P05, P07 |
| INT-061 | D09 Workshop | D06 Costing | Valoriser la production atelier | Heures, matière, rebuts, coûts atelier, OF | Production | Notification | P06, P10 |
| INT-062 | D12 Equipment | D06 Costing | Valoriser l'utilisation des équipements | Utilisation, maintenance, panne, location | Utilisation | Notification | P09, P10 |
| INT-063 | D13 Logistics | D06 Costing | Valoriser le transport | Coût, affaire, lot, transporteur, incident | Livraison | Notification | P08, P10 |
| INT-064 | D14 Quality | D06 Costing | Valoriser la non-qualité | NCR, reprise, rebut, temps, coût | Traitement qualité | Notification | P11 |
| INT-065 | D15 Safety | D06 Costing | Valoriser la prévention et les incidents | Coût de prévention, arrêt, incident, action | Prévention et incident | Notification | P11 |
| INT-066 | D07 Workforce | D06 Costing | Fournir les taux de référence | Taux horaire, poste, contrat, période | Valorisation | Référentiel | P10 |
| INT-067 | D06 Costing | D18 Reporting | Alimenter le pilotage économique | Coûts, marges, écarts, EAC, tendances | Reporting | Consultation | P10 |

### 3.7 D07 — Workforce

| ID | Source | Destinataire | Motif | Informations concernées | Moment | Nature | Processus |
| --- | --- | --- | --- | --- | --- | --- | --- |
| INT-068 | D07 Workforce | D08 TimeTracking | Fournir les données nécessaires au pointage | Collaborateur, équipe, contrat, droits à absence, période | Saisie et validation | Référentiel | P10 |
| INT-069 | D08 TimeTracking | D07 Workforce | Préparer les variables de paie | Temps validés, absences, heures supplémentaires, primes | Cycle de paie | Notification | P10 |
| INT-070 | D07 Workforce | D05 Budgets | Fournir les hypothèses de coût RH | Taux, postes, effectifs, disponibilité | Élaboration budgétaire | Référentiel | P01, P03 |
| INT-071 | D07 Workforce | D15 Safety | Fournir les formations et qualifications | Formation, qualification, validité, preuve | Affectation et prévention | Référentiel | P04, P09 |
| INT-072 | D15 Safety | D07 Workforce | Exprimer les exigences de formation et signaler les incidents | Exigence, habilitation, incident, restriction | Prévention | Demande | P04, P11 |
| INT-073 | D07 Workforce | D14 Quality | Fournir les qualifications techniques disponibles | Qualification, validité, titulaire, preuve | Contrôle qualité | Référentiel | P11 |
| INT-074 | D07 Workforce | D18 Reporting | Alimenter le pilotage RH | Effectifs, qualifications, absences, masse salariale | Reporting | Consultation | P10 |
| INT-075 | D07 Workforce | Prestataire de paie (externe) | Transmettre les éléments de paie | Variables, absences, contrat, période, centre de coût | Cycle de paie | Document | P10 |

> **Hors domaines.** INT-075 sort du périmètre des 18 domaines : le prestataire de paie est externe. Il est documenté pour mémoire, car il consomme des données produites par Workforce et TimeTracking.

### 3.8 D08 — TimeTracking

| ID | Source | Destinataire | Motif | Informations concernées | Moment | Nature | Processus |
| --- | --- | --- | --- | --- | --- | --- | --- |
| INT-076 | D08 TimeTracking | D18 Reporting | Alimenter le pilotage des temps | Heures, absences, présence, taux, affaire | Reporting | Consultation | P10 |

> Les interactions sortantes principales de TimeTracking sont déjà décrites : INT-050 vers Planning, INT-058 vers Costing, INT-069 vers Workforce, INT-033 vers Projects.

### 3.9 D09 — Workshop

| ID | Source | Destinataire | Motif | Informations concernées | Moment | Nature | Processus |
| --- | --- | --- | --- | --- | --- | --- | --- |
| INT-077 | D09 Workshop | D11 Inventory | Demander la matière nécessaire à un OF | Article, quantité, date, OF, lot | Lancement et exécution | Demande | P06 |
| INT-078 | D11 Inventory | D09 Workshop | Répondre sur la disponibilité matière | Disponibilité, réservation, sortie, pénurie, substitution | Exécution | Notification | P06 |
| INT-079 | D09 Workshop | D10 Procurement | Demander une fabrication ou une opération externe | Dossier technique, périmètre, quantité, date, exigences | Décision de faire-faire | Demande | P07 |
| INT-080 | D10 Procurement | D09 Workshop | Informer sur la commande externe | Sous-traitant, commande, délai, statut, réception | Sous-traitance | Notification | P07 |
| INT-081 | D09 Workshop | D14 Quality | Demander un contrôle ou signaler un écart | OF, opération, autocontrôle, caractéristique, NCR | Production | Demande | P06, P11 |
| INT-082 | D14 Quality | D09 Workshop | Informer sur la conformité et les reprises | Résultat, NCR, reprise, refus, certificat | Production | Notification | P06, P11 |
| INT-083 | D09 Workshop | D13 Logistics | Signaler un colis prêt à expédier | Colis, poids, dimensions, destination, date | Expédition | Demande | P08 |
| INT-084 | D13 Logistics | D09 Workshop | Informer sur l'enlèvement et la livraison | Statut, date, incident, retour | Expédition | Notification | P08 |
| INT-085 | D09 Workshop | D16 Documents | Verser les dossiers et documents de fabrication | Plans, nomenclatures, comptes rendus, PV | Production | Document | P03, P06 |
| INT-086 | D16 Documents | D09 Workshop | Fournir les versions contrôlées | Référence, version, statut, diffusion | Production | Référentiel | P03, P06 |
| INT-087 | D09 Workshop | D18 Reporting | Alimenter le pilotage atelier | Capacité, avancement, rebuts, délais | Reporting | Consultation | P10 |

### 3.10 D10 — Procurement

| ID | Source | Destinataire | Motif | Informations concernées | Moment | Nature | Processus |
| --- | --- | --- | --- | --- | --- | --- | --- |
| INT-088 | D10 Procurement | D11 Inventory | Annoncer les commandes et livraisons attendues | Commande, article, quantité, fournisseur, date, statut | Commande et approvisionnement | Notification | P05 |
| INT-089 | D11 Inventory | D10 Procurement | Signaler les besoins et écarts de réception | Stock, pénurie, réception, écart, retour | Réapprovisionnement et réception | Notification | P05 |
| INT-090 | D10 Procurement | D14 Quality | Fournir les données de qualification | Fournisseur, sous-traitant, certificats, historique | Sélection | Référentiel | P05, P07 |
| INT-091 | D14 Quality | D10 Procurement | Alimenter l'évaluation fournisseur | NCR, audit, conformité, performance | Suivi fournisseur | Notification | P05, P07 |
| INT-092 | D15 Safety | D10 Procurement | Signaler la conformité sécurité d'un sous-traitant | Documents, habilitation, incident, restriction | Sélection et suivi | Notification | P05, P07 |
| INT-093 | D10 Procurement | D13 Logistics | Demander l'organisation d'un transport | Enlèvement, livraison, fournisseur, date, colis | Approvisionnement | Demande | P05, P08 |
| INT-094 | D13 Logistics | D10 Procurement | Informer sur le transport | Statut, incident, retard, avarie | Livraison | Notification | P08 |
| INT-095 | D10 Procurement | D18 Reporting | Alimenter le pilotage des achats | Commandes, engagements, délais, performance | Reporting | Consultation | P10 |

### 3.11 D11 — Inventory

| ID | Source | Destinataire | Motif | Informations concernées | Moment | Nature | Processus |
| --- | --- | --- | --- | --- | --- | --- | --- |
| INT-096 | D11 Inventory | D13 Logistics | Demander l'expédition d'un colis | Colis, poids, dimensions, destination, date | Expédition | Demande | P08 |
| INT-097 | D13 Logistics | D11 Inventory | Confirmer la livraison ou signaler un écart | Statut, réception, retour, avarie, manque | Livraison | Notification | P08 |
| INT-098 | D11 Inventory | D14 Quality | Demander un contrôle à réception | Article, lot, fournisseur, quantité, exigence | Réception | Demande | P05 |
| INT-099 | D14 Quality | D11 Inventory | Statuer sur la réception | Accepté, refusé, quarantaine, NCR | Réception | Notification | P05 |
| INT-100 | D11 Inventory | D18 Reporting | Alimenter le pilotage du stock | Stock, rotation, écarts, pénuries | Reporting | Consultation | P10 |

### 3.12 D12 — Equipment

| ID | Source | Destinataire | Motif | Informations concernées | Moment | Nature | Processus |
| --- | --- | --- | --- | --- | --- | --- | --- |
| INT-101 | D12 Equipment | D13 Logistics | Fournir les véhicules et moyens disponibles | Équipement, disponibilité, capacité, affectation | Transport | Référentiel | P08 |
| INT-102 | D13 Logistics | D12 Equipment | Signaler l'utilisation, le retour ou la panne | Usage, compteur, état, panne, retour | Transport | Notification | P08 |
| INT-103 | D12 Equipment | D15 Safety | Fournir le statut des inspections et certificats | Inspection, validité, certificat, blocage | Utilisation | Notification | P09, P11 |
| INT-104 | D12 Equipment | D10 Procurement | Demander un achat, une location ou une maintenance externe | Équipement, besoin, date, fournisseur, budget | Acquisition et maintenance | Demande | P05 |
| INT-105 | D10 Procurement | D12 Equipment | Informer sur la commande ou la location | Statut, dates, fournisseur, coût | Acquisition et maintenance | Notification | P05 |
| INT-106 | D12 Equipment | D18 Reporting | Alimenter le pilotage du parc | Disponibilité, utilisation, maintenance, coûts | Reporting | Consultation | P10 |

### 3.13 D13 — Logistics

| ID | Source | Destinataire | Motif | Informations concernées | Moment | Nature | Processus |
| --- | --- | --- | --- | --- | --- | --- | --- |
| INT-107 | D13 Logistics | D18 Reporting | Alimenter le pilotage logistique | Délais, coûts, incidents, retours | Reporting | Consultation | P10 |

> Les interactions sortantes principales de Logistics sont déjà décrites : INT-031 vers Projects, INT-048 vers Planning, INT-084 vers Workshop, INT-094 vers Procurement, INT-063 vers Costing, INT-097 vers Inventory, INT-102 vers Equipment.

### 3.14 D14 — Quality

| ID | Source | Destinataire | Motif | Informations concernées | Moment | Nature | Processus |
| --- | --- | --- | --- | --- | --- | --- | --- |
| INT-108 | D14 Quality | D16 Documents | Verser les preuves et certificats | Rapports, contrôles, certificats, NCR, actions | Contrôle et clôture | Document | P11 |
| INT-109 | D14 Quality | D17 Handover | Fournir les preuves de conformité | Contrôles, essais, certificats, NCR clôturées | Réception | Document | P12 |
| INT-110 | D14 Quality | D18 Reporting | Alimenter le pilotage qualité | Taux de conformité, NCR, audits, actions | Reporting | Consultation | P10 |

> Les interactions sortantes principales de Quality sont déjà décrites : INT-023 vers Projects, INT-082 vers Workshop, INT-091 vers Procurement, INT-099 vers Inventory, INT-064 vers Costing.

### 3.15 D15 — Safety

| ID | Source | Destinataire | Motif | Informations concernées | Moment | Nature | Processus |
| --- | --- | --- | --- | --- | --- | --- | --- |
| INT-111 | D15 Safety | D09 Workshop | Fournir les consignes et inspections atelier | Risques, consignes, inspection, incident, action | Exécution atelier | Notification | P06, P09 |
| INT-112 | D15 Safety | D16 Documents | Verser les preuves de sécurité | Analyses, inspections, incidents, actions, autorisations | Prévention et incident | Document | P11 |
| INT-113 | D15 Safety | D18 Reporting | Alimenter le pilotage sécurité | Fréquence, gravité, conformité, actions | Reporting | Consultation | P10 |

> Les interactions sortantes principales de Safety sont déjà décrites : INT-025 vers Projects, INT-051 vers Planning, INT-072 vers Workforce, INT-092 vers Procurement, INT-103 reçue d'Equipment, INT-065 vers Costing.

### 3.16 D16 — Documents

| ID | Source | Destinataire | Motif | Informations concernées | Moment | Nature | Processus |
| --- | --- | --- | --- | --- | --- | --- | --- |
| INT-114 | Tous les domaines | D16 Documents | Verser un document et ses métadonnées | Contenu, type, propriétaire, classification, statut, liens | Production ou réception | Document | P01–P12 |
| INT-115 | D16 Documents | Tous les domaines | Fournir les références et versions contrôlées | Référence, version, statut, diffusion, droits | Consultation | Référentiel | P01–P12 |
| INT-116 | D16 Documents | D17 Handover | Fournir la complétude et les versions du DOE | Pièces, versions, statut, diffusion, accusés | Réception | Référentiel | P12 |
| INT-117 | D16 Documents | D18 Reporting | Alimenter le pilotage documentaire | Volume, versions, diffusion, archivage | Reporting | Consultation | P10 |

### 3.17 D17 — Handover

| ID | Source | Destinataire | Motif | Informations concernées | Moment | Nature | Processus |
| --- | --- | --- | --- | --- | --- | --- | --- |
| INT-118 | D17 Handover | D14 Quality | Demander le traitement technique d'une réserve | Réserve, localisation, description, délai, preuve attendue | Réception | Demande | P12 |
| INT-119 | D17 Handover | D16 Documents | Demander la compilation et la diffusion du DOE | Pièces, ordre, destinataires, versions | Réception | Document | P12 |
| INT-120 | D17 Handover | D06 Costing | Fournir les dates de réception et de garantie | Réception, réserves, garantie, clôture | Réception et clôture | Notification | P12 |
| INT-121 | D17 Handover | D18 Reporting | Alimenter le pilotage des réceptions | Délais, réserves, levées, garanties | Reporting | Consultation | P10 |
| INT-122 | D10 Procurement | D17 Handover | Fournir les garanties fournisseurs et sous-traitants | Garantie, fournisseur, objet, durée, conditions | Clôture | Document | P12 |

> Les interactions sortantes principales de Handover sont déjà décrites : INT-029 vers Projects, INT-010 vers Clients, INT-109 reçue de Quality, INT-116 reçue de Documents.

### 3.18 D18 — Reporting

| ID | Source | Destinataire | Motif | Informations concernées | Moment | Nature | Processus |
| --- | --- | --- | --- | --- | --- | --- | --- |
| INT-123 | Tous les domaines | D18 Reporting | Alimenter les indicateurs et rapports | Données, événements, indicateurs source, période | Génération | Notification | P10 |
| INT-124 | D18 Reporting | Tous les domaines | Fournir les rapports et alertes | Rapport, tableau de bord, indicateur, seuil, période | Pilotage | Consultation | P10 |
| INT-125 | D18 Reporting | D16 Documents | Archiver ou diffuser un rapport | Rapport, export, période, destinataire | Publication | Document | P10 |

## 4. Interactions entrantes par domaine

Le tableau suivant donne une lecture par destinataire. Il ne remplace pas le registre détaillé : il permet de vérifier qu'aucun domaine n'est isolé et que les flux sont cohérents avec sa mission.

| Domaine destinataire | Interactions reçues | Total |
| --- | --- | ---: |
| D01 Identity | INT-003, INT-004, INT-005 | 3 |
| D02 Clients | INT-007, INT-010 | 2 |
| D03 Projects | INT-006, INT-008, INT-013, INT-015, INT-017, INT-019, INT-021, INT-023, INT-025, INT-027, INT-029, INT-031, INT-033, INT-035 | 14 |
| D04 Planning | INT-012, INT-038, INT-040, INT-042, INT-044, INT-046, INT-048, INT-050, INT-051 | 9 |
| D05 Budgets | INT-014, INT-054, INT-056, INT-070 | 4 |
| D06 Costing | INT-016, INT-053, INT-058, INT-059, INT-060, INT-061, INT-062, INT-063, INT-064, INT-065, INT-066, INT-120 | 12 |
| D07 Workforce | INT-037, INT-069, INT-072 | 3 |
| D08 TimeTracking | INT-032, INT-049, INT-068 | 3 |
| D09 Workshop | INT-018, INT-041, INT-078, INT-080, INT-082, INT-084, INT-086, INT-111 | 8 |
| D10 Procurement | INT-020, INT-043, INT-055, INT-079, INT-089, INT-091, INT-092, INT-094, INT-104 | 9 |
| D11 Inventory | INT-034, INT-045, INT-077, INT-088, INT-097, INT-099 | 6 |
| D12 Equipment | INT-039, INT-102, INT-105 | 3 |
| D13 Logistics | INT-030, INT-047, INT-083, INT-093, INT-096, INT-101 | 6 |
| D14 Quality | INT-022, INT-073, INT-081, INT-090, INT-098, INT-118 | 6 |
| D15 Safety | INT-024, INT-071, INT-103 | 3 |
| D16 Documents | INT-026, INT-085, INT-108, INT-112, INT-114, INT-119, INT-125 | 7 |
| D17 Handover | INT-009, INT-028, INT-109, INT-116, INT-122 | 5 |
| D18 Reporting | INT-002, INT-011, INT-036, INT-052, INT-057, INT-067, INT-074, INT-076, INT-087, INT-095, INT-100, INT-106, INT-107, INT-110, INT-113, INT-117, INT-121, INT-123 | 18 |

> **Note.** Ce tableau recense les interactions dont le destinataire est un domaine identifié. Les interactions génériques `INT-001` (Identity → tous), `INT-115` (Documents → tous) et `INT-124` (Reporting → tous) ne sont pas répétées dans chaque ligne. L'interaction `INT-075` a pour destinataire le prestataire de paie externe et n'apparaît donc pas dans ce tableau.

## 5. Règles de lecture et points de vigilance

### 5.1 Ce que le registre autorise

Le registre autorise un **besoin métier**. Il n'autorise pas :

- un import de classe interne ;
- un accès direct à une table ;
- une transaction partagée ;
- un couplage de cycle de vie ;
- une dépendance technique non documentée.

### 5.2 Interactions et contrats

| Situation | Forme pressentie | Remarque |
| --- | --- | --- |
| Référentiel stable | Contrat de lecture ou synchronisation contrôlée | La forme exacte relève de CHAN-28. |
| Consultation à la demande | Contrat synchrone de lecture | Ne doit pas avoir d'effet de bord. |
| Notification | Événement inter-domaines | Réservé au Lot 3 de CHAN-28 ; ne pas improviser. |
| Demande | Contrat synchrone de commande ou événement de demande | Doit documenter l'idempotence et les effets de bord. |
| Décision | Contrat synchrone avec résultat explicite | Le fournisseur applique ses invariants et son autorisation. |
| Document | Contrat documentaire ou événement de publication | Le contenu reste propriété du domaine métier. |

### 5.3 Risques de couplage

| Risque | Exemple | Prévention |
| --- | --- | --- |
| Accès direct | Un domaine lit la table `affaires` de Projects. | Interdit ; passer par un contrat. |
| Duplication de règle | Costing recalcule un budget au lieu de consommer Budgets. | Le propriétaire de la règle est unique. |
| Boucle de dépendance | Projects appelle Planning qui appelle Projects pour une décision. | Identifier la responsabilité et inverser le sens. |
| Transaction partagée | Un domaine enveloppe deux appels de contrats dans une transaction. | Interdit par défaut ; décision explicite requise. |
| Événement sans consommateur | Un événement est publié « au cas où ». | Ne pas créer sans consommateur réel. |
| Document confondu avec donnée | Un document est utilisé comme source d'état métier. | Le domaine propriétaire reste la source. |
| Reporting comme modèle d'écriture | Un rapport corrige une donnée source. | Reporting est en lecture seule. |

### 5.4 Interactions non retenues

Les interactions suivantes n'ont pas été retenues comme besoins certains :

- un accès direct de Reporting aux tables des domaines ;
- un accès direct de Procurement au stock pour modifier les quantités ;
- un accès direct de Workshop aux commandes fournisseurs ;
- un accès direct de Quality aux tables de Handover ;
- un accès direct de Handover aux fichiers du DOE sans passer par Documents ;
- un partage de transaction entre Budgets et Procurement ;
- un échange de Models Eloquent entre domaines ;
- un portail client ou fournisseur présumé.

## 6. Questions ouvertes liées aux interactions

| Question | Impact sur le registre |
| --- | --- |
| Q-01 Relation affaire/chantier | Détermine les axes échangés entre Projects, Planning, Budgets, Costing. |
| Q-02 Rôles client/donneur d'ordre | Détermine les informations échangées entre Clients, Projects, Handover. |
| Q-03 Opportunité commerciale | Détermine si Clients ou Projects pilote l'étude initiale. |
| Q-05 Référentiel tiers | Détermine si un tiers peut être client, fournisseur et sous-traitant sans duplication. |
| Q-09 Reconnaissance des engagements | Détermine le moment de l'échange Procurement → Costing. |
| Q-10 Coût final estimé | Détermine le contenu de l'échange Costing → Budgets/Projects. |
| Q-12 Absences | Détermine la frontière Workforce ↔ TimeTracking. |
| Q-14 Périmètre de paie | Détermine le contenu de l'échange Workforce → prestataire. |
| Q-17 Article | Détermine la frontière Inventory ↔ Procurement. |
| Q-19 Stock de chantier | Détermine les échanges Inventory ↔ Logistics ↔ Projects. |
| Q-22 Qualification sous-traitant | Détermine les échanges Procurement ↔ Quality ↔ Safety. |
| Q-23 Acceptation technique externe | Détermine les échanges Workshop ↔ Quality ↔ Procurement. |
| Q-27 Avancement | Détermine les échanges Projects ↔ Planning ↔ TimeTracking. |
| Q-30 Réserve / NCR | Détermine les échanges Handover ↔ Quality. |
| Q-31 DOE | Détermine les échanges Handover ↔ Documents. |
| Q-34 Reporting | Détermine les interactions de Reporting avec tous les domaines. |
| Q-35 Comptes externes | Détermine INT-004 et INT-005. |
| Q-37 Unité monétaire | Détermine le format des montants échangés. |
| Q-41 Sous-traitance dans les deux sens | Détermine les échanges Clients/Projects/Procurement/Handover. |

## 7. Références

- [`domain-responsibilities.md`](domain-responsibilities.md) — responsabilités des 18 domaines.
- [`business-processes.md`](business-processes.md) — processus métier.
- [`business-objects.md`](business-objects.md) — objets métier.
- [`domain-boundary-decisions.md`](domain-boundary-decisions.md) — chevauchements et questions ouvertes.
- [`domain-conventions.md`](domain-conventions.md) — conventions internes CHAN-27.
- [`domain-communication.md`](domain-communication.md) — contrats synchrones CHAN-28.
