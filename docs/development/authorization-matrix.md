# Matrice RBAC CHAN-40 — Rôles et permissions

> **Statut :** référentiel fonctionnel consolidé ; conventions A-01 à A-09 normalisées le 24 novembre 2026 ; catalogue technique et seeders à implémenter.
> **Ticket :** CHAN-40 — Créer le modèle de rôles et permissions initiaux.
> **Date :** 23 novembre 2026.
> **Périmètre :** catalogue des permissions, rôles, affectations RBAC et accès au panel Filament.
> **Hors périmètre :** Policies et restrictions par ressource ou chantier (CHAN-42), tests fonctionnels complets d’autorisation (CHAN-46). Les seeders, le catalogue RBAC et le contrôle d’accès au panel font partie des livrables techniques de CHAN-40, après consolidation et validation de la nomenclature.

## Sources et limites

Sources fonctionnelles :

- Jira 10297 — principes généraux et sécurité ;
- Jira 10298 — Direction, Administratif, Super administrateur, Conducteur de travaux, Chef de chantier, Responsable atelier ;
- Jira 10299 — Salarié ;
- Jira 10300 — Gestion administrative et financière opérationnelle ;
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
GAF = Gestionnaire administratif et financier opérationnel
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

**Finalité.** Piloter l’entreprise et exercer l’ensemble des décisions opérationnelles, stratégiques, administratives et financières relevant de la Direction.

**Périmètre et règle d’attribution.** DIR dispose par défaut de toutes les permissions fonctionnelles existantes dans le catalogue RBAC, sur l’ensemble des modules, ressources et données métier de l’application, avec un scope global société. Cela comprend toutes les actions atomiques applicables à chaque ressource (consultation, création, modification, suppression lorsqu'elle existe, affectation, soumission, validation, approbation, arbitrage, export, clôture et toute action métier spécifique). Toute permission ou ressource fonctionnelle ajoutée ultérieurement au catalogue est accordée à DIR sans nouvel arbitrage individuel, sauf exception expressément identifiée ci-dessous. Cette règle remplace les validations ressource par ressource précédemment demandées pour DIR.

**Administration des habilitations.** Le plein accès fonctionnel ne confère pas l’administration technique des identités et habilitations : DIR ne gère pas les utilisateurs, rôles, permissions, affectations de rôles ni paramètres d’accès. L’accès au panel Filament ne donne pas, à lui seul, de droits d’administration des habilitations.

**Données RH et médicales.** DIR dispose des permissions fonctionnelles sur les données RH, y compris les données sensibles métier, dans les limites légales. Les documents médicaux détaillés détenus dans l’espace confidentiel des professionnels de santé et les informations couvertes par le secret médical restent exclus. Les informations médicales légalement accessibles et strictement nécessaires peuvent être consultées dans les limites applicables.

**Séparation des tâches.** DIR conserve la validation finale de la paie. Toute séparation des tâches obligatoire dans un workflow demeure applicable : le plein accès ne permet pas l'auto-approbation interdite ni le contournement d'un contrôle réglementaire. Aucun workflow de paiement bancaire n'est défini dans le périmètre actuel.

**Engagements financiers.** Les règles d'approbation des engagements restent applicables, notamment l'approbation préalable par DIR ou SA au-delà de 100 000 € HT cumulés pour une même opération, commandes et avenants agrégés, sans possibilité de fractionnement. Les délégations et workflows associés ne sont pas supprimés par la règle d'accès intégral.

**Traçabilité et conservation.** Toutes les actions sensibles de DIR sont historisées. Les obligations légales de conservation, l'intégrité des preuves, l'immuabilité des journaux d'audit et les restrictions légales demeurent applicables. Une permission de suppression n'autorise jamais la destruction d'une pièce ou d'une preuve dont la conservation est obligatoire.

**Policies et périmètre technique.** Le scope fonctionnel de DIR est global société. Les Policies CHAN-42 continuent d'appliquer les restrictions légales, de confidentialité et de sécurité ; elles ne doivent pas réintroduire de limitation métier par chantier pour DIR en dehors de ces restrictions.

**Lots et phases.** La règle générale d'accès intégral s'applique également aux ressources métier de lots et phases. Le rattachement A-17 est validé : Affaire 1—N Chantier, Chantier 1—N Lot, Lot 1—N Phase ; chaque lot appartient à un seul chantier et chaque phase à un seul lot. DIR conserve un scope global ; les accès opérationnels CT/CC suivent `assigned_sites` via le chantier parent. Les actions atomiques restent à définir.

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
- Pointages : ADM n’assure pas une validation supplémentaire des pointages. CC valide son équipe, CT contrôle et peut corriger ou rouvrir les pointages des salariés affectés après validation CC, RA valide son équipe, GAF exploite les pointages validés pour la paie sans modification libre. ADM assure les contrôles administratifs et réglementaires, notamment sur les heures supplémentaires.
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

### 3.8 Gestion administrative et financière opérationnelle

**Finalité.** Assurer le traitement administratif et le suivi financier opérationnel des activités, sans exercer de fonctions de comptabilité générale ni d'opérations bancaires.

**Périmètre.**
- **Clients :** factures, avoirs, relances, échéanciers, litiges et suivi opérationnel des règlements.
- **Achats :** traitement administratif des commandes et factures fournisseurs.
- **Ressources humaines :** paie, bulletins, éléments variables et données strictement nécessaires à la gestion administrative.
- **Budgets et Costing :** consultation et suivi opérationnel selon les permissions définies pour chaque ressource.

**Consultation, création et modification.** Uniquement les opérations administratives expressément attribuées dans le catalogue des permissions ; aucun droit n'est déduit du seul intitulé du rôle.

**Paie.** GAF prépare et contrôle les éléments variables et les éléments nécessaires à la paie. DIR ou SA conserve la validation finale. Toute modification postérieure à cette validation suit le mécanisme de nouvelle validation prévu par le workflow.

**Données RH.** Accès limité aux bulletins, éléments variables et données strictement nécessaires à la gestion administrative et à la paie. Aucun accès général aux dossiers disciplinaires ni aux justificatifs personnels sans lien avec ces finalités. Les coordonnées bancaires éventuellement consultables pour la gestion administrative de la paie ne confèrent aucun droit sur les virements.

**Validation.** Aucune approbation générale d'engagement ou de commande, aucune validation finale de paie et aucune auto-validation lorsque le workflow impose une séparation des tâches.

**Exclusions impératives.** Aucune écriture comptable, journal, plan comptable, rapprochement bancaire comptable, trésorerie comptable, déclaration, clôture comptable, immobilisation ou amortissement. Aucun droit de préparation, d'autorisation ou d'exécution de paiement bancaire. Aucun mandat bancaire.

**Limites de périmètre.** Les scopes et restrictions de données sont définis ressource par ressource au §5 et par les Policies CHAN-42.

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

### 4.2 Périmètre fonctionnel sans comptabilité

Le logiciel Chantier ne comporte pas de module comptable. La comptabilité générale, les journaux, le plan comptable, les périodes comptables, les rapprochements bancaires, la trésorerie comptable, les déclarations et clôtures comptables, les immobilisations, les amortissements et les écritures comptables sont hors périmètre.

Les fonctions de gestion opérationnelle conservées restent propriétaires de leurs domaines : facturation et règlements clients dans Clients, achats et factures fournisseurs dans Procurement selon leur workflow, budgets dans Budgets, coûts et marges de gestion dans Costing, paie et données RH dans Workforce. Ces fonctions ne constituent pas un module comptable.

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

### État de normalisation

Les conventions A-01 à A-09 sont désormais les références de nommage et de construction du catalogue :
- domaine canonique TimeTracking : `timetracking` ;
- ressource facture client : `clients.factures_clients` ; `clients.factures` est un alias interdit ;
- ressource Budgets : `budgets`, avec ressources distinctes pour les lignes, révisions et contingences ;
- ressource de consommation : `inventory.consomations` ;
- actions limitées au registre A-07 et justifiées par le workflow réel.

Les anciennes listes de « points à vérifier » présentes dans les versions antérieures sont historiques et ne constituent plus des arbitrages ouverts. Les contrôles mécaniques des clés et références restent à réaliser lors de la construction du catalogue technique.

## 5. Catalogue complet des permissions

Les tableaux indiquent les actions et les rôles. Chaque action listée forme une permission atomique `{domain}.{resource}.{action}`. Les ressources non listées ne reçoivent aucune permission par défaut. La dernière colonne sépare le statut fonctionnel et le statut technique ; une décision métier validée ne signifie pas que le code est normalisé ou implémenté.

Deux rôles disposent d'une portée fonctionnelle globale, avec des réserves distinctes :

- **SA** : droit métier et administratif global sur les modules et données métier, sous réserve de l’exception médicale et des Policies CHAN-42. Les permissions SA listées dans les tableaux précisent les workflows et actions dédiés.
- **DIR** : toutes les permissions fonctionnelles présentes et futures du catalogue, sur tous les domaines et ressources métier, avec scope global société. Les lignes du §5 détaillent les autres rôles, les workflows et les exceptions ; elles ne limitent pas le principe d'accès intégral de DIR. Aucune validation individuelle supplémentaire n'est requise lorsqu'une nouvelle permission métier est ajoutée. Les seules exceptions sont l'administration des habilitations techniques, les documents médicaux couverts par le secret médical, les séparations de tâches obligatoires (notamment préparation/exécution des paiements), ainsi que les restrictions légales de conservation, confidentialité et audit.

La règle DIR est fonctionnellement `Validé` et techniquement `À normaliser`. Le rôle DIR reçoit chaque permission fonctionnelle atomique du catalogue, y compris celles ajoutées ultérieurement, sans permission générique `manage` ni wildcard : les associations sont explicites dans le seeder. Cette règle ne donne pas à DIR l'administration des habilitations et ne supprime aucun contrôle légal ou workflow obligatoire.

### 5.1 Identity

| Ressource | Actions / rôles | Scope | Justification | Source | Statut fonctionnel / technique |
| --- | --- | --- | --- | --- | --- |
| `admin_panel` | `access` : SA, DIR, ADM, CT, CC, RA, GAF | global | Accès au panel Filament, sans accès ressource | 10297, 10298, 10301 | `Validé` ; `À implémenter` |
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
| `prospects` | Accès complet DIR : toutes les actions applicables (`view`, `create`, `update`, `merge`, `archive`, `delete` si disponibles) ; `view`, `create`, `update` : ADM | global pour DIR ; global / company pour ADM | Gestion complète des fiches prospects ; suppression soumise aux obligations de conservation et à la traçabilité | 10298, décision A.4.2 du 24/11/2026 | Accès complet DIR confirmé ; actions de fusion/archivage/suppression selon capacités applicatives et règles de conservation |
| `clients` | Accès complet DIR : toutes les actions applicables (`view`, `create`, `update`, `merge`, `archive`, `delete` si disponibles) ; `view`, `create`, `update` : ADM | global pour DIR ; global / company pour ADM | Gestion complète des fiches clients ; suppression soumise aux obligations de conservation et à la traçabilité | 10298, décision A.4.2 du 24/11/2026 | Accès complet DIR confirmé ; actions de fusion/archivage/suppression selon capacités applicatives et règles de conservation |
| `contacts` | Accès complet DIR : toutes les actions applicables (`view`, `create`, `update`, `merge`, `archive`, `delete` si disponibles) ; `view`, `create`, `update` : ADM | global pour DIR ; global / company pour ADM | Gestion complète des fiches contacts ; suppression soumise aux obligations de conservation et à la traçabilité | 10298, décision A.4.2 du 24/11/2026 | Accès complet DIR confirmé ; actions de fusion/archivage/suppression selon capacités applicatives et règles de conservation |
| `relations_commerciales` | Accès complet DIR : toutes les actions applicables (`view`, `create`, `update`, `qualify`, `track`, `archive`, `delete` si disponibles) ; `view`, `create`, `update` : ADM | global pour DIR ; global / company pour ADM | Gestion complète des relations commerciales par DIR, y compris création, modification, qualification, suivi et archivage | 10298, décision A.4.2 du 24/11/2026 | Accès complet DIR confirmé ; suppression soumise aux obligations de conservation et à la traçabilité |
| `conditions_commerciales` | Accès complet DIR : toutes les actions applicables (`view`, `create`, `update`, `approve`, `delete` si disponible) ; `view`, `create`, `update` : ADM ; `approve` : DIR, SA | global | Gestion complète des conditions commerciales par DIR, y compris création, modification et approbation de toutes les conditions initiales, modifications et dérogations | 10298, arbitrages A.4.2 Groupe 1 et décision du 24/11/2026 | Accès complet DIR confirmé ; suppression soumise aux obligations de conservation et à la traçabilité ; workflow à préciser |
| `devis_commerciaux` | Accès complet DIR : toutes les actions applicables (`view`, `create`, `update`, `submit`, `approve`, `issue`, `close`, `delete` si disponibles) ; `view`, `create`, `update`, `submit` : ADM ; `approve` : DIR, SA | global | DIR dispose de tous les droits métier applicables sur les devis commerciaux, y compris création, modification, validation/approbation, émission et clôture ; droits ADM conservés | 10298, 10301, décision A.4.2 du 24/11/2026 | Accès complet DIR confirmé ; suppression soumise aux obligations de conservation et à la traçabilité ; workflow à préciser |
| `factures_clients` | Accès complet DIR : toutes les actions applicables (`view`, `create`, `update`, `issue`, `delete` si l’action existe) ; `view`, `create`, `update`, `issue` : GAF | global pour DIR et GAF | DIR dispose de tous les droits métier applicables sur les factures clients, y compris leur création, modification et émission ; droits GAF conservés | 10300, décision A.4.2 du 24/11/2026 | Accès complet DIR confirmé ; toute suppression reste soumise aux obligations légales de conservation et à la traçabilité |
| `avoirs` | Accès complet DIR : toutes les actions applicables (`view`, `create`, `update`, `issue`, `delete` si l’action existe) ; `view`, `create`, `update`, `issue` : GAF | global pour DIR et GAF | DIR dispose de tous les droits métier applicables sur les avoirs clients, y compris leur création, modification et émission ; droits GAF conservés | 10300, décision A.4.2 du 24/11/2026 | Accès complet DIR confirmé ; suppression soumise aux obligations comptables de conservation et à la traçabilité |
| `relances` | Accès complet DIR : toutes les actions applicables (`view`, `create`, `update`, `issue`, `close`, `delete` si disponibles) ; `view`, `create`, `update` : GAF | global pour DIR et GAF | DIR dispose de tous les droits métier applicables sur les relances clients, y compris création, modification, émission et clôture ; droits GAF conservés | 10300, décision A.4.2 du 24/11/2026 | Accès complet DIR confirmé ; suppression soumise aux obligations de conservation et à la traçabilité |
| `echeanciers` | Accès complet DIR : toutes les actions applicables (`view`, `create`, `update`, `validate`, `close`, `delete` si disponibles) ; `view`, `create`, `update` : GAF | global pour DIR et GAF | DIR dispose de tous les droits métier applicables sur les échéanciers clients, y compris création, modification, validation et clôture ; droits GAF conservés | 10300, décision A.4.2 du 24/11/2026 | Accès complet DIR confirmé ; suppression soumise aux obligations de conservation et à la traçabilité |
| `litiges_facturation` | Accès complet DIR : toutes les actions applicables (`view`, `create`, `update`, `treat`, `arbitrate`, `close`, `delete` si disponibles) ; `view`, `create`, `update` : GAF | global pour DIR et GAF | DIR dispose de tous les droits métier applicables sur les litiges de facturation, y compris création, modification, traitement, arbitrage et clôture ; droits GAF conservés | 10300, arbitrage A.4.2 Groupe 1 et décision du 24/11/2026 | Accès complet DIR confirmé ; action `arbitrate` à normaliser (A-07) ; régularisation financière via workflow distinct ; suppression soumise à conservation et traçabilité |
| `reglements` | Accès complet DIR : toutes les actions métier applicables (`view`, `create`, `update`, `validate`, `reconcile`, `close` et `delete` uniquement si disponible et légalement autorisée) ; `view`, `reconcile` : GAF, droits complémentaires GAF conservés | global pour DIR et GAF | DIR peut créer, modifier, valider et rapprocher les règlements clients ; pour GAF, `reconcile` désigne uniquement le suivi opérationnel du règlement avec la facture, jamais un rapprochement bancaire | 10300, arbitrage A.4.2 Groupe 1 et décision du 24/11/2026 | Accès complet DIR confirmé dans le périmètre des règlements ; aucun paiement bancaire ; conservation et traçabilité obligatoires |

### 5.3 Projects

| Ressource | Actions / rôles | Scope | Justification | Source | Statut fonctionnel / technique |
| --- | --- | --- | --- | --- | --- |
| `affaires` | `view`, `create`, `update` : CT ; `view` : ADM, CC, GAF, DIR | global pour DIR ; assigned_projects pour CT | Affaires au niveau contractuel/commercial ; consultation DIR globale | 10298, arbitrage A.4.2 Groupe 1 | Consultation DIR validée ; permissions à intégrer |
| `chantiers` | `view`, `create`, `update` : CT ; `view` : ADM, CC, GAF, DIR | global pour DIR ; assigned_sites pour CT | Gestion opérationnelle ; consultation DIR globale | 10298, arbitrage A.4.2 Groupe 1 | Consultation DIR validée ; permissions à intégrer |
| `lots_phases` | Actions métier à définir ; DIR : accès complet à toutes les actions applicables ; CT : accès sur les chantiers affectés ; CC : accès opérationnel sur les chantiers affectés, selon actions à définir | global pour DIR ; assigned_sites pour CT/CC | Un lot appartient à un seul chantier ; une phase appartient à un seul lot et hérite du chantier | Décision métier A-17 du 24/11/2026 | Rattachement validé ; actions atomiques et attribution des autres rôles à définir |
| `etudes` | `view`, `create`, `update` : CT ; `view` : DIR | global pour DIR ; assigned_projects pour CT | Consultation DIR des études | 10298, arbitrage A.4.2 Groupe 1 | Consultation DIR validée ; permission à intégrer |
| `commandes_clients` | `view` : DIR, ADM, CT, GAF ; `approve` : DIR, SA | global pour DIR ; assigned_projects pour CT | Approbation obligatoire par DIR de toutes les commandes clients, sans restriction de montant ; consultation globale DIR | 10298, 10301, arbitrage A.4.2 | Décision métier validée ; workflow à préciser |
| `avenants` | `view`, `prepare`, `submit` : CT ; `view` : DIR, ADM ; `approve` : DIR, SA | global pour DIR ; assigned_projects pour CT | CT prépare et soumet les avenants dans son périmètre ; DIR et SA approuvent ; DIR n’assure ni préparation ni soumission | 10298, 10303, arbitrage A.4.2 Groupe 1 et décision du 24/11/2026 | Décision métier validée ; workflow, seuil et cumul applicables à préciser |
| `contrats` | `view` : DIR, ADM, CT, GAF ; `approve` : DIR, SA | global pour DIR ; assigned_projects pour CT | Approbation obligatoire par DIR de tous les contrats, sans restriction de montant ; consultation globale DIR | 10298, 10301, arbitrage A.4.2 | Décision métier validée ; workflow à préciser |
| `jalons` | `view`, `update` : CT ; `view` : DIR, CC | global pour DIR ; assigned_projects pour CT ; périmètre CC selon affectation | Consultation globale DIR des jalons ; CT conserve la mise à jour opérationnelle | 10298, arbitrage A.4.2 | Consultation DIR validée ; permission à intégrer |
| `receptions` | `view`, `prepare` : CT ; `view` : CC ; `approve` : DIR | global pour DIR ; assigned_projects pour CT | Approbation de la réception contractuelle par DIR, distincte de l'approbation finale du dossier Handover | 10298, arbitrage A.4.2 Groupe 1 | Décision métier validée ; permission à intégrer |
| `rapports_operationnels` | `view`, `create`, `update` : CT, CC ; `view` : DIR | global pour DIR ; assigned_projects pour CT/CC | Consultation globale DIR des rapports opérationnels ; aucune création ni modification DIR | 10298, arbitrage A.4.2 | Consultation DIR validée ; permission à intégrer |

### 5.4 Planning

| Ressource | Actions / rôles | Scope | Justification | Source | Statut fonctionnel / technique |
| --- | --- | --- | --- | --- | --- |
| `plannings`, `affectations` | `view`, `create`, `update`, `assign` : CT ; `view` : CC, RA, SAL, DIR ; `update` atelier : RA | global pour DIR ; assigned_projects / own_team pour les rôles opérationnels | Consultation DIR des plannings contractuels et opérationnels ; aucune gestion quotidienne | 10298, arbitrage A.4.2 Groupe 1 | Consultation DIR validée ; permission à intégrer |
| `conflits` | `view`, `arbitrate` : DIR ; `view` : CT | global pour DIR ; assigned_projects pour CT | DIR consulte et arbitre les conflits de planning ; CT conserve son périmètre opérationnel affecté | 10298, arbitrage A.4.2 Groupe 1 et Groupe 2 | Arbitrage DIR validé fonctionnellement ; permission à normaliser (A-07) et Policy à appliquer dans CHAN-42 |
| `avancement` | `view`, `update` : CT, CC ; `view` : DIR | global pour DIR ; assigned_projects pour CT/CC | Consultation globale DIR de l’avancement ; aucune modification DIR | 10298, arbitrage A.4.2 | Consultation DIR validée ; permission à intégrer |

### 5.5 Budgets

| Ressource | Actions / rôles | Scope | Justification | Source | Statut fonctionnel / technique |
| --- | --- | --- | --- | --- | --- |
| `budgets` | `view`, `create`, `update`, `submit` : CT ; `approve` : DIR, SA ; `view` : ADM, GAF, DIR | assigned_projects pour CT ; global pour DIR, SA, ADM, GAF selon rôle | Budgets ; approbation obligatoire de tous les budgets par DIR sans seuil de montant | 10298, 10301, arbitrage A.4.2 Groupe 2 | Approbation DIR sans restriction de montant validée fonctionnellement ; workflow à préciser |
| `lignes_budgetaires` | Accès complet DIR : toutes les actions applicables (`view`, `create`, `update`, `delete`, `submit`, `validate`, `approve` selon les opérations disponibles) ; `view`, `create`, `update` : CT ; `view` : ADM, GAF | global pour DIR ; assigned_projects pour CT ; portée des autres rôles inchangée | DIR dispose d’un accès complet aux lignes budgétaires, sans restriction de montant ; les droits CT de préparation dans son périmètre sont conservés | 10298, décision A.4.2 du 24/11/2026 | Accès complet DIR confirmé ; suppression soumise aux obligations de conservation et à la traçabilité ; workflow à préciser |
| `revisions_budgetaires` | `view`, `create`, `update`, `submit` : CT ; `approve` : DIR, SA ; `view` : ADM, GAF | assigned_projects pour CT ; global pour DIR, SA, ADM, GAF selon rôle | Révisions ; approbation obligatoire de toutes les révisions par DIR sans seuil de montant | 10298, 10301, arbitrage A.4.2 Groupe 2 | Approbation DIR sans restriction de montant validée fonctionnellement ; workflow à préciser |
| `contingences` | `view`, `create`, `update` : CT ; `approve` : DIR | assigned_projects pour CT ; global pour DIR | Approbation obligatoire de toutes les contingences par DIR sans seuil de montant ; préparation et modification restent distinctes | 10298, arbitrage A.4.2 Groupe 2 | Approbation DIR sans restriction de montant validée fonctionnellement ; workflow et séparation des tâches à préciser |

### 5.6 Costing

| Ressource | Actions / rôles | Scope | Justification | Source | Statut fonctionnel / technique |
| --- | --- | --- | --- | --- | --- |
| `chiffrages`, `couts`, `ecarts` | `view`, `create`, `update`, `validate` : DIR ; `view` : ADM, CT, RA, GAF ; `create`, `update` : CT, RA selon objet | global pour DIR ; assigned_projects pour CT/RA selon objet | Chiffrages, coûts et écarts financiers opérationnels | 10298, 10300, arbitrage A.4.2 Groupe 2 | Accès complet DIR, validation comprise, confirmé fonctionnellement ; workflow et séparation des tâches à préciser |
| `engagements` | `view` : DIR, CT ; `approve` : DIR, SA uniquement lorsque le seuil cumulé dépasse 100 000 € HT pour une même opération | global pour DIR/SA ; assigned_projects pour CT | Approbation préalable obligatoire au-delà de 100 000 € HT cumulés pour une même opération, en agrégeant commandes et avenants et en prévenant le fractionnement ; en dessous ou au seuil, pas d'approbation DIR au titre de cette règle | 10297, 10298, 10303, arbitrage A.4.2 Groupe 2 | Seuil et cumul validés ; aucune approbation ni permission d'engagement attribuée à GAF |
| `marges` | `view` : DIR, CT, RA, GAF | assigned_projects / global | Rentabilité | 10298, 10300 | `Proposé` |
| `provisions_analytiques` | `view` : DIR, CT, GAF ; `approve` : DIR, SA pour toutes les provisions analytiques, sans seuil de montant | global | Provisions | 10298, 10301, arbitrage A.4.2 Groupe 2 | Approbation DIR systématique confirmée ; workflow et séparation des tâches à préciser |
| `periodes_analytiques` | `view`, `lock`, `unlock`, `close` : DIR ; `view` : GAF | global | Périodes analytiques | 10300, arbitrage A.4.2 Groupe 2 | DIR conserve l'administration des périodes analytiques ; GAF dispose uniquement de la consultation |

### 5.7 Workforce

| Ressource | Actions / rôles | Scope | Justification | Source | Statut fonctionnel / technique |
| --- | --- | --- | --- | --- | --- |
| `collaborateurs`, `contrats`, `postes`, `qualifications`, `formations`, `equipes`, `disponibilites` | Accès complet DIR : `view`, `create`, `update`, `delete` et toutes actions métier applicables ; ADM conserve `view`, `create`, `update` ; CT, CC, RA et SAL conservent leurs consultations limitées | global DIR / company / own_team / own | Accès complet Direction aux données RH administratives | Arbitrage A.4.2 Groupe 2 | Décision DIR confirmée ; actions à normaliser |
| `dossiers_rh` | Accès complet DIR : `view`, `create`, `update`, `delete` et toutes actions métier applicables ; ADM conserve `view`, `create`, `update` ; SAL conserve `view` own | global DIR / company / own | Dossiers RH, hors documents médicaux confidentiels | Arbitrage A.4.2 Groupe 2 | Décision DIR confirmée ; actions à normaliser |
| `dossiers_disciplinaires` | Accès complet DIR : `view`, `create`, `update`, `delete` et toutes actions métier applicables ; SA conserve ses droits globaux sous réserve des restrictions applicables | global DIR / restricted | Dossiers RH sensibles | Arbitrage A.4.2 Groupe 2 ; 10303 | Décision DIR confirmée ; actions à normaliser |
| `donnees_medicales` | DIR : accès uniquement aux informations légalement accessibles et strictement nécessaires ; aucun accès aux documents médicaux détaillés détenus par les professionnels de santé ; SA : aucun accès automatique aux documents médicaux détaillés ; ADM : réception et traitement administratif des justificatifs sans accès général aux données médicales détaillées ; GAF : seules informations nécessaires à la paie et à la administration de la paie | restricted | Secret médical et confidentialité des informations de santé | 10303 ; limite impérative maintenue | Exception explicite à l’accès complet ; accès détaillé interdit hors habilitation légale spécifique |
| `coordonnees_bancaires` | Accès complet DIR : `view`, `create`, `update`, `delete`, `validate` et toutes actions métier applicables ; SA conserve ses droits ; GAF : `view` uniquement pour les données strictement nécessaires à la gestion administrative de la paie ; SAL : `view` own et `request_update` | global DIR / own / restricted | Données bancaires ; historique sécurisé et validation indépendante des demandes de changement ; aucun droit de virement pour GAF | Arbitrage A.4.2 Groupe 2 ; 10303 | Actions à normaliser ; validation indépendante du demandeur/modificateur maintenue ; accès GAF limité à la consultation nécessaire |
| `elements_variables_paie` | Accès complet DIR : `view`, `create`, `update`, `delete`, `prepare`, `control`, `submit`, `validate` et toutes actions métier applicables ; ADM conserve ses droits de préparation/soumission ; GAF conserve `view`, `prepare`, `control` | global DIR / company | Variables de paie ; GAF prépare et contrôle les éléments variables sans validation finale | Arbitrage A.4.2 Groupe 2 ; 10298, 10300 | Actions à normaliser ; séparation des tâches maintenue |
| `paies`, `bulletins_paie` | Accès complet DIR : `view`, `create`, `update`, `delete`, `prepare`, `control`, `validate` et toutes actions métier applicables ; GAF conserve `view`, `prepare`, `control` ; SAL conserve `view` bulletins own ; SA conserve ses droits | global DIR / own / restricted | Paie, bulletins et écritures ; validation finale et historique des modifications | Arbitrage A.4.2 Groupe 2 ; 10299, 10300, 10303 | Décision DIR confirmée ; actions à normaliser ; interdiction d’auto-approbation et exigences de validation après modification maintenues |
| `indemnites_grands_deplacements` | Accès complet DIR : `view`, `create`, `update`, `delete`, `prepare`, `control`, `process`, `validate` et toutes actions métier applicables ; SAL conserve `view` own ; ADM et GAF conservent leurs droits | global DIR / own / company | Indemnités de grand déplacement, éléments de paie et gestion administrative opérationnelle | Arbitrage A.4.2 Groupe 2 ; 10303 | Décision DIR confirmée ; actions à normaliser |
| `grands_deplacements` | Accès complet DIR : `view`, `create`, `update`, `delete`, `declare`, `control`, `prepare`, `process`, `validate` et toutes actions métier applicables ; CT/RA conservent la déclaration de leurs équipes ; ADM/GAF/SAL conservent leurs droits | global DIR / assigned_workers / own / company | Déclarations, contrôle administratif et exploitation paie | Arbitrage A.4.2 Groupe 2 ; 10303 | Décision DIR confirmée ; actions à normaliser |
| `baremes_grands_deplacements` | Accès complet DIR : `view`, `create`, `update`, `delete` et toutes actions métier applicables ; SA conserve ses droits globaux | global DIR | Barèmes paramétrables, datés et historisés | Arbitrage A.4.2 Groupe 2 ; 10303 | Décision DIR confirmée ; actions à normaliser ; aucune modification rétroactive des périodes traitées |

Les permissions RH de DIR couvrent toutes les ressources RH et toutes les actions métier applicables, y compris création, modification, validation et suppression, à l’échelle globale. Cette attribution ne lève pas le secret médical : les documents médicaux détaillés détenus par les professionnels de santé restent hors d’accès général. Les suppressions ne peuvent intervenir que lorsque la loi, les durées de conservation et les obligations de traçabilité le permettent ; à défaut, archivage ou désactivation. Les règles de séparation des tâches demeurent applicables, notamment l’interdiction de s’auto-approuver et la validation indépendante des changements de coordonnées bancaires. Les permissions RH de CT, CC et RA restent limitées aux informations opérationnelles nécessaires ; ADM et GAF conservent les droits indiqués dans chaque ligne. Les restrictions de champs et de périmètre relèvent de CHAN-42.

### 5.8 TimeTracking

| Ressource | Actions / rôles | Scope | Justification | Source | Statut fonctionnel / technique |
| --- | --- | --- | --- | --- | --- |
| `pointages`, `feuilles_de_temps` | Accès complet DIR : toutes actions applicables, notamment `view`, `create`, `update`, `delete`, `submit`, `validate`, `correct`, `reopen`, `supervise` ; CC/RA et SAL conservent leurs droits ; CT conserve ses droits de contrôle/correction ; GAF conserve `view` pour la paie | global DIR / own / own_team / assigned_sites / assigned_workers / company | Pointages et feuilles de temps ; conserver les validations opérationnelles, l’historique et les motifs de correction | Arbitrage A.4.2 Groupe 2 ; 10298, 10299, 10303 | Décision DIR confirmée ; actions à normaliser |
| `corrections` | Accès complet DIR : toutes actions applicables, notamment `view`, `create`, `update`, `delete`, `submit`, `validate`, `reopen` ; SAL, CC, RA et CT conservent leurs droits selon leurs périmètres | global DIR / own / own_team / assigned_workers | Corrections horodatées ; conserver valeur initiale, nouvelle valeur, auteur, date, motif et valideur ; notifier GAF si transmission paie déjà effectuée | Arbitrage A.4.2 Groupe 2 ; 10298, 10299, 10303 | Décision DIR confirmée ; actions à normaliser ; traçabilité obligatoire |
| `periodes` | Accès complet DIR : `view`, `create`, `update`, `delete`, `close`, `reopen` et toutes actions applicables ; SA conserve `reopen` | global DIR | Clôture après contrôles ; réouverture motivée et auditée | Arbitrage A.4.2 Groupe 2 ; 10303 | Décision DIR confirmée ; actions à normaliser ; clôture et réouverture tracées |
| `absences` | Accès complet DIR : toutes actions applicables, notamment `view`, `create`, `update`, `delete`, `submit`, `review`, `validate`, `arbitrate` ; SAL, CC, CT, RA et ADM conservent leurs droits ; GAF conserve la consultation nécessaire à la paie | global DIR / own / own_team / company | Demandes, avis opérationnels, validation courante et arbitrage des exceptions ; historisation des décisions | Arbitrage A.4.2 Groupe 2 ; 10299, 10303 | Décision DIR confirmée ; actions à normaliser |
| `justificatifs_medicaux` | DIR : accès aux seules informations administratives et d’indisponibilité légalement accessibles et nécessaires ; aucun accès général aux documents médicaux détaillés ; ADM conserve le traitement administratif ; GAF se limite aux informations nécessaires à la paie et à la administration de la paie | restricted | Secret médical ; séparation des justificatifs administratifs et des données de santé détaillées | 10303 ; limite impérative maintenue | Exception explicite à l’accès complet ; documents médicaux détaillés hors accès général |
| `heures_supplementaires` | Accès complet DIR : toutes actions applicables, notamment `view`, `create`, `update`, `delete`, `authorize`, `submit`, `validate`, `validate_excess`, `control`, `process` ; SAL, CT, RA, ADM et GAF conservent leurs droits selon leurs responsabilités | global DIR / own / own_team / assigned_workers / company | Distinguer heures autorisées, déclarées, réellement travaillées et validées ; un dépassement refusé reste enregistré comme temps réellement travaillé | Arbitrage A.4.2 Groupe 2 ; 10299, 10303 | Décision DIR confirmée ; actions à normaliser ; responsabilités opérationnelles et traçabilité conservées |

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
| `fournisseurs`, `sous_traitants` | Accès complet DIR : toutes actions applicables ; ADM, CT, CC, RA et GAF conservent leurs droits | global DIR / global | Référentiels fournisseurs et sous-traitants | Arbitrage A.4.2 Groupe 2 ; 10298, 10300 | Décision DIR confirmée ; actions à normaliser |
| `demandes_achat` | Accès complet DIR : toutes actions applicables ; ADM, CT et RA conservent leurs droits | global DIR / assigned_projects | Demandes d’achat | Arbitrage A.4.2 Groupe 2 ; 10298 | Décision DIR confirmée ; actions à normaliser |
| `besoins` | Accès complet DIR : toutes actions applicables ; CC, CT et RA conservent leurs droits | global DIR / assigned_projects | Signalement et suivi des besoins d’approvisionnement | Arbitrage A.4.2 Groupe 2 ; 10303 | Décision DIR confirmée ; actions à normaliser |
| `offres_fournisseurs` | Accès complet DIR : toutes actions applicables ; ADM et RA conservent leurs droits | global DIR / global | Offres fournisseurs | Arbitrage A.4.2 Groupe 2 ; 10298 | Décision DIR confirmée ; actions à normaliser |
| `commandes_achats`, `lignes_commande` | Accès complet DIR aux actions applicables, dont consultation, préparation, modification, soumission et approbation ; GAF : consultation, préparation, modification et soumission selon le workflow ; ADM, CT, RA et SA conservent leurs droits respectifs, sans approbation GAF | global DIR / global / assigned_projects | Commandes d’achat et engagements ; GAF assure le traitement administratif sans pouvoir d'approbation d'engagement | Arbitrage A.4.2 Groupe 2 ; 10298, 10301, 10303 | Approbation DIR uniquement lorsque le seuil cumulé de 100 000 € HT par opération est dépassé, selon §5.6 ; actions à normaliser |
| `commandes_sous_traitance` | Accès complet DIR aux actions applicables, dont consultation, préparation, modification, soumission et approbation ; GAF : consultation, préparation, modification et soumission selon le workflow ; ADM, CT, RA et SA conservent leurs droits respectifs, sans approbation GAF | global DIR / global / assigned_projects | Commandes de sous-traitance et engagements ; GAF assure le traitement administratif sans pouvoir d'approbation d'engagement | Arbitrage A.4.2 Groupe 2 ; 10298, 10301, 10303 | Approbation DIR uniquement lorsque le seuil cumulé de 100 000 € HT par opération est dépassé, selon §5.6 ; actions à normaliser |
| `evaluations_fournisseurs` | Accès complet DIR : toutes actions applicables ; ADM et RA conservent leurs droits | global DIR / global | Évaluation des fournisseurs | Arbitrage A.4.2 Groupe 2 ; 10298 | Décision DIR confirmée ; actions à normaliser |
| `accords_cadres`, `garanties_fournisseurs` | Accès complet DIR : toutes actions applicables, y compris approbation si l’action existe ; ADM et RA conservent leurs droits | global DIR / global | Accords-cadres et garanties fournisseurs | Arbitrage A.4.2 Groupe 2 ; 10298 | Décision DIR confirmée ; actions à normaliser |
| `factures_fournisseurs` | Accès complet DIR : toutes actions applicables, dont consultation, création, modification et rapprochement ; GAF et ADM conservent leurs droits administratifs | global DIR / global | Factures fournisseurs et rapprochement administratif avec les commandes ; aucun droit de préparation, d'autorisation ou d'exécution de paiement bancaire | Arbitrage A.4.2 Groupe 2 ; 10300 | Décision DIR confirmée ; actions à normaliser ; aucun workflow de paiement bancaire attribué |
| `incidents_sous_traitance` | Accès complet DIR : toutes actions applicables ; CC, CT et RA conservent leurs droits | global DIR / assigned_projects | Incidents de sous-traitance | Arbitrage A.4.2 Groupe 2 ; 10303 | Décision DIR confirmée ; actions à normaliser |

### 5.11 Inventory

| Ressource | Actions / rôles | Scope | Justification | Source | Statut fonctionnel / technique |
| --- | --- | --- | --- | --- | --- |
| `articles`, `entrepots`, `emplacements`, `lots_stock` | Accès complet DIR : toutes actions applicables ; RA, CT, CC et GAF conservent leurs droits | global DIR / workshop / assigned_sites | Référentiels et suivi des stocks | Arbitrage A.4.2 Groupe 2 ; 10298, 10300 | Décision DIR confirmée ; actions à normaliser |
| `mouvements_stock` | Accès complet DIR : toutes actions applicables, y compris création, modification, annulation/inversion et validation si applicable ; RA, CT, CC et GAF conservent leurs droits | global DIR / assigned_sites / workshop | Mouvements de stock et traçabilité | Arbitrage A.4.2 Groupe 2 ; 10298, 10300 | Décision DIR confirmée ; actions à normaliser ; conserver l’historique des mouvements |
| `receptions_stock`, `reservations_stock` | Accès complet DIR : toutes actions applicables ; RA, CT et CC conservent leurs droits | global DIR / workshop / assigned_sites | Réceptions et réservations | Arbitrage A.4.2 Groupe 2 ; 10298 | Décision DIR confirmée ; actions à normaliser |
| `consommations` | Accès complet DIR : toutes actions applicables, y compris création, modification, annulation/inversion et validation si applicable ; CC, RA, CT et GAF conservent leurs droits | global DIR / assigned_sites / workshop | Consommations de matières | Arbitrage A.4.2 Groupe 2 ; 10298, 10300 | Décision DIR confirmée ; code normalisé `inventory.consommations` ; actions à normaliser |
| `bons_sortie` | Accès complet DIR : toutes actions applicables ; RA et CC conservent leurs droits | global DIR / workshop | Bons de sortie | Arbitrage A.4.2 Groupe 2 ; 10298 | Décision DIR confirmée ; actions à normaliser |
| `inventaires_physiques` | Accès complet DIR : toutes actions applicables ; RA et GAF conservent leurs droits | global DIR / workshop | Inventaires physiques | Arbitrage A.4.2 Groupe 2 ; 10298, 10300 | Décision DIR confirmée ; actions à normaliser |
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
| `demandes_transport`, `plans_transport`, `tournees` | Accès complet DIR : toutes les actions applicables ; RA et CT conservent leurs droits | global DIR / workshop / assigned_sites | Demandes de transport, plans et tournées | 10298, arbitrage A.4.2 Groupe 2 | Décision DIR confirmée ; actions à normaliser ; historique des plans et tournées à conserver |
| `livraisons`, `receptions_chantier` | Accès complet DIR : toutes les actions applicables ; RA, CT et CC conservent leurs droits | global DIR / assigned_sites / workshop | Livraisons et réceptions chantier | 10298, arbitrage A.4.2 Groupe 2 | Décision DIR confirmée ; actions à normaliser ; conserver preuves et réserves de réception |
| `retours` | Accès complet DIR : toutes les actions applicables ; RA conserve ses droits | global DIR / workshop | Retours logistiques | 10298, arbitrage A.4.2 Groupe 2 | Décision DIR confirmée ; actions à normaliser ; historique des retours à conserver |
| `acces_chantier` | `view`, `create`, `update`, `delete` et actions spécifiques : DIR ; `view` : CT, CC ; `update` : CT à confirmer | global DIR / assigned_sites | Gestion des accès chantier | 10298, arbitrage A.4.2 Groupe 2 | Accès complet DIR confirmé ; actions CT à arbitrer séparément ; traçabilité des autorisations d’accès obligatoire |

### 5.14 Quality

| Ressource | Actions / rôles | Scope | Justification | Source | Statut fonctionnel / technique |
| --- | --- | --- | --- | --- | --- |
| `plans_qualite`, `plans_controle` | Accès complet DIR : toutes les actions applicables ; CT, RA et CC conservent leurs droits | global DIR / assigned_projects / workshop | Plans qualité et plans de contrôle | 10298, arbitrage A.4.2 Groupe 2 | Décision DIR confirmée ; actions à normaliser ; historique des versions à conserver |
| `controles_qualite` | Accès complet DIR : toutes les actions applicables ; CT, CC et RA conservent leurs droits | global DIR / assigned_projects / workshop | Contrôles qualité | 10298, arbitrage A.4.2 Groupe 2 | Décision DIR confirmée ; actions à normaliser ; résultats et validations tracés |
| `non_conformites` | Accès complet DIR : toutes les actions applicables ; CT, CC et RA conservent leurs droits | global DIR / assigned_projects / workshop | Non-conformités | 10298, arbitrage A.4.2 Groupe 2 | Décision DIR confirmée ; actions à normaliser ; historique de traitement et clôture à conserver |
| `actions_correctives`, `audits_qualite`, `certificats_qualite`, `qualifications_techniques` | Accès complet DIR : toutes les actions applicables ; RA et CT conservent leurs droits | global DIR / workshop | Actions correctives, audits, certificats et qualifications techniques | 10298, arbitrage A.4.2 Groupe 2 | Décision DIR confirmée ; actions à normaliser ; conserver les preuves et historiques d’audit/certification |
| `signalements` | Accès complet DIR : toutes les actions applicables ; `create` : SAL, qui conserve ses droits | global DIR / own | Signalements qualité, distincts des non-conformités | 10299, 10303, arbitrage A.4.2 Groupe 2 | Accès complet DIR confirmé ; rôle de traitement des autres rôles à arbitrer ; conserver l’auteur et l’historique du signalement |

### 5.15 Safety

| Ressource | Actions / rôles | Scope | Justification | Source | Statut fonctionnel / technique |
| --- | --- | --- | --- | --- | --- |
| `analyses_risques`, `plans_prevention` | Accès complet DIR : toutes les actions applicables ; RA, CT et CC conservent leurs droits | global DIR / workshop / assigned_projects | Analyses de risques et plans de prévention | 10298, arbitrage A.4.2 Groupe 2 | Décision DIR confirmée ; actions à normaliser ; versions et preuves à conserver |
| `inspections_securite`, `incidents` | Accès complet DIR : toutes les actions applicables ; CC, RA et CT conservent leurs droits | global DIR / assigned_projects / workshop | Inspections de sécurité et incidents | 10298, arbitrage A.4.2 Groupe 2 | Décision DIR confirmée ; actions à normaliser ; constats, suites et clôtures tracés |
| `actions_securite` | Accès complet DIR : toutes les actions applicables ; RA et CT conservent leurs droits | global DIR / workshop | Actions de sécurité | 10298, arbitrage A.4.2 Groupe 2 | Décision DIR confirmée ; actions à normaliser ; suivi et clôture tracés |
| `habilitations`, `autorisations_travail`, `inductions` | Accès complet DIR : toutes les actions applicables ; RA, ADM, CT et CC conservent leurs droits | global DIR / workshop / company | Habilitations, autorisations de travail et accueils sécurité | 10298, arbitrage A.4.2 Groupe 2 | Décision DIR confirmée ; actions à normaliser ; validités et justificatifs conservés |
| `signalements` | Accès complet DIR : toutes les actions applicables ; `create` : SAL, qui conserve ses droits | global DIR / own | Signalements sécurité, distincts des incidents | 10299, 10303, arbitrage A.4.2 Groupe 2 | Accès complet DIR confirmé ; rôle de traitement des autres rôles à arbitrer ; auteur et historique conservés |

### 5.16 Documents

| Ressource | Actions / rôles | Scope | Justification | Source | Statut fonctionnel / technique |
| --- | --- | --- | --- | --- | --- |
| `documents`, `versions`, `dossiers_documentaires` | Accès complet DIR : toutes les actions applicables ; ADM, CT, CC, RA, GAF et SAL conservent leurs droits | global DIR / company / assigned_projects / own | Documents, versions et dossiers documentaires, y compris les dossiers administratifs clients et leurs pièces associées ; création, modification, validation, téléchargement, archivage et autres actions applicables | 10298, 10299, arbitrage A.4.2 Groupe 2 et décision du 24/11/2026 | Accès complet DIR confirmé pour les dossiers administratifs clients ; droits soumis aux restrictions légales et catégories sensibles à qualifier (M-17) ; versions et traces conservées |
| `types_document`, `regles_conservation` | Accès complet DIR : toutes les actions applicables ; ADM conserve ses droits | global DIR / global | Types documentaires et règles de conservation | 10298, arbitrage A.4.2 Groupe 2 | Décision DIR confirmée ; ne pas autoriser une suppression contraire aux obligations de conservation |
| `diffusions` | Accès complet DIR : toutes les actions applicables ; ADM, CT, CC, RA et SAL conservent leurs droits | global DIR / assigned_projects / own | Diffusion documentaire et accusés de réception | 10298, 10299, arbitrage A.4.2 Groupe 2 | Décision DIR confirmée ; conserver destinataires, dates, versions diffusées et accusés de réception |
| `download`, `sign` | Accès complet DIR : téléchargement et signature sur les documents auxquels DIR est légalement habilité à accéder ; SAL conserve `download`, `sign` own | global DIR sous réserve des catégories sensibles / own / policy_defined | Téléchargement et signature documentaire | 10299, arbitrage A.4.2 Groupe 2 | Décision DIR confirmée ; signature soumise aux règles de délégation, d'identité et de preuve ; M-17 reste ouvert pour les catégories/champs sensibles |
| `exports` | Accès complet DIR : toutes les actions applicables, dont `export` ; ADM et GAF conservent leurs droits | global DIR / global | Exports documentaires | 10300, arbitrage A.4.2 Groupe 2 | Export DIR confirmé ; appliquer les mêmes restrictions de confidentialité et de périmètre que la consultation |

### 5.17 Handover

| Ressource | Actions / rôles | Scope | Justification | Source | Statut fonctionnel / technique |
| --- | --- | --- | --- | --- | --- |
| `dossiers_reception` | Accès complet DIR : toutes les actions applicables, y compris `approve`, `validate` et `close` ; CT et CC conservent leurs droits | global DIR / assigned_projects CT, CC | Dossiers de réception et approbation finale | 10298, arbitrages A.4.2 Groupes 1 et 2 | Accès complet DIR confirmé ; conserver les preuves de réception, décisions, réserves et historique de clôture |
| `reserves`, `levees_reserves`, `doe` | Accès complet DIR : toutes les actions applicables, y compris création, modification, validation et clôture ; CT et CC conservent leurs droits | global DIR / assigned_projects CT, CC | Réserves, levées de réserves et DOE | 10298, arbitrage A.4.2 Groupe 2 | Accès complet DIR confirmé ; conserver les preuves, dates, responsables et historique des levées et versions DOE |
| `garanties_clients` | Accès complet DIR : toutes les actions applicables ; CT et ADM conservent leurs droits | global DIR / company / assigned_projects | Garanties clients | 10298, arbitrage A.4.2 Groupe 2 | Accès complet DIR confirmé ; conserver échéances, déclarations, décisions et historiques de garantie |
| `dossiers_cloture` | Accès complet DIR : toutes les actions applicables, y compris `close` ; CT et ADM conservent leurs droits | global DIR / assigned_projects / company | Dossiers de clôture de chantier | 10298, arbitrage A.4.2 Groupe 2 | Accès complet DIR confirmé ; clôture et pièces justificatives historisées |

### 5.18 Reporting

| Ressource | Actions / rôles | Scope | Justification | Source | Statut fonctionnel / technique |
| --- | --- | --- | --- | --- | --- |
| `rapports`, `indicateurs` | Accès complet DIR : toutes les actions applicables, y compris consultation, création, modification, validation, suppression et export lorsque disponible ; droits existants des autres rôles conservés | global DIR / company / assigned_projects | Rapports et indicateurs | 10298, 10300, arbitrage A.4.2 Groupe 2 | Accès complet DIR confirmé ; préserver sources, définitions, périodes et historiques |
| `tableaux_bord` | Accès complet DIR : toutes les actions applicables ; droits existants des autres rôles conservés | global DIR / company | Tableaux de bord | 10298, 10300, arbitrage A.4.2 Groupe 2 | Accès complet DIR confirmé |
| `tableaux_bord_strategiques` | Accès complet DIR : toutes les actions applicables | global DIR | Tableaux de bord stratégiques | 10300, arbitrage A.4.2 Groupe 2 | Accès complet DIR confirmé |
| `snapshots` | Accès complet DIR : toutes les actions applicables, y compris création, consultation, modification, suppression et export lorsque disponible | global DIR | Snapshots | 10301, arbitrage A.4.2 Groupe 2 | Accès complet DIR confirmé ; préserver horodatage, périmètre, source et intégrité des instantanés |
| `exports` | Accès complet DIR : toutes les actions applicables, y compris préparation, génération, consultation, téléchargement et export | global DIR | Exports de reporting | 10300, arbitrage A.4.2 Groupe 2 | Accès complet DIR confirmé ; M-05 levé pour les exports du domaine Reporting, sous réserve des restrictions légales et de confidentialité |

## 6. Matrice rôles × permissions

Cette matrice synthétise les droits des huit rôles. Pour DIR, la règle générale validée est l'attribution de toutes les permissions fonctionnelles du catalogue, présentes et futures, avec scope global société. Les cellules DIR détaillent les exceptions et workflows particuliers ; elles ne constituent pas une liste limitative. Les seules exclusions sont l'administration des habilitations techniques, les documents médicaux couverts par le secret médical, les auto-approbations interdites et les restrictions légales/ de conservation, confidentialité et audit.

| Domaine | SA | DIR | ADM | CT | CC | RA | SAL | GAF |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Identity | administration complète des habilitations, panel | panel, sans administration des habilitations | panel | panel | panel | panel | portail personnel, panel non | panel |
| Clients | droits métier globaux | accès complet global aux prospects, clients, contacts, relations commerciales, devis, conditions commerciales, factures, avoirs, relances, échéanciers, litiges et règlements, selon les actions applicables du §5 ; régularisation financière des litiges par workflow distinct ; aucune préparation/exécution de paiement | prospects, clients, contacts, devis | lecture | — | — | — | factures, avoirs, relances |
| Projects | droits métier globaux | view global affaires, chantiers, études, jalons et rapports opérationnels ; view/approve commandes clients et contrats ; view/approve avenants ; approve réceptions contractuelles ; accès complet aux lignes budgétaires ; lots/phases : accès global DIR ; accès opérationnel CT/CC selon `assigned_sites` (actions atomiques à définir) |
| Planning | droits métier globaux | view global plannings contractuels/opérationnels, affectations, conflits et avancement (consultation globale) ; arbitrate conflits | — | planning, affectations | lecture | planning atelier | planning personnel | — |
| Budgets | droits métier globaux | view budgets ; approve tous budgets, révisions et contingences sans seuil ; accès complet aux lignes budgétaires selon §5 | lecture | budgets, révisions, contingences | — | — | — | workflows à préciser |
| Costing | droits métier globaux | view/create/update/validate chiffrages, coûts et écarts ; view marges/provisions ; approve provisions ; approve engagements uniquement au-delà de 100 000 € HT cumulés par opération ; view/lock/unlock/close périodes analytiques | — | coûts, marges, écarts | — | coûts atelier | — | consultation et suivi opérationnel selon §5 |
| Workforce | données RH métier hors exception médicale | accès complet global à toutes les ressources RH et actions applicables, y compris create/update/validate/delete ; secret médical, conservation légale et séparation des tâches maintenus | RH administrative, variables paie selon §5 | RH opérationnelle limitée | équipe | collaborateurs | dossier et bulletins propres | paie, bulletins et données nécessaires aux virements |
| TimeTracking | droits métier globaux | accès complet global à toutes les ressources et actions applicables, y compris create/update/delete/validate/authorize/close/reopen ; hors documents médicaux détaillés | absences courantes | pointages chantier affectés, corrections/réouvertures | pointages équipe | pointages équipe atelier | pointages et absences propres | lecture des temps validés pour paie |
| Workshop | droits métier globaux | accès complet global à toutes les ressources et actions applicables (view/create/update/delete/validate et actions spécifiques) | — | lecture | OF, comptes rendus | OF, production | OF personnels | — |
| Procurement | droits métier globaux | accès complet global aux ressources et actions applicables ; approbation des engagements DIR selon seuil cumulé > 100 000 € HT par opération | fournisseurs, demandes, préparation | demandes | besoins, sous-traitants | demandes, fournisseurs | — | traitement administratif des commandes et factures fournisseurs, sans approbation d'engagement ni paiement bancaire |
| Inventory | droits métier globaux | accès complet global aux ressources et actions applicables, sous réserve de la traçabilité des mouvements et ajustements | — | mouvements | stocks, consommations | stocks, mouvements | — | lecture |
| Equipment | droits métier globaux | accès complet global à toutes les ressources et actions applicables (view/create/update/delete/assign/validate et actions spécifiques), avec traçabilité réglementaire et technique | — | équipements | équipements, pannes | équipements, maintenance | équipement personnel | — |
| Logistics | droits métier globaux | accès complet global à toutes les ressources et actions applicables, avec traçabilité des transports, livraisons, réceptions, retours et accès chantier | — | livraisons | — | expédition | — | — |
| Quality | droits métier globaux | accès complet global à toutes les ressources et actions applicables, y compris validation, traitement et clôture, avec conservation des preuves et historiques qualité | — | contrôles | contrôles, NCR | contrôles, NCR, clôture | signalements | — |
| Safety | droits métier globaux | accès complet global à toutes les ressources et actions applicables, y compris validation, traitement et clôture, avec conservation des preuves, justificatifs et historiques sécurité | — | inspections | inspections, incidents | atelier | signalements | — |
| Documents | droits métier globaux | accès complet global à toutes les ressources et actions applicables : consultation, création, modification, suppression, téléchargement, signature, diffusion et export, sous réserve des restrictions légales, de confidentialité et de conservation | documents admin | documents chantier | documents, diffusion | documents atelier | documents personnels | lecture |
| Handover | droits métier globaux | accès complet global à toutes les ressources et actions applicables, y compris consultation, création, modification, validation, approbation et clôture des réceptions, réserves, levées de réserves, DOE, garanties et dossiers de clôture | — | réceptions | réserves | DOE et clôtures | — | — |
| Reporting | droits métier globaux | accès complet global DIR à toutes les ressources et actions applicables : rapports, indicateurs, tableaux de bord, tableaux de bord stratégiques, snapshots et exports | rapports | rapports | rapports quotidiens | reporting production | snapshots | exports |

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
| GAF | Pas d’approbation d’engagement ; pas de pouvoir d'approbation ou d'engagement sur les commandes ; pas de validation finale de paie ; aucun droit de préparation, d'autorisation ou d'exécution de paiement bancaire ; aucune fonction comptable ; pas de tableaux de bord stratégiques ; pas de validation de ses propres frais ; pas d’accès général aux dossiers disciplinaires ou justificatifs personnels sans lien avec la paie |

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
| `operational_admin_finance` | Gestion administrative et financière opérationnelle, hors comptabilité | GAF |
| `restricted` | Accès restreint ou besoin d’en connaître (RH sensible, médical, banque) | dossiers RH, justificatifs médicaux, coordonnées bancaires |
| `policy_defined` | Périmètre effectif déterminé par les Policies métier définies dans CHAN-42 | documents, clients, absences, etc. |

Les cellules composites (`assigned_projects / own_team`, `company / own`, etc.) listent les scopes applicables ; le scope `policy_defined` est déterminé par les Policies métier de CHAN-42. `assigned_projects` est réservé aux affaires et projets affectés au niveau contractuel/commercial ; `assigned_sites` aux sites ou chantiers affectés au niveau opérationnel ; `assigned_workers` aux salariés affectés à un chantier ou à un périmètre opérationnel. Une affaire n’implique pas automatiquement l’accès à tous ses chantiers, et un chantier n’implique pas l’accès aux données commerciales ou comptables de l’affaire. `lots_phases` est rattaché exclusivement au chantier : un lot appartient à un seul chantier et une phase appartient à un seul lot. Le scope opérationnel est donc `assigned_sites` (notamment CT/CC), tandis que DIR conserve son scope global. La phase hérite du chantier via son lot ; aucun rattachement direct phase-chantier indépendant n’existe. `transversal` est représenté dans la matrice §6 et ne remplace pas les scopes de ressource du §5. Aucun mécanisme de Policy n’est implémenté par ce lot.

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
| Paiements bancaires | Hors périmètre actuel ; aucun droit de préparation, autorisation ou exécution | — | À arbitrer uniquement si cette fonction est demandée |
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
| M-04 | Données RH sensibles | Accès DIR/SA, GAF et ADM différencié ; ADM limité aux données RH courantes ; restrictions médicales établies | Décliner chaque famille de données en ressources et permissions techniques précises | Catalogue Workforce | Architecture / métier |
| M-05 | Exports sensibles | Aucun export global implicite ; droits par ressource et rôle | Établir la liste des exports, champs et rôles autorisés | Permissions `export` | Direction |
| M-06 | Suppression et archivage | SA peut supprimer lorsque l’opération est prévue ; archivage à privilégier lorsque pertinent | Définir ressource par ressource les opérations réellement supprimables pour les autres rôles | Actions atomiques | Métier |
| M-07 | Besoins Chef de chantier | Signalement de besoin prévu | Confirmer le nom canonique et le rattachement de la ressource | Catalogue Procurement | Métier / architecture |
| M-08 | Incidents sous-traitance | Création/signalement par CC ; suivi opérationnel | Préciser les actions de mise à jour, traitement et clôture | Catalogue Procurement | Métier |
| M-09 | Signalements Salarié | Signalements qualité et sécurité prévus | Déterminer les ressources et circuits de traitement, et désigner le rôle responsable du traitement qualité et le rôle responsable du traitement sécurité | Catalogue Quality/Safety | Métier |
| M-10 | Annuaire et messagerie | Fonctions personnelles mentionnées pour SAL | Confirmer si elles appartiennent à Identity ou à un contexte dédié | Architecture | Architecture |
| M-11 | Accès stratégique Reporting | Tableaux de bord stratégiques réservés à DIR | Confirmer les ressources/snapshots exacts et leurs données sources | Catalogue Reporting | Direction |
| M-12 | Barèmes grands déplacements | Barèmes datés/historisés ; DIR et SA supervisent et administrent les règles | Préciser si ADM reçoit une délégation de paramétrage et les droits de publication/activation | Catalogue Workforce | Direction |
| M-13 | Absences maladie/accident/exceptionnelles | Circuits fonctionnels distincts définis | Déterminer si les différences exigent des ressources distinctes ou seulement des champs/statuts | Modèle et permissions | Métier / architecture |
| M-14 | Périmètre des justificatifs médicaux consultables par ADM | ADM traite administrativement les justificatifs ; DIR/SA/GAF n’ont pas d’accès automatique ; les responsables ne voient que l’indisponibilité | Définir les documents et champs exacts visibles par ADM et les règles de séparation | Modèle d’accès et permissions médicales | Direction / juridique / RH |
| M-15 | Validation des dépassements d’heures supplémentaires | `validate_excess` est prévu mais le rôle compétent n’est pas défini | Désigner le rôle habilité et les règles de validation complémentaire | Permission et workflow | Direction / métier |
| M-16 | Sémantique de `suspend` et `delete` des délégations financières | Seuls DIR et SA administrent les délégations ; l’effet exact de `suspend` et `delete` n’est pas défini | Préciser suspension temporaire, révocation et conservation de l’historique | Permissions et audit | Direction |
| M-17 | Documents hors Salarié | SAL dispose de `download` et `sign` sur ses documents ; les autres attributions ne sont pas définies | Identifier les rôles autorisés à télécharger ou signer d’autres documents | Permissions documentaires | Direction / métier |
| | A-01 | Namespace comptable | Aucun namespace comptable dans le logiciel | Le domaine comptable est exclu du périmètre applicatif ; ne créer aucune ressource ni permission comptable. | Périmètre produit | Décision confirmée le 24/11/2026 ||
| | A-02 | Frontière facturation / comptabilité | Les pièces opérationnelles restent dans leurs domaines métier ; aucune écriture comptable n'est gérée dans le logiciel | Ne pas ajouter de module ni de permissions comptables. | Périmètre produit | Décision confirmée le 24/11/2026 ||
| A-03 | Slug TimeTracking | `timetracking` est le slug canonique | Conserver `timetracking` en un seul mot dans les domaines, ressources et permissions. `time_tracking` est un alias interdit dans le catalogue canonique ; toute occurrence existante devra être migrée avant gel. | Codes | Normalisé ; occurrence dans le dépôt à vérifier avant implémentation |
| A-04 | Singulier/pluriel et libellés de ressources | Les slugs de collections sont au pluriel ; les ressources singleton sont au singulier | Utiliser des slugs techniques anglais cohérents et stables, sans accents ni libellés français dans les identifiants. Les noms français restent dans les libellés/documentation. Une ressource métier ne reçoit qu'un seul slug canonique ; les synonymes sont documentés comme libellés, jamais comme permissions alternatives. | Codes | Convention normalisée ; mapping complet au catalogue technique |
| A-05 | Ressource Budget | `budgets` est le slug canonique de la collection et de la ressource métier Budgets | Ne pas créer un slug `budget` concurrent. Les éléments unitaires (lignes, révisions, contingences) conservent leurs propres ressources explicites : `lignes_budgetaires`, `revisions_budgetaires`, `contingences`. | Codes | Normalisé ; vérifier les références du dépôt avant implémentation |
| A-06 | Factures clients | `factures_clients` est le slug canonique de la ressource facture client dans le domaine Clients | Écarter `factures` comme alias de permission. Les factures clients restent gérées exclusivement dans Clients ; aucune ressource ni écriture comptable n'est créée. Les noms de permissions canoniques suivent `clients.factures_clients.action` selon la convention domaine.ressource.action. | Codes | Normalisé ; propriété métier Clients confirmée |
| A-07 | Registre d’actions | Registre atomique canonique étendu et stabilisé | Actions canoniques : `view`, `create`, `update`, `delete`, `submit`, `validate`, `approve`, `issue`, `prepare`, `execute`, `export`, `reverse`, `reconcile`, `lock`, `unlock`, `reopen`, `close`, `download`, `acknowledge`, `sign`, `assign`, `access`, `deactivate`, `archive`, `revoke`, `send`, `adjust`, `arbitrate`, `review`, `control`, `declare`, `process`, `request_update`, `supervise`, `validate_excess`, `suspend`, `authorize`, `merge`, `convert`, `qualify`, `track`. Actions distinctes : `approve` = décision d'approbation ; `arbitrate` = décision d'arbitrage ; `authorize` = autorisation explicite d'une opération ; `issue` = émission/édition officielle ; `send` = transmission ; `archive` = archivage réversible ou logique ; `delete` = suppression réellement permise ; `deactivate` = désactivation ; `revoke` = retrait/révocation ; `suspend` = suspension temporaire ; `review` = revue ; `control` = contrôle ; `process` = traitement ; `supervise` = supervision ; `adjust` = ajustement ; `reverse` = contrepassation/annulation compensatrice ; `reopen` = réouverture ; `validate_excess` = validation d'un dépassement. N'utiliser une action que si le workflow et la ressource la justifient. | Registre commun | Actions normalisées ; chaque usage doit être relié à une ressource et un workflow ; aucun alias implicite |
| A-08 | Source de vérité du catalogue | Source de vérité technique : `app/Domains/Identity/Catalog/` ; `PermissionCatalog` et `RoleCatalog` constituent les définitions canoniques | Les seeders consomment ces catalogues ; la matrice Markdown documente les décisions et doit rester synchronisée. Les permissions sont construites sous forme `domaine.ressource.action`. | Architecture Identity | Décision d'architecture retenue ; à implémenter dans CHAN-40 |
| A-09 | Versionnement | Slugs de permissions immuables ; version du catalogue distincte des identifiants | Ne jamais inclure un numéro de version dans un slug de permission. Toute modification de sens ou renommage passe par une migration explicite avec période de compatibilité si nécessaire, mise à jour des attributions et tests ; les permissions obsolètes sont dépréciées puis retirées de façon contrôlée. Porter une constante `CATALOG_VERSION` dans le catalogue et incrémenter selon les changements structurels/compatibilité. | Maintenance | Décision d'architecture retenue ; stratégie à implémenter et tester |
| A-10 | Seeders | Seeders idempotents requis par CHAN-40 | Définir stratégie d’upsert, suppression contrôlée et synchronisation | Implémentation | Développement |
| A-11 | Accès panel Filament | Permission dédiée `identity.admin_panel.access` exigée ; SAL exclu du panel | Définir l’emplacement exact du contrôle dans `canAccessPanel()` et ses tests | Implémentation | Développement |
| A-12 | Affectations utilisateurs | Aucune affectation automatique | Définir le processus initial d’attribution manuelle et son responsable | Exploitation | Direction / développement |
| A-13 | Cache Spatie | Cache standard constaté | Documenter l’invalidation après synchronisation et opérations SQL directes | Exploitation | Développement |
| A-14 | Intégration comptable externe | Périmètre non défini dans les commentaires disponibles | Déterminer l’interface et la frontière avec un logiciel/prestataire comptable | Architecture | Direction / architecture |
| A-15 | Périmètre CHAN-45 et audit | CHAN-45 est mentionné dans la documentation du dépôt comme journalisation de sécurité ; le périmètre exact sur l’audit métier immuable n’est pas vérifié | Confirmer si CHAN-45 porte l’audit métier ou prévoir un lot dédié | Périmètre du stockage d’audit | Architecture / sécurité |
| A-16 | Règle générale d'accès intégral DIR et normalisation | La Direction a confirmé le 24/11/2026 que DIR doit disposer de toutes les permissions fonctionnelles, présentes et futures, sur tous les modules et ressources métier, avec scope global société. Il n'est plus nécessaire de faire arbitrer les actions DIR une par une. | Appliquer automatiquement à DIR chaque permission atomique du catalogue, sans wildcard ni permission générique ; conserver uniquement les exceptions explicitement définies (administration des habilitations, secret médical, séparation des tâches, auto-approbation interdite, obligations légales de conservation/confidentialité/audit). | Les droits métier DIR ne sont plus à arbitrer ressource par ressource. A-16 est clos sur le plan fonctionnel. Les conventions A-01 à A-09 sont normalisées ; restent la construction du catalogue canonique, la synchronisation des associations et les vérifications de cohérence avant gel. Aucun workflow de paiement bancaire n'est inclus dans le périmètre. | Construire `PermissionCatalog` et `RoleCatalog`, associer automatiquement toutes les permissions fonctionnelles à DIR, intégrer les exceptions et tester les séparations CHAN-46. | Architecture / développement |
| A-17 | Rattachement des lots et phases | Décision métier validée le 24/11/2026 : Affaire 1—N Chantier ; Chantier 1—N Lot ; Lot 1—N Phase. Chaque lot appartient à un seul chantier ; chaque phase appartient obligatoirement à un seul lot et hérite du chantier via ce lot. | Appliquer `assigned_sites` aux accès opérationnels CT/CC sur lots et phases ; DIR conserve le scope global. Ne pas créer de rattachement direct phase-chantier indépendant. Les actions atomiques et les attributions des autres rôles restent à définir à partir des workflows réels. | Décision utilisateur du 24/11/2026 ; §5.3, §8 et arbitrage A.4.1 | Métier validé ; permissions détaillées à définir |


### A.4.2 — Décision générale complémentaire DIR (24/11/2026)

**Arbitrage métier définitif.** La Direction a confirmé que le rôle DIR dispose de toutes les permissions fonctionnelles du logiciel, sur tous les domaines et toutes les ressources métier, avec un scope global société. Toutes les actions atomiques existantes et futures sont accordées à DIR par défaut. Il n'est plus demandé de valider chaque ressource ou action individuellement.

Cette règle s'applique aux actions de consultation, création, modification, suppression lorsqu'elle existe, affectation, fusion, conversion, qualification, suivi, soumission, émission, validation, approbation, arbitrage, export, téléchargement, signature, clôture, verrouillage, déverrouillage et à toute action métier spécifique effectivement présente dans le catalogue. Toute nouvelle permission fonctionnelle ajoutée au catalogue doit être associée à DIR sans nouvel arbitrage individuel.

**Exceptions impératives et garde-fous conservés :**

- DIR n'administre pas les utilisateurs, rôles, permissions, affectations de rôles ni paramètres d'habilitation.
- Les documents médicaux détaillés relevant du secret médical et détenus par les professionnels de santé restent exclus.
- Aucun workflow de préparation, d'autorisation ou d'exécution de paiement bancaire n'est inclus dans le périmètre actuel.
- Toute séparation des tâches obligatoire, interdiction d'auto-approbation, obligation légale de conservation, confidentialité, intégrité des preuves et protection des journaux d'audit demeure applicable.
- Le seuil d'approbation de 100 000 € HT cumulés par opération et les workflows financiers existants sont maintenus.
- Les Policies CHAN-42 continuent d'appliquer les restrictions légales et de sécurité ; elles ne doivent pas réduire le scope métier global de DIR sans fondement explicite dans ces exceptions.

**Conséquences sur les points ouverts.** A-16 est clos sur l'arbitrage fonctionnel : seules restent la normalisation des permissions atomiques et la synchronisation des associations rôle/permission. A-07, A-01 et M-17 restent des dépendances de nomenclature, architecture ou conformité ; A-17 est clos sur le rattachement métier. Pour les lots/phases, DIR conserve l'accès global et les accès opérationnels CT/CC suivent `assigned_sites` via le chantier parent ; les actions atomiques et les attributions des autres rôles restent à définir.

**Effet sur les décisions précédentes.** Cet arbitrage remplace toute formulation antérieure indiquant que DIR ne dispose que des actions explicitement listées ligne par ligne, qu'un CRUDV doit être validé ressource par ressource ou qu'une action supplémentaire doit être confirmée individuellement. Les exceptions expressément conservées ci-dessus prévalent.

### Décisions de normalisation A-01 à A-09 — 24/11/2026

Les décisions ci-dessous fixent les conventions techniques nécessaires au gel du catalogue. Elles ne changent pas les attributions métier des rôles, à l'exception de l'application systématique de la règle globale DIR déjà arbitrée.

1. **Domaines.** Les pièces de facturation client restent propriétaires de Clients ; aucun domaine ni traitement comptable n'est inclus dans le périmètre.
2. **Facturation client.** `factures_clients` est le slug canonique dans Clients ; `factures` n'est pas un alias de permission.
3. **TimeTracking.** `timetracking` est le slug canonique ; `time_tracking` est écarté.
4. **Noms de ressources.** Les collections utilisent le pluriel ; les ressources singleton le singulier. Les slugs sont anglais, stables, sans accents ; les libellés français restent des labels.
5. **Budgets.** `budgets` est canonique. Les lignes, révisions et contingences restent des ressources distinctes.
6. **Actions.** Le registre A-07 est adopté comme registre canonique. Chaque action conserve une sémantique distincte ; aucune action n'est ajoutée à une ressource sans justification dans son workflow.
7. **Source de vérité.** Le code canonique sera porté par `app/Domains/Identity/Catalog/PermissionCatalog.php` et `RoleCatalog.php`. Les seeders consomment ces définitions ; cette matrice documente et explique les décisions.
8. **Versionnement.** Les slugs restent immuables et ne contiennent pas de version. Les renommages et changements de sens passent par migration explicite, compatibilité transitoire si nécessaire, mise à jour des attributions et tests. Le catalogue expose une constante `CATALOG_VERSION`.

Ces choix sont désormais les conventions de référence pour le catalogue CHAN-40. Toute divergence découverte dans le dépôt devra être traitée par migration explicite ; elle ne doit pas conduire à maintenir deux slugs concurrents.

## 11.1 Dossier d'arbitrage A.4.1 — couverture transversale de DIR

**Objectif.** Conserver la trace de la revue initiale des droits de Direction (DIR) dans les 19 domaines. Cette revue historique ne crée aucune permission et ne transforme pas la responsabilité transversale de DIR en CRUDV générique. Les décisions A.4.2 des Groupes 1 à 4, consignées après cette revue, complètent ou précisent les lignes ci-dessous et prévalent en cas d'écart. Le tableau doit être lu comme un état consolidé, non comme une liste de décisions encore à obtenir.

**Méthode de lecture.**

- « Explicite » signifie qu'une action DIR est déjà inscrite sur une ressource au §5 ; elle peut être reprise dans §6 après contrôle de cohérence.
- « À examiner » signifie que la responsabilité transversale peut justifier un besoin, mais que la ressource, l'action ou le scope doit être confirmé par la Direction.
- « Restriction » rappelle qu'un workflow ou une limite déjà définie ne peut pas être contourné.
- Aucun droit absent de §5 n'est ajouté par cette revue. Les permissions proposées restent distinctes des décisions métier validées.
- Les scopes sont des indications de périmètre ; leur contrôle effectif relève de CHAN-42.

| Domaine | Droits DIR actuellement explicites au §5 | Vérifications / arbitrages nécessaires | Garde-fous à préserver |
| --- | --- | --- | --- |
| Identity | admin_panel.access ; consultation et administration des financial_delegations selon les actions listées | Ne pas étendre à users, roles, permissions, role_assignments ou access_settings | DIR n'administre pas les habilitations ; sémantique suspend/delete reste M-16 |
| Clients | Accès complet DIR aux prospects, clients, contacts, relations commerciales, devis et conditions commerciales ; accès complet aux ressources de facturation clients et règlements selon §5 | Normalisation des actions et définition du workflow distinct de régularisation financière des litiges ; séparation des paiements inchangée | Ne pas confondre gestion des règlements et préparation/exécution des paiements ; conserver les obligations comptables et de traçabilité |
| Projects | Consultation globale des affaires, chantiers, études, jalons et rapports opérationnels ; view/approve de toutes les commandes clients et contrats ; view/approve des avenants ; approve des réceptions contractuelles ; accès complet aux lignes budgétaires | Rattachement A-17 validé ; DIR global et CT/CC selon `assigned_sites` via le chantier parent ; actions et workflows doivent être normalisés sans extension implicite | assigned_projects et assigned_sites restent distincts ; aucune création/modification DIR sur jalons ou rapports opérationnels ; réception contractuelle distincte de Handover |
| Planning | Consultation globale DIR des plannings contractuels et opérationnels, affectations, conflits et avancement ; arbitrage des conflits | Aucun droit DIR de modification ou d'affectation quotidienne au titre de ces décisions | Droits opérationnels des CT, CC et RA maintenus ; arbitrage des conflits normalisé via A-07 |
| Budgets | Approbation de tous les budgets, révisions et contingences sans seuil ; accès complet DIR aux lignes budgétaires | Normaliser les actions et préciser les workflows d'approbation | Conserver les droits opérationnels de CT et la traçabilité des validations |
| Costing | Accès complet DIR (`view`, `create`, `update`, `validate`) sur chiffrages, coûts et écarts ; consultation des marges ; approbation DIR/SA de toutes les provisions analytiques sans seuil ; approbation DIR/SA des engagements uniquement au-delà de 100 000 € HT cumulés par opération ; consultation, verrouillage, déverrouillage et clôture des périodes analytiques | Confirmer les autres droits DIR sur les ressources de costing et préciser les délégations sous seuil des engagements | Accès complet chiffrages/coûts/écarts confirmé ; provisions approuvées systématiquement ; périodes analytiques administrables par DIR et GAF ; engagements soumis au cumul commandes/avenants pour une même opération, prévention du fractionnement et absence d'auto-approbation |
| Workforce | Accès complet DIR à toutes les ressources et actions RH applicables, selon §5 | Normaliser les actions et traduire les workflows de validation indépendante, notamment pour les coordonnées bancaires et la paie | Secret médical, données légalement protégées, conservation légale et séparation des tâches maintenus ; aucun accès aux documents médicaux détaillés |
| TimeTracking | Accès complet DIR à toutes les ressources et actions applicables, hors documents médicaux détaillés | Normaliser les actions et préciser l'acteur de clôture mensuelle (M-03) | Historique, motifs et traçabilité obligatoires ; confidentialité médicale maintenue |
| Workshop | Accès complet DIR à toutes les ressources et actions applicables | Normaliser les actions ; aucune approbation des plans de conception n'est déduite si elle n'existe pas comme action de ressource | Préserver les historiques de production et l'autonomie opérationnelle des rôles atelier |
| Procurement | Accès complet DIR à toutes les ressources et actions applicables ; approbation des commandes d'achat et de sous-traitance uniquement au-delà de 100 000 € HT cumulés par opération | Normaliser les actions et le calcul du cumul | Prévenir le fractionnement ; conserver la séparation des paiements et les droits des autres rôles |
| Inventory | Accès complet DIR à toutes les ressources et actions applicables | Normaliser les actions | Conserver la piste d'audit des mouvements, consommations, inventaires et ajustements ; éviter l'effacement physique des preuves |
| Equipment | Accès complet DIR à toutes les ressources et actions applicables | Normaliser les actions | Conserver l'historique des affectations, maintenances, interventions, inspections réglementaires et pannes |
| Logistics | Accès complet DIR à toutes les ressources et actions applicables | Normaliser les actions ; arbitrage séparé restant pour les droits CT sur `acces_chantier` | Conserver les preuves de transport, livraison, réception, retour et autorisation d'accès |
| Quality | Accès complet DIR à toutes les ressources et actions applicables | Normaliser les actions ; rôle de traitement des signalements des autres rôles à arbitrer | Conserver les preuves, versions, résultats, auteurs, décisions et historiques qualité ; ne pas effacer les éléments requis pour conformité et audit |
| Safety | Accès complet DIR à toutes les ressources et actions applicables | Normaliser les actions | Conserver les preuves de prévention, incidents, habilitations, formations et conformité réglementaire ; ne pas effacer les historiques requis |
| Documents | Accès complet DIR à toutes les ressources et actions applicables, y compris téléchargement, signature, diffusion et export, sous réserve des restrictions légales | Qualifier les catégories et champs sensibles (M-17) et normaliser les actions | Conservation, confidentialité, protection des données et restrictions légales maintenues ; M-05 levé uniquement pour Reporting |
| Handover | Accès complet DIR confirmé sur toutes les ressources et actions applicables du §5.17 | Préserver l'historique des validations, réceptions, réserves, levées, DOE, garanties et clôtures | Réception contractuelle Projects distincte ; preuves et signatures conservées |
| Reporting | Accès complet DIR à toutes les ressources et actions applicables du §5.18, exports compris | Préserver les sources, définitions, périodes, horodatages et intégrité des snapshots | M-05 levé pour les exports Reporting ; les autres points M-11 non couverts restent ouverts |

### Décisions à obtenir en séance métier

Pour chaque ligne « À examiner », la Direction doit choisir explicitement l'une des réponses suivantes, ressource par ressource :

1. **Confirmer** : préciser l'action atomique (view, create, update, approve, etc.), le scope métier attendu et, si nécessaire, les conditions du workflow.
2. **Refuser** : consigner qu'aucune permission DIR n'est accordée.
3. **Reporter** : conserver le point ouvert avec son responsable et son ticket éventuel.

Une réponse « accès transversal » ou « accès complet » n'est pas suffisante : elle doit être décomposée en ressources et actions explicites. Toute action de validation doit être distinguée d'une approbation stratégique ou financière. Les décisions seront ensuite reportées dans les lignes concernées du §5, puis dans la synthèse §6 et dans A-16.

### A.4.2 — Registre des arbitrages DIR, Groupe 1

**Décisions métier reçues et confirmées par la Direction le 23/11/2026.** Elles complètent les sources Jira antérieures, sans valoir gel du catalogue ni implémentation. Les décisions des Groupes 2 à 4 et les arbitrages ultérieurs complètent ou précisent ce registre historique ; en cas d'écart, la décision ultérieure explicitement validée prévaut. Les mentions « à arbitrer » ci-dessous ne restent ouvertes que si elles ne sont pas clôturées dans un groupe ultérieur.

| Domaine / ressource | Décision DIR | Action atomique / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Identity / panel et habilitations | Confirmer les droits existants | `identity.admin_panel.access` ; aucun droit sur users, roles, permissions, role_assignments ou access_settings | Global pour le panel | Confirmé ; aucune extension des habilitations |
| Clients / factures, avoirs, relances, échéanciers, litiges, règlements | Consultation initiale, ensuite complétée par les décisions d'accès complet du Groupe 3 | Groupe 1 : `view` ; Groupe 3 : toutes les actions applicables par ressource, sans workflow de paiement bancaire | Global | Aucun droit GAF de préparation, d'autorisation ou d'exécution d'un paiement bancaire ; GAF conserve uniquement les droits opérationnels définis dans §5 |
| Clients / litiges de facturation | Arbitrage commercial et financier | `arbitrate` sur le litige ; approbation d'une régularisation financière dans un workflow distinct | Global | Arbitrage confirmé ; action `arbitrate` à normaliser (A-07) ; nature exacte de la régularisation, objet approuvé et action atomique restent à préciser |
| Clients / conditions commerciales | Approbation initialement décidée, puis accès complet confirmé au Groupe 3 | Groupe 1 : `approve` ; Groupe 3 : toutes les actions métier applicables | Global | Décision complétée au Groupe 3 ; workflow à préciser |
| Projects / affaires, chantiers, études | Consultation | `view` | Global pour DIR | Confirmé ; CHAN-42 doit appliquer le périmètre global DIR sans modifier les scopes CT/CC |
| Projects / lots et phases | Rattachement validé par A-17 | DIR : accès global ; CT/CC : périmètre opérationnel `assigned_sites` via le chantier parent | Global DIR / assigned_sites CT-CC | Actions atomiques et attribution des autres rôles encore à définir |
| Projects / avenants | Approbation uniquement pour DIR | `approve` ; aucun `prepare` ni `submit` DIR | Global pour DIR | Confirmé ; préparation/soumission CT restent à arbitrer |
| Projects / réception contractuelle | Approbation | `projects.receptions.approve` | Global pour DIR | Confirmé ; workflow distinct de Handover |
| Planning / plannings contractuels et opérationnels, affectations | Consultation seule | `view` ; aucun `create`, `update` ou `assign` DIR | Global pour DIR | Confirmé ; responsabilités quotidiennes CT/RA conservées |
| Planning / conflits | Consultation initialement confirmée ; arbitrage ensuite confirmé au Groupe 2 | `view` et `arbitrate` | Global pour DIR | Arbitrage confirmé au Groupe 2 ; action `arbitrate` à normaliser via A-07 |
| Handover / dossier de réception | Approbation finale | `handover.dossiers_reception.approve` | Global pour DIR | Confirmé ; distinct de la réception contractuelle Projects ; ne valide pas automatiquement réserves, levées de réserves ou DOE |

**Garde-fous associés.**

- Les consultations globales DIR sont des décisions fonctionnelles ; leur application aux ressources relève des Policies CHAN-42. Les scopes des autres rôles ne changent pas.
- L'approbation des conditions commerciales n'accorde pas de droit de modification.
- L'arbitrage d'un litige et l'approbation d'une régularisation financière ne confèrent aucun droit de préparation, d'autorisation ou d'exécution de paiement bancaire. Le suivi des règlements clients par GAF reste limité aux opérations dans Clients.
- Les deux approbations de réception sont distinctes : réception contractuelle Projects et approbation finale du dossier Handover. Les validations opérationnelles des réserves, levées de réserves et DOE ne sont pas transférées à DIR.
- Le rattachement des lots/phases est validé par A-17 ; les actions atomiques et les attributions détaillées restent à définir.
- Les actions `arbitrate` et l'approbation de régularisation financière nécessitent une normalisation et une définition du workflow avant intégration définitive au catalogue.

**Points non tranchés conservés après les décisions ultérieures.**

- Action atomique, objet et circuit de l'approbation des régularisations financières liées aux litiges.
- Actions atomiques et attribution détaillée des rôles pour lots/phases, après validation du rattachement A-17.
- M-16 et les autres points M encore ouverts ; M-05 est levé uniquement pour les exports Reporting et M-17 reste ouvert pour les catégories documentaires sensibles.
- A-01 à A-15 selon leur état respectif ; A-07 reste notamment ouvert pour la normalisation de `arbitrate`.
- Les actions et workflows non explicitement arbitrés demeurent à définir sans déduire de permission supplémentaire.

**État du lot.** Les décisions du Groupe 1 sont complétées par les arbitrages des Groupes 2 à 4. La couverture métier des 19 domaines a été revue ; A-16 reste ouvert uniquement pour la normalisation, la synchronisation et les dépendances techniques ou de workflow identifiées. A-17 est clos sur le rattachement métier ; les actions atomiques et attributions détaillées des rôles restent à définir. Aucun code, migration, seeder, test ou paramètre applicatif n'est modifié par cette mise à jour documentaire.


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

**Limites conservées.** DIR peut consulter, verrouiller, déverrouiller et clôturer les périodes analytiques. GAF dispose uniquement d'un droit de consultation sur ces périodes, sans verrouillage, déverrouillage ni clôture. Les règles de clôture, les conditions de déverrouillage et la traçabilité des opérations restent à préciser.

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
- Les droits existants de RA, CT, CC et GAF sont conservés ; les responsabilités opérationnelles ne leur sont pas retirées.
- Cette décision concerne uniquement Inventory (§5.11) et ne crée aucun droit supplémentaire dans Equipment, Logistics, Quality ou Safety.

### Arbitrage de périmètre — rôle GAF

Le rôle GAF remplace l'ancien rôle CPT. Il couvre les opérations administratives et financières opérationnelles : factures, avoirs, relances, échéanciers, litiges et suivi opérationnel des règlements clients ; traitement administratif des commandes et factures fournisseurs ; paie, bulletins, éléments variables et données nécessaires à la gestion administrative ; consultation et suivi opérationnel des budgets et du Costing selon les permissions définies pour chaque ressource.

Sont exclus : écritures comptables, journaux, plan comptable, rapprochements bancaires comptables, trésorerie comptable, déclarations, clôtures comptables, immobilisations et amortissements. Aucun droit de préparation, d'autorisation ou d'exécution de paiement bancaire n'est attribué à GAF.

GAF ne dispose d'aucune approbation générale d'engagement ou de commande ni de validation finale de paie. Les validations restent attribuées à DIR/SA ou au responsable opérationnel explicitement désigné. Les séparations de tâches et la traçabilité demeurent obligatoires.

### A.4.2 — Registre des arbitrages DIR, Groupe 2 — Reporting

**Décision métier reçue le 24/11/2026.** DIR bénéficie d’un accès complet à toutes les ressources du domaine Reporting, y compris les exports.

| Domaine / ressource | Décision DIR | Actions / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Reporting / toutes les ressources du §5.18 | Accès complet DIR | Toutes les actions applicables sur rapports, indicateurs, tableaux de bord, tableaux de bord stratégiques, snapshots et exports ; génération, consultation, téléchargement et export inclus lorsque disponibles | Global pour DIR | Décision confirmée ; M-05 levé pour les exports Reporting |

**Garde-fous et limites.**

- Préserver les sources, définitions, périodes, horodatages, périmètres et historiques des rapports, indicateurs et tableaux de bord.
- Préserver l’intégrité et la traçabilité des snapshots ; toute correction ou suppression doit respecter les obligations de conservation et les historiques requis.
- Les exports restent soumis aux règles légales, à la confidentialité et aux restrictions applicables aux données sous-jacentes ; l’accès complet Reporting ne lève pas les restrictions des autres domaines ni M-17.
- Les droits existants des autres rôles sont conservés ; cette décision ne modifie pas les droits de préparation, validation ou approbation métier dans les domaines sources.

### A.4.2 — Registre des arbitrages DIR, Groupe 2 — Handover / Réception et clôture

**Décision métier reçue le 24/11/2026.** DIR bénéficie d’un accès complet à toutes les ressources du domaine Handover, y compris validation, approbation et clôture.

| Domaine / ressource | Décision DIR | Actions / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Handover / toutes les ressources du §5.17 | Accès complet DIR | Toutes les actions applicables : consultation, création, modification, suppression, validation, approbation et clôture des dossiers de réception, réserves, levées de réserves, DOE, garanties et dossiers de clôture | Global pour DIR | Décision confirmée ; conserver preuves, signatures et historiques contractuels |

**Garde-fous et limites.**

- Conserver les dossiers de réception, réserves, levées, DOE, garanties et dossiers de clôture, avec versions, dates, responsables, signatures, décisions, justificatifs et historique des validations/clôtures.
- Une suppression physique ne doit pas effacer les preuves de réception, conformité contractuelle, levée de réserves, DOE ou garanties ; privilégier archivage et correction/clôture tracée.
- Les droits existants de CT, CC et ADM sont conservés ; l’accès complet DIR ne transfère pas leurs responsabilités opérationnelles. Les actions restent soumises aux obligations contractuelles et de conservation.
- Cette décision concerne uniquement Handover (§5.17) ; elle ne modifie pas les droits de réception contractuelle définis dans Projects ni les autres domaines.

### A.4.2 — Registre des arbitrages DIR, Groupe 2 — Documents / Gestion documentaire

**Décision métier reçue le 24/11/2026.** DIR bénéficie d’un accès complet à toutes les ressources documentaires et à toutes les actions applicables, y compris téléchargement, signature, diffusion et export.

| Domaine / ressource | Décision DIR | Actions / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Documents / toutes les ressources du §5.16 | Accès complet DIR | Toutes les actions applicables : consultation, création, modification, suppression, téléchargement, signature, diffusion, accusé de réception et export | Global pour DIR, sous réserve des restrictions légales et de confidentialité | Décision confirmée ; M-17 reste ouvert pour les catégories et champs sensibles |

**Garde-fous et limites.**

- Conserver les versions, métadonnées, signatures, diffusions, accusés de réception, téléchargements et exports, avec auteur, horodatage, destinataires, motif et historique.
- Une suppression ne doit pas contourner les obligations légales de conservation ; privilégier l’archivage ou une correction tracée lorsque la conservation est requise.
- Téléchargement, signature et export restent soumis aux règles de délégation, d’identité, de preuve, de confidentialité et aux restrictions légales applicables. Les documents médicaux détaillés et autres catégories légalement protégées ne deviennent pas accessibles par le seul effet de cet arbitrage.
- Les droits existants d’ADM, CT, CC, RA, GAF et SAL sont conservés. Cette décision concerne uniquement Documents (§5.16) et ne crée aucun droit supplémentaire dans Handover ou Reporting.

### A.4.2 — Registre des arbitrages DIR, Groupe 2 — Safety / Sécurité

**Décision métier reçue le 24/11/2026.** DIR bénéficie d’un accès complet à toutes les ressources du domaine Safety et à toutes les actions applicables.

| Domaine / ressource | Décision DIR | Actions / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Safety / toutes les ressources du §5.15 | Accès complet DIR | Toutes les actions applicables, notamment consultation, création, modification, suppression, validation, traitement, clôture et actions spécifiques aux analyses, plans, inspections, incidents, actions, habilitations, autorisations, inductions et signalements | Global pour DIR | Décision confirmée ; actions à normaliser dans le catalogue |

**Garde-fous et limites.**

- Conserver les analyses de risques, plans de prévention, inspections, constats d’incidents, actions de sécurité, habilitations, autorisations de travail, inductions et signalements : auteur, date, validités, justificatifs, décisions et historique de traitement.
- Une suppression physique ne doit pas effacer les preuves de prévention, de formation, d’incident ou de conformité réglementaire ; privilégier l’archivage ou la clôture/correction tracée.
- Les droits existants de RA, CT, CC, ADM et SAL sont conservés ; l’accès complet DIR ne transfère pas leurs responsabilités opérationnelles. Le traitement des signalements par les autres rôles reste à arbitrer.
- Cette décision concerne uniquement Safety (§5.15) et ne crée aucun droit supplémentaire dans Quality, Documents ou Handover.

### A.4.2 — Registre des arbitrages DIR, Groupe 2 — Quality / Qualité

**Décision métier reçue le 24/11/2026.** DIR bénéficie d’un accès complet à toutes les ressources du domaine Quality et à toutes les actions applicables.

| Domaine / ressource | Décision DIR | Actions / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Quality / toutes les ressources du §5.14 | Accès complet DIR | Toutes les actions applicables, notamment consultation, création, modification, suppression, validation, traitement, clôture et actions spécifiques aux plans, contrôles, non-conformités, actions correctives, audits, certificats, qualifications et signalements | Global pour DIR | Décision confirmée ; actions à normaliser dans le catalogue |

**Garde-fous et limites.**

- Conserver les versions des plans qualité et de contrôle, résultats de contrôles, non-conformités, actions correctives, rapports d’audit, certificats, qualifications et signalements : auteur, date, preuves, décision, statut et historique de clôture.
- Une suppression physique ne doit pas effacer les éléments requis pour la conformité, la certification, la traçabilité contractuelle ou l’audit ; privilégier l’archivage ou la clôture/correction tracée.
- Les droits existants de CT, CC, RA et SAL sont conservés ; l’accès complet DIR ne transfère pas leurs responsabilités opérationnelles. Le traitement des signalements par les autres rôles reste à arbitrer.
- Cette décision concerne uniquement Quality (§5.14) et ne crée aucun droit supplémentaire dans Safety, Documents ou Handover.

### A.4.2 — Registre des arbitrages DIR, Groupe 2 — Logistics / Logistique

**Décision métier reçue le 24/11/2026.** DIR bénéficie d’un accès complet à toutes les ressources du domaine Logistics et à toutes les actions applicables.

| Domaine / ressource | Décision DIR | Actions / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Logistics / toutes les ressources du §5.13 | Accès complet DIR | Toutes les actions applicables, notamment consultation, création, modification, suppression, planification, affectation, validation, clôture et actions spécifiques aux transports, tournées, livraisons, réceptions, retours et accès chantier | Global pour DIR | Décision confirmée ; actions à normaliser dans le catalogue |

**Garde-fous et limites.**

- Conserver les historiques des demandes et plans de transport, tournées, livraisons, réceptions chantier, retours et accès chantier : auteur, horodatage, motif, statuts et justificatifs associés.
- Les suppressions physiques ne doivent pas effacer les preuves de livraison/réception, les réserves, les historiques de transport ni les autorisations d’accès requises ; privilégier l’archivage, l’annulation ou la correction tracée.
- Les droits existants de RA, CT et CC sont conservés ; leurs responsabilités opérationnelles ne leur sont pas retirées. L’accès complet DIR ne résout pas les droits CT encore à arbitrer sur `acces_chantier`.
- Cette décision concerne uniquement Logistics (§5.13) et ne crée aucun droit supplémentaire dans Quality, Safety ou Documents.

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

### Arbitrage A-17 — rattachement des lots et phases — décision validée le 24/11/2026

**Modèle métier retenu :**

```text
Affaire (1) ─── (N) Chantier
Chantier (1) ─── (N) Lot
Lot (1) ─── (N) Phase
```

- Une affaire peut comporter plusieurs chantiers ; chaque chantier est rattaché à une affaire.
- Un chantier peut comporter plusieurs lots ; chaque lot appartient à un seul chantier.
- Un lot peut comporter plusieurs phases ; chaque phase appartient obligatoirement à un seul lot.
- Une phase ne peut pas être rattachée directement à un chantier indépendamment d'un lot.
- Le chantier et l'affaire d'une phase sont obtenus par héritage de son lot puis du chantier parent.

**Conséquences sur les scopes :**

- `assigned_projects` reste le scope des affaires au niveau contractuel/commercial.
- `assigned_sites` est le scope des chantiers, lots et phases pour les accès opérationnels CT/CC.
- DIR conserve le scope global sur toutes les ressources métier, conformément à A-16.
- Aucun scope `assigned_projects` autonome n'est attribué aux lots/phases ; leur périmètre opérationnel est déterminé par le chantier parent.

**Ce que la décision ne valide pas :** les actions atomiques propres aux lots/phases et l'attribution détaillée des permissions aux rôles autres que les règles globales déjà établies. Ces éléments doivent être dérivés des workflows réels avant intégration au catalogue canonique. Le modèle et les contrôles de périmètre devront rester cohérents entre CHAN-40 et CHAN-42.

### État A.4.1

- Revue des 19 domaines préparée ; les droits DIR déjà explicites sont recensés sans les élargir.
- Les domaines sans droit DIR explicite sont signalés comme sujets de décision, sans permission ajoutée.
- Les workflows financiers, RH, médicaux, de paie, de temps et de validation opérationnelle restent prioritaires et inchangés.
- A-16 est clos sur le plan fonctionnel ; A-17 est validé sur le rattachement métier le 24/11/2026. Les actions atomiques des lots/phases restent à définir.
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


### A.4.2 — Registre des arbitrages DIR — Commandes clients et contrats

**Décision métier reçue le 24/11/2026.** DIR doit approuver obligatoirement toutes les commandes clients et tous les contrats, sans restriction ni seuil de montant.

| Domaine / ressource | Décision DIR | Actions / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Projects / `commandes_clients` | Approbation obligatoire de chaque commande client | `view`, `approve` ; aucune préparation ni modification DIR ajoutée par cette décision | global DIR | Décision validée ; workflow d'approbation à préciser |
| Projects / `contrats` | Approbation obligatoire de chaque contrat | `view`, `approve` ; aucune préparation ni modification DIR ajoutée par cette décision | global DIR | Décision validée ; workflow d'approbation à préciser |

Cette décision ne modifie pas les règles propres aux avenants, aux engagements financiers, aux délégations ni aux paiements. Les droits existants de SA sont conservés. La validation technique et les Policies relèvent des lots d'implémentation concernés.


### A.4.2 — Registre des arbitrages DIR — Consultation des jalons, rapports opérationnels et avancement

**Décision métier reçue le 24/11/2026.** DIR dispose d’un droit de consultation global sur les jalons, les rapports opérationnels et l’avancement, sans droit de création ni de modification sur ces ressources au titre de cette décision.

| Domaine / ressource | Décision DIR | Actions / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Projects / `jalons` | Consultation globale | `view` uniquement pour DIR ; `update` opérationnel conservé à CT | global DIR ; assigned_projects CT | Décision validée ; permission à intégrer |
| Projects / `rapports_operationnels` | Consultation globale | `view` uniquement pour DIR ; `create` et `update` conservés à CT/CC | global DIR ; assigned_projects CT/CC | Décision validée ; permission à intégrer |
| Planning / `avancement` | Consultation globale | `view` uniquement pour DIR ; `update` conservé à CT/CC | global DIR ; assigned_projects CT/CC | Décision validée ; permission à intégrer |

La portée globale concerne exclusivement la consultation DIR. Elle ne modifie pas les responsabilités opérationnelles des CT et CC, ni leurs scopes d’affectation.


### A.4.2 — Registre des arbitrages DIR — Préparation et soumission des avenants

**Décision métier reçue le 24/11/2026.** Le Conducteur de travaux (CT) prépare et soumet les avenants dans son périmètre ; DIR et SA conservent l’approbation. DIR ne prépare ni ne soumet les avenants.

| Domaine / ressource | Décision métier | Actions / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Projects / `avenants` | Préparation et soumission par CT ; approbation par DIR et SA | CT : `view`, `prepare`, `submit` ; DIR : `view`, `approve` ; SA : `approve` selon les droits déjà définis | assigned_projects pour CT ; global pour DIR | Décision validée ; seuil et cumul des engagements, ainsi que le workflow d’approbation, restent applicables et à préciser |

Cette décision confirme la séparation entre préparation/soumission opérationnelle et approbation. Elle ne modifie pas le seuil cumulé de 100 000 € HT applicable aux engagements financiers par opération ni les règles de prévention du fractionnement.


### A.4.2 — Registre des arbitrages DIR — Lignes budgétaires

**Décision métier reçue le 24/11/2026.** DIR bénéficie d’un accès complet aux lignes budgétaires, sur l’ensemble des actions applicables et sans restriction de montant. Les droits opérationnels de CT sur les lignes budgétaires sont maintenus dans le scope `assigned_projects`.

| Domaine / ressource | Décision métier | Actions / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Budgets / `lignes_budgetaires` | Accès complet DIR | Toutes les actions applicables, notamment consultation, création, modification, soumission, validation, approbation et suppression lorsque l’action existe | global pour DIR ; assigned_projects pour CT | Décision validée ; toute suppression reste soumise aux obligations de conservation et à la traçabilité ; workflow à préciser |

Cette décision complète les droits DIR déjà confirmés sur les budgets, leurs révisions et les contingences. Elle ne modifie pas les scopes des autres rôles.


### A.4.2 — Registre des arbitrages DIR — Factures clients

**Décision métier reçue le 24/11/2026.** DIR bénéficie de tous les droits métier applicables sur la ressource `factures_clients`, sans restriction de montant : consultation, création, modification, émission et suppression si cette action est effectivement prévue par le modèle applicatif. Les droits existants de GAF sont conservés.

| Domaine / ressource | Décision métier | Actions / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Clients / `factures_clients` | Accès complet DIR | Toutes les actions applicables, dont `view`, `create`, `update`, `issue` et `delete` si disponible | global pour DIR | Décision validée ; suppression soumise aux obligations de conservation, à la traçabilité et aux règles comptables applicables |

Cette décision concerne exclusivement les factures clients. Elle n’étend pas automatiquement les droits DIR aux avoirs, aux relances, aux échéanciers, aux règlements ou à l’exécution des paiements. Aucun workflow de paiement bancaire n'est défini dans le périmètre actuel.


### A.4.2 — Registre des arbitrages DIR — Avoirs clients

**Décision métier reçue le 24/11/2026.** DIR bénéficie de tous les droits métier applicables sur la ressource `avoirs`, y compris consultation, création, modification et émission, sans restriction de montant. Les droits existants de GAF sont conservés.

| Domaine / ressource | Décision métier | Actions / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Clients / `avoirs` | Accès complet DIR | Toutes les actions applicables, dont `view`, `create`, `update`, `issue` et `delete` si disponible | global pour DIR | Décision validée ; suppression soumise aux obligations comptables de conservation et à la traçabilité |

Aucun workflow de paiement bancaire n'est défini dans le périmètre actuel.


### A.4.2 — Registre des arbitrages DIR — Relances clients

**Décision métier reçue le 24/11/2026.** DIR bénéficie de tous les droits métier applicables sur les relances clients, notamment consultation, création, modification, émission et clôture. Les droits existants de GAF sont conservés.

| Domaine / ressource | Décision métier | Actions / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Clients / `relances` | Accès complet DIR | Toutes les actions applicables, dont `view`, `create`, `update`, `issue`, `close` et `delete` si disponibles | global pour DIR | Décision validée ; suppression soumise aux obligations de conservation et à la traçabilité |

Cette décision est limitée aux relances. Elle ne modifie pas les droits sur les échéanciers, les litiges, les avoirs ou les règlements, ni la séparation des tâches applicable aux paiements.


### A.4.2 — Registre des arbitrages DIR — Échéanciers clients

**Décision métier reçue le 24/11/2026.** DIR bénéficie de tous les droits métier applicables sur les échéanciers clients, notamment consultation, création, modification, validation et clôture. Les droits existants de GAF sont conservés.

| Domaine / ressource | Décision métier | Actions / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Clients / `echeanciers` | Accès complet DIR | Toutes les actions applicables, dont `view`, `create`, `update`, `validate`, `close` et `delete` si disponible | global pour DIR | Décision validée ; suppression soumise aux obligations de conservation et à la traçabilité |

Cette décision est limitée aux échéanciers. Elle ne modifie pas les droits DIR sur les litiges de facturation, ni la séparation des tâches applicable aux paiements.


### A.4.2 — Registre des arbitrages DIR — Litiges de facturation

**Décision métier reçue le 24/11/2026.** DIR bénéficie de tous les droits métier applicables sur les litiges de facturation : consultation, création, modification, traitement, arbitrage et clôture. La suppression est accordée uniquement si l’action existe et si elle est compatible avec les obligations de conservation et de traçabilité. Les droits existants de GAF sont conservés.

| Domaine / ressource | Décision métier | Actions / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Clients / `litiges_facturation` | Accès complet DIR | Toutes les actions applicables, dont `view`, `create`, `update`, `treat`, `arbitrate`, `close` et `delete` si disponible | global pour DIR | Décision validée ; normalisation de `arbitrate` maintenue dans A-07 ; régularisation financière via workflow distinct ; suppression soumise à conservation et traçabilité |

L'accès complet aux litiges n'autorise pas implicitement l'émission d'un avoir ni l'exécution d'un paiement. L'approbation d'une régularisation financière reste un workflow distinct à modéliser. Aucun workflow de paiement bancaire n'est défini dans le périmètre actuel.


### A.4.2 — Registre des arbitrages DIR — Règlements clients

**Décision métier reçue le 24/11/2026.** DIR bénéficie d'un accès complet aux règlements clients, incluant notamment consultation, création, modification, validation et rapprochement, ainsi que les autres actions métier applicables dans cette ressource. Toute suppression n'est possible que si l'action existe et si elle respecte les obligations de conservation comptable et de traçabilité. Les droits existants de GAF sont conservés.

| Domaine / ressource | Décision métier | Actions / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Clients / `reglements` | Accès complet DIR aux opérations de gestion des règlements | Toutes les actions métier applicables, dont `view`, `create`, `update`, `validate`, `reconcile`, `close` ; `delete` uniquement si disponible et légalement autorisée | global pour DIR | Décision validée ; aucun droit de préparation ni d'exécution des paiements ; conservation et traçabilité obligatoires |

**Périmètre des règlements clients :** les droits sur les règlements concernent leur suivi opérationnel dans Clients. Ils ne créent aucun droit de préparation, d'autorisation ou d'exécution de paiement bancaire.


### A.4.2 — Registre des arbitrages DIR — Devis commerciaux

**Décision métier reçue le 24/11/2026.** DIR bénéficie d'un accès complet aux devis commerciaux, sur toutes les actions métier applicables, notamment consultation, création, modification, soumission, validation/approbation, émission et clôture. La suppression n'est accordée que si elle existe dans le modèle applicatif et respecte les obligations de conservation et de traçabilité. Les droits existants d'ADM et de SA sont conservés.

| Domaine / ressource | Décision métier | Actions / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Clients / `devis_commerciaux` | Accès complet DIR | Toutes les actions applicables, dont `view`, `create`, `update`, `submit`, `approve`, `issue`, `close` ; `delete` si disponible et autorisée | global pour DIR | Décision validée ; suppression soumise aux obligations de conservation et à la traçabilité ; workflow à préciser |

Cette décision porte sur les devis commerciaux. Elle ne modifie pas la règle distincte déjà établie selon laquelle DIR approuve toutes les conditions commerciales, leurs modifications et dérogations ; le droit d'approbation des conditions ne vaut pas, à lui seul, droit de modification de celles-ci.


### A.4.2 — Registre des arbitrages DIR — Prospects, clients et contacts

**Décision métier reçue le 24/11/2026.** DIR bénéficie d'un accès complet aux fiches prospects, clients et contacts, pour toutes les actions métier applicables, notamment consultation, création, modification, fusion et archivage. La suppression est accordée si elle existe dans le modèle applicatif et reste compatible avec les obligations de conservation et de traçabilité. Les droits existants des autres rôles sont conservés. Cette décision ne modifie pas les droits sur les relations commerciales, qui restent distincts.

| Domaine / ressource | Décision métier | Actions / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Clients / `prospects` | Accès complet DIR | Toutes les actions applicables, dont `view`, `create`, `update`, `merge`, `archive`, `delete` si disponible et autorisée | global pour DIR | Décision validée ; conservation et traçabilité obligatoires |
| Clients / `clients` | Accès complet DIR | Toutes les actions applicables, dont `view`, `create`, `update`, `merge`, `archive`, `delete` si disponible et autorisée | global pour DIR | Décision validée ; conservation et traçabilité obligatoires |
| Clients / `contacts` | Accès complet DIR | Toutes les actions applicables, dont `view`, `create`, `update`, `merge`, `archive`, `delete` si disponible et autorisée | global pour DIR | Décision validée ; conservation et traçabilité obligatoires |



### A.4.2 — Registre des arbitrages DIR — Conditions commerciales

**Décision métier reçue le 24/11/2026.** DIR bénéficie d'un accès complet aux conditions commerciales, pour toutes les actions métier applicables, notamment consultation, création, modification et approbation. Cette décision couvre les conditions initiales, leurs modifications et les dérogations. La suppression est accordée si elle existe dans le modèle applicatif et respecte les obligations de conservation et de traçabilité. Les droits existants des autres rôles, notamment ADM et SA, sont conservés.

| Domaine / ressource | Décision métier | Actions / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Clients / `conditions_commerciales` | Accès complet DIR | Toutes les actions applicables, dont `view`, `create`, `update`, `approve` ; `delete` si disponible et autorisée | global pour DIR | Décision validée ; conditions initiales, modifications et dérogations ; workflow à préciser |



### A.4.2 — Registre des arbitrages DIR — Relations commerciales

**Décision métier reçue le 24/11/2026.** DIR bénéficie d'un accès complet aux relations commerciales, pour toutes les actions métier applicables, notamment consultation, création, modification, qualification, suivi et archivage. La suppression est accordée si elle existe dans le modèle applicatif et respecte les obligations de conservation et de traçabilité. Les droits existants d'ADM sont conservés.

| Domaine / ressource | Décision métier | Actions / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Clients / `relations_commerciales` | Accès complet DIR | Toutes les actions applicables, dont `view`, `create`, `update`, `qualify`, `track`, `archive` ; `delete` si disponible et autorisée | global pour DIR | Décision validée ; conservation et traçabilité obligatoires |



### A.4.2 — Registre des arbitrages DIR — Dossiers administratifs clients

**Décision métier reçue le 24/11/2026.** DIR bénéficie d'un accès complet aux dossiers administratifs clients et à leurs pièces associées, via les ressources documentaires existantes `documents`, `versions` et `dossiers_documentaires`. Cet accès couvre toutes les actions applicables, notamment création, modification, validation, téléchargement et archivage. La suppression reste conditionnée à son existence dans le modèle applicatif et au respect des obligations légales de conservation et de traçabilité. Les restrictions légales et les catégories documentaires sensibles restent applicables ; M-17 demeure ouvert pour leur qualification. Aucun nouveau type de ressource ou droit documentaire distinct n'est créé par cet arbitrage.

| Domaine / ressource | Décision métier | Actions / portée | Scope métier | Statut / réserve |
| --- | --- | --- | --- | --- |
| Documents clients / `documents`, `versions`, `dossiers_documentaires` | Accès complet DIR aux dossiers administratifs clients et pièces associées | Toutes les actions applicables, notamment `view`, `create`, `update`, `validate`, `download`, `archive` ; `delete` si disponible et légalement autorisée | global pour DIR dans le périmètre documentaire | Décision validée ; restrictions légales, conservation, traçabilité et M-17 maintenus |



## Décision de périmètre — exclusion de la comptabilité (24/11/2026)

Le logiciel Chantier ne comporte aucun module comptable. Le domaine D19 Accounting n'est pas retenu dans le catalogue fonctionnel ni dans la matrice RBAC. Le rôle GAF est conservé comme profil de gestion administrative et financière opérationnelle ; aucune permission ni ressource comptable ne doit être créée. Les fonctions opérationnelles Clients, Procurement, Budgets, Costing et Workforce restent limitées à leurs workflows de gestion et ne doivent pas implémenter d'écritures ou de traitements comptables.


## 17. Finalisation documentaire — état consolidé (24/11/2026)

Cette section fait foi pour la lecture de l'état documentaire après les lots 1 à 5. Elle prévaut sur les anciennes sections de planification qui décrivent encore les lots comme restant à produire, sans supprimer l'historique des décisions et des travaux.

### 17.1 Éléments consolidés

- Les huit rôles sont définis : SA, DIR, ADM, CT, CC, RA, SAL et GAF. La matrice synthétique des rôles existe ; elle ne constitue pas encore la table exhaustive des associations permission × rôle.
- Les 18 domaines métier sont inventoriés. Aucun domaine, objet, module ou droit comptable n'est prévu.
- Le rôle GAF remplace CPT et couvre uniquement les opérations administratives et financières opérationnelles dans Clients, Procurement, Workforce, Budgets et Costing, selon les droits propres à chaque ressource.
- GAF ne dispose d'aucun droit de préparation, d'autorisation ou d'exécution de paiement bancaire, ni d'aucune permission comptable.
- DIR reçoit explicitement chaque permission fonctionnelle atomique retenue, scope global, sauf les exceptions Identity/habilitations, secret médical, séparation des tâches, auto-approbation interdite, conservation, confidentialité et audit.
- A-01 à A-09 sont les conventions canoniques retenues. Leur conformité mécanique sera vérifiée lors de la génération du catalogue.
- Les scopes opérationnels et l'accès à une ressource ou à un chantier restent distincts des permissions fonctionnelles et relèvent de CHAN-42.

### 17.2 Points encore ouverts — sans réouverture des décisions validées

| Référence | Point restant | Ce qui est nécessaire | Effet |
| --- | --- | --- | --- |
| A-07 | Mappings `treat`, `correct`, `refuse` | Confirmer les workflows réels. `process` reste candidat pour le traitement d'un litige ; `update` reste candidat pour la correction tracée d'un pointage ; aucun `refuse` autonome n'est ajouté sans capacité distincte démontrée. | Ne pas créer ces permissions avant confirmation du workflow. |
| A-17 | Rattachement des lots/phases | Décision validée : Affaire 1—N Chantier, Chantier 1—N Lot, Lot 1—N Phase ; scopes opérationnels `assigned_sites` via le chantier parent. | Rattachement clos ; actions atomiques et attribution détaillée des rôles restant à définir sans supposition. |
| M-01 à M-16 | Paramètres et workflows | Résoudre chaque point uniquement pour les ressources et actions qu'il conditionne. | Les permissions indépendantes ne sont pas bloquées. |
| M-17 | Catégories documentaires sensibles | Définir les catégories/champs et les règles de lecture, téléchargement, signature et export. | Ne pas généraliser les droits documentaires sensibles. |
| Objets transverses | `financial_delegations`, `directory`, `messages`, exports, signalements, données paie/bancaires/médicales | Confirmer propriétaire métier, cycle de vie et éventuelle autonomie comme ressource. | Ne pas créer de permission avant qualification. |
| Ressources des domaines lots 2 et 3 | Actions encore « à décomposer » | Décrire les opérations réelles et leur workflow ; les domaines applicatifs étant encore des squelettes au contrôle documentaire, aucune action ne peut être validée par inspection de code. | Ne pas remplacer « à décomposer » par un CRUD supposé. |
| Audit métier | Périmètre CHAN-45 | Confirmer si CHAN-45 couvre l'audit métier immuable ou créer un lot dédié. | CHAN-40 décrit les capacités et événements, pas le stockage d'audit. |

### 17.3 Séparation des travaux et critères de sortie

1. **Nettoyage documentaire :** effectué dans cette phase pour les références manifestement obsolètes et les formulations ambiguës identifiées.
2. **Arbitrages métier :** restent limités aux points du tableau §17.2 ; aucune décision métier nouvelle n'est supposée.
3. **Contrôle du catalogue :** à réaliser après qualification des ressources et workflows ; il devra vérifier unicité des triplets, slugs canoniques, absence de doublons, actions justifiées et absence de domaine comptable.
4. **Matrice atomique :** à générer explicitement pour les huit rôles à partir des permissions retenues ; DIR suit la règle générale et ses exceptions. Aucun héritage implicite.
5. **Validation formelle :** le catalogue ne sera gelé qu'après présentation et validation de la liste atomique, des associations de rôles et des scopes séparés.
6. **Implémentation :** seulement après gel : `PermissionCatalog`, `RoleCatalog`, seeders idempotents, synchronisation contrôlée, contrôle Filament et tests CHAN-40/CHAN-46 selon leur périmètre.

**État à la fin de cette phase :** référentiel documentaire consolidé, mais catalogue non gelé et CHAN-40 non livré. Aucun code, migration, seeder, test ni statut Jira n'est modifié par la phase de finalisation documentaire.

## 18. M-17 — arbitrage documentaire final (24/11/2026)

**Statut : arbitrage fonctionnel des catégories et des opérations clôturé.** Cet arbitrage remplace les mentions historiques indiquant que M-17 reste ouvert ou à arbitrer pour la matrice des catégories documentaires. Il ne vaut pas gel global du catalogue RBAC.

### 18.1 Règle générale retenue

Pour chacune des dix catégories DOC-01 à DOC-10, les droits existants sont conservés sans extension ni réduction automatique pour chacune des opérations `view`, `download`, `sign` et `export`. Aucune nouvelle attribution à un rôle n'est déduite de cet arbitrage : les associations existantes et leurs scopes restent la référence. Lorsqu'une attribution atomique existante n'est pas explicitée dans les documents sources, elle reste à vérifier lors de la consolidation de la matrice rôle × permission ; elle n'est pas inventée ici.

| Code | Catégorie | Périmètre documentaire |
| --- | --- | --- |
| DOC-01 | Administratif entreprise | Kbis, attestations d'assurance, fiscales et sociales, documents de l'entreprise, administrations et organismes |
| DOC-02 | Clients | Contrats, devis, commandes, correspondances et factures |
| DOC-03 | Affaires et chantiers | Plans, études, notes de calcul, DOE et comptes rendus |
| DOC-04 | Atelier et fabrication | Plans de fabrication, nomenclatures et listes de débit |
| DOC-05 | Ressources humaines | Contrats, avenants et dossiers salariés |
| DOC-06 | Paie et rémunération | Bulletins, variables de paie, rémunérations et DSN |
| DOC-07 | Médical | Visites, avis, justificatifs et données médicales détaillées |
| DOC-08 | Banque et finance | RIB, coordonnées bancaires, financements et relevés |
| DOC-09 | Sécurité et prévention | Plans de prévention, autorisations, formations et documents de sécurité |
| DOC-10 | Juridique et contentieux | Procédures, mises en demeure, litiges et documents d'avocats |

### 18.2 Décision par opération

| Opération | Décision applicable aux DOC-01 à DOC-10 |
| --- | --- |
| `view` | Conservation stricte des droits existants et de leurs scopes |
| `download` | Conservation stricte des droits existants et de leurs scopes |
| `sign` | Conservation stricte des droits existants ; signature uniquement dans le cadre d'une délégation valable, avec identité et preuve |
| `export` | Conservation stricte des droits existants ; mêmes restrictions de confidentialité et de périmètre que pour les données/documents sources |

### 18.3 Exceptions et garde-fous impératifs

- Les droits SAL sur ses propres documents restent limités aux droits déjà prévus, notamment `download` et `sign` own lorsqu'ils s'appliquent.
- Le secret médical et la confidentialité des données de santé prévalent sur les droits généraux, y compris ceux de DIR. Aucun accès aux documents médicaux détaillés n'est accordé par la seule règle d'accès global.
- Les documents RH, de paie/rémunération, bancaires/financiers et juridiques/contentieux restent soumis à leurs restrictions légales et de confidentialité existantes.
- Les exports héritent des restrictions de la source ; l'export ne permet pas de contourner un scope ou une restriction d'accès.
- La signature suppose une délégation applicable, l'identification du signataire et la conservation de la preuve.
- Les obligations de conservation, l'intégrité des versions et la traçabilité demeurent applicables ; aucune permission ne permet de détruire une pièce ou une preuve dont la conservation est obligatoire.
- Les règles de séparation des tâches et l'interdiction d'auto-approbation restent applicables.

**Conclusion :** M-17 est clôturé pour la classification DOC-01 à DOC-10 et pour les opérations `view`, `download`, `sign`, `export`, sur la base du maintien des droits existants. La consolidation technique des associations atomiques et scopes déjà existants reste distincte et ne constitue pas une réouverture de cet arbitrage.
