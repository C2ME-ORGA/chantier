# Matrice RBAC CHAN-40 — Rôles et permissions

> **Statut :** référentiel de conception consolidé à partir des décisions Jira ; nomenclature et traductions techniques restant à normaliser avant implémentation.
> **Ticket :** CHAN-40 — Créer le modèle de rôles et permissions initiaux.
> **Date :** 23 novembre 2026.
> **Périmètre :** catalogue des permissions, rôles, affectations RBAC et accès au panel Filament.
> **Hors périmètre :** Policies et restrictions par ressource ou chantier (CHAN-42), tests fonctionnels complets d’autorisation (CHAN-46). Les seeders, le catalogue RBAC et le contrôle d’accès au panel font partie des livrables techniques de CHAN-40, après consolidation et validation de la nomenclature.

## Sources et limites

Sources fonctionnelles :

- Jira 10297 — principes généraux et sécurité ;
- Jira 10298 — Direction, Administratif, Super administrateur, Conducteur de travaux, Chef de chantier, Responsable atelier ;
- Jira 10299 — Salarié ;
- Jira 10300 — Comptabilité ;
- Jira 10301 — consolidation ;
- Jira 10303 — arbitrages actualisés du 20/11/2026.

Les décisions Jira 10297 à 10303 sont utilisées comme cadrage à partir des éléments fournis pour cette mission. La relecture directe des commentaires Jira n’a pas été possible dans l’environnement (API/Jira inaccessible, `404`). Le commentaire 10303 du 20/11/2026 complète les commentaires 10297 à 10301 ; il ne les remplace pas. Les décisions antérieures restent applicables lorsqu’elles ne sont pas modifiées ou précisées par 10303.

Priorité d’interprétation :

1. décisions explicites de 10303 ;
2. restrictions détaillées de 10298, 10299 et 10300 ;
3. synthèse 10301, sans extension automatique ;
4. propositions techniques de ce document, clairement identifiées.

| Type de source | Source effectivement utilisée | Statut |
| --- | --- | --- |
| Décisions Jira | 10297 à 10303, reprises via le cadrage fourni | Utilisées |
| Constat de code | Dépôt `develop`, commit `e305736` | Vérifié |
| Proposition de conception | Présent document | Non validée |
| Vérification directe Jira | API/Jira | Non accessible (`404`) |

## Légende

### Statut fonctionnel

| Statut | Signification |
| --- | --- |
| `Validé` | Règle fonctionnelle explicitement arbitrée dans Jira |
| `Proposé` | Droit décrit mais non encore validé fonctionnellement |
| `À arbitrer` | Décision métier ou rattachement non tranché |
| `Hors périmètre` | Sujet relevant d’un autre ticket |

### Statut technique

| Statut | Signification |
| --- | --- |
| `À normaliser` | Code ou action à aligner sur la convention |
| `Normalisé` | Code stable, pas encore implémenté |
| `À implémenter` | Code stable, implémentation à réaliser |
| `Implémenté` | Permission, rôle ou association présent dans le code ou la base |
| `À vérifier` | Ressource, action ou détail technique à confirmer |

Dans les tableaux de permissions, la colonne `Statut fonctionnel / technique` sépare les deux niveaux par un point-virgule. Exemple : `Décision métier validée ; actions à normaliser`. Lorsque la partie technique est absente, la permission est par défaut `À normaliser`.

Rôles :

```text
SA  = Super administrateur
DIR = Direction
ADM = Administratif
CT  = Conducteur de travaux
CC  = Chef de chantier
RA  = Responsable atelier
SAL = Salarié
CPT = Comptabilité
```

## 1. Contexte et références Jira

La matrice couvre huit rôles et doit servir de référence à l’implémentation CHAN-40 et à la rédaction des tests CHAN-46. Elle ne doit pas être utilisée pour déduire un accès à une ressource précise : les Policies et périmètres relèvent de CHAN-42.

Principes directeurs :

- default deny ;
- une permission Spatie représente une capacité fonctionnelle atomique ;
- aucune permission générique `manage` ;
- aucun wildcard ;
- guard `web` ;
- Teams désactivé ;
- `identity.admin_panel.access` contrôle l’accès au panel, sans donner accès aux ressources ;
- les règles de seuil, cumul, workflow et historique ne sont pas des permissions ;
- aucune affectation automatique de rôle aux utilisateurs existants ;
- aucun héritage implicite entre rôles.

## 2. État technique constaté

| Élément | Constat |
| --- | --- |
| Branche | `develop` |
| Commit | `e305736` |
| Statut Git | Propre |
| Package | `spatie/laravel-permission` 8.5.0 |
| Guard | `web` |
| Teams | `false` |
| Wildcard | Désactivé |
| Cache | 24 h, clé `spatie.permission.cache`, store `default` |
| Tables Spatie | `permissions`, `roles`, `model_has_permissions`, `model_has_roles`, `role_has_permissions` |
| `HasRoles` | Présent sur `App\Models\User` |
| `app/Domains/Identity/` | Seulement `.gitkeep` |
| Catalogue métier | Absent |
| Rôles métier | Absents |
| Seeder d’autorisation | Absent |
| `DatabaseSeeder` | Crée uniquement un utilisateur de test |
| `identity.admin_panel.access` | Absent du dépôt |
| `inventory.consomations` | Absent du dépôt ; correction à porter dans le catalogue source |
| `canAccessPanel()` | Retourne `true` pour tout utilisateur authentifié |
| Tests existants | 223 tests, 1 369 assertions, OK |
| Tests Spatie | Techniques, non représentatifs du catalogue métier |

Divergences entre documentation et code :

- `docs/development/authorization.md` décrit le socle CHAN-38, pas le catalogue métier.
- `docs/architecture/business-objects.md` contient 132 objets métier, mais aucun catalogue de permissions.
- `config/permission.php` est standard, sans catalogue de rôles.
- `canAccessPanel()` n’applique aucune permission.

## 3. Rôles et responsabilités

### 3.1 Super administrateur

**Finalité.** Administrer les habilitations et disposer d’une capacité d’intervention métier et administrative globale, y compris en suppléance de la Direction.

**Périmètre.** Tous les modules et données métier, ainsi que l’administration des utilisateurs, rôles, permissions, attributions et paramètres d’accès.

**Consultation.** Accès à l’ensemble des données métier et administratives, sous réserve de l’exception médicale ci-dessous.

**Création et modification.** Peut créer et modifier les données métier et administratives lorsque l’opération est prévue par le processus. Administre également les utilisateurs, rôles, permissions, attributions et paramètres d’accès.

**Suppression.** Peut supprimer lorsque l’opération est prévue et autorisée par les règles métier ; privilégier l’archivage ou la désactivation lorsque la suppression physique n’est pas appropriée.

**Validation / approbation.** Peut intervenir sur les opérations relevant normalement de la Direction, notamment les autorisations financières et la validation finale de la paie, selon les catégories et règles de délégation applicables. Toute approbation financière par SA comporte un motif obligatoire.

**Restrictions.**

- Aucun accès automatique aux documents médicaux détaillés relevant du secret médical.
- Aucun contournement des Policies CHAN-42 : les droits globaux fonctionnels ne suppriment pas les contrôles d’accès aux ressources.
- Toutes les actions sensibles sont auditées ; l’auteur de l’action, y compris SA, ne peut ni modifier ni supprimer les traces d’audit.
- Interdiction de s’auto-approuver lorsque le workflow impose une séparation des tâches.

**Limites de périmètre.** Société entière pour les capacités métier et administratives, sous réserve des restrictions légales, médicales, des workflows et des Policies CHAN-42.

### 3.2 Direction

**Finalité.** Piloter l’entreprise et exercer les décisions opérationnelles, stratégiques et financières relevant de la Direction.

**Périmètre.** Tous les modules métier et toutes les données métier sont dans le champ de responsabilité de la Direction. Les capacités effectives de consultation, création, modification et validation sont toutefois définies ressource par ressource et selon les workflows du catalogue §5 ; la portée transversale ne vaut pas attribution automatique de toutes ces actions. La matrice §6 synthétise exclusivement les permissions explicites du §5. Les droits validés mais non encore traduits sont recensés dans A-16, sans extension implicite du catalogue. La gestion des habilitations techniques reste exclue.

**Consultation.** Consultation transversale des données métier nécessaires à ses fonctions, sous réserve des permissions explicites du catalogue §5 et des Policies applicables. Pour les données RH sensibles, accès limité aux informations légalement accessibles et nécessaires. Pour les données médicales, aucun accès aux documents détenus dans l’espace confidentiel des professionnels de santé.

**Création et modification.** Ces capacités sont attribuées uniquement lorsqu’une action correspondante est explicitement prévue pour DIR dans la ligne de ressource concernée au §5 et par le workflow applicable. Une capacité de consultation transversale ne confère pas, à elle seule, un droit de création ou de modification. Les droits sur les données RH sensibles restent strictement différenciés.

**Suppression.** Aucune suppression universelle implicite. La suppression reste définie ressource par ressource, lorsqu’une décision métier l’autorise.

**Validation / approbation.**

- Peut autoriser les paiements préparés par Comptabilité et valider définitivement la paie.
- Peut approuver les engagements financiers selon le seuil et les délégations paramétrées.
- Au-delà de 100 000 € HT cumulés pour une même opération, validation préalable de DIR ou SA obligatoire.
- Pas de motif obligatoire pour ses approbations, mais auteur, date, décision, montant et objet sont historisés.
- Les validations opérationnelles attribuées à CT, CC ou RA ne lui sont pas transférées implicitement : chaque workflow conserve ses responsabilités dédiées.

**Restrictions.**

- Aucun droit de création, modification, attribution ou suppression des utilisateurs, rôles, permissions ou paramètres d’habilitation.
- Aucun contournement des workflows de séparation des tâches ou des Policies CHAN-42.
- Respect du secret médical et des restrictions légales applicables.
- Interdiction d’autoriser son propre paiement ou de s’auto-approuver lorsque le workflow impose un tiers.

**Limites de périmètre.** Société entière pour les données et opérations métier, dans les limites légales, des workflows et des restrictions de confidentialité.

### 3.3 Administratif

**Finalité.** Gestion administrative et préparation.

**Périmètre.** Prospects, clients, contacts, relations commerciales, conditions commerciales, devis, données administratives RH, contrats, postes, qualifications, formations, dossiers RH, variables de paie, documents administratifs, fournisseurs, sous-traitants, demandes d’achat, préparation administrative des commandes, consultation des affaires, chantiers et budgets, rapports autorisés.

**Consultation.** Clients, affaires, chantiers, budgets, RH administrative hors rémunérations, bulletins, coordonnées bancaires, dossiers disciplinaires et données médicales détaillées, documents, fournisseurs, rapports autorisés.

**Création.** Prospects, clients, contacts, relations, devis, dossiers RH, variables de paie, demandes d’achat, documents, fournisseurs, sous-traitants.

**Modification.** Mêmes périmètres ; pas de modification technique des chantiers.

**Suppression.** Non explicitement décidée ; archivage/désactivation à privilégier.

**Validation.**

- validation courante des absences ;
- pas de validation finale de paie ;
- pas d’approbation financière ;
- pas de paiement.

**Restrictions.**

- Pas d’accès par défaut aux rémunérations, bulletins, coordonnées bancaires, dossiers disciplinaires ou données médicales détaillées.
- Gestion RH courante : identité, coordonnées, contrats, avenants, qualifications, habilitations, formations, absences et documents administratifs.
- Pas de validation finale de paie.
- Pas de pouvoir de paiement.
- Pas de modification technique des chantiers.
- Validation courante des absences ; contrôle administratif des heures supplémentaires et des grands déplacements.
- Pointages : ADM n’assure pas une validation supplémentaire des pointages. CC valide son équipe, CT contrôle et peut corriger ou rouvrir les pointages des salariés affectés après validation CC, RA valide son équipe, CPT exploite les pointages validés pour la paie sans modification libre. ADM assure les contrôles administratifs et réglementaires, notamment sur les heures supplémentaires.
- La référence V-47, si elle est conservée, reste un point à vérifier et ne doit pas créer une seconde validation des pointages.

**Limites de périmètre.** Administration société ; accès RH selon confidentialité.

### 3.4 Conducteur de travaux

**Finalité.** Gestion opérationnelle des affaires et chantiers affectés.

**Périmètre.** Affaires, chantiers, lots et phases, planning et affectations, budgets prévisionnels, coûts prévisionnels, révisions préparées, consultation des coûts et rentabilité, collaborateurs, pointages des salariés affectés, demandes d’achat, stocks et mouvements, matériels, livraisons, contrôles qualité, observations sécurité, documents chantier, réceptions et rapports opérationnels.

**Consultation.** Affaires, chantiers, planning, budgets, coûts, marges, écarts, collaborateurs, pointages, stocks, matériels, livraisons, qualité, sécurité, documents, réceptions, rapports.

**Création.** Affaires, chantiers, lots, planning, affectations, budgets, révisions, demandes d’achat, mouvements de stock, contrôles qualité, observations sécurité, documents, réceptions, rapports.

**Modification.** Mêmes périmètres. Pas d’approbation de ses propres révisions.

**Suppression.** Non explicitement décidée ; archivage à privilégier.

**Validation.** Contrôle et validation des pointages des salariés affectés à ses chantiers, y compris ceux déjà validés par un Chef de chantier. Peut corriger ou rouvrir un pointage avec motif et traçabilité ; une seconde validation systématique n’est pas nécessaire. Validation qualité à préciser.

**Restrictions.**

- Pas d’approbation financière générale.
- Pas d’approbation de ses propres révisions budgétaires.
- Pas d’engagement financier autonome.
- Périmètre d’accès contrôlé par CHAN-42.
- La validation des pointages dépend de l’affectation chantier, pas seulement de la hiérarchie.
- Accès RH limité aux informations opérationnelles nécessaires ; pas d’accès aux rémunérations, bulletins, coordonnées bancaires, dossiers disciplinaires ou données médicales.
- Pas de seconde validation systématique des pointages déjà contrôlés par un Chef de chantier.

**Limites de périmètre.** Affaires et chantiers affectés.

### 3.5 Chef de chantier

**Finalité.** Exécution quotidienne du chantier affecté.

**Périmètre.** Affaires et chantiers affectés, planning consultable, équipe, pointages, ordres de fabrication, stocks et consommations, besoins, matériel affecté, contrôles qualité, non-conformités, observations sécurité, documents, rapports quotidiens, réserves de réception, sous-traitants et incidents.

**Consultation.** Affaires, chantiers, planning, équipe, OF, stocks, matériel, documents, rapports, réserves.

**Création.** Pointages et corrections de son équipe, consommations, contrôles qualité, non-conformités, observations sécurité, rapports quotidiens, réserves, signalements de besoins, incidents sous-traitance, incidents matériel.

**Modification.** Pointages de son équipe, documents, rapports. Pas de modification du planning.

**Suppression.** Aucune suppression décidée.

**Validation.** Pointages de son équipe. Pas de clôture autonome des non-conformités relevant du Conducteur. Pas de validation formelle de réception.

**Restrictions.**

- Aucun accès aux budgets, coûts engagés, marges ou rentabilité.
- Aucun accès financier.
- Pas de création autonome de commande ou d’engagement d’achat.
- Pas de modification du planning.
- Pas de clôture de non-conformité relevant du Conducteur.
- Pas de validation formelle de réception.
- Accès limité aux chantiers affectés.
- Accès RH limité aux informations opérationnelles de son équipe ; pas d’accès aux rémunérations, bulletins, coordonnées bancaires, dossiers disciplinaires ou données médicales.
- Donne un avis opérationnel sur les absences ; ne valide pas les demandes courantes et n’arbitre pas.
- Contrôle, corrige et valide les heures de son équipe ; les heures supplémentaires sont autorisées par le CT ou le RA selon le périmètre.

**Limites de périmètre.** Chantiers et équipes affectés.

### 3.6 Responsable atelier

**Finalité.** Autonomie opérationnelle de production.

**Périmètre.** OF, dossiers de fabrication, opérations, postes, capacités, demandes matière, comptes rendus, colis, planning atelier, affectations opérateurs, stocks, mouvements, consommations, inventaires, ajustements, équipements, maintenance, qualité atelier, sécurité atelier, logistique et expédition, demandes d’achat, coûts atelier, temps de son équipe, reporting de production.

**Consultation.** OF, production, stocks, équipements, qualité, sécurité, logistique, coûts atelier, engagements, temps, reporting.

**Création.** OF, dossiers, opérations, demandes matière, comptes rendus, colis, mouvements, consommations, inventaires, maintenance, contrôles qualité, non-conformités, actions sécurité, demandes de transport, demandes d’achat, rapports.

**Modification.** OF, priorités atelier, affectations opérateurs, planning atelier, stocks, équipements, maintenance, qualité, sécurité, temps de son équipe.

**Suppression.** Non explicitement décidée ; archivage à privilégier.

**Validation.** Fabrications, qualité atelier, non-conformités atelier après vérification, temps de son équipe. Validations personnelles et auditées.

**Restrictions.**

- Pas d’engagement financier autonome.
- Les commandes nécessitent une approbation préalable.
- Pas d’approbation des plans de conception.
- Les changements de priorité impactant les engagements chantier doivent être coordonnés avec le Conducteur.
- Accès RH limité aux informations opérationnelles de son équipe ; pas d’accès aux rémunérations, bulletins, coordonnées bancaires, dossiers disciplinaires ou données médicales.
- Donne un avis opérationnel sur les absences ; ne valide pas les demandes courantes et n’arbitre pas.
- Autorise les heures supplémentaires de l’équipe atelier et déclare les périodes de grands déplacements de son équipe.

**Limites de périmètre.** Atelier et production.

### 3.7 Salarié

**Finalité.** Portail personnel.

**Périmètre.** Son dossier, contrat, poste, bulletins, formations, qualifications, pointages, heures supplémentaires, congés et absences, documents des chantiers affectés, OF et tâches affectées, matériel affecté, plannings, signalements qualité et sécurité, annuaire et messagerie interne. La gestion des sessions personnelles relève de CHAN-43.

**Consultation.** Ses données, ses documents, ses OF, son matériel, ses plannings.

**Création.** Pointages, corrections, heures supplémentaires, demandes de congé ou absence, comptes rendus de production, signalements qualité et sécurité, messages.

**Modification.** Certaines coordonnées personnelles, pointages et corrections, dans son propre périmètre.

**Suppression.** Aucune suppression décidée. La révocation de ses sessions relève de CHAN-43.

**Validation.** Aucune auto-validation.

**Restrictions.**

- Aucun accès au panel Filament.
- Aucun accès aux budgets, coûts, marges, prix de vente, données commerciales ou comptables.
- Aucun accès au module des frais professionnels.
- Aucun accès aux rapports et livraisons.
- Pas de mouvement de stock ni de gestion d’équipement.
- Données limitées à son propre dossier et à ses affectations réelles.
- Accès à ses propres coordonnées bancaires uniquement ; une modification reste inactive jusqu’à validation par une personne habilitée.
- Aucun accès aux données médicales détaillées, aux dossiers disciplinaires ou aux données d’un autre salarié.
- Aucune auto-validation de ses pointages, absences, heures supplémentaires ou modifications de coordonnées.

**Limites de périmètre.** Données personnelles et affectations réelles, via CHAN-42.

### 3.8 Comptabilité

**Finalité.** Comptabilité, facturation, paiements autorisés, paie comptable, banque, clôtures et exports.

**Périmètre.** Factures clients, avoirs, relances, échéanciers, litiges, factures fournisseurs, rapprochement commande/facture, consultation des commandes, préparation et exécution des paiements autorisés, trésorerie, relevés et rapprochements bancaires, éléments de paie, salaires, cotisations, bulletins, clôtures et déclarations, comptabilité analytique, écritures, journaux, plan comptable, périodes, contrepassations, immobilisations, amortissements, indemnités de grands déplacements, exports comptables, analytiques, paie, immobilisations, trésorerie, fournisseurs et clients.

**Consultation.** Factures, commandes, paie, banque, trésorerie, comptabilité, données financières.

**Création.** Factures, avoirs, relances, échéanciers, litiges, factures fournisseurs, écritures, journaux, plan comptable, rapprochements, paiements préparés, déclarations, clôtures, analytique, immobilisations, amortissements, indemnités de grands déplacements, exports, relations organismes.

**Modification.** Mêmes périmètres ; contrepassations, régularisations, verrouillage/déverrouillage des périodes.

**Suppression.** Non explicitement décidée ; contrepassation à privilégier.

**Paie et paiements.** Prépare et contrôle les éléments de paie ; DIR ou SA valide définitivement la paie. Après validation, CPT transmet et traite le paiement. Toute modification postérieure à la validation impose une nouvelle validation. Prépare les paiements et leurs justificatifs ; DIR ou SA autorise ou refuse ; CPT exécute uniquement après autorisation. Le préparateur ne peut pas autoriser son propre paiement.

**Données RH.** Accès aux informations nécessaires à la paie et à la comptabilité sociale, notamment bulletins et coordonnées bancaires nécessaires aux virements. Pas d’accès général aux dossiers disciplinaires ou aux justificatifs personnels sans lien avec la paie.

**Validation.** Aucune approbation d’engagement, aucune validation de commande, aucune validation finale de paie, aucune validation des comptes annuels, aucune modification des mandats bancaires, aucune auto-autorisation de paiement.

**Restrictions.**

- Paiements exécutés uniquement après autorisation préalable.
- Interdiction d’auto-autorisation d’un paiement.
- Pas d’accès aux tableaux de bord stratégiques réservés à la Direction.
- Opérations sensibles auditées.
- Pas d’approbation budgétaire.
- Pas de validation définitive des déclarations fiscales ou sociales.

**Limites de périmètre.** Société entière pour la comptabilité ; données bancaires et paie restreintes.

## 4. Catalogue normalisé des domaines et ressources

### 4.1 Domaines

| Code | Domaine | Slug proposé | Ressources principales |
| --- | --- | --- | --- |
| D01 | Identity | `identity` | Utilisateur, Rôle, Permission, Périmètre, Délégation, UnitéOrganisationnelle, Sessions (CHAN-43), Annuaire, Messagerie |
| D02 | Clients | `clients` | Prospect, Client, Contact, RelationCommerciale, ConditionsCommerciales, DevisCommercial, FactureClient, Avoir, Relance, Échéancier, Litige |
| D03 | Projects | `projects` | Affaire, Chantier, LotPhase, Étude, CommandeClient, Avenant, Contrat, Jalon, Réception |
| D04 | Planning | `planning` | PlanDeCharge, Activité, Affectation, Calendrier, Conflit, Avancement |
| D05 | Budgets | `budgets` | Budget, LigneBudgétaire, RévisionBudgétaire, Contingence |
| D06 | Costing | `costing` | Chiffrage, Coût, Engagement, Marge, Écart, ProvisionAnalytique, PériodeAnalytique |
| D07 | Workforce | `workforce` | Collaborateur, Contrat, Poste, Qualification, Formation, Équipe, Disponibilité, ÉlémentVariableDePaie, DossierRH, Paie, Bulletin, CoordonnéesBancaires, DossierDisciplinaire, DonnéesMédicales, GrandDéplacement |
| D08 | TimeTracking | `timetracking` | Pointage, FeuilleDeTemps, Imputation, Période, Correction, Absence, HeureSupplémentaire |
| D09 | Workshop | `workshop` | OrdreDeFabrication, DossierDeFabrication, Opération, Poste, DemandeMatière, CompteRendu, Colis, Capacité |
| D10 | Procurement | `procurement` | Fournisseur, SousTraitant, DemandeDAchat, Offre, CommandeDAchat, Ligne, CommandeDeSousTraitance, Évaluation, AccordCadre, Garantie, FactureFournisseur, Besoin, IncidentSousTraitance |
| D11 | Inventory | `inventory` | Article, Entrepôt, Emplacement, Lot, Mouvement, Réception, Réservation, Consommation, BonDeSortie, Inventaire |
| D12 | Equipment | `equipment` | Équipement, Catégorie, Affectation, Maintenance, Intervention, Inspection, Panne |
| D13 | Logistics | `logistics` | DemandeDeTransport, PlanDeTransport, Tournée, Livraison, RéceptionChantier, Retour, AccèsChantier |
| D14 | Quality | `quality` | PlanQualité, PlanDeContrôle, Contrôle, NonConformité, ActionCorrective, Audit, Certificat, QualificationTechnique, Signalement |
| D15 | Safety | `safety` | AnalyseDeRisques, PlanDePrévention, Inspection, Incident, ActionSécurité, Habilitation, AutorisationDeTravail, Induction, Signalement |
| D16 | Documents | `documents` | Document, Version, Dossier, TypeDocument, Diffusion, RègleDeConservation |
| D17 | Handover | `handover` | DossierDeRéception, Réserve, LevéeDeRéserve, DOE, GarantieClient, DossierDeClôture |
| D18 | Reporting | `reporting` | Rapport, TableauDeBord, Indicateur, Snapshot, Export, TableauDeBordStratégique |

### 4.2 Namespace `accounting`

Le namespace `accounting` est introduit par 10300 mais n’est pas un domaine validé.

| Option | Avantages | Inconvénients |
| --- | --- | --- |
| Domaine distinct | Périmètre cohérent, propriétaire unique | Contredit les 18 domaines ; chevauche Clients, Procurement, Workforce, Budgets et Costing |
| Répartition dans les domaines existants | Respecte les 18 domaines | Éclate la comptabilité ; banque, journaux, immobilisations et déclarations sans propriétaire |
| Module ou contexte séparé | Préserve les 18 domaines, isole la finance | Nécessite une convention d’intégration et une décision d’architecture |

**Décision d’architecture :** à arbitrer. Le rattachement du namespace `accounting` n’est pas tranché. Les décisions fonctionnelles sur les paiements, la paie, la banque et les clôtures sont validées ; leurs codes restent techniquement `À normaliser` et leur rattachement de domaine reste `À arbitrer`.

### 4.3 Convention de nommage

Proposition :

```text
{domain}.{resource}.{action}
```

- domaine en minuscules ;
- ressource en `snake_case` ;
- action en anglais, minuscule ;
- collections au pluriel, objets uniques au singulier ;
- pas de wildcard ;
- pas de `manage` générique.

Points à vérifier :

| Sujet | Proposition | Statut technique |
| --- | --- | --- |
| TimeTracking | `timetracking` | `À vérifier` |
| Budgets | `budgets.budget` plutôt que `budgets.budgets` | `À vérifier` |
| Factures clients | `clients.factures` plutôt que `clients.factures_clients` | `À vérifier` |
| Consommations | `inventory.consommations` | `Normalisé` pour la correction orthographique |
| Actions | Registre existant + actions complémentaires à valider | `À normaliser` |

## 5. Catalogue complet des permissions

Les tableaux indiquent les actions et les rôles. Chaque action listée forme une permission atomique `{domain}.{resource}.{action}`. Les ressources non listées ne reçoivent aucune permission par défaut. La dernière colonne sépare le statut fonctionnel et le statut technique ; une décision métier validée ne signifie pas que le code est normalisé ou implémenté.

Deux rôles ont une portée fonctionnelle globale décidée par 10303. Ces règles ne sont pas répétées sur chaque ligne métier :

- **SA** : droit métier et administratif global sur les modules et données métier, sous réserve de l’exception médicale et des Policies CHAN-42. Les permissions SA listées dans les tableaux sont celles qui nécessitent une précision.
- **DIR** : responsabilité métier transversale sur les modules et les données nécessaires au pilotage. Elle ne crée pas automatiquement de CRUDV générique : les accès complets accordés par arbitrage explicite sont détaillés ressource par ressource au §5 (notamment Costing, Workforce, TimeTracking, Workshop, Procurement, Inventory et Equipment). Les autres actions DIR effectivement inscrites au §5 sont les seules permissions explicites ; toute capacité non traduite est suivie en A-16 et toute capacité dont l’existence ou l’étendue n’est pas suffisamment établie reste à arbitrer. Les approbations financières, paiements, paie, données médicales et reporting stratégique conservent leurs règles spécifiques.

Les règles de portée globale sont fonctionnellement `Validé` et techniquement `À normaliser` pour SA. Pour DIR, le principe de responsabilité transversale est validé, mais les permissions restent celles explicitement définies au §5 ; les écarts non traduits ou à arbitrer sont suivis en A-16. Aucun de ces principes ne crée un droit d’administration des habilitations pour DIR ni un accès automatique aux documents médicaux détaillés pour SA.

### 5.1 Identity

| Ressource | Actions / rôles | Scope | Justification | Source | Statut fonctionnel / technique |
| --- | --- | --- | --- | --- | --- |
| `admin_panel` | `access` : SA, DIR, ADM, CT, CC, RA, CPT | global | Accès au panel Filament, sans accès ressource | 10297, 10298, 10301 | `Validé` ; `À implémenter` |
| `users` | `view`, `create`, `update`, `deactivate` : SA | global | Administration des comptes | 10298 | `Proposé` / `deactivate` à arbitrer |
| `roles` | `view`, `create`, `update`, `delete`, `assign` : SA | global | Administration des rôles | 10298 | `Proposé` / `delete` à arbitrer |
| `permissions` | `view`, `create`, `update`, `delete` : SA | global | Administration des permissions | 10298 | `Proposé` |
| `role_assignments` | `assign`, `revoke` : SA | global | Attribution et retrait de rôles | 10298 | `Proposé` / `revoke` à arbitrer |
| `access_settings` | `view`, `update` : SA | global | Paramètres d’accès | 10298 | `Proposé` |
| `financial_delegations` | `view`, `create`, `update`, `suspend`, `delete` : SA, DIR | global | Paramétrage des délégations par rôle et catégorie ; toute modification est historisée ; `suspend` et `delete` restent à préciser | 10303 | Décision métier validée ; sémantique de `suspend`/`delete` à arbitrer |
| `sessions` | Hors périmètre CHAN-40 — géré par CHAN-43 | own | Sessions personnelles | 10299, CHAN-43 | `Hors périmètre` / `À vérifier` |
| `directory` | `view` : SAL et autres rôles à confirmer | global | Annuaire interne | 10299 | `À arbitrer` |
| `messages` | `send` : SAL et autres rôles à confirmer | own / global | Messagerie interne | 10299 | `À arbitrer` |

### 5.2 Clients

| Ressource | Actions / rôles | Scope | Justification | Source | Statut fonctionnel / technique |
| --- | --- | --- | --- | --- | --- |
| `prospects`, `clients`, `contacts`, `relations_commerciales` | `view`, `create`, `update` : ADM ; `view` : DIR selon liste | global / company | Gestion administrative | 10298 | `Proposé` |
| `conditions_commerciales` | `view`, `create`, `update` : ADM ; `approve` : DIR pour toutes les conditions, modifications et dérogations | global | Approbation des conditions commerciales, sans droit implicite de modification pour DIR | 10298, arbitrage A.4.2 Groupe 1 | Décision métier validée ; permission à intégrer et workflow à préciser |
| `devis_commerciaux` | `view`, `create`, `update`, `submit` : ADM ; `approve` : DIR, SA ; `view` : DIR | global | Préparation, soumission et approbation | 10298, 10301 | `Proposé` |
| `factures_clients`, `avoirs` | `view`, `create`, `update`, `issue` : CPT ; `view` : DIR | global | Consultation DIR ; préparation et émission comptables conservées à CPT | 10300, arbitrage A.4.2 Groupe 1 | Décision métier validée ; permissions à intégrer |
| `relances`, `echeanciers`, `litiges_facturation` | `view`, `create`, `update` : CPT ; `view`, `arbitrate` : DIR ; approbation d'une régularisation financière par DIR à modéliser dans un workflow distinct | global | Consultation et arbitrage DIR ; aucune création/émission d'avoir ni exécution de paiement par effet implicite | 10300, arbitrage A.4.2 Groupe 1 | Arbitrage et consultation validés ; action `arbitrate` à normaliser (A-07) ; objet/action d'approbation financière à préciser |
| `reglements` | `view`, `reconcile` : CPT ; `view` : DIR | global | Consultation DIR ; rapprochement CPT | 10300, arbitrage A.4.2 Groupe 1 | Décision métier validée ; permissions à intégrer |

### 5.3 Projects

| Ressource | Actions / rôles | Scope | Justification | Source | Statut fonctionnel / technique |
| --- | --- | --- | --- | --- | --- |
| `affaires` | `view`, `create`, `update` : CT ; `view` : ADM, CC, CPT, DIR | global pour DIR ; assigned_projects pour CT | Affaires au niveau contractuel/commercial ; consultation DIR globale | 10298, arbitrage A.4.2 Groupe 1 | Consultation DIR validée ; permissions à intégrer |
| `chantiers` | `view`, `create`, `update` : CT ; `view` : ADM, CC, CPT, DIR | global pour DIR ; assigned_sites pour CT | Gestion opérationnelle ; consultation DIR globale | 10298, arbitrage A.4.2 Groupe 1 | Consultation DIR validée ; permissions à intégrer |
| `lots_phases` | Actions et attribution à confirmer selon le rattachement métier au niveau affaire ou chantier | À arbitrer | Le document source ne permet pas de fixer un scope unique sans arbitrage | 10298 | `À arbitrer` |
| `etudes` | `view`, `create`, `update` : CT ; `view` : DIR | global pour DIR ; assigned_projects pour CT | Consultation DIR des études | 10298, arbitrage A.4.2 Groupe 1 | Consultation DIR validée ; permission à intégrer |
| `commandes_clients` | `view` : DIR, ADM, CT, CPT ; `approve` : DIR, SA | global / assigned_projects | Approbation contractuelle | 10298, 10301 | `Proposé` |
| `avenants` | `view` : DIR, ADM, CT ; `prepare`, `submit` : CT à confirmer ; `approve` : DIR, SA | global pour DIR ; assigned_projects pour CT | Approbation DIR uniquement ; préparation/soumission CT non modifiées ; seuil et cumul applicables | 10298, 10303, arbitrage A.4.2 Groupe 1 | Approbation DIR validée ; préparation/soumission CT restent à arbitrer |
| `contrats` | `view` : DIR, ADM, CT, CPT ; `approve` : DIR, SA | global | Contrats | 10298, 10301 | `Proposé` |
| `jalons` | `view`, `update` : CT ; `view` : DIR, CC | assigned_projects | Jalons | 10298 | `Proposé` |
| `receptions` | `view`, `prepare` : CT ; `view` : CC ; `approve` : DIR | global pour DIR ; assigned_projects pour CT | Approbation de la réception contractuelle par DIR, distincte de l'approbation finale du dossier Handover | 10298, arbitrage A.4.2 Groupe 1 | Décision métier validée ; permission à intégrer |
| `rapports_operationnels` | `view`, `create`, `update` : CT, CC ; `view` : DIR | assigned_projects | Rapports | 10298 | `Proposé` |

### 5.4 Planning

| Ressource | Actions / rôles | Scope | Justification | Source | Statut fonctionnel / technique |
| --- | --- | --- | --- | --- | --- |
| `plannings`, `affectations` | `view`, `create`, `update`, `assign` : CT ; `view` : CC, RA, SAL, DIR ; `update` atelier : RA | global pour DIR ; assigned_projects / own_team pour les rôles opérationnels | Consultation DIR des plannings contractuels et opérationnels ; aucune gestion quotidienne | 10298, arbitrage A.4.2 Groupe 1 | Consultation DIR validée ; permission à intégrer |
| `conflits` | `view`, `arbitrate` : DIR ; `view` : CT | global pour DIR ; assigned_projects pour CT | DIR consulte et arbitre les conflits de planning ; CT conserve son périmètre opérationnel affecté | 10298, arbitrage A.4.2 Groupe 1 et Groupe 2 | Arbitrage DIR validé fonctionnellement ; permission à normaliser (A-07) et Policy à appliquer dans CHAN-42 |
| `avancement` | `view`, `update` : CT, CC ; `view` : DIR | assigned_projects | Avancement | 10298 | `Proposé` |

### 5.5 Budgets

| Ressource | Actions / rôles | Scope | Justification | Source | Statut fonctionnel / technique |
| --- | --- | --- | --- | --- | --- |
| `budgets` | `view`, `create`, `update`, `submit` : CT ; `approve` : DIR, SA ; `view` : ADM, CPT, DIR | assigned_projects pour CT ; global pour DIR, SA, ADM, CPT selon rôle | Budgets ; approbation obligatoire de tous les budgets par DIR sans seuil de montant | 10298, 10301, arbitrage A.4.2 Groupe 2 | Approbation DIR sans restriction de montant validée fonctionnellement ; workflow à préciser |
| `lignes_budgetaires` | `view`, `create`, `update` : CT ; `view` : ADM, CPT | assigned_projects | Lignes budgétaires | 10298 | `Proposé` |
| `revisions_budgetaires` | `view`, `create`, `update`, `submit` : CT ; `approve` : DIR, SA ; `view` : ADM, CPT | assigned_projects pour CT ; global pour DIR, SA, ADM, CPT selon rôle | Révisions ; approbation obligatoire de toutes les révisions par DIR sans seuil de montant | 10298, 10301, arbitrage A.4.2 Groupe 2 | Approbation DIR sans restriction de montant validée fonctionnellement ; workflow à préciser |
| `contingences` | `view`, `create`, `update` : CT ; `approve` : DIR | assigned_projects pour CT ; global pour DIR | Approbation obligatoire de toutes les contingences par DIR sans seuil de montant ; préparation et modification restent distinctes | 10298, arbitrage A.4.2 Groupe 2 | Approbation DIR sans restriction de montant validée fonctionnellement ; workflow et séparation des tâches à préciser |

### 5.6 Costing

| Ressource | Actions / rôles | Scope | Justification | Source | Statut fonctionnel / technique |
| --- | --- | --- | --- | --- | --- |
| `chiffrages`, `couts`, `ecarts` | `view`, `create`, `update`, `validate` : DIR ; `view` : ADM, CT, RA, CPT ; `create`, `update` : CT, RA selon objet | global pour DIR ; assigned_projects pour CT/RA selon objet | Chiffrages, coûts et écarts financiers opérationnels | 10298, 10300, arbitrage A.4.2 Groupe 2 | Accès complet DIR, validation comprise, confirmé fonctionnellement ; workflow et séparation des tâches à préciser |
| `engagements` | `view` : DIR, CT, CPT ; `approve` : DIR, SA uniquement lorsque le seuil cumulé dépasse 100 000 € HT pour une même opération | global pour DIR/SA ; assigned_projects pour CT | Approbation préalable obligatoire au-delà de 100 000 € HT cumulés pour une même opération, en agrégeant commandes et avenants et en prévenant le fractionnement ; en dessous ou au seuil, pas d'approbation DIR au titre de cette règle | 10297, 10298, 10303, arbitrage A.4.2 Groupe 2 | Seuil et cumul validés ; modalités de délégation sous seuil et workflow à préciser
| `marges` | `view` : DIR, CT, RA, CPT | assigned_projects / global | Rentabilité | 10298, 10300 | `Proposé` |
| `provisions_analytiques` | `view` : DIR, CT, CPT ; `approve` : DIR, SA pour toutes les provisions analytiques, sans seuil de montant | global | Provisions | 10298, 10301, arbitrage A.4.2 Groupe 2 | Approbation DIR systématique confirmée ; workflow et séparation des tâches à préciser |
| `periodes_analytiques` | `view`, `lock`, `unlock`, `close` : DIR, CPT | global | Périodes analytiques | 10300, arbitrage A.4.2 Groupe 2 | Droits DIR confirmés sur consultation, verrouillage, déverrouillage et clôture ; workflow et séparation des tâches à préciser |

### 5.7 Workforce

| Ressource | Actions / rôles | Scope | Justification | Source | Statut fonctionnel / technique |
| --- | --- | --- | --- | --- | --- |
| `collaborateurs`, `contrats`, `postes`, `qualifications`, `formations`, `equipes`, `disponibilites` | Accès complet DIR : `view`, `create`, `update`, `delete` et toutes actions métier applicables ; ADM conserve `view`, `create`, `update` ; CT, CC, RA et SAL conservent leurs consultations limitées | global DIR / company / own_team / own | Accès complet Direction aux données RH administratives | Arbitrage A.4.2 Groupe 2 | Décision DIR confirmée ; actions à normaliser |
| `dossiers_rh` | Accès complet DIR : `view`, `create`, `update`, `delete` et toutes actions métier applicables ; ADM conserve `view`, `create`, `update` ; SAL conserve `view` own | global DIR / company / own | Dossiers RH, hors documents médicaux confidentiels | Arbitrage A.4.2 Groupe 2 | Décision DIR confirmée ; actions à normaliser |
| `dossiers_disciplinaires` | Accès complet DIR : `view`, `create`, `update`, `delete` et toutes actions métier applicables ; SA conserve ses droits globaux sous réserve des restrictions applicables | global DIR / restricted | Dossiers RH sensibles | Arbitrage A.4.2 Groupe 2 ; 10303 | Décision DIR confirmée ; actions à normaliser |
| `donnees_medicales` | DIR : accès uniquement aux informations légalement accessibles et strictement nécessaires ; aucun accès aux documents médicaux détaillés détenus par les professionnels de santé ; SA : aucun accès automatique aux documents médicaux détaillés ; ADM : réception et traitement administratif des justificatifs sans accès général aux données médicales détaillées ; CPT : seules informations nécessaires à la paie et à la comptabilité sociale | restricted | Secret médical et confidentialité des informations de santé | 10303 ; limite impérative maintenue | Exception explicite à l’accès complet ; accès détaillé interdit hors habilitation légale spécifique |
| `coordonnees_bancaires` | Accès complet DIR : `view`, `create`, `update`, `delete`, `validate` et toutes actions métier applicables ; SA et CPT conservent leurs droits ; SAL conserve `view` own et `request_update` | global DIR / own / restricted | Données bancaires ; historique sécurisé et validation indépendante des demandes de changement | Arbitrage A.4.2 Groupe 2 ; 10303 | Décision DIR confirmée ; actions à normaliser ; validation indépendante du demandeur/modificateur maintenue |
| `elements_variables_paie` | Accès complet DIR : `view`, `create`, `update`, `delete`, `prepare`, `control`, `submit`, `validate` et toutes actions métier applicables ; ADM conserve ses droits de préparation/soumission ; CPT conserve `view` | global DIR / company | Variables de paie | Arbitrage A.4.2 Groupe 2 ; 10298, 10300 | Décision DIR confirmée ; actions à normaliser ; séparation des tâches maintenue |
| `paies`, `bulletins_paie`, `ecritures_paie` | Accès complet DIR : `view`, `create`, `update`, `delete`, `prepare`, `control`, `validate` et toutes actions métier applicables ; CPT conserve `view`, `prepare`, `control` ; SAL conserve `view` bulletins own ; SA conserve ses droits | global DIR / own / restricted | Paie, bulletins et écritures ; validation finale et historique des modifications | Arbitrage A.4.2 Groupe 2 ; 10299, 10300, 10303 | Décision DIR confirmée ; actions à normaliser ; interdiction d’auto-approbation et exigences de validation après modification maintenues |
| `indemnites_grands_deplacements` | Accès complet DIR : `view`, `create`, `update`, `delete`, `prepare`, `control`, `process`, `validate` et toutes actions métier applicables ; SAL conserve `view` own ; ADM et CPT conservent leurs droits | global DIR / own / company | Indemnités de grand déplacement, éléments de paie et traitement comptable | Arbitrage A.4.2 Groupe 2 ; 10303 | Décision DIR confirmée ; actions à normaliser |
| `grands_deplacements` | Accès complet DIR : `view`, `create`, `update`, `delete`, `declare`, `control`, `prepare`, `process`, `validate` et toutes actions métier applicables ; CT/RA conservent la déclaration de leurs équipes ; ADM/CPT/SAL conservent leurs droits | global DIR / assigned_workers / own / company | Déclarations, contrôle administratif et exploitation paie | Arbitrage A.4.2 Groupe 2 ; 10303 | Décision DIR confirmée ; actions à normaliser |
| `baremes_grands_deplacements` | Accès complet DIR : `view`, `create`, `update`, `delete` et toutes actions métier applicables ; SA conserve ses droits globaux | global DIR | Barèmes paramétrables, datés et historisés | Arbitrage A.4.2 Groupe 2 ; 10303 | Décision DIR confirmée ; actions à normaliser ; aucune modification rétroactive des périodes traitées |

Les permissions RH de DIR couvrent toutes les ressources RH et toutes les actions métier applicables, y compris création, modification, validation et suppression, à l’échelle globale. Cette attribution ne lève pas le secret médical : les documents médicaux détaillés détenus par les professionnels de santé restent hors d’accès général. Les suppressions ne peuvent intervenir que lorsque la loi, les durées de conservation et les obligations de traçabilité le permettent ; à défaut, archivage ou désactivation. Les règles de séparation des tâches demeurent applicables, notamment l’interdiction de s’auto-approuver et la validation indépendante des changements de coordonnées bancaires. Les permissions RH de CT, CC et RA restent limitées aux informations opérationnelles nécessaires ; ADM et CPT conservent les droits indiqués dans chaque ligne. Les restrictions de champs et de périmètre relèvent de CHAN-42.

### 5.8 TimeTracking

| Ressource | Actions / rôles | Scope | Justification | Source | Statut fonctionnel / technique |
| --- | --- | --- | --- | --- | --- |
| `pointages`, `feuilles_de_temps` | Accès complet DIR : toutes actions applicables, notamment `view`, `create`, `update`, `delete`, `submit`, `validate`, `correct`, `reopen`, `supervise` ; CC/RA et SAL conservent leurs droits ; CT conserve ses droits de contrôle/correction ; CPT conserve `view` pour la paie | global DIR / own / own_team / assigned_sites / assigned_workers / company | Pointages et feuilles de temps ; conserver les validations opérationnelles, l’historique et les motifs de correction | Arbitrage A.4.2 Groupe 2 ; 10298, 10299, 10303 | Décision DIR confirmée ; actions à normaliser |
| `corrections` | Accès complet DIR : toutes actions applicables, notamment `view`, `create`, `update`, `delete`, `submit`, `validate`, `reopen` ; SAL, CC, RA et CT conservent leurs droits selon leurs périmètres | global DIR / own / own_team / assigned_workers | Corrections horodatées ; conserver valeur initiale, nouvelle valeur, auteur, date, motif et valideur ; notifier CPT si transmission paie déjà effectuée | Arbitrage A.4.2 Groupe 2 ; 10298, 10299, 10303 | Décision DIR confirmée ; actions à normaliser ; traçabilité obligatoire |
| `periodes` | Accès complet DIR : `view`, `create`, `update`, `delete`, `close`, `reopen` et toutes actions applicables ; SA conserve `reopen` | global DIR | Clôture après contrôles ; réouverture motivée et auditée | Arbitrage A.4.2 Groupe 2 ; 10303 | Décision DIR confirmée ; actions à normaliser ; clôture et réouverture tracées |
| `absences` | Accès complet DIR : toutes actions applicables, notamment `view`, `create`, `update`, `delete`, `submit`, `review`, `validate`, `arbitrate` ; SAL, CC, CT, RA et ADM conservent leurs droits ; CPT conserve la consultation nécessaire à la paie | global DIR / own / own_team / company | Demandes, avis opérationnels, validation courante et arbitrage des exceptions ; historisation des décisions | Arbitrage A.4.2 Groupe 2 ; 10299, 10303 | Décision DIR confirmée ; actions à normaliser |
| `justificatifs_medicaux` | DIR : accès aux seules informations administratives et d’indisponibilité légalement accessibles et nécessaires ; aucun accès général aux documents médicaux détaillés ; ADM conserve le traitement administratif ; CPT se limite aux informations nécessaires à la paie et à la comptabilité sociale | restricted | Secret médical ; séparation des justificatifs administratifs et des données de santé détaillées | 10303 ; limite impérative maintenue | Exception explicite à l’accès complet ; documents médicaux détaillés hors accès général |
| `heures_supplementaires` | Accès complet DIR : toutes actions applicables, notamment `view`, `create`, `update`, `delete`, `authorize`, `submit`, `validate`, `validate_excess`, `control`, `process` ; SAL, CT, RA, ADM et CPT conservent leurs droits selon leurs responsabilités | global DIR / own / own_team / assigned_workers / company | Distinguer heures autorisées, déclarées, réellement travaillées et validées ; un dépassement refusé reste enregistré comme temps réellement travaillé | Arbitrage A.4.2 Groupe 2 ; 10299, 10303 | Décision DIR confirmée ; actions à normaliser ; responsabilités opérationnelles et traçabilité conservées |

Le code candidat `timetracking.timesheets.validate` désigne la validation des feuilles de temps ; dans ce document, la ressource est `feuilles_de_temps`. La correspondance de slug reste à normaliser. CT ne reçoit pas `validate` sur cette ressource au titre de son rôle opérationnel : il contrôle après CC et peut corriger ou rouvrir via `corrections`. DIR dispose d’un accès complet global sur les ressources TimeTracking, sans suppression des contrôles d’historique, des motifs obligatoires ni des exigences de traçabilité.

### 5.9 Workshop

| Ressource | Actions / rôles | Scope | Justification | Source | Statut fonctionnel / technique |
| --- | --- | --- | --- | --- | --- |
| `ordres_fabrication` | Accès complet DIR : toutes actions applicables, notamment `view`, `create`, `update`, `delete`, `reopen`, `close`, `validate` ; CT, CC, RA et SAL conservent leurs droits | global DIR / workshop / own | Production et pilotage des ordres de fabrication | Arbitrage A.4.2 Groupe 2 ; 10298, 10299 | Décision DIR confirmée ; actions à normaliser |
| `dossiers_fabrication`, `operations`, `postes`, `capacites_atelier` | Accès complet DIR : toutes actions applicables, notamment `view`, `create`, `update`, `delete`, `validate` ; RA, CT et CC conservent leurs droits | global DIR / workshop | Dossiers, opérations, postes et capacité atelier | Arbitrage A.4.2 Groupe 2 ; 10298 | Décision DIR confirmée ; actions à normaliser |
| `demandes_matiere` | Accès complet DIR : toutes actions applicables, notamment `view`, `create`, `update`, `delete`, `submit`, `validate` ; RA conserve ses droits | global DIR / workshop | Besoins et demandes matière | Arbitrage A.4.2 Groupe 2 ; 10298 | Décision DIR confirmée ; actions à normaliser |
| `comptes_rendus_production` | Accès complet DIR : toutes actions applicables, notamment `view`, `create`, `update`, `delete`, `submit`, `validate` ; RA, CT, CC et SAL conservent leurs droits | global DIR / workshop / own | Déclaration et suivi de production | Arbitrage A.4.2 Groupe 2 ; 10298, 10299 | Décision DIR confirmée ; actions à normaliser ; historique de production conservé |
| `colis_fabrication` | Accès complet DIR : toutes actions applicables, notamment `view`, `create`, `update`, `delete`, `validate`, `close` ; RA et CT conservent leurs droits | global DIR / workshop | Colis et expédition de fabrication | Arbitrage A.4.2 Groupe 2 ; 10298 | Décision DIR confirmée ; actions à normaliser |
| `rebuts`, `reprises` | Accès complet DIR : toutes actions applicables, notamment `view`, `create`, `update`, `delete`, `reopen`, `validate`, `close` ; RA conserve ses droits | global DIR / workshop | Rebuts, reprises et suivi de non-conformités de production | Arbitrage A.4.2 Groupe 2 ; 10298 | Décision DIR confirmée ; actions à normaliser |

### 5.10 Procurement

| Ressource | Actions / rôles | Scope | Justification | Source | Statut fonctionnel / technique |
| --- | --- | --- | --- | --- | --- |
| `fournisseurs`, `sous_traitants` | Accès complet DIR : toutes actions applicables ; ADM, CT, CC, RA et CPT conservent leurs droits | global DIR / global | Référentiels fournisseurs et sous-traitants | Arbitrage A.4.2 Groupe 2 ; 10298, 10300 | Décision DIR confirmée ; actions à normaliser |
| `demandes_achat` | Accès complet DIR : toutes actions applicables ; ADM, CT et RA conservent leurs droits | global DIR / assigned_projects | Demandes d’achat | Arbitrage A.4.2 Groupe 2 ; 10298 | Décision DIR confirmée ; actions à normaliser |
| `besoins` | Accès complet DIR : toutes actions applicables ; CC, CT et RA conservent leurs droits | global DIR / assigned_projects | Signalement et suivi des besoins d’approvisionnement | Arbitrage A.4.2 Groupe 2 ; 10303 | Décision DIR confirmée ; actions à normaliser |
| `offres_fournisseurs` | Accès complet DIR : toutes actions applicables ; ADM et RA conservent leurs droits | global DIR / global | Offres fournisseurs | Arbitrage A.4.2 Groupe 2 ; 10298 | Décision DIR confirmée ; actions à normaliser |
| `commandes_achats`, `lignes_commande` | Accès complet DIR aux actions applicables, dont consultation, préparation, modification, soumission et approbation ; ADM, CT, RA, CPT et SA conservent leurs droits | global DIR / global / assigned_projects | Commandes d’achat et engagements | Arbitrage A.4.2 Groupe 2 ; 10298, 10301, 10303 | Décision DIR confirmée ; approbation DIR uniquement lorsque le seuil cumulé de 100 000 € HT par opération est dépassé, selon §5.6 ; actions à normaliser |
| `commandes_sous_traitance` | Accès complet DIR aux actions applicables, dont consultation, préparation, modification, soumission et approbation ; ADM, CT, RA, CPT et SA conservent leurs droits | global DIR / global / assigned_projects | Commandes de sous-traitance et engagements | Arbitrage A.4.2 Groupe 2 ; 10298, 10301, 10303 | Décision DIR confirmée ; approbation DIR uniquement lorsque le seuil cumulé de 100 000 € HT par opération est dépassé, selon §5.6 ; actions à normaliser |
| `evaluations_fournisseurs` | Accès complet DIR : toutes actions applicables ; ADM et RA conservent leurs droits | global DIR / global | Évaluation des fournisseurs | Arbitrage A.4.2 Groupe 2 ; 10298 | Décision DIR confirmée ; actions à normaliser |
| `accords_cadres`, `garanties_fournisseurs` | Accès complet DIR : toutes actions applicables, y compris approbation si l’action existe ; ADM et RA conservent leurs droits | global DIR / global | Accords-cadres et garanties fournisseurs | Arbitrage A.4.2 Groupe 2 ; 10298 | Décision DIR confirmée ; actions à normaliser |
| `factures_fournisseurs` | Accès complet DIR : toutes actions applicables, dont consultation, création, modification et rapprochement ; CPT et ADM conservent leurs droits | global DIR / global | Factures fournisseurs et rapprochement | Arbitrage A.4.2 Groupe 2 ; 10300 | Décision DIR confirmée ; actions à normaliser ; exécution des paiements soumise aux règles financières dédiées |
| `incidents_sous_traitance` | Accès complet DIR : toutes actions applicables ; CC, CT et RA conservent leurs droits | global DIR / assigned_projects | Incidents de sous-traitance | Arbitrage A.4.2 Groupe 2 ; 10303 | Décision DIR confirmée ; actions à normaliser |

### 5.11 Inventory

| Ressource | Actions / rôles | Scope | Justification | Source | Statut fonctionnel / technique |
| --- | --- | --- | --- | --- | --- |
| `articles`, `entrepots`, `emplacements`, `lots_stock` | Accès complet DIR : toutes actions applicables ; RA, CT, CC et CPT conservent leurs droits | global DIR / workshop / assigned_sites | Référentiels et suivi des stocks | Arbitrage A.4.2 Groupe 2 ; 10298, 10300 | Décision DIR confirmée ; actions à normaliser |
| `mouvements_stock` | Accès complet DIR : toutes actions applicables, y compris création, modification, annulation/inversion et validation si applicable ; RA, CT, CC et CPT conservent leurs droits | global DIR / assigned_sites / workshop | Mouvements de stock et traçabilité | Arbitrage A.4.2 Groupe 2 ; 10298, 10300 | Décision DIR confirmée ; actions à normaliser ; conserver l’historique des mouvements |
| `receptions_stock`, `reservations_stock` | Accès complet DIR : toutes actions applicables ; RA, CT et CC conservent leurs droits | global DIR / workshop / assigned_sites | Réceptions et réservations | Arbitrage A.4.2 Groupe 2 ; 10298 | Décision DIR confirmée ; actions à normaliser |
| `consommations` | Accès complet DIR : toutes actions applicables, y compris création, modification, annulation/inversion et validation si applicable ; CC, RA, CT et CPT conservent leurs droits | global DIR / assigned_sites / workshop | Consommations de matières | Arbitrage A.4.2 Groupe 2 ; 10298, 10300 | Décision DIR confirmée ; code normalisé `inventory.consommations` ; actions à normaliser |
| `bons_sortie` | Accès complet DIR : toutes actions applicables ; RA et CC conservent leurs droits | global DIR / workshop | Bons de sortie | Arbitrage A.4.2 Groupe 2 ; 10298 | Décision DIR confirmée ; actions à normaliser |
| `inventaires_physiques` | Accès complet DIR : toutes actions applicables ; RA et CPT conservent leurs droits | global DIR / workshop | Inventaires physiques | Arbitrage A.4.2 Groupe 2 ; 10298, 10300 | Décision DIR confirmée ; actions à normaliser |
| `ajustements` | Accès complet DIR : toutes actions applicables, y compris création, modification, validation, annulation/inversion et suppression si légalement et techniquement permise ; RA conserve ses droits | global DIR / workshop | Ajustements de stock | Arbitrage A.4.2 Groupe 2 ; 10298 | Décision DIR confirmée ; actions à normaliser ; préserver la piste d’audit des corrections |

### 5.12 Equipment

| Ressource | Actions / rôles | Scope | Justification | Source | Statut fonctionnel / technique |
| --- | --- | --- | --- | --- | --- |
| `equipements`, `affectations` | Accès complet DIR : toutes les actions applicables ; RA conserve `view`, `create`, `update`, `assign` ; CT, CC et SAL conservent leurs droits | global DIR / workshop / assigned_sites / own | Équipements et affectations | 10298, 10299, arbitrage A.4.2 Groupe 2 | Décision DIR confirmée ; actions à normaliser ; historique des affectations à conserver |
| `categories`, `plans_maintenance`, `interventions` | Accès complet DIR : toutes les actions applicables ; RA conserve ses droits | global DIR / workshop | Catégories, plans de maintenance et interventions | 10298, arbitrage A.4.2 Groupe 2 | Décision DIR confirmée ; actions à normaliser ; historique de maintenance à conserver |
| `inspections_reglementaires` | Accès complet DIR : toutes les actions applicables ; RA conserve ses droits | global DIR / workshop | Inspections réglementaires des équipements | 10298, arbitrage A.4.2 Groupe 2 | Décision DIR confirmée ; actions à normaliser ; échéances, résultats et justificatifs réglementaires à conserver |
| `pannes` | Accès complet DIR : toutes les actions applicables ; RA, CC et CT conservent leurs droits | global DIR / workshop / assigned_sites | Pannes et incidents matériel | 10298, arbitrage A.4.2 Groupe 2 | Décision DIR confirmée ; actions à normaliser ; historique de panne, diagnostic et intervention à conserver |

### 5.13 Logistics

| Ressource | Actions / rôles | Scope | Justification | Source | Statut fonctionnel / technique |
| --- | --- | --- | --- | --- | --- |
| `demandes_transport`, `plans_transport`, `tournees` | `view`, `create`, `update` : RA, CT selon périmètre | workshop / assigned_sites | Transport | 10298 | `Proposé` |
| `livraisons`, `receptions_chantier` | `view`, `create`, `update` : RA ; `view` : CT, CC | assigned_sites / workshop | Livraisons | 10298 | `Proposé` |
| `retours` | `view`, `create`, `update` : RA | workshop | Retours | 10298 | `Proposé` |
| `acces_chantier` | `view` : CT, CC ; `update` : CT à confirmer | assigned_sites | Accès chantier | 10298 | `À arbitrer` |

### 5.14 Quality

| Ressource | Actions / rôles | Scope | Justification | Source | Statut fonctionnel / technique |
| --- | --- | --- | --- | --- | --- |
| `plans_qualite`, `plans_controle` | `view`, `create`, `update` : CT, RA ; `view` : DIR, CC | assigned_projects / workshop | Plans qualité | 10298 | `Proposé` |
| `controles_qualite` | `view`, `create`, `update` : CT, CC, RA ; `validate` : CT, RA | assigned_projects / workshop | Contrôles | 10298 | `Proposé` |
| `non_conformites` | `view` : DIR, CT, CC, RA ; `create` : CC ; `update`, `validate`, `close` : CT, RA | assigned_projects / workshop | Non-conformités | 10298 | `Proposé` |
| `actions_correctives`, `audits_qualite`, `certificats_qualite`, `qualifications_techniques` | `view`, `create`, `update` : RA ; `view` : CT | workshop | Qualité atelier | 10298 | `Proposé` |
| `signalements` | `create` : SAL ; traitement : rôle responsable à arbitrer | own | Signalement qualité, distinct d’une non-conformité | 10299, 10303 | `À arbitrer` sur le rôle de traitement |

### 5.15 Safety

| Ressource | Actions / rôles | Scope | Justification | Source | Statut fonctionnel / technique |
| --- | --- | --- | --- | --- | --- |
| `analyses_risques`, `plans_prevention` | `view`, `create`, `update` : RA ; `view` : CT, CC | workshop / assigned_projects | Prévention | 10298 | `Proposé` |
| `inspections_securite`, `incidents` | `view`, `create`, `update` : CC, RA ; `view` : CT | assigned_projects / workshop | Sécurité | 10298 | `Proposé` |
| `actions_securite` | `view`, `create`, `update` : RA ; `view` : CT | workshop | Actions sécurité | 10298 | `Proposé` |
| `habilitations`, `autorisations_travail`, `inductions` | `view`, `create`, `update` : RA ; `view` : ADM, CT, CC | workshop / company | Habilitations | 10298 | `Proposé` |
| `signalements` | `create` : SAL ; traitement : rôle responsable à arbitrer | own | Signalement sécurité, distinct d’un incident | 10299, 10303 | `À arbitrer` sur le rôle de traitement |

### 5.16 Documents

| Ressource | Actions / rôles | Scope | Justification | Source | Statut fonctionnel / technique |
| --- | --- | --- | --- | --- | --- |
| `documents`, `versions`, `dossiers_documentaires` | `view`, `create`, `update` : ADM, CT, CC, RA ; `view` : DIR, CPT, SAL own | company / assigned_projects / own | Documents | 10298, 10299 | `Proposé` |
| `types_document`, `regles_conservation` | `view`, `create`, `update` : ADM | global | Référentiel documentaire | 10298 | `Proposé` |
| `diffusions` | `view`, `create` : ADM, CT, CC, RA ; `acknowledge` : SAL own | assigned_projects / own | Diffusion | 10298, 10299 | `Proposé` |
| `download`, `sign` | `download`, `sign` : SAL own ; autres attributions à arbitrer | own / policy_defined | Documents personnels ; autres rôles non déterminés | 10299 | `Proposé` ; attribution hors SAL à arbitrer |
| `exports` | `export` : DIR, ADM, CPT | global | Exports documentaires | 10300 | `À arbitrer` |

### 5.17 Handover

| Ressource | Actions / rôles | Scope | Justification | Source | Statut fonctionnel / technique |
| --- | --- | --- | --- | --- | --- |
| `dossiers_reception` | `view`, `create`, `update` : CT, CC ; `view`, `approve` : DIR | global pour DIR ; assigned_projects pour CT, CC | Approbation finale DIR du dossier de réception, distincte de la réception contractuelle Projects ; n'accorde pas l'approbation des réserves, levées de réserves ou DOE | 10298, arbitrage A.4.2 Groupe 1 | Décision métier validée ; permission à intégrer |\n| `reserves`, `levees_reserves`, `doe` | `view`, `create`, `update` : CT, CC ; `view` : DIR | global pour DIR ; assigned_projects pour CT, CC | Consultation et gestion opérationnelle des réserves, levées et DOE ; aucune approbation DIR décidée ici | 10298, arbitrage A.4.2 Groupe 1 | Consultation confirmée ; actions opérationnelles inchangées |
| `garanties_clients` | `view` : CT, ADM ; `update` : ADM à confirmer | company / assigned_projects | Garanties | 10298 | `À arbitrer` |
| `dossiers_cloture` | `view` : DIR, CT, ADM ; `create`, `update` : CT, ADM ; `close` : ADM à confirmer | assigned_projects / company | Clôture | 10298 | `À arbitrer` |

### 5.18 Reporting

| Ressource | Actions / rôles | Scope | Justification | Source | Statut fonctionnel / technique |
| --- | --- | --- | --- | --- | --- |
| `rapports`, `indicateurs` | `view` : DIR, ADM, CT, CC, RA, CPT ; `create`, `update` : CT, CC, RA | company / assigned_projects | Reporting | 10298, 10300 | `Proposé` |
| `tableaux_bord` | `view` : DIR, ADM, CT, RA ; CPT non stratégique | company | Tableaux de bord | 10298, 10300 | `Proposé` |
| `tableaux_bord_strategiques` | `view` : DIR | global | Direction uniquement | 10300 | `Proposé` |
| `snapshots` | `view` : DIR | global | Snapshots | 10301 | `Proposé` |
| `exports` | `export` : DIR, ADM, CPT | global | Exports sensibles | 10300 | `À arbitrer` |

### 5.19 Accounting

| Ressource | Actions / rôles | Scope | Justification | Source | Statut fonctionnel / technique |
| --- | --- | --- | --- | --- | --- |
| `ecritures`, `journaux`, `plan_comptable` | `view`, `create`, `update`, `reverse` : CPT | global | Comptabilité | 10300 | `Proposé`, domaine `À arbitrer` |
| `periodes` | `lock`, `unlock` : CPT | global | Périodes | 10300 | `Proposé`, domaine `À arbitrer` |
| `rapprochements_bancaires` | `view`, `create`, `update` : CPT | global | Banque | 10300 | `Proposé`, domaine `À arbitrer` |
| `payments` (candidat Jira) / `paiements` (normalisation française à arbitrer) | `prepare`, `approve`, `execute` : CPT pour `prepare`/`execute` ; `approve` : DIR, SA ; séparation obligatoire entre préparateur et autorisateur | global | CPT prépare les paiements et justificatifs ; DIR ou SA autorise ou refuse ; CPT exécute après autorisation ; le préparateur ne peut pas autoriser son propre paiement | 10300, 10303 | Décision métier validée ; codes candidats `accounting.payments.prepare`, `.approve`, `.execute` à normaliser |
| `tresorerie` | `view`, `update` : CPT | global | Trésorerie | 10300 | `Proposé`, domaine `À arbitrer` |
| `declarations`, `clotures` | `prepare`, `submit` : CPT | global | Déclarations et clôtures | 10300 | `Proposé`, actions à vérifier |
| `analytique` | `view`, `create`, `update` : CPT | global | Analytique | 10300 | `Proposé` |
| `revisions_budgetaires` | `view`, `create`, `update`, `submit` : CPT | global | Révisions | 10300 | `À arbitrer`, doublon budgets |
| `immobilisations`, `amortissements` | `view`, `create`, `update` : CPT | global | Immobilisations | 10300 | `Proposé` |
| `donnees_financieres` | `view` : CPT | global | Données financières | 10300 | `À arbitrer`, trop large |
| `exports` | `export` : CPT | global | Exports | 10300 | `À arbitrer` sur action |
| `relations_organismes` | `view`, `create`, `update` : CPT | global | Organismes | 10300 | `Proposé` |

## 6. Matrice rôles × permissions

Cette matrice est une synthèse du catalogue §5 et ne peut pas accorder de droit supplémentaire. Les cellules DIR reprennent uniquement les permissions explicites du §5. Lorsqu’un droit transversal DIR est validé fonctionnellement mais non encore traduit en permission, la cellule indique `transversal à normaliser` et le point A-16 est ouvert. Aucune cellule DIR n’implique `delete` universel, administration des habilitations ou accès médical illimité.

| Domaine | SA | DIR | ADM | CT | CC | RA | SAL | CPT |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Identity | administration complète des habilitations, panel | panel, sans administration des habilitations | panel | panel | panel | panel | portail personnel, panel non | panel |
| Clients | droits métier globaux | view factures, avoirs, relances, échéanciers, litiges, règlements ; approve conditions commerciales/devis ; arbitrate litiges ; approbation de régularisation financière à modéliser | prospects, clients, contacts, devis | lecture | — | — | — | factures, avoirs, relances |
| Projects | droits métier globaux | view global affaires, chantiers, études, jalons, rapports, commandes, contrats, avenants et réceptions ; approve commandes/avenants/contrats/réception contractuelle et dossier Handover | lecture | affaires, chantiers, lots | lecture | — | — | lecture chantiers |
| Planning | droits métier globaux | view global plannings contractuels/opérationnels, affectations, conflits et avancement ; arbitrate conflits | — | planning, affectations | lecture | planning atelier | planning personnel | — |
| Budgets | droits métier globaux | view budgets ; approve tous budgets, toutes révisions et toutes contingences sans seuil de montant | lecture | budgets, révisions, contingences | — | — | — | workflows à préciser |
| Costing | droits métier globaux | view/create/update/validate chiffrages, coûts et écarts ; view marges/provisions ; approve provisions ; approve engagements uniquement au-delà de 100 000 € HT cumulés par opération ; view/lock/unlock/close périodes analytiques | — | coûts, marges, écarts | — | coûts atelier | — | coûts |
| Workforce | données RH métier hors exception médicale | accès complet global à toutes les ressources RH et actions applicables, y compris create/update/validate/delete ; secret médical, conservation légale et séparation des tâches maintenus | RH administrative, variables paie selon §5 | RH opérationnelle limitée | équipe | collaborateurs | dossier et bulletins propres | paie, bulletins et données nécessaires aux virements |
| TimeTracking | droits métier globaux | accès complet global à toutes les ressources et actions applicables, y compris create/update/delete/validate/authorize/close/reopen ; hors documents médicaux détaillés | absences courantes | pointages chantier affectés, corrections/réouvertures | pointages équipe | pointages équipe atelier | pointages et absences propres | lecture des temps validés pour paie |
| Workshop | droits métier globaux | accès complet global à toutes les ressources et actions applicables (view/create/update/delete/validate et actions spécifiques) | — | lecture | OF, comptes rendus | OF, production | OF personnels | — |
| Procurement | droits métier globaux | accès complet global aux ressources et actions applicables ; approbation des engagements DIR selon seuil cumulé > 100 000 € HT par opération | fournisseurs, demandes, préparation | demandes | besoins, sous-traitants | demandes, fournisseurs | — | consultation commandes |
| Inventory | droits métier globaux | accès complet global aux ressources et actions applicables, sous réserve de la traçabilité des mouvements et ajustements | — | mouvements | stocks, consommations | stocks, mouvements | — | lecture |
| Equipment | droits métier globaux | accès complet global à toutes les ressources et actions applicables (view/create/update/delete/assign/validate et actions spécifiques), avec traçabilité réglementaire et technique | — | équipements | équipements, pannes | équipements, maintenance | équipement personnel | — |
| Logistics | droits métier globaux | transversal à normaliser | — | livraisons | — | expédition | — | — |
| Quality | droits métier globaux | view plans/NCR selon §5 ; autres capacités transversales à qualifier en A-16 si confirmées | — | contrôles | contrôles, NCR | contrôles, NCR, clôture | signalements | — |
| Safety | droits métier globaux | transversal à normaliser | — | inspections | inspections, incidents | atelier | signalements | — |
| Documents | droits métier globaux | view selon §5 ; autres capacités transversales à qualifier en A-16 si confirmées | documents admin | documents chantier | documents, diffusion | documents atelier | documents personnels | lecture |
| Handover | droits métier globaux | view global dossiers de réception, réserves, levées et DOE ; approve dossier de réception final uniquement | clôture à normaliser | réceptions, réserves | réserves | — | — | — |
| Reporting | droits métier globaux | view stratégique et autres droits uniquement selon §5 ; exports DIR à confirmer selon M-05/A-16 | rapports | rapports | rapports quotidiens | reporting production | — | exports |
| Accounting | droits métier globaux selon périmètre retenu | approve paiements + valider paie | — | — | — | — | — | préparation et exécution après autorisation |

## 7. Matrice des restrictions et interdictions

| Rôle | Interdictions explicites |
| --- | --- |
| SA | Pas d’accès automatique aux documents médicaux détaillés ; pas d’auto-approbation lorsque le workflow impose une séparation ; pas de contournement des Policies |
| DIR | Pas d’administration des utilisateurs, rôles, permissions ou habilitations ; respect des restrictions légales et du secret médical ; pas d’auto-autorisation de paiement ; pas de suppression universelle implicite |
| ADM | Pas d’approbation financière ; pas de paiement ; pas de validation finale de paie ; pas de modification technique des chantiers ; pas d’accès par défaut aux rémunérations, bulletins, coordonnées bancaires, dossiers disciplinaires ou données médicales |
| CT | Pas d’approbation financière générale ; pas d’approbation de ses propres révisions ; pas d’engagement autonome ; pas d’accès RH sensible ; périmètre limité aux affaires/chantiers affectés |
| CC | Aucun budget, coût, marge ou rentabilité ; aucun accès financier ; pas de commande ; pas de modification du planning ; pas de clôture NCR relevant du Conducteur ; pas de réception formelle ; pas d’accès RH sensible |
| RA | Pas d’engagement financier autonome ; commandes soumises à approbation ; pas d’approbation des plans de conception ; validations personnelles et auditées ; pas d’accès RH sensible |
| SAL | Pas de panel ; pas d’auto-validation ; pas de finances, commerce ou comptabilité ; pas de frais professionnels ; pas de rapports ou livraisons ; pas de stock ou équipement ; pas d’accès aux données d’un autre salarié |
| CPT | Pas d’approbation d’engagement ; pas de création/validation de commande ; pas de validation finale de paie ; pas de validation des comptes annuels ; pas de mandats bancaires ; pas de tableaux de bord stratégiques ; pas de validation de ses propres frais ; pas d’accès général aux dossiers disciplinaires ou justificatifs personnels sans lien avec la paie |

## 8. Matrice des scopes d’accès

Les scopes sont des propositions à mettre en œuvre dans CHAN-42. Une permission globale ne donne jamais accès à toutes les ressources.

Vocabulaire documentaire retenu :

| Scope | Description | Exemples |
| --- | --- | --- |
| `global` | Portée applicative complète ou ressource sans restriction de périmètre lorsque le rôle le permet | panel, administration Identity, comptabilité |
| `company` | Société entière pour un domaine | RH administrative, reporting Direction |
| `transversal` | Données métier accessibles transversalement à DIR/SA, sous réserve des restrictions du §7 et des workflows | consultation transversale DIR/SA |
| `assigned_projects` | Affaires et projets affectés au niveau contractuel ou commercial ; ne donne pas accès automatiquement aux chantiers associés | CT |
| `assigned_sites` | Sites/chantiers affectés pour les opérations de terrain ; ne donne pas accès automatiquement aux données contractuelles/commerciales de l’affaire | CT, CC ; autres rôles opérationnels uniquement lorsque leur affectation chantier est explicitement prévue |
| `assigned_workers` | Salariés affectés à un chantier | contrôle des pointages par CT |
| `own_team` | Salariés de l’équipe encadrée | CC, RA |
| `own` | Données propres à l’utilisateur | SAL |
| `workshop` | Atelier | RA |
| `finance` | Périmètre comptable | CPT |
| `restricted` | Accès restreint ou besoin d’en connaître (RH sensible, médical, banque) | dossiers RH, justificatifs médicaux, coordonnées bancaires |
| `policy_defined` | Périmètre effectif déterminé par les Policies métier définies dans CHAN-42 | documents, clients, absences, etc. |

Les cellules composites (`assigned_projects / own_team`, `company / own`, etc.) listent les scopes applicables ; le scope `policy_defined` est déterminé par les Policies métier de CHAN-42. `assigned_projects` est réservé aux affaires et projets affectés au niveau contractuel/commercial ; `assigned_sites` aux sites ou chantiers affectés au niveau opérationnel ; `assigned_workers` aux salariés affectés à un chantier ou à un périmètre opérationnel. Une affaire n’implique pas automatiquement l’accès à tous ses chantiers, et un chantier n’implique pas l’accès aux données commerciales ou comptables de l’affaire. Les `lots_phases` ne reçoivent pas de scope par déduction : leur rattachement à l’affaire ou au chantier doit être confirmé ; dans l’attente, ils restent `À arbitrer`. `transversal` est représenté dans la matrice §6 et ne remplace pas les scopes de ressource du §5. Aucun mécanisme de Policy n’est implémenté par ce lot.

## 9. Règles de validation et séparation des responsabilités

Les règles ci-dessous sont fonctionnellement validées. Leur implémentation technique reste à planifier dans CHAN-40, CHAN-42, CHAN-45 ou un lot dédié, sous réserve de confirmation du périmètre de CHAN-45.

| Règle | Portée | Source | Statut fonctionnel |
| --- | --- | --- | --- |
| Default deny | Toutes permissions | 10297 | Validé |
| Pas de wildcard | Toutes permissions | 10297 | Validé |
| Permission atomique | Toutes permissions | 10303 | Validé |
| Pointages : validation par CC, CT et RA selon leur périmètre | Pointages | 10298, 10303 | Validé |
| Corrections et réouvertures de pointages tracées | Pointages | 10303 | Validé |
| Contrôle CT après validation CC : pas une seconde validation systématique | Pointages | 10303 | Validé |
| Congés/absences : avis CC/CT/RA, validation ADM, arbitrage DIR | Absences | 10303 | Validé |
| Paiements : CPT prépare, DIR/SA autorise, CPT exécute | Paiements | 10303 | Validé |
| Pas d’auto-autorisation de paiement | Paiements | 10303 | Validé |
| Préparation / validation finale séparées | Paie | 10303 | Validé |
| Seuil global 100 000 € HT | Engagements | 10303 | Validé |
| Cumul commandes/avenants | Engagements | 10303 | Validé |
| Délégations financières paramétrables et historisées | Finance | 10303 | Validé |
| Clôture mensuelle des temps | Pointages | 10303 | Validé |
| Réouverture exceptionnelle DIR/SA | Pointages | 10303 | Validé |
| Historique des modifications | Temps, délégations, actions sensibles | 10303 | Validé |
| Justificatifs médicaux protégés | Absences | 10303 | Validé |
| Heures supplémentaires : autorisation, déclaration, validation, dépassement | Temps | 10303 | Validé |
| Grands déplacements : indemnité de paie, pas de note de frais salarié | Paie | 10303 | Validé |
| Barèmes grands déplacements paramétrables et historisés | Paie | 10303 | Validé |

## 10. Journalisation et audit des actions sensibles

Actions à journaliser :

- création, modification, désactivation d’utilisateurs ;
- création, modification, suppression/archivage de rôles et permissions ;
- attribution et retrait de rôles ;
- modification des paramètres d’accès ;
- création, modification et révocation de délégations financières ;
- approbations financières ;
- préparation, autorisation et exécution des paiements ;
- modification des coordonnées bancaires ;
- consultation des données médicales ;
- préparation et validation finale de la paie ;
- clôture et réouverture des périodes de temps ;
- corrections de pointages ;
- validation et arbitrage des absences ;
- autorisation, déclaration et validation des heures supplémentaires ;
- déclaration, contrôle et exploitation des grands déplacements ;
- contrepassations, verrouillage/déverrouillage de périodes comptables ;
- exports sensibles ;
- accès au panel Filament, si la politique d’audit le retient ;

Champs minimaux proposés :

```text
acteur, rôle, permission, ressource, identifiant de ressource,
avant, après, motif, date, adresse IP, session, source
```

Les traces d’audit sont immuables pour leur auteur, y compris le Super administrateur. La mise en œuvre technique de l’audit doit être confirmée : CHAN-45 est documenté dans le dépôt comme journalisation de sécurité, mais son périmètre exact sur l’audit métier immuable reste à vérifier ; à défaut, un lot dédié doit porter cette mise en œuvre. CHAN-40 définit les événements et les permissions sensibles, pas le stockage.

## 11. Points restant à préciser ou à arbitrer

Les décisions fonctionnelles explicitement validées dans Jira 10297 à 10303 ne sont pas répétées ici comme des questions ouvertes. Le tableau ci-dessous ne conserve que les paramètres, conventions ou choix de conception qui ne sont pas tranchés par les sources.

| ID | Sujet | État connu | Point restant | Conséquence | Responsable |
| --- | --- | --- | --- | --- | --- |
| M-01 | Délégations sous 100 000 € HT | Délégations par rôle et catégorie validées ; pas de plafond individuel | Fixer les montants concrets par rôle, catégorie et périmètre | Paramétrage workflow | Direction |
| M-02 | Double contrôle bancaire | Préparation, autorisation et exécution séparées ; pas d’auto-autorisation | Déterminer si une seconde autorisation est exigée selon montant/catégorie | Workflow bancaire | Direction |
| M-03 | Clôture mensuelle des temps | Séquence et réouverture DIR/SA validées | Désigner techniquement l’acteur/service qui exécute l’action de clôture après contrôles | Permission `close` et workflow | Direction / métier |
| M-04 | Données RH sensibles | Accès DIR/SA, CPT et ADM différencié ; ADM limité aux données RH courantes ; restrictions médicales établies | Décliner chaque famille de données en ressources et permissions techniques précises | Catalogue Workforce | Architecture / métier |
| M-05 | Exports sensibles | Aucun export global implicite ; droits par ressource et rôle | Établir la liste des exports, champs et rôles autorisés | Permissions `export` | Direction |
| M-06 | Suppression et archivage | SA peut supprimer lorsque l’opération est prévue ; archivage à privilégier lorsque pertinent | Définir ressource par ressource les opérations réellement supprimables pour les autres rôles | Actions atomiques | Métier |
| M-07 | Besoins Chef de chantier | Signalement de besoin prévu | Confirmer le nom canonique et le rattachement de la ressource | Catalogue Procurement | Métier / architecture |
| M-08 | Incidents sous-traitance | Création/signalement par CC ; suivi opérationnel | Préciser les actions de mise à jour, traitement et clôture | Catalogue Procurement | Métier |
| M-09 | Signalements Salarié | Signalements qualité et sécurité prévus | Déterminer les ressources et circuits de traitement, et désigner le rôle responsable du traitement qualité et le rôle responsable du traitement sécurité | Catalogue Quality/Safety | Métier |
| M-10 | Annuaire et messagerie | Fonctions personnelles mentionnées pour SAL | Confirmer si elles appartiennent à Identity ou à un contexte dédié | Architecture | Architecture |
| M-11 | Accès stratégique Reporting | Tableaux de bord stratégiques réservés à DIR | Confirmer les ressources/snapshots exacts et leurs données sources | Catalogue Reporting | Direction |
| M-12 | Barèmes grands déplacements | Barèmes datés/historisés ; DIR et SA supervisent et administrent les règles | Préciser si ADM reçoit une délégation de paramétrage et les droits de publication/activation | Catalogue Workforce | Direction |
| M-13 | Absences maladie/accident/exceptionnelles | Circuits fonctionnels distincts définis | Déterminer si les différences exigent des ressources distinctes ou seulement des champs/statuts | Modèle et permissions | Métier / architecture |
| M-14 | Périmètre des justificatifs médicaux consultables par ADM | ADM traite administrativement les justificatifs ; DIR/SA/CPT n’ont pas d’accès automatique ; les responsables ne voient que l’indisponibilité | Définir les documents et champs exacts visibles par ADM et les règles de séparation | Modèle d’accès et permissions médicales | Direction / juridique / RH |
| M-15 | Validation des dépassements d’heures supplémentaires | `validate_excess` est prévu mais le rôle compétent n’est pas défini | Désigner le rôle habilité et les règles de validation complémentaire | Permission et workflow | Direction / métier |
| M-16 | Sémantique de `suspend` et `delete` des délégations financières | Seuls DIR et SA administrent les délégations ; l’effet exact de `suspend` et `delete` n’est pas défini | Préciser suspension temporaire, révocation et conservation de l’historique | Permissions et audit | Direction |
| M-17 | Documents hors Salarié | SAL dispose de `download` et `sign` sur ses documents ; les autres attributions ne sont pas définies | Identifier les rôles autorisés à télécharger ou signer d’autres documents | Permissions documentaires | Direction / métier |
| A-01 | Namespace `accounting` | Introduit par 10300, non validé comme 19e domaine | Choisir domaine distinct, répartition ou contexte/module séparé | Convention de domaine | Architecture |
| A-02 | Facturation clients | Factures clients présentes dans Clients ; comptabilité traite les opérations comptables | Définir le propriétaire fonctionnel de chaque ressource et éviter les doublons | Catalogue | Architecture |
| A-03 | Slug TimeTracking | `timetracking` utilisé dans les commentaires et le document | Confirmer la forme canonique `timetracking` ou `time_tracking` | Codes | Architecture |
| A-04 | Singulier/pluriel et libellés de ressources | Collections au pluriel, objets uniques au singulier proposés | Appliquer la convention à toutes les ressources, y compris les correspondances français/anglais comme `timesheets` / `feuilles_de_temps` | Codes | Architecture |
| A-05 | Ressource Budget | `budgets` et `budget` apparaissent selon les usages | Retenir un identifiant canonique selon la règle collection/objet | Codes | Architecture |
| A-06 | Factures clients | `factures_clients` et `factures` apparaissent selon les usages | Retenir un identifiant canonique et le propriétaire | Codes | Architecture |
| A-07 | Registre d’actions | `view`, `create`, `update`, `delete`, `submit`, `validate`, `approve`, `issue`, `prepare`, `execute`, `export`, `reverse`, `reconcile`, `lock`, `unlock`, `reopen`, `close`, `download`, `acknowledge`, `sign`, `assign`, `access` définis | Stabiliser ou refuser explicitement : `deactivate`, `archive`, `revoke`, `send`, `adjust`, `arbitrate` (requis pour l'arbitrage DIR des litiges et à distinguer de `approve`), `review`, `control`, `declare`, `process`, `request_update`, `supervise`, `validate_excess`, `suspend`, `authorize` | Registre commun | Architecture |
| A-08 | Source de vérité du catalogue | Catalogue central recommandé | Confirmer l’emplacement et la structure des définitions | Architecture Identity | Architecture |
| A-09 | Versionnement | Codes immuables recommandés | Définir le mécanisme de version et de migration du catalogue | Maintenance | Architecture |
| A-10 | Seeders | Seeders idempotents requis par CHAN-40 | Définir stratégie d’upsert, suppression contrôlée et synchronisation | Implémentation | Développement |
| A-11 | Accès panel Filament | Permission dédiée `identity.admin_panel.access` exigée ; SAL exclu du panel | Définir l’emplacement exact du contrôle dans `canAccessPanel()` et ses tests | Implémentation | Développement |
| A-12 | Affectations utilisateurs | Aucune affectation automatique | Définir le processus initial d’attribution manuelle et son responsable | Exploitation | Direction / développement |
| A-13 | Cache Spatie | Cache standard constaté | Documenter l’invalidation après synchronisation et opérations SQL directes | Exploitation | Développement |
| A-14 | Intégration comptable externe | Périmètre non défini dans les commentaires disponibles | Déterminer l’interface et la frontière avec un logiciel/prestataire comptable | Architecture | Direction / architecture |
| A-15 | Périmètre CHAN-45 et audit | CHAN-45 est mentionné dans la documentation du dépôt comme journalisation de sécurité ; le périmètre exact sur l’audit métier immuable n’est pas vérifié | Confirmer si CHAN-45 porte l’audit métier ou prévoir un lot dédié | Périmètre du stockage d’audit | Architecture / sécurité |
| A-16 | Droits transversaux DIR non traduits | Groupe 1 arbitré sur Identity, Clients, Projects et Planning ; Groupe 2 : arbitrages sur planning/conflits, budgets, contingences, engagements, provisions, périodes analytiques, chiffrages/coûts/écarts, accès complet RH, TimeTracking, Workshop, Procurement, Inventory et Equipment | Poursuivre la revue exhaustive des domaines restants et des ressources/actions non résolues ; intégrer les permissions atomiques après normalisation, puis synchroniser §5 et §6. Les droits RH, TimeTracking, Workshop, Procurement, Inventory et Equipment DIR couvrent toutes les ressources et actions applicables, y compris create/update/validate/delete, sous réserve du secret médical, de la conservation légale, de la traçabilité et de la séparation des tâches. Pour Equipment, conserver l’historique des affectations, maintenances, interventions, inspections réglementaires et pannes ; les suppressions physiques ne doivent pas effacer les preuves ni les historiques requis. Pour les mouvements, consommations, inventaires et ajustements de stock, les historiques, motifs, auteurs et horodatages doivent être conservés ; les suppressions physiques ne doivent pas effacer la piste d’audit. Pour les commandes d’achat et de sous-traitance, l’approbation DIR reste limitée aux engagements dépassant 100 000 € HT cumulés par opération ; l’exécution des paiements conserve ses règles financières dédiées. Ne pas étendre ces décisions aux autres domaines ni aux lots/phases tant que A-17 reste ouvert | Compléter la revue ressource par ressource ; conserver les points non tranchés avec responsable et motif ; synchroniser §5 et §6 après décision explicite | Architecture / métier / Direction |
| A-17 | Rattachement des lots et phases | `affaires` et `chantiers` disposent de scopes distincts (`assigned_projects` et `assigned_sites`) ; aucun élément validé ne permet d’attribuer un scope aux `lots_phases` | Confirmer si chaque lot/phase relève de l’affaire, du chantier ou d’une relation propre. Tant que ce rattachement n’est pas validé, conserver la ressource sans permission opérationnelle ni scope attribué ; ne pas déduire `assigned_projects`, `assigned_sites` ou `policy_defined` de l’ancien regroupement | §5.3 et §8 ; accès non attribué en attente d’arbitrage | Architecture / métier |


## 11.1 Dossier d'arbitrage A.4.1 — couverture transversale de DIR

**Objectif.** Préparer la validation métier exhaustive des droits de Direction (DIR) dans les 19 domaines du catalogue. Cette revue ne crée aucune permission et ne transforme pas la responsabilité transversale de DIR en CRUDV générique.

**Méthode de lecture.**

- « Explicite » signifie qu'une action DIR est déjà inscrite sur une ressource au §5 ; elle peut être reprise dans §6 après contrôle de cohérence.
- « À examiner » signifie que la responsabilité transversale peut justifier un besoin, mais que la ressource, l'action ou le scope doit être confirmé par la Direction.
- « Restriction » rappelle qu'un workflow ou une limite déjà définie ne peut pas être contourné.
- Aucun droit absent de §5 n'est ajouté par cette revue. Les permissions proposées restent distinctes des décisions métier validées.
- Les scopes sont des indications de périmètre ; leur contrôle effectif relève de CHAN-42.

| Domaine | Droits DIR actuellement explicites au §5 | Vérifications / arbitrages nécessaires | Garde-fous à préserver |
| --- | --- | --- | --- |
| Identity | admin_panel.access ; consultation et administration des financial_delegations selon les actions listées | Ne pas étendre à users, roles, permissions, role_assignments ou access_settings | DIR n'administre pas les habilitations ; sémantique suspend/delete reste M-16 |
| Clients | Consultation des prospects, clients, contacts et relations commerciales selon liste ; conditions_commerciales.approve à préciser ; consultation/approbation des devis selon ligne | Confirmer les ressources commerciales et les conditions exactes d'approbation ; clarifier la consultation des factures, avoirs, relances, échéanciers, litiges et règlements | Ne pas attribuer création/modification ou action financière par simple transversalité |
| Projects | Consultation des affaires et chantiers selon liste ; consultation des commandes clients/contrats ; approbation des commandes clients, avenants et contrats selon lignes ; consultation des jalons et rapports ; approbation des réceptions à confirmer | Confirmer les droits DIR sur études, lots/phases, planning contractuel, avenants (préparation/soumission), réceptions et autres ressources non explicitement attribuées | assigned_projects et assigned_sites restent distincts ; lots_phases demeure non attribué jusqu'à arbitrage A-17 |
| Planning | Consultation des conflits et avancement ; arbitrage des conflits à confirmer | Déterminer les actions DIR sur plannings, affectations, conflits et avancement, sans reprendre les opérations quotidiennes | Ne pas retirer les validations opérationnelles de CT, CC ou RA |
| Budgets | Consultation des budgets et révisions ; approbation de tous les budgets, révisions et contingences sans seuil de montant | Confirmer les droits sur les lignes budgétaires et préciser les workflows d'approbation | Conserver la préparation/soumission par CT ; aucune création ou modification DIR implicite |
| Costing | Accès complet DIR (`view`, `create`, `update`, `validate`) sur chiffrages, coûts et écarts ; consultation des marges ; approbation DIR/SA de toutes les provisions analytiques sans seuil ; approbation DIR/SA des engagements uniquement au-delà de 100 000 € HT cumulés par opération ; consultation, verrouillage, déverrouillage et clôture des périodes analytiques | Confirmer les autres droits DIR sur les ressources de costing et préciser les délégations sous seuil des engagements | Accès complet chiffrages/coûts/écarts confirmé ; provisions approuvées systématiquement ; périodes analytiques administrables par DIR et CPT ; engagements soumis au cumul commandes/avenants pour une même opération, prévention du fractionnement et absence d'auto-approbation |
| Workforce | Consultation RH DIR selon liste ; accès encadré aux données RH sensibles ; consultation des dossiers disciplinaires ; droits sur coordonnées bancaires ; validation indépendante des demandes de modification bancaire ; validation finale de paie ; supervision des indemnités et grands déplacements | Confirmer les ressources RH exactes et distinguer consultation, modification, validation et administration ; confirmer les droits DIR sur barèmes de grands déplacements | Secret médical ; pas d'accès aux documents médicaux confidentiels ; séparation des tâches bancaires et de paie ; ne pas étendre les données sensibles au-delà du besoin légal |
| TimeTracking | view/supervise sur pointages ; arbitrage des absences ; supervision des heures supplémentaires | Confirmer si DIR a besoin d'autres actions de supervision sur corrections, périodes et indicateurs, sans créer de validation courante | Clôture mensuelle par acteur à définir (M-03) ; réouverture exceptionnelle DIR/SA motivée ; pas de validation opérationnelle implicite |
| Workshop | Consultation des ordres de fabrication selon ligne | Confirmer si DIR doit consulter d'autres ressources atelier (dossiers, opérations, capacités, demandes matière, production, colis, rebuts/reprises) et avec quel niveau de détail | Pas d'approbation des plans de conception attribuée par défaut ; préserver l'autonomie opérationnelle RA |
| Procurement | Consultation des demandes d'achat, commandes d'achat et commandes de sous-traitance ; approbation des commandes selon les lignes | Confirmer les droits DIR sur fournisseurs, offres, accords-cadres, garanties, évaluations, incidents et besoins | Pas d'engagement sans approbation prévue ; seuil, cumul et délégations financières applicables |
| Inventory | Aucun droit DIR explicite sur les ressources de stock au §5 | Décider si DIR doit consulter articles, entrepôts, mouvements, consommations, inventaires, ajustements ou indicateurs de stock | Ne pas déduire un droit de modification, d'ajustement ou de mouvement |
| Equipment | Aucun droit DIR explicite sur les ressources matériel au §5 | Décider si DIR doit consulter les équipements, affectations, maintenances, interventions, inspections et pannes | Ne pas attribuer d'action opérationnelle ou réglementaire non décidée |
| Logistics | Aucun droit DIR explicite sur les ressources logistiques au §5 | Décider si DIR doit consulter transports, tournées, livraisons, retours et accès chantier | Ne pas attribuer planification ou modification opérationnelle par défaut |
| Quality | Consultation des plans qualité et des non-conformités | Confirmer consultation des contrôles, actions correctives, audits, certificats et signalements ; déterminer si une décision d'arbitrage qualité est réellement requise | Ne pas attribuer à DIR la validation ou clôture opérationnelle réservée à CT/RA ; rôle de traitement des signalements à arbitrer |
| Safety | Aucun droit DIR explicite sur les ressources sécurité au §5 | Décider si DIR doit consulter analyses de risques, plans de prévention, inspections, incidents, actions, habilitations et signalements | Ne pas déduire un rôle de responsable sécurité ou des actions de traitement |
| Documents | Consultation des documents selon ligne ; export DIR listé mais encore à arbitrer | Confirmer ressources documentaires consultables, téléchargement, signature, diffusion et export, avec liste des catégories/champs sensibles | M-05 et M-17 restent ouverts ; les scopes documentaires relèvent de CHAN-42 |
| Handover | Consultation des dossiers de réception, réserves, levées de réserves et DOE ; consultation des garanties et dossiers de clôture selon lignes | Confirmer les actions DIR sur garanties, clôtures, réserves et réception finale | Ne pas attribuer validation ou clôture sans décision explicite |
| Reporting | Consultation des rapports, indicateurs, tableaux de bord, tableaux de bord stratégiques et snapshots ; export DIR listé mais à arbitrer | Définir les ressources stratégiques, snapshots, sources de données, exports et éventuelles restrictions de champs | Préserver le caractère stratégique réservé à DIR ; M-05 et M-11 restent ouverts |
| Accounting | Approbation des paiements préparés par CPT ; autres droits DIR non explicitement listés dans le domaine | Confirmer si DIR a besoin de consultation sur trésorerie, écritures, journaux, rapprochements, immobilisations, déclarations et clôtures ; déterminer si le domaine accounting est distinct | DIR autorise/refuse les paiements, mais ne les prépare ni ne les exécute ; namespace A-01 ouvert |

### Décisions à obtenir en séance métier

Pour chaque ligne « À examiner », la Direction doit choisir explicitement l'une des réponses suivantes, ressource par ressource :

1. **Confirmer** : préciser l'action atomique (view, create, update, approve, etc.), le scope métier attendu et, si nécessaire, les conditions du workflow.
2. **Refuser** : consigner qu'aucune permission DIR n'est accordée.
3. **Reporter** : conserver le point ouvert avec son responsable et son ticket éventuel.

Une réponse « accès transversal » ou « accès complet » n'est pas suffisante : elle doit être décomposée en ressources et actions explicites. Toute action de validation doit être distinguée d'une approbation stratégique ou financière. Les décisions seront ensuite reportées dans les lignes concernées du §5, puis dans la synthèse §6 et dans A-16.

### A.4.2 — Registre des arbitrages DIR, Groupe 1

**Décisions métier reçues et confirmées par la Direction le 23/11/2026.** Elles complètent les sources Jira antérieures, sans valoir gel du catalogue ni implémentation.

| Domaine / ressource | Décision DIR | Action atomique / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Identity / panel et habilitations | Confirmer les droits existants | `identity.admin_panel.access` ; aucun droit sur users, roles, permissions, role_assignments ou access_settings | Global pour le panel | Confirmé ; aucune extension des habilitations |
| Clients / factures, avoirs, relances, échéanciers, litiges, règlements | Consultation | `view` sur chacune des ressources | Global | Confirmé ; CPT conserve préparation, modification, émission et rapprochement selon §5 |
| Clients / litiges de facturation | Arbitrage commercial et financier | `arbitrate` sur le litige ; approbation d'une régularisation financière dans un workflow distinct | Global | Arbitrage confirmé ; action `arbitrate` à normaliser (A-07) ; nature exacte de la régularisation, objet approuvé et action atomique restent à préciser |
| Clients / conditions commerciales | Approbation de toutes les conditions, y compris modifications et dérogations | `approve` ; pas de `create` ni `update` DIR | Global | Confirmé ; workflow et seuils éventuels à définir sans attribuer de modification |
| Projects / affaires, chantiers, études | Consultation | `view` | Global pour DIR | Confirmé ; CHAN-42 doit appliquer le périmètre global DIR sans modifier les scopes CT/CC |
| Projects / lots et phases | Besoin de consultation | Aucune permission attribuée avant décision A-17 | Non attribué à ce stade | Consultation souhaitée, mais modèle de rattachement non arbitré |
| Projects / avenants | Approbation uniquement pour DIR | `approve` ; aucun `prepare` ni `submit` DIR | Global pour DIR | Confirmé ; préparation/soumission CT restent à arbitrer |
| Projects / réception contractuelle | Approbation | `projects.receptions.approve` | Global pour DIR | Confirmé ; workflow distinct de Handover |
| Planning / plannings contractuels et opérationnels, affectations | Consultation seule | `view` ; aucun `create`, `update` ou `assign` DIR | Global pour DIR | Confirmé ; responsabilités quotidiennes CT/RA conservées |
| Planning / conflits | Consultation ; arbitrage non explicitement confirmé par la décision « consultation des plannings » | `view` ; pas de permission `arbitrate` confirmée à ce stade | Global pour DIR | Arbitrage des conflits conservé comme point ouvert |
| Handover / dossier de réception | Approbation finale | `handover.dossiers_reception.approve` | Global pour DIR | Confirmé ; distinct de la réception contractuelle Projects ; ne valide pas automatiquement réserves, levées de réserves ou DOE |

**Garde-fous associés.**

- Les consultations globales DIR sont des décisions fonctionnelles ; leur application aux ressources relève des Policies CHAN-42. Les scopes des autres rôles ne changent pas.
- L'approbation des conditions commerciales n'accorde pas de droit de modification.
- L'arbitrage d'un litige et l'approbation d'une régularisation financière ne donnent pas à DIR le droit de créer/émettre un avoir ou d'exécuter un paiement. CPT conserve l'exécution après autorisation ; l'auto-autorisation reste interdite.
- Les deux approbations de réception sont distinctes : réception contractuelle Projects et approbation finale du dossier Handover. Les validations opérationnelles des réserves, levées de réserves et DOE ne sont pas transférées à DIR.
- Les consultations de lots/phases restent non attribuées tant que A-17 n'est pas arbitré.
- Les actions `arbitrate` et l'approbation de régularisation financière nécessitent une normalisation et une définition du workflow avant intégration définitive au catalogue.

**Points non tranchés conservés.**

- Action atomique, objet et circuit de l'approbation des régularisations financières liées aux litiges.
- Arbitrage des conflits de planning.
- Rattachement métier et scope des lots/phases (A-17).
- Préparation/soumission des avenants par CT.
- Actions sur réserves, levées de réserves et DOE au-delà des droits déjà inscrits.
- M-16 et les autres points M-01 à M-15, M-17.
- A-01 à A-15, dont A-07 pour la normalisation du registre d'actions.
- Couverture des 15 autres domaines de A-16.

**État du lot.** Le groupe 1 est arbitré fonctionnellement, sous les réserves explicites ci-dessus. A-16 reste ouvert jusqu'à la couverture des 19 domaines ; A-17 reste ouvert. Aucun code, migration, seeder, test ou paramètre applicatif n'est modifié par cette mise à jour documentaire.


### A.4.2 — Registre des arbitrages DIR, Groupe 2

**Décision métier reçue le 23/11/2026.** Elle complète le groupe 1 sans valoir gel du catalogue ni implémentation.

| Domaine / ressource | Décision DIR | Action atomique / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Planning / conflits | Arbitrage des conflits | `arbitrate` sur les conflits de planning, en complément de `view` | Global pour DIR ; CT reste limité à assigned_projects | Décision fonctionnelle confirmée ; permission à normaliser dans A-07 et contrôle de périmètre à implémenter dans CHAN-42 |

**Limites conservées.** Ce droit permet à DIR de trancher les conflits de planning. Il ne lui attribue pas la création, la modification ou l'affectation quotidienne des plannings, et ne transfère pas les responsabilités opérationnelles de CT, CC ou RA. La portée globale concerne l'arbitrage DIR ; les scopes des rôles opérationnels restent inchangés.


### A.4.2 — Registre des arbitrages DIR, Groupe 2 — Budgets

**Décision métier reçue le 23/11/2026.**

| Domaine / ressource | Décision DIR | Action atomique / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Budgets | Approbation systématique de tous les budgets | `approve` sur chaque budget, sans seuil ni restriction de montant | Global pour DIR | Décision fonctionnelle confirmée ; workflow et séparation des tâches à préciser |
| Révisions budgétaires | Approbation systématique de toutes les révisions | `approve` sur chaque révision budgétaire, sans seuil ni restriction de montant | Global pour DIR | Décision fonctionnelle confirmée ; workflow et séparation des tâches à préciser |

**Limites conservées.** Cette décision ne donne pas à DIR les droits `create`, `update` ou `submit` sur les budgets ou leurs révisions. Les droits de préparation et de soumission de CT restent distincts. L'approbation par DIR est requise pour chaque budget et chaque révision, quel que soit le montant.

### A.4.2 — Registre des arbitrages DIR, Groupe 2 — Contingences

**Décision métier reçue le 23/11/2026.**

| Domaine / ressource | Décision DIR | Action atomique / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Contingences budgétaires | Approbation systématique de toutes les contingences | `approve` sur chaque contingence, sans seuil ni restriction de montant | Global pour DIR ; assigned_projects pour CT sur la préparation | Décision fonctionnelle confirmée ; workflow et séparation des tâches à préciser |

**Limites conservées.** Cette décision ne donne pas à DIR les droits `create` ou `update` sur les contingences. CT conserve la préparation et la modification dans son périmètre affecté. L'approbation DIR est requise pour chaque contingence, quel que soit le montant.

### A.4.2 — Registre des arbitrages DIR, Groupe 2 — Engagements financiers

**Décision métier reçue le 23/11/2026.**

| Domaine / ressource | Décision DIR | Action atomique / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Engagements financiers | Approbation DIR uniquement lorsque le seuil dépasse 100 000 € HT cumulés pour une même opération | `approve` sur les engagements concernés ; agrégation des commandes et avenants rattachés à la même opération | Global pour DIR ; CT reste dans son périmètre affecté pour les opérations de préparation | Seuil, cumul et principe anti-fractionnement confirmés ; modalités de délégation sous seuil et workflow à préciser |

**Limites conservées.** DIR n'approuve pas systématiquement tous les engagements : son approbation préalable est requise uniquement lorsque le cumul dépasse 100 000 € HT pour une même opération. Le calcul doit agréger les commandes et avenants liés à cette opération et empêcher le fractionnement artificiel. Les délégations applicables sous ce seuil restent à préciser ; aucune permission de préparation ou de modification des engagements n'est accordée à DIR par cette décision.

### A.4.2 — Registre des arbitrages DIR, Groupe 2 — Provisions analytiques

**Décision métier reçue le 23/11/2026.**

| Domaine / ressource | Décision DIR | Action atomique / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Provisions analytiques | Approbation systématique de toutes les provisions analytiques | `approve` sur chaque provision, sans seuil ni restriction de montant | Global pour DIR | Décision fonctionnelle confirmée ; workflow et séparation des tâches à préciser |

**Limites conservées.** Cette décision ne donne pas à DIR les droits `create` ou `update` sur les provisions analytiques. L'approbation concerne toutes les provisions, quel que soit leur montant. Les modalités de préparation, de soumission et la séparation des tâches restent à définir.

### A.4.2 — Registre des arbitrages DIR, Groupe 2 — Chiffrages, coûts et écarts

**Décision métier reçue le 23/11/2026.**

| Domaine / ressource | Décision DIR | Action atomique / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Chiffrages, coûts et écarts | Accès complet de DIR à toutes les ressources de ce périmètre, validation comprise | `view`, `create`, `update`, `validate` sur `chiffrages`, `couts` et `ecarts` | Global pour DIR ; les scopes CT/RA restent inchangés | Décision fonctionnelle confirmée ; workflow de validation et séparation des tâches à préciser |

**Limites conservées.** L'action `validate` est distincte de `approve` : cette décision n'ajoute pas d'approbation stratégique ou financière (`approve`) sur ces trois ressources. Elle n'accorde pas non plus de droit sur les marges, engagements, provisions ou périodes analytiques au-delà des permissions déjà inscrites dans leurs lignes respectives.

### A.4.2 — Registre des arbitrages DIR, Groupe 2 — Périodes analytiques

**Décision métier reçue le 23/11/2026.**

| Domaine / ressource | Décision DIR | Action atomique / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Périodes analytiques | DIR dispose de l'ensemble des actions de gestion des périodes | `view`, `lock`, `unlock`, `close` sur les périodes analytiques | Global pour DIR | Décision fonctionnelle confirmée ; workflow et séparation des tâches à préciser |

**Limites conservées.** DIR peut consulter, verrouiller, déverrouiller et clôturer les périodes analytiques. CPT conserve également ces quatre actions. Les règles de clôture, les conditions de déverrouillage et la traçabilité des opérations restent à préciser ; aucune autre permission comptable n'est déduite de cette décision.

### A.4.2 — Registre des arbitrages DIR, Groupe 2 — Ressources RH

**Décision métier reçue le 23/11/2026.** La Direction confirme que « accès complet » signifie toutes les ressources RH et toutes les actions applicables, sans restriction fonctionnelle ordinaire.

| Domaine / ressource | Décision DIR | Actions / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Workforce / toutes les ressources RH du §5.7 | Accès complet DIR | Toutes les actions applicables, notamment `view`, `create`, `update`, `delete`, `prepare`, `control`, `submit`, `validate`, `process`, `declare` et toute action spécifique à la ressource | Global pour DIR | Décision confirmée ; actions à normaliser dans le catalogue |

**Garde-fous impératifs.**

- L’accès complet ne donne pas accès aux documents médicaux détaillés couverts par le secret médical et détenus par les professionnels de santé. DIR ne consulte que les informations de santé légalement accessibles et strictement nécessaires.
- La suppression est accordée fonctionnellement, mais son exécution doit respecter les obligations légales de conservation, les durées de rétention et l’inaltérabilité des traces. Lorsque la suppression est interdite ou inappropriée, utiliser l’archivage ou la désactivation.
- Les workflows de séparation des tâches restent applicables : DIR ne peut pas s’auto-approuver lorsque la règle impose une validation indépendante ; les changements de coordonnées bancaires doivent être validés par une personne différente du demandeur/modificateur.
- Cette décision ne modifie pas les droits des autres rôles et ne donne aucun droit sur les ressources non RH.

### A.4.2 — Registre des arbitrages DIR, Groupe 2 — Inventory / Stocks

**Décision métier reçue le 24/11/2026.** DIR bénéficie d’un accès complet à toutes les ressources du domaine Inventory et à toutes les actions applicables.

| Domaine / ressource | Décision DIR | Actions / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Inventory / toutes les ressources du §5.11 | Accès complet DIR | Toutes les actions applicables, notamment consultation, création, modification, suppression, validation, annulation/inversion et ajustement | Global pour DIR | Décision confirmée ; actions à normaliser dans le catalogue |

**Garde-fous et limites.**

- Les mouvements, consommations, réceptions, sorties, inventaires et ajustements doivent conserver une piste d’audit exploitable : auteur, horodatage, motif et historique des corrections.
- Une annulation ou inversion doit être privilégiée à une suppression physique lorsqu’un mouvement a déjà un impact sur le stock ou la comptabilité. Les suppressions ne doivent pas effacer les traces obligatoires.
- Les droits existants de RA, CT, CC et CPT sont conservés ; les responsabilités opérationnelles ne leur sont pas retirées.
- Cette décision concerne uniquement Inventory (§5.11) et ne crée aucun droit supplémentaire dans Equipment, Logistics, Quality ou Safety.

### A.4.2 — Registre des arbitrages DIR, Groupe 2 — Equipment / Équipements

**Décision métier reçue le 24/11/2026.** DIR bénéficie d’un accès complet à toutes les ressources du domaine Equipment et à toutes les actions applicables.

| Domaine / ressource | Décision DIR | Actions / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Equipment / toutes les ressources du §5.12 | Accès complet DIR | Toutes les actions applicables, notamment consultation, création, modification, suppression, affectation, validation et actions spécifiques aux équipements, maintenances, interventions, inspections réglementaires et pannes | Global pour DIR | Décision confirmée ; actions à normaliser dans le catalogue |

**Garde-fous et limites.**

- Conserver l’historique des affectations, maintenances, interventions, inspections réglementaires, diagnostics et pannes : auteur, horodatage, motif, résultat et justificatifs associés.
- Les suppressions physiques ne doivent pas effacer les preuves réglementaires, les historiques de maintenance ni les éléments nécessaires à la sécurité et à l’audit ; privilégier l’archivage, la désactivation ou l’annulation tracée lorsque nécessaire.
- Les droits existants de RA, CT, CC et SAL sont conservés ; leurs responsabilités opérationnelles ne leur sont pas retirées.
- Cette décision concerne uniquement Equipment (§5.12) et ne crée aucun droit supplémentaire dans Logistics, Quality, Safety ou Inventory.

### A.4.2 — Registre des arbitrages DIR, Groupe 2 — Procurement / Achats et approvisionnements

**Décision métier reçue le 23/11/2026.** DIR bénéficie d’un accès complet à toutes les ressources du domaine Procurement et à toutes les actions applicables.

| Domaine / ressource | Décision DIR | Actions / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Procurement / toutes les ressources du §5.10 | Accès complet DIR | Toutes les actions applicables, notamment consultation, création, modification, suppression, préparation, soumission, validation, approbation et rapprochement lorsque ces actions existent | Global pour DIR | Décision confirmée ; actions à normaliser dans le catalogue |

**Garde-fous et limites.**

- Pour les commandes d’achat et de sous-traitance constituant des engagements financiers, l’approbation DIR demeure soumise au seuil cumulé strictement supérieur à 100 000 € HT par opération, en agrégeant commandes et avenants et en empêchant le fractionnement artificiel (§5.6).
- L’accès complet aux factures fournisseurs et leur rapprochement ne confèrent pas à DIR un droit d’exécuter les paiements ; les règles de préparation, autorisation et exécution des paiements restent distinctes.
- Les droits existants des autres rôles sont conservés. Les responsabilités de préparation et de traitement opérationnel ne sont pas transférées à DIR.
- Cette décision concerne uniquement Procurement (§5.10) et ne crée aucun droit supplémentaire dans Inventory, Equipment, Logistics, Quality ou Safety.

### A.4.2 — Registre des arbitrages DIR, Groupe 2 — Workshop / Production

**Décision métier reçue le 23/11/2026.** DIR bénéficie d’un accès complet à toutes les ressources du domaine Workshop et à toutes les actions applicables.

| Domaine / ressource | Décision DIR | Actions / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Workshop / toutes les ressources du §5.9 | Accès complet DIR | Toutes les actions applicables, notamment `view`, `create`, `update`, `delete`, `submit`, `validate`, `reopen`, `close`, et les actions spécifiques aux ressources | Global pour DIR | Décision confirmée ; actions à normaliser dans le catalogue |

**Garde-fous et limites.**

- L’accès complet DIR ne retire pas les responsabilités opérationnelles de RA sur l’atelier, ni les droits existants de CT, CC et SAL.
- Les opérations de production, rebuts et reprises doivent conserver leur historique et leur traçabilité ; une suppression physique ne doit pas effacer les éléments nécessaires à la justification de la production ou à l’audit.
- Cette décision concerne uniquement le domaine Workshop (§5.9). Elle n’accorde pas automatiquement de droits sur Inventory, Equipment, Logistics, Quality ou Safety, qui feront l’objet d’arbitrages distincts.

### A.4.2 — Registre des arbitrages DIR, Groupe 2 — TimeTracking

**Décision métier reçue le 23/11/2026.** DIR bénéficie d’un accès complet à toutes les ressources du domaine TimeTracking et à toutes les actions applicables.

| Domaine / ressource | Décision DIR | Actions / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| TimeTracking / toutes les ressources du §5.8 | Accès complet DIR | Toutes les actions applicables, notamment `view`, `create`, `update`, `delete`, `submit`, `review`, `validate`, `validate_excess`, `authorize`, `control`, `arbitrate`, `close`, `reopen` et `supervise` | Global pour DIR | Décision confirmée ; actions à normaliser dans le catalogue |

**Garde-fous impératifs.**

- L’accès complet TimeTracking ne donne pas accès aux documents médicaux détaillés des justificatifs couverts par le secret médical. DIR ne consulte que les informations administratives ou d’indisponibilité légalement accessibles et nécessaires.
- Les corrections, validations, clôtures et réouvertures doivent conserver l’historique, l’auteur, l’horodatage, les motifs et les traces de décision.
- Les heures réellement travaillées restent enregistrées, y compris lorsqu’un dépassement d’heures supplémentaires est refusé.
- Les responsabilités opérationnelles des autres rôles restent décrites dans leurs lignes ; les droits complets de DIR ne modifient pas leurs périmètres.

### Arbitrage A-17 — rattachement des lots et phases

Le catalogue distingue déjà :

- affaires : objet contractuel/commercial, scope candidat actuellement inscrit assigned_projects ;
- chantiers : objet opérationnel/site, scope candidat actuellement inscrit assigned_sites ;
- lots_phases : relation métier non déterminée, sans permission opérationnelle ni scope attribué.

**Options à faire confirmer par le métier :**

| Option | Rattachement envisagé | Conséquence possible | Point à confirmer |
| --- | --- | --- | --- |
| A | Un lot/une phase appartient à une affaire | Héritage du contexte affaire et du scope assigned_projects à étudier | Un lot peut-il exister sans chantier ou couvrir plusieurs chantiers ? |
| B | Un lot/une phase appartient à un chantier | Héritage du contexte site et du scope assigned_sites à étudier | Un lot peut-il être partagé entre plusieurs chantiers ou affaires ? |
| C | Un lot/une phase est une entité propre liée à l'affaire et au chantier | Relation et contrôle de périmètre spécifiques à définir dans CHAN-42 | Quelle est la cardinalité réelle et quelle affectation ouvre l'accès ? |
| D | Autre modèle métier | Décrire le rattachement et les cardinalités attendues | Faire préciser le modèle par le responsable métier |

Aucune option n'est retenue par le présent document. Jusqu'à décision, lots_phases reste sans permission opérationnelle et sans scope attribué. Le choix de modèle de données et les contrôles de périmètre devront être cohérents entre CHAN-40 et CHAN-42.

### État A.4.1

- Revue des 19 domaines préparée ; les droits DIR déjà explicites sont recensés sans les élargir.
- Les domaines sans droit DIR explicite sont signalés comme sujets de décision, sans permission ajoutée.
- Les workflows financiers, RH, médicaux, de paie, de temps et de validation opérationnelle restent prioritaires et inchangés.
- Les arbitrages A-16 et A-17 restent **ouverts** jusqu'à validation explicite par la Direction.
- Ce dossier ne vaut pas gel du catalogue et n'autorise pas encore la génération des seeders RBAC.

## 12. Correspondance avec CHAN-40, CHAN-42, CHAN-43, CHAN-45 et CHAN-46

| Ticket | Responsabilité | Éléments de ce document |
| --- | --- | --- |
| CHAN-40 | Référentiel RBAC, rôles, permissions, associations, seeders idempotents, accès panel et tests socle | Sections 4 à 6, 9, 10, 13 |
| CHAN-42 | Policies, accès aux ressources, périmètres affaire/chantier | Section 8 et scopes |
| CHAN-43 | Authentification et sessions | Hors périmètre CHAN-40 ; seul un renvoi documentaire est conservé, sans permission RBAC de session |
| CHAN-45 (périmètre à vérifier) | Journalisation de sécurité mentionnée dans la documentation du dépôt | Le périmètre exact sur l’audit métier immuable reste à confirmer ; à défaut, lot dédié |
| CHAN-46 | Tests fonctionnels d’autorisation | Matrice de tests à construire à partir des sections 6 à 9 |

Exemples de frontière :

- `timetracking.pointages.validate` est une permission CHAN-40 ; le fait qu’un Chef ne valide que son équipe est CHAN-42.
- `documents.documents.view` est une permission CHAN-40 ; l’accès aux documents d’un chantier affecté est CHAN-42.
- `identity.admin_panel.access` est une permission CHAN-40 ; elle ne donne aucun accès aux ressources.
- La matrice complète des refus et des périmètres est CHAN-46.

## 13. Recommandations pour la future implémentation

1. Créer un catalogue central dans `app/Domains/Identity/Catalog/`.
2. Définir `PermissionDefinition`, `PermissionCatalog` et `RoleCatalog`.
3. Utiliser des codes immuables et versionnés.
4. Créer des seeders idempotents, sans affectation automatique aux utilisateurs.
5. Vérifier le guard `web` et l’absence de Teams/wildcard.
6. Vérifier `identity.admin_panel.access` dans `canAccessPanel()`.
7. Implémenter les scopes dans CHAN-42, pas dans les permissions.
8. Implémenter les workflows de seuil, cumul, paiement, paie, temps, absences, heures supplémentaires et grands déplacements dans les services métier.
9. Prévoir la journalisation des actions sensibles en confirmant le périmètre de CHAN-45 ; à défaut, prévoir un lot dédié.
10. Construire les tests CHAN-46 à partir de la matrice des restrictions et des scopes.

Le catalogue, les seeders idempotents, les associations de rôles et les tests socle restent dans le périmètre CHAN-40.

### Règle de création des permissions

- Une décision fonctionnelle validée peut être normalisée techniquement et intégrée au catalogue.
- Un point encore à arbitrer ne doit pas être implémenté sur la base d’une hypothèse.
- Un arbitrage ouvert ne bloque pas les permissions indépendantes déjà validées.
- Toute permission doit respecter la convention de nommage et les principes RBAC du document.

## Synthèse

Le référentiel fonctionnel est consolidé sur la base des commentaires Jira 10297 à 10303. Le catalogue technique complet n’est pas encore prêt à être gelé :

- les huit rôles sont déjà validés ; leurs responsabilités sont reprises des décisions Jira ;
- les permissions explicites et les propositions sont distinguées ;
- les restrictions sensibles sont explicites ;
- les règles de séparation sont posées ;
- les décisions métier validées sont séparées des paramètres encore ouverts et des choix d’architecture.

Seules les permissions dont le domaine, la ressource, l’action et l’attribution aux rôles sont suffisamment définis peuvent être intégrées au catalogue. Les points ouverts de la section 11 bloquent uniquement les permissions qui en dépendent ; ils ne remettent pas en cause les décisions métier déjà validées. Avant génération des seeders, chaque entrée doit disposer d’un identifiant canonique et d’un statut de normalisation explicite.
