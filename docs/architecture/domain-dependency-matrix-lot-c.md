# Lot C — Matrice technique de qualification des dépendances inter-domaines

## 1. Objet et statut

Ce document constitue le livrable de consolidation documentaire du Lot C de CHAN-29. Il reprend les **130 identifiants uniques** présents dans `domain-dependency-register.md` sur la base de `develop` au démarrage du lot.

Il sépare explicitement :
- le **statut métier existant** du registre source ;
- la **classe technique CHAN-29**, qui n'est pas déduite automatiquement de la qualification métier ;
- le **mode CHAN-28 pressenti**, qui est une orientation de travail et non la preuve qu'un contrat ou événement existe déjà.

**Règle de prudence :** faute de preuve documentaire suffisante, la classe technique reste « À qualifier ». Aucune dépendance n'est déclarée « Autorisée » ou « Interdite » par simple extrapolation du type d'interaction. Une classe « Interdite » nécessite l'identification d'un contournement ou couplage contraire aux règles ; aucune telle preuve n'est affirmée ici.

## 2. Références et méthode

Sources consultées sur `develop` :
- `docs/architecture/domain-dependency-register.md` — registre source des interactions ;
- `docs/architecture/domain-responsibilities.md` — responsabilités et propriétaires métier ;
- `docs/architecture/business-processes.md` — contexte des processus ;
- `docs/architecture/domain-boundary-decisions.md` — décisions et questions ouvertes ;
- `docs/architecture/domain-interactions-register.md` — détail des interactions ;
- `docs/architecture/domain-communication.md` — règles CHAN-28 relatives aux contrats, événements, transactions, publication après commit, idempotence et fiabilité.

La direction est conservée telle qu'elle apparaît dans le registre : **consommateur → fournisseur**. Le propriétaire est recopié depuis la colonne source, y compris lorsque plusieurs propriétaires ou une question ouverte sont mentionnés.

## 3. Critères de classification technique

| Classe | Critère |
| --- | --- |
| Autorisée | Consommateur réel, propriétaire confirmé, capacité/donnée minimale et contrat public ou événement conforme à CHAN-28 démontrés. |
| Conditionnelle | Cas d'usage borné, condition vérifiable, déclencheur, données et limites documentés. |
| Interdite | Contournement de propriété/invariants, accès interne ou tables d'un autre domaine, écriture directe ou couplage/transaction partagée implicite. |
| À qualifier | Preuve insuffisante sur le besoin, l'orientation, le fournisseur, le contrat ou les garanties. |

Le mode CHAN-28 proposé ci-dessous est indicatif. Il ne constitue pas une décision technique d'implémentation. En particulier, une notification ne devient un événement que si elle décrit un fait accompli et si aucun résultat immédiat n'est attendu ; une demande ne devient un contrat synchrone que si la réponse est nécessaire avant de poursuivre.

## 4. Matrice consolidée — 130 identifiants

| INT | Consommateur → fournisseur | Processus | Capacité / donnée consommée | Propriétaire source | Statut métier source | Classe technique | Mode CHAN-28 pressenti |
|---|---|---|---|---|---|---|---|
| INT-001 | Points d'entrée concernés → D01 Identity (service transverse, hors dépendance métier uniforme) | P01–P12 | Identifier l'acteur et vérifier ses droits — Identifiant d'acteur, rôles, permissions, périmètre, statut | D01 Identity | Hors matrice inter-domaines | À qualifier | Service transverse d'authentification/autorisation ; ne pas créer de dépendance métier uniforme |
| INT-002 | D18 Reporting → D01 Identity | P10 | Restreindre l'accès aux rapports — Périmètre, rôles, droits de consultation | D01 Identity | Qualifiée | À qualifier | Contrat public de lecture à envisager ; confirmer le besoin et le consommateur réel |
| INT-003 | D01 Identity → D07 Workforce | P03, P09 | Aligner le compte avec la vie du collaborateur — Arrivée, départ, changement de poste ou d'unité, date d'effet | D07 Workforce | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-004 | D02 Clients → D01 Identity | P12 | Ouvrir un accès externe éventuel à un contact client — Identité du contact, client, périmètre, demande du client | D01 Identity | À arbitrer | À qualifier | Contrat de commande si réponse immédiate requise ; événement uniquement si demande acceptée comme fait autonome |
| INT-005 | D10 Procurement → D01 Identity | P05, P07 | Ouvrir un accès externe éventuel à un fournisseur ou sous-traitant — Identité du tiers, contact, périmètre, demande | D01 Identity | À arbitrer | À qualifier | Contrat de commande si réponse immédiate requise ; événement uniquement si demande acceptée comme fait autonome |
| INT-006 | D03 Projects → D02 Clients | P01, P02 | Identifier le client et le donneur d'ordre de l'engagement — Identifiant public du tiers, contacts, rôles contextualisés, adresses et conditions commerciales cadre | D02 Clients | Qualifiée | À qualifier | Contrat public de lecture à envisager ; confirmer le besoin et le consommateur réel |
| INT-007 | D02 Clients → D03 Projects | P01, P02, P12 | Mettre à jour la relation et le statut du client — Affaire ouverte, commande, réception, clôture, incident relationnel | D03 Projects | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-008 | D02 Clients → D03 Projects | P01 | Demander une étude technique préalable au devis lorsque nécessaire — Besoin, contacts, périmètre, échéance, documents disponibles | D03 Projects | Qualifiée | À qualifier | Contrat de commande si réponse immédiate requise ; événement uniquement si demande acceptée comme fait autonome |
| INT-009 | D17 Handover → D02 Clients | P12 | Identifier les représentants du client à la réception — Contacts, rôles, coordonnées, pouvoirs de réception | D02 Clients | Qualifiée | À qualifier | Contrat public de lecture à envisager ; confirmer le besoin et le consommateur réel |
| INT-010 | D02 Clients → D03 Projects | P12 | Mettre à jour la relation commerciale avec les faits de réception et les éléments de clôture — Réception, réserves, levées, éléments de clôture | D03 Projects | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-010a | D02 Clients → D17 Handover | P12 | Mettre à jour la relation commerciale avec les éléments documentaires de réception et les garanties — PV, DOE, dates et pièces de garantie | D17 Handover / D10 Procurement (Q-44) | À préciser | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-011 | D18 Reporting → D02 Clients | P10 | Analyser le portefeuille et la relation commerciale — Prospects, clients, relation commerciale, statut, affaires connues | D02 Clients | Qualifiée | À qualifier | Contrat public de lecture à envisager ; Reporting peut utiliser une projection en lecture |
| INT-012 | D04 Planning → D03 Projects | P02, P03, P04, P09 | Fournir le périmètre et les jalons à planifier — Affaire, chantier, lots, jalons contractuels, priorités, contraintes de site | D03 Projects | Qualifiée | À qualifier | Contrat public de lecture à envisager ; confirmer le besoin et le consommateur réel |
| INT-013 | D03 Projects → D04 Planning | P01, P02, P04, P10 | Alimenter le pilotage contractuel — Planning, dates prévisionnelles, avancement des activités, conflits | D04 Planning | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-014 | D05 Budgets → D03 Projects | P01, P02, P03 | Établir ou réviser l'enveloppe budgétaire — Périmètre, lots, montant du contrat, avenants, besoin budgétaire | D03 Projects | Qualifiée | À qualifier | Contrat de commande si réponse immédiate requise ; événement uniquement si demande acceptée comme fait autonome |
| INT-015 | D03 Projects → D05 Budgets | P01, P02, P03, P10 | Valider et suivre l'enveloppe — Budget validé, disponible, seuils, écarts, alertes | D05 Budgets | Qualifiée | À qualifier | Contrat synchrone si décision requise avant poursuite ; fournisseur propriétaire de la décision |
| INT-016 | D03 Projects → D06 Costing | P01–P12 | Demander une estimation rapide — Affaire, lots, besoin, demande d'estimation rapide | D06 Costing | Qualifiée | À qualifier | Contrat de commande si réponse immédiate requise ; événement uniquement si demande acceptée comme fait autonome |
| INT-016a | D06 Costing → D03 Projects | P01–P12 | Obtenir les références contractuelles et analytiques — Affaire, lots, montants contractuels, avenants, avancement | D03 Projects | Qualifiée | À qualifier | Contrat public de lecture à envisager ; confirmer le besoin et le consommateur réel |
| INT-017 | D03 Projects → D06 Costing | P01, P02, P10, P12 | Fournir une estimation économique, les risques et les alertes — Estimation, coût réel, EAC, marge, écarts, alertes de risque | D06 Costing | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-018 | D03 Projects → D09 Workshop | P02, P03, P06 | Solliciter la capacité de fabrication ou d'étude détenue par Workshop — Besoin, lot, dossier technique, dates, priorités fournis par Projects | D09 Workshop | Qualifiée | À qualifier | Contrat de commande si réponse immédiate requise ; événement uniquement si demande acceptée comme fait autonome |
| INT-019 | D03 Projects → D09 Workshop | P02, P06, P09 | Informer sur la fabrication — Avancement, disponibilité, contraintes, retards, achèvement | D09 Workshop | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-020 | D03 Projects → D10 Procurement | P02, P03, P09 | Solliciter le traitement Procurement d'un besoin d'achat ou de sous-traitance défini par Projects — Prestation, spécifications, quantité, date, lot, budget | D10 Procurement | Qualifiée | À qualifier | Contrat de commande si réponse immédiate requise ; événement uniquement si demande acceptée comme fait autonome |
| INT-021 | D03 Projects → D10 Procurement | P02, P05, P09 | Informer sur les engagements et livraisons — Commande, fournisseur, montant, dates, statut, retards | D10 Procurement | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-022 | D03 Projects → D14 Quality | P02, P03, P11 | Obtenir le plan qualité et les critères de contrôle — Plan qualité, critères, points de contrôle, exigences qualité | D14 Quality | Qualifiée | À qualifier | Contrat public de lecture à envisager ; confirmer le besoin et le consommateur réel |
| INT-023 | D14 Quality → D03 Projects | P02, P03, P11 | Obtenir les exigences contractuelles applicables — Périmètre, spécifications, exigences contractuelles, jalons | D03 Projects | Qualifiée | À qualifier | Contrat public de lecture à envisager ; confirmer le besoin et le consommateur réel |
| INT-023a | D03 Projects → D14 Quality | P02, P03, P11 | Obtenir les résultats de conformité et blocages — Résultats, NCR, gravité, blocage, certificats | D14 Quality | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-024 | D15 Safety → D03 Projects | P02, P03, P09 | Fournir les sites, activités et intervenants à couvrir — Sites, activités, planning, sous-traitants, risques connus | D03 Projects | Qualifiée | À qualifier | Contrat public de lecture à envisager ; confirmer le besoin et le consommateur réel |
| INT-025 | D03 Projects → D15 Safety | P02, P09, P11 | Informer sur la prévention et les incidents — Plan de prévention, consignes, inspections, incidents, autorisations | D15 Safety | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-026 | D03 Projects → D16 Documents | P01–P12 | Verser les documents contractuels et d'exécution — Contrats, études, devis, plans, PV, documents de site | D16 Documents | Qualifiée | À qualifier | Contrat public de dépôt ou consultation selon l'opération ; Documents possède le contenant |
| INT-027 | D03 Projects → D16 Documents | P01–P12 | Fournir les références documentaires contrôlées — Référence, version, statut, diffusion, liens | D16 Documents | Qualifiée | À qualifier | Contrat public de lecture à envisager ; confirmer le besoin et le consommateur réel |
| INT-028 | D03 Projects → D17 Handover | P12 | Préparer le dossier documentaire de réception d'un lot ou de l'affaire — Périmètre, lots, client, dates, achèvement, documents attendus | D17 Handover | Qualifiée | À qualifier | Contrat de commande si réponse immédiate requise ; événement uniquement si demande acceptée comme fait autonome |
| INT-029 | D03 Projects → D17 Handover | P12 | Centraliser les pièces et livrables de réception — PV, réserves, levées, DOE, garanties, complétude documentaire | D17 Handover | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-030 | D13 Logistics → D03 Projects | P08, P09 | Fournir les contraintes d'accès et de livraison — Site, adresse, accès, horaires, destinataires, contraintes | D03 Projects | Qualifiée | À qualifier | Contrat public de lecture à envisager ; confirmer le besoin et le consommateur réel |
| INT-031 | D03 Projects → D13 Logistics | P08, P09 | Informer sur les livraisons — Statut, date, réception, écarts, avaries | D13 Logistics | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-032 | D08 TimeTracking → D03 Projects | P10 | Fournir les axes d'imputation du temps — Affaire, chantier, lot, activité, centre de coût | D03 Projects | Qualifiée | À qualifier | Contrat public de lecture à envisager ; confirmer le besoin et le consommateur réel |
| INT-033 | D03 Projects → D08 TimeTracking | P10 | Alimenter l'avancement contractuel — Temps par lot, avancement constaté, absences | D08 TimeTracking | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-034 | D03 Projects → D11 Inventory | P05, P09 | Exprimer un besoin de matériel pour le chantier — Article, quantité, date, lot, destination | D11 Inventory | Qualifiée | À qualifier | Contrat de commande si réponse immédiate requise ; événement uniquement si demande acceptée comme fait autonome |
| INT-035 | D03 Projects → D11 Inventory | P05, P09 | Informer sur la disponibilité et les sorties — Disponibilité, réservation, sortie, pénurie | D11 Inventory | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-036 | D18 Reporting → D03 Projects | P10, P12 | Alimenter le pilotage des affaires — Portefeuille, montants contractuels, avancement, engagements, réception, clôture | D03 Projects | Qualifiée | À qualifier | Contrat public de lecture à envisager ; Reporting peut utiliser une projection en lecture |
| INT-037 | D04 Planning → D07 Workforce | P02, P04 | Exprimer les besoins en ressources humaines — Activités, périodes, qualifications, charge, lieu | D07 Workforce | Qualifiée | À qualifier | Contrat de commande si réponse immédiate requise ; événement uniquement si demande acceptée comme fait autonome |
| INT-038 | D04 Planning → D07 Workforce | P02, P04 | Fournir la disponibilité et les contraintes RH — Collaborateurs, équipes, qualifications, disponibilité, contrat | D07 Workforce | Qualifiée | À qualifier | Contrat public de lecture à envisager ; confirmer le besoin et le consommateur réel |
| INT-039 | D04 Planning → D12 Equipment | P02, P04 | Exprimer les besoins en équipements — Équipement, activité, période, site, conditions | D12 Equipment | Qualifiée | À qualifier | Contrat de commande si réponse immédiate requise ; événement uniquement si demande acceptée comme fait autonome |
| INT-040 | D04 Planning → D12 Equipment | P02, P04 | Fournir la disponibilité des équipements — Disponibilité, maintenance, inspections, affectations | D12 Equipment | Qualifiée | À qualifier | Contrat public de lecture à envisager ; confirmer le besoin et le consommateur réel |
| INT-041 | D04 Planning → D09 Workshop | P02, P04, P06 | Réserver des créneaux d'atelier — OF, activité, période, priorité, contraintes | D09 Workshop / D04 Planning (Q-24) | À arbitrer | À qualifier | Contrat de commande si réponse immédiate requise ; événement uniquement si demande acceptée comme fait autonome |
| INT-042 | D04 Planning → D09 Workshop | P02, P04, P06 | Fournir la capacité et l'avancement atelier — Capacité, durées, charge, avancement, retards | D09 Workshop / D04 Planning (Q-24) | À arbitrer | À qualifier | Contrat public de lecture à envisager ; confirmer le besoin et le consommateur réel |
| INT-043 | D04 Planning → D10 Procurement | P02, P04, P05 | Exprimer les besoins datés et les délais critiques — Articles, services, dates, quantités, priorités | D10 Procurement | Qualifiée | À qualifier | Contrat de commande si réponse immédiate requise ; événement uniquement si demande acceptée comme fait autonome |
| INT-044 | D04 Planning → D10 Procurement | P02, P04, P05 | Fournir les délais et dates de livraison — Délais, dates prévues, retards, alternatives | D10 Procurement | Qualifiée | À qualifier | Contrat public de lecture à envisager ; confirmer le besoin et le consommateur réel |
| INT-045 | D04 Planning → D11 Inventory | P02, P04, P05 | Vérifier la disponibilité matière — Articles, quantités, dates, réservations | D11 Inventory | Qualifiée | À qualifier | Contrat de commande si réponse immédiate requise ; événement uniquement si demande acceptée comme fait autonome |
| INT-046 | D04 Planning → D11 Inventory | P02, P04, P05 | Signaler les pénuries et disponibilités — Disponibilité, pénurie, réservation, réapprovisionnement | D11 Inventory | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-047 | D04 Planning → D13 Logistics | P04, P08 | Exprimer les besoins de transport — Colis, dates, destinations, contraintes | D13 Logistics | Qualifiée | À qualifier | Contrat de commande si réponse immédiate requise ; événement uniquement si demande acceptée comme fait autonome |
| INT-048 | D04 Planning → D13 Logistics | P04, P08 | Fournir les contraintes et dates de transport — Délais, capacités, accès, incidents | D13 Logistics | Qualifiée | À qualifier | Contrat public de lecture à envisager ; confirmer le besoin et le consommateur réel |
| INT-049 | D08 TimeTracking → D04 Planning | P10 | Fournir les activités à pointer — Activité, affaire, lot, période, responsable | D04 Planning | Qualifiée | À qualifier | Contrat public de lecture à envisager ; confirmer le besoin et le consommateur réel |
| INT-050 | D04 Planning → D08 TimeTracking | P04, P10 | Alimenter la replanification — Temps réels, absences, écarts | D08 TimeTracking | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-051 | D04 Planning → D15 Safety | P04, P09 | Signaler les restrictions d'affectation — Habilitation, autorisation, restriction, expiration | D15 Safety (Q-29) | À préciser | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-052 | D18 Reporting → D04 Planning | P10 | Alimenter le pilotage de la charge — Charge, planning, conflits, respect des délais | D04 Planning | Qualifiée | À qualifier | Contrat public de lecture à envisager ; Reporting peut utiliser une projection en lecture |
| INT-053 | D06 Costing → D05 Budgets | P02, P03, P10 | Fournir la référence budgétaire — Enveloppe, lignes, lots, natures, période | D05 Budgets | Qualifiée | À qualifier | Contrat public de lecture à envisager ; confirmer le besoin et le consommateur réel |
| INT-054 | D05 Budgets → D06 Costing | P02, P10 | Alimenter l'analyse budgétaire — Engagements, coûts constatés, EAC, écarts | D06 Costing | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-055 | D10 Procurement → D05 Budgets | P05 | Consulter le disponible et l'alerte budgétaire — Disponible, seuil, nature, lot, conditions, alerte | D05 Budgets | Qualifiée | À qualifier | Contrat public de lecture à envisager ; Reporting peut utiliser une projection en lecture |
| INT-056 | D05 Budgets → D10 Procurement | P02, P05 | Informer sur la consommation de l'enveloppe — Commande, montant, engagement, annulation, variation | D10 Procurement | À préciser | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-057 | D18 Reporting → D05 Budgets | P10 | Alimenter le pilotage budgétaire — Budget, consommation, écarts, prévisions | D05 Budgets | Qualifiée | À qualifier | Contrat public de lecture à envisager ; Reporting peut utiliser une projection en lecture |
| INT-058 | D06 Costing → D08 TimeTracking | P10 | Valoriser la main-d'œuvre — Heures validées, affaire, lot, nature | D08 TimeTracking | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-059 | D06 Costing → D11 Inventory | P05, P10 | Valoriser la matière consommée — Article, quantité, lot, valorisation, affaire | D11 Inventory | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-060 | D06 Costing → D10 Procurement | P01, P02, P05, P07 | Enregistrer les engagements et offres — Commande, montant, fournisseur, variations, offres | D10 Procurement | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-061 | D06 Costing → D09 Workshop | P06, P10 | Valoriser la production atelier — Heures, matière, rebuts, coûts atelier, OF | D09 Workshop | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-062 | D06 Costing → D12 Equipment | P09, P10 | Valoriser l'utilisation des équipements — Utilisation, maintenance, panne, location | D12 Equipment | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-063 | D06 Costing → D13 Logistics | P08, P10 | Valoriser le transport — Coût, affaire, lot, transporteur, incident | D13 Logistics | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-064 | D06 Costing → D14 Quality | P11 | Valoriser la non-qualité — NCR, reprise, rebut, temps, coût | D14 Quality | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-065 | D06 Costing → D15 Safety | P11 | Valoriser la prévention et les incidents — Coût de prévention, arrêt, incident, action | D15 Safety | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-066 | D06 Costing → D07 Workforce | P02, P10 | Obtenir les données RH de référence — Poste, contrat, période, données RH disponibles | D07 Workforce / D06 Costing (Q-11) | À arbitrer | À qualifier | Contrat public de lecture à envisager ; confirmer le besoin et le consommateur réel |
| INT-067 | D18 Reporting → D06 Costing | P10 | Alimenter le pilotage économique — Coûts, marges, écarts, EAC, tendances | D06 Costing | Qualifiée | À qualifier | Contrat public de lecture à envisager ; Reporting peut utiliser une projection en lecture |
| INT-068 | D08 TimeTracking → D07 Workforce | P10 | Fournir les données nécessaires au pointage — Collaborateur, équipe, contrat, droits à absence, période | D07 Workforce | Qualifiée | À qualifier | Contrat public de lecture à envisager ; confirmer le besoin et le consommateur réel |
| INT-069 | D07 Workforce → D08 TimeTracking | P10 | Fournir les faits de temps nécessaires aux variables de paie — Temps validés, absences, heures supplémentaires | D08 TimeTracking | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-070 | D05 Budgets → D07 Workforce | P01, P02, P03 | Obtenir les données et hypothèses RH disponibles — Postes, effectifs, disponibilité, hypothèses de coût | D07 Workforce / D05 Budgets (Q-11) | À arbitrer | À qualifier | Contrat public de lecture à envisager ; confirmer le besoin et le consommateur réel |
| INT-071 | D15 Safety → D07 Workforce | P04, P09 | Fournir les formations et qualifications — Formation, qualification, validité, preuve | D07 Workforce (Q-29) | À préciser | À qualifier | Contrat public de lecture à envisager ; confirmer le besoin et le consommateur réel |
| INT-072a | D07 Workforce → D15 Safety | P04, P11 | Recevoir les exigences et alertes sécurité — Exigences, restrictions, habilitations opérationnelles, alertes, dates d'effet | D15 Safety (Q-29) | À préciser | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-073 | D14 Quality → D07 Workforce | P11 | Transmettre les formations et qualifications RH disponibles — Formations, qualifications RH, validité, preuves | D07 Workforce | Qualifiée | À qualifier | Contrat public de lecture à envisager ; confirmer le besoin et le consommateur réel |
| INT-074 | D18 Reporting → D07 Workforce | P10 | Alimenter le pilotage RH — Effectifs, qualifications, absences, masse salariale | D07 Workforce | À arbitrer | À qualifier | Contrat public de lecture à envisager ; Reporting peut utiliser une projection en lecture |
| INT-075 | D07 Workforce → Prestataire de paie externe | P10 | Transmettre les éléments de paie — Variables, absences, contrat, période, centre de coût | D07 Workforce / prestataire externe | Hors matrice inter-domaines | À qualifier | Contrat public de dépôt ou consultation selon l'opération ; Documents possède le contenant |
| INT-076 | D18 Reporting → D08 TimeTracking | P10 | Alimenter le pilotage des temps — Heures, absences, présence, affaire | D08 TimeTracking | À préciser | À qualifier | Contrat public de lecture à envisager ; Reporting peut utiliser une projection en lecture |
| INT-077 | D09 Workshop → D11 Inventory | P06 | Demander la matière nécessaire à un OF — Article, quantité, date, OF, lot | D11 Inventory | Qualifiée | À qualifier | Contrat de commande si réponse immédiate requise ; événement uniquement si demande acceptée comme fait autonome |
| INT-078 | D09 Workshop → D11 Inventory | P06 | Répondre sur la disponibilité matière — Disponibilité, réservation, sortie, pénurie, substitution | D11 Inventory | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-079 | D09 Workshop → D10 Procurement | P07 | Demander une fabrication ou une opération externe — Dossier technique, périmètre, quantité, date, exigences | D10 Procurement | Qualifiée | À qualifier | Contrat de commande si réponse immédiate requise ; événement uniquement si demande acceptée comme fait autonome |
| INT-080 | D09 Workshop → D10 Procurement | P07 | Informer sur la commande externe — Sous-traitant, commande, délai, statut, réception | D10 Procurement | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-081 | D09 Workshop → D14 Quality | P06, P11 | Demander un contrôle ou signaler un écart — OF, opération, autocontrôle, caractéristique, NCR | D14 Quality | Qualifiée | À qualifier | Contrat de commande si réponse immédiate requise ; événement uniquement si demande acceptée comme fait autonome |
| INT-082 | D09 Workshop → D14 Quality | P06, P11 | Informer sur la conformité et les reprises — Résultat, NCR, reprise, refus, certificat | D14 Quality | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-083 | D09 Workshop → D13 Logistics | P08 | Signaler un colis prêt à expédier — Colis, poids, dimensions, destination, date | D13 Logistics | Qualifiée | À qualifier | Contrat de commande si réponse immédiate requise ; événement uniquement si demande acceptée comme fait autonome |
| INT-084 | D09 Workshop → D13 Logistics | P08 | Informer sur l'enlèvement et la livraison — Statut, date, incident, retour | D13 Logistics | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-085 | D09 Workshop → D16 Documents | P03, P06 | Verser les dossiers et documents de fabrication — Plans, nomenclatures, comptes rendus, PV | D16 Documents | Qualifiée | À qualifier | Contrat public de dépôt ou consultation selon l'opération ; Documents possède le contenant |
| INT-086 | D09 Workshop → D16 Documents | P03, P06 | Fournir les versions contrôlées — Référence, version, statut, diffusion | D16 Documents | Qualifiée | À qualifier | Contrat public de lecture à envisager ; confirmer le besoin et le consommateur réel |
| INT-087 | D18 Reporting → D09 Workshop | P10 | Alimenter le pilotage atelier — Capacité, avancement, rebuts, délais | D09 Workshop | Qualifiée | À qualifier | Contrat public de lecture à envisager ; Reporting peut utiliser une projection en lecture |
| INT-088 | D11 Inventory → D10 Procurement | P05 | Annoncer les commandes et livraisons attendues — Commande, article, quantité, fournisseur, date, statut | D10 Procurement | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-089 | D10 Procurement → D11 Inventory | P05 | Signaler les besoins et écarts de réception — Stock, pénurie, réception, écart, retour | D11 Inventory | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-090 | D10 Procurement → D14 Quality | P05, P07 | Fournir les données de qualification — Fournisseur, sous-traitant, certificats, historique | D14 Quality | Qualifiée | À qualifier | Contrat public de lecture à envisager ; confirmer le besoin et le consommateur réel |
| INT-091 | D10 Procurement → D14 Quality | P05, P07 | Alimenter l'évaluation fournisseur — NCR, audit, conformité, performance | D14 Quality | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-092 | D10 Procurement → D15 Safety | P05, P07 | Signaler la conformité sécurité d'un sous-traitant — Documents, habilitation, incident, restriction | D15 Safety | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-093 | D10 Procurement → D13 Logistics | P05, P08 | Demander l'organisation d'un transport — Enlèvement, livraison, fournisseur, date, colis | D13 Logistics | Qualifiée | À qualifier | Contrat de commande si réponse immédiate requise ; événement uniquement si demande acceptée comme fait autonome |
| INT-094 | D10 Procurement → D13 Logistics | P08 | Informer sur le transport — Statut, incident, retard, avarie | D13 Logistics | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-095 | D18 Reporting → D10 Procurement | P10 | Alimenter le pilotage des achats — Commandes, engagements, délais, performance | D10 Procurement | Qualifiée | À qualifier | Contrat public de lecture à envisager ; Reporting peut utiliser une projection en lecture |
| INT-096 | D11 Inventory → D13 Logistics | P08 | Demander l'expédition d'un colis — Colis, poids, dimensions, destination, date | D13 Logistics | Qualifiée | À qualifier | Contrat de commande si réponse immédiate requise ; événement uniquement si demande acceptée comme fait autonome |
| INT-097 | D11 Inventory → D13 Logistics | P08 | Confirmer la livraison ou signaler un écart — Statut, réception, retour, avarie, manque | D13 Logistics | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-098 | D11 Inventory → D14 Quality | P05 | Demander un contrôle à réception — Article, lot, fournisseur, quantité, exigence | D14 Quality | Qualifiée | À qualifier | Contrat de commande si réponse immédiate requise ; événement uniquement si demande acceptée comme fait autonome |
| INT-099 | D11 Inventory → D14 Quality | P05 | Statuer sur la réception — Accepté, refusé, quarantaine, NCR | D14 Quality | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-100 | D18 Reporting → D11 Inventory | P10 | Alimenter le pilotage du stock — Stock, rotation, écarts, pénuries | D11 Inventory | Qualifiée | À qualifier | Contrat public de lecture à envisager ; Reporting peut utiliser une projection en lecture |
| INT-101 | D13 Logistics → D12 Equipment | P08 | Fournir les véhicules et moyens disponibles — Équipement, disponibilité, capacité, affectation | D12 Equipment | Qualifiée | À qualifier | Contrat public de lecture à envisager ; confirmer le besoin et le consommateur réel |
| INT-102 | D12 Equipment → D13 Logistics | P08 | Signaler l'utilisation, le retour ou la panne — Usage, compteur, état, panne, retour | D13 Logistics | À préciser | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-103 | D15 Safety → D12 Equipment | P09, P11 | Fournir le statut des inspections et certificats — Inspection, validité, certificat, blocage | D12 Equipment | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-104 | D12 Equipment → D10 Procurement | P05 | Demander un achat, une location ou une maintenance externe — Équipement, besoin, date, fournisseur, budget | D10 Procurement | Qualifiée | À qualifier | Contrat de commande si réponse immédiate requise ; événement uniquement si demande acceptée comme fait autonome |
| INT-105 | D12 Equipment → D10 Procurement | P05 | Informer sur la commande ou la location — Statut, dates, fournisseur, coût | D10 Procurement | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-106 | D18 Reporting → D12 Equipment | P10 | Alimenter le pilotage du parc — Disponibilité, utilisation, maintenance, coûts | D12 Equipment | Qualifiée | À qualifier | Contrat public de lecture à envisager ; Reporting peut utiliser une projection en lecture |
| INT-107 | D18 Reporting → D13 Logistics | P10 | Alimenter le pilotage logistique — Délais, coûts, incidents, retours | D13 Logistics | Qualifiée | À qualifier | Contrat public de lecture à envisager ; Reporting peut utiliser une projection en lecture |
| INT-108 | D14 Quality → D16 Documents | P11 | Verser les preuves et certificats — Rapports, contrôles, certificats, NCR, actions | D16 Documents | Qualifiée | À qualifier | Contrat public de dépôt ou consultation selon l'opération ; Documents possède le contenant |
| INT-109 | D17 Handover → D14 Quality | P12 | Fournir les preuves de conformité — Contrôles, essais, certificats, NCR clôturées | D14 Quality | Qualifiée | À qualifier | Contrat public de dépôt ou consultation selon l'opération ; Documents possède le contenant |
| INT-110 | D18 Reporting → D14 Quality | P10 | Alimenter le pilotage qualité — Taux de conformité, NCR, audits, actions | D14 Quality | Qualifiée | À qualifier | Contrat public de lecture à envisager ; Reporting peut utiliser une projection en lecture |
| INT-111 | D09 Workshop → D15 Safety | P06, P09 | Fournir les consignes et inspections atelier — Risques, consignes, inspection, incident, action | D15 Safety | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-112 | D15 Safety → D16 Documents | P11 | Verser les preuves de sécurité — Analyses, inspections, incidents, actions, autorisations | D16 Documents | Qualifiée | À qualifier | Contrat public de dépôt ou consultation selon l'opération ; Documents possède le contenant |
| INT-113 | D18 Reporting → D15 Safety | P10 | Alimenter le pilotage sécurité — Fréquence, gravité, conformité, actions | D15 Safety | Qualifiée | À qualifier | Contrat public de lecture à envisager ; Reporting peut utiliser une projection en lecture |
| INT-114 | Domaines déposants → D16 Documents | P01–P12 | Verser un document et ses métadonnées — Contenu, type, propriétaire, classification, statut, liens | D16 Documents / domaine déposant | À décomposer | À qualifier | Contrat public de dépôt ou consultation selon l'opération ; Documents possède le contenant |
| INT-115 | Tous les domaines → D16 Documents | P01–P12 | Fournir les références et versions contrôlées — Référence, version, statut, diffusion, droits | D16 Documents | À décomposer | À qualifier | Contrat public de lecture à envisager ; confirmer le besoin et le consommateur réel |
| INT-116 | D17 Handover → D16 Documents | P12 | Obtenir les références et versions des pièces du DOE — Pièces, versions, statut, diffusion, accusés | D16 Documents / D17 Handover (Q-31) | À préciser | À qualifier | Contrat public de lecture à envisager ; confirmer le besoin et le consommateur réel |
| INT-117 | D18 Reporting → D16 Documents | P10 | Alimenter le pilotage documentaire — Volume, versions, diffusion, archivage | D16 Documents | Qualifiée | À qualifier | Contrat public de lecture à envisager ; Reporting peut utiliser une projection en lecture |
| INT-118 | D17 Handover → D14 Quality | P12 | Demander le traitement technique d'une réserve — Réserve, localisation, description, délai, preuve attendue | D14 Quality | Qualifiée | À qualifier | Contrat de commande si réponse immédiate requise ; événement uniquement si demande acceptée comme fait autonome |
| INT-119 | D17 Handover → D16 Documents | P12 | Demander la compilation et la diffusion du DOE — Pièces, ordre, destinataires, versions | D16 Documents / D17 Handover (Q-31) | À préciser | À qualifier | Contrat public de dépôt ou consultation selon l'opération ; Documents possède le contenant |
| INT-120 | D06 Costing → D03 Projects | P12 | Fournir les dates et décisions contractuelles de réception et les éléments de clôture — Réception, réserves, éléments de clôture | D03 Projects | Qualifiée | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-120a | D06 Costing → D17 Handover | P12 | Obtenir les dates de garantie et références documentaires — Dates de garantie, pièces et références documentaires | D17 Handover / D10 Procurement (Q-44) | À préciser | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-121 | D18 Reporting → D03 Projects | P10 | Alimenter le pilotage contractuel des réceptions — Délais et décisions de réception contractuelle, clôture | D03 Projects | Qualifiée | À qualifier | Contrat public de lecture à envisager ; Reporting peut utiliser une projection en lecture |
| INT-121a | D18 Reporting → D17 Handover | P10 | Alimenter le pilotage documentaire des réceptions et garanties — Suivi des réserves, levées, garanties et complétude documentaire | D17 Handover | Qualifiée | À qualifier | Contrat public de lecture à envisager ; Reporting peut utiliser une projection en lecture |
| INT-122 | D17 Handover → D10 Procurement | P12 | Obtenir les garanties fournisseurs et sous-traitants — Garantie, fournisseur, objet, durée, conditions | D10 Procurement / D17 Handover (Q-44) | À préciser | À qualifier | Contrat public de consultation auprès de Procurement ; Handover consomme les garanties fournisseurs |
| INT-123 | D18 Reporting → domaines sources | P10 | Alimenter les indicateurs et rapports — Données, événements, indicateurs source, période | Variable selon le domaine source | À décomposer | À qualifier | Événement d'intégration si fait accompli sans réponse attendue ; sinon requalifier le besoin |
| INT-124 | Consommateurs à identifier → D18 Reporting | P10 | Fournir les rapports et alertes — Rapport, tableau de bord, indicateur, seuil, période | D18 Reporting | À décomposer | À qualifier | Consultation via contrat public de lecture vers Reporting ; décomposer par domaine et usage, sans dépendance universelle |
| INT-125 | D16 Documents → D18 Reporting | P10 | Archiver ou diffuser un rapport — Rapport, export, période, destinataire | D18 Reporting | Qualifiée | À qualifier | Événement de publication du rapport par Reporting, consommé par Documents pour archivage et diffusion |

## 5. Points transverses à conserver

### 5.1 Questions métier ouvertes

- **Q-11** : propriété des taux horaires de référence ; ne pas attribuer de source définitive.
- **Q-24** : propriété de la capacité atelier et arbitrage Workshop / Planning.
- **Q-29** : périmètre des habilitations opérationnelles, EPI et autorisations de sécurité.
- **Q-31** : distinction entre exigences de contenu DOE (Handover) et cycle de vie documentaire (Documents).
- **Q-44** : répartition des garanties clientes et fournisseurs entre Handover et Procurement.

Les interactions associées restent dans leur statut métier source et ne sont pas artificiellement résolues par la classification technique.

### 5.2 Interactions génériques à décomposer

- **INT-114 / INT-115** : identifier chaque déposant et consommateur documentaire réel ; pas de dépendance universelle à Documents.
- **INT-123 / INT-124** : identifier chaque source de données, indicateur et consommateur de reporting ; Reporting ne devient pas autorité métier.
- **INT-001** : contrôle technique d'identité et d'autorisation, hors matrice des dépendances métier uniformes.
- **INT-004 / INT-005** : conditionnées à une décision effective d'ouverture des portails concernés.

### 5.3 Garde-fous de propriété

- Clients conserve le référentiel maître des tiers et le devis commercial complet jusqu'à signature.
- Projects porte l'affaire et les décisions contractuelles de réception ; le service administratif prononce la clôture administrative selon V-59.
- Quality conserve les contrôles, la conformité et les NCR.
- Documents possède le contenant documentaire, les versions et la diffusion, pas la validité métier.
- Handover prépare et centralise les pièces de réception et le suivi documentaire.
- Reporting consomme et agrège ; il ne réécrit pas les données sources et ne décide pas à la place des domaines.
- Identity n'est pas une dépendance métier uniforme.
- Aucun domaine consommateur n'accède aux Models, Actions, Services, Policies ou tables internes d'un autre domaine.

### 5.4 Règles de cycles et de fiabilité

1. Décomposer toute relation métier réciproque en échanges distincts, avec un fournisseur explicite pour chaque capacité.
2. Publier les faits accomplis depuis leur domaine propriétaire ; le consommateur réagit sans retour synchrone implicite.
3. Ne pas déclencher une nouvelle modification chez l'émetteur en réponse automatique à son propre événement.
4. Réserver les contrats synchrones aux réponses nécessaires avant la poursuite de l'opération.
5. Ne pas introduire de transaction partagée inter-domaines par défaut.
6. Pour les événements liés à une écriture transactionnelle, publier après commit conformément à CHAN-28 ; protéger les effets de bord contre les doublons.
7. Ne promettre ni livraison exactly-once, ni durabilité sans infrastructure effectivement prévue et documentée.

## 6. Limites de cette consolidation

Cette matrice est une qualification documentaire initiale, pas un inventaire de contrats ou d'événements déjà implémentés. Les sources examinées ne démontrent pas, pour chacune des interactions, le chemin de code, le contrat public, le payload, les consommateurs effectifs, la politique d'erreur ou les garanties d'exploitation. Ces éléments doivent être vérifiés lors de la conception et de la revue technique correspondantes, sans introduire de code dans CHAN-29.

Le registre métier source reste la référence pour le statut métier et les descriptions détaillées. Toute modification de ces statuts nécessite un arbitrage métier explicite.

## 7. Traçabilité

- Référence Jira : CHAN-29.
- Lot : C — classification technique et consolidation documentaire.
- Branche de travail : `docs/chan-29-lot-c-technical-dependency-matrix`.
- Base : `develop`.
- Périmètre : documentation uniquement ; aucun PHP, DTO, événement, listener, job, provider, migration, test d'architecture ou changement Jira.
- Fusion : non autorisée par le présent livrable ; revue et validation requises.
