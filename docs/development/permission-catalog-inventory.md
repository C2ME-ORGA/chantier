# Inventaire canonique des permissions — CHAN-40

> **Statut :** inventaire des 18 domaines documenté — lots 1 à 4 ; catalogue non gelé, implémentation non commencée.
> **Référentiel :** `docs/development/authorization-matrix.md`, relu le 24/11/2026.
> **Gel :** non effectué. Aucun seeder, migration ou code d'autorisation ne doit être généré à ce stade.

## 1. Méthode

- Une permission est atomique : `{domain}.{resource}.{action}`.
- Slugs conformes à A-03 à A-06 ; actions conformes au registre A-07.
- Seules les actions justifiées par les processus décrits dans la matrice sont retenues. « Accès complet DIR » n'autorise pas à créer toutes les actions possibles sur une ressource.
- DIR reçoit explicitement chaque permission fonctionnelle retenue, scope global, sauf administration des habilitations, secret médical, préparation/exécution des paiements et contrôles légaux de séparation des tâches.
- Les autres rôles sont repris de la matrice sans héritage implicite. Les scopes opérationnels relèvent de CHAN-42.
- Les règles de seuil, cumul, validation, conservation et audit sont des règles de workflow, pas des permissions.

## 2. Lot 1 — Ressources et actions candidates

Les actions ci-dessous sont des candidats issus des actions explicitement citées dans la matrice. Les actions conditionnelles ou proposées ne sont pas gelées.

### Identity

| Ressource | Actions candidates | Rôles hors DIR / portée | Statut |
| --- | --- | --- | --- |
| `admin_panel` | `access` | SA, ADM, CT, CC, RA, GAF / global | Retenu ; SAL exclu du panel |
| `users` | `view`, `create`, `update`, `deactivate` | SA / global | Proposé ; désactivation à confirmer |
| `roles` | `view`, `create`, `update`, `delete`, `assign` | SA / global | Proposé ; suppression à confirmer |
| `permissions` | `view`, `create`, `update`, `delete` | SA / global | Proposé |
| `role_assignments` | `assign`, `revoke` | SA / global | Proposé ; révocation à confirmer |
| `access_settings` | `view`, `update` | SA / global | Proposé |
| `financial_delegations` | `view`, `create`, `update`, `suspend`, `delete` | SA ; DIR selon règle dédiée | À arbitrer : propriétaire et exception DIR à clarifier |
| `sessions` | — | — | Hors périmètre CHAN-40 ; CHAN-43 |
| `directory` | `view` | SAL ; autres rôles à confirmer | À arbitrer |
| `messages` | `send` | SAL ; autres rôles à confirmer | À arbitrer |

**Exception DIR :** aucune permission fonctionnelle ne donne à DIR l'administration des utilisateurs, rôles, permissions, affectations de rôles ou paramètres d'accès. `identity.admin_panel.access` ne donne aucun droit ressource.

### Clients

| Ressource | Actions candidates | Rôles hors DIR / portée | Statut |
| --- | --- | --- | --- |
| `prospects` | `view`, `create`, `update`, `merge`, `archive` ; `delete` conditionnel | ADM : view/create/update / global-company | Retenu ; suppression selon conservation |
| `clients` | `view`, `create`, `update`, `merge`, `archive` ; `delete` conditionnel | ADM : view/create/update / global-company | Retenu ; suppression selon conservation |
| `contacts` | `view`, `create`, `update`, `merge`, `archive` ; `delete` conditionnel | ADM : view/create/update / global-company | Retenu ; suppression selon conservation |
| `relations_commerciales` | `view`, `create`, `update`, `qualify`, `track`, `archive` ; `delete` conditionnel | ADM : view/create/update / global-company | Retenu |
| `conditions_commerciales` | `view`, `create`, `update`, `approve` ; `delete` conditionnel | ADM : view/create/update ; SA : approve | Retenu ; approbation DIR des conditions initiales, modifications et dérogations |
| `devis_commerciaux` | `view`, `create`, `update`, `submit`, `approve`, `issue`, `close` ; `delete` conditionnel | ADM : view/create/update/submit ; SA : approve | Retenu ; workflow à préciser |
| `factures_clients` | `view`, `create`, `update`, `issue` ; `delete` conditionnel | GAF : view/create/update/issue | Retenu ; pièces et justificatifs soumis aux règles de conservation applicables, sans traitement comptable |
| `avoirs` | `view`, `create`, `update`, `issue` ; `delete` conditionnel | GAF : view/create/update/issue | Retenu ; pièces et justificatifs soumis aux règles de conservation applicables, sans traitement comptable |
| `relances` | `view`, `create`, `update`, `issue`, `close` ; `delete` conditionnel | GAF : view/create/update | Retenu |
| `echeanciers` | `view`, `create`, `update`, `validate`, `close` ; `delete` conditionnel | GAF : view/create/update | Retenu |
| `litiges_facturation` | `view`, `create`, `update`, `arbitrate`, `close` ; traitement à normaliser | GAF : view/create/update | Anomalie A-07 : `treat` absent du registre ; régularisation financière distincte |
| `reglements` | `view`, `create`, `update`, `validate`, `reconcile`, `close` ; `delete` conditionnel | GAF : view/reconcile | Retenu ; aucun droit de préparation/exécution de paiement |

**Propriété des ressources :** les documents de facturation et de gestion client restent dans `clients`. Procurement reste propriétaire des factures fournisseurs et des commandes fournisseurs ; aucune ressource de facturation n'est dupliquée dans un domaine comptable.

### Projects

| Ressource | Actions candidates | Rôles hors DIR / portée | Statut |
| --- | --- | --- | --- |
| `affaires` | `view`, `create`, `update` | CT : view/create/update ; ADM, CC, GAF : view | Retenu |
| `chantiers` | `view`, `create`, `update` | CT : view/create/update ; ADM, CC, GAF : view | Retenu |
| `lots_phases` | Actions atomiques à définir après description des workflows | DIR : toutes actions applicables ; CT/CC : actions opérationnelles sur chantiers affectés | Rattachement A-17 validé : Chantier 1—N Lot ; Lot 1—N Phase ; scope opérationnel `assigned_sites` hérité du chantier |
| `etudes` | `view`, `create`, `update` | CT : view/create/update | Retenu |
| `commandes_clients` | `view`, `approve` | ADM, CT, GAF : view ; SA : approve | Retenu ; DIR approuve toutes les commandes, sans seuil |
| `avenants` | `view`, `prepare`, `submit`, `approve` | CT : view/prepare/submit ; SA : approve | Retenu ; DIR n'assure ni préparation ni soumission |
| `contrats` | `view`, `approve` | ADM, CT, GAF : view ; SA : approve | Retenu ; DIR approuve tous les contrats, sans seuil |
| `jalons` | `view`, `update` | CT : view/update ; CC : view | Retenu |
| `receptions` | `view`, `prepare`, `approve` | CT : view/prepare ; CC : view | Retenu ; distinct de Handover |
| `rapports_operationnels` | `view`, `create`, `update` | CT/CC : view/create/update | Retenu |

### Planning

| Ressource | Actions candidates | Rôles hors DIR / portée | Statut |
| --- | --- | --- | --- |
| `plannings` | `view`, `create`, `update` | CT : view/create/update ; CC, RA, SAL : view ; RA : update atelier | Retenu |
| `affectations` | `view`, `create`, `update`, `assign` | CT : view/create/update/assign ; CC, RA, SAL : view | Retenu |
| `conflits` | `view`, `arbitrate` | CT : view | Retenu ; arbitrage DIR |
| `avancement` | `view`, `update` | CT/CC : view/update | Retenu |

### Budgets

| Ressource | Actions candidates | Rôles hors DIR / portée | Statut |
| --- | --- | --- | --- |
| `budgets` | `view`, `create`, `update`, `submit`, `approve` | CT : view/create/update/submit ; ADM/GAF : view ; SA : approve | Retenu ; approbation DIR sans seuil |
| `lignes_budgetaires` | `view`, `create`, `update`, `submit`, `validate`, `approve` ; delete conditionnel | CT : view/create/update ; ADM/GAF : view | Retenu ; accès complet DIR |
| `revisions_budgetaires` | `view`, `create`, `update`, `submit`, `approve` | CT : view/create/update/submit ; ADM/GAF : view ; SA : approve | Retenu ; approbation DIR sans seuil |
| `contingences` | `view`, `create`, `update`, `approve` | CT : view/create/update | Retenu ; approbation DIR sans seuil |

### Costing

| Ressource | Actions candidates | Rôles hors DIR / portée | Statut |
| --- | --- | --- | --- |
| `chiffrages` | `view`, `create`, `update`, `validate` | ADM/CT/RA/GAF : view ; CT/RA : create/update selon objet | Retenu |
| `couts` | `view`, `create`, `update`, `validate` | ADM/CT/RA/GAF : view ; CT/RA : create/update selon objet | Retenu |
| `ecarts` | `view`, `create`, `update`, `validate` | ADM/CT/RA/GAF : view ; CT/RA : create/update selon objet | Retenu |
| `engagements` | `view`, `approve` | CT : view ; GAF : aucun droit d'approbation ou d'engagement ; SA/DIR : approve selon seuil | Retenu ; GAF n'approuve pas les engagements |
| `marges` | `view` | CT/RA/GAF : view selon matrice | À préciser ; source au statut « Proposé » |
| `provisions_analytiques` | `view`, `approve` | CT/GAF : view ; SA : approve | Retenu ; approbation sans seuil |
| `periodes_analytiques` | `view`, `lock`, `unlock`, `close` | GAF : `view` uniquement ; DIR : view/lock/unlock/close | Retenu ; GAF ne verrouille ni ne clôture les périodes analytiques |


## 6. Lot 2 — Workforce, TimeTracking, Workshop, Procurement, Inventory et Equipment

> Les ressources et les workflows ci-dessous sont repris des sections 5.7 à 5.12 de la matrice. Pour les lignes qui indiquent seulement « toutes actions applicables », aucune liste exhaustive n'est inventée : elles restent à décomposer à partir des opérations réellement disponibles dans l'application. DIR est associé explicitement à chaque permission fonctionnelle qui sera retenue, sous réserve des exceptions médicales, financières, de séparation des tâches et de conservation.

### 6.1 Workforce

| Ressource | Actions explicitement citées / candidates | Rôles hors DIR et portée | Statut / contraintes |
| --- | --- | --- | --- |
| `collaborateurs` | `view`, `create`, `update`, `delete` | ADM : view/create/update ; CT, CC, RA, SAL : consultations limitées | Retenu ; suppression seulement si conservation légale autorisée |
| `contrats` | `view`, `create`, `update`, `delete` | ADM : view/create/update ; autres droits selon périmètres RH | Retenu ; conservation légale |
| `postes` | `view`, `create`, `update`, `delete` | ADM : view/create/update | Retenu |
| `qualifications` | `view`, `create`, `update`, `delete` | ADM : view/create/update ; consultations opérationnelles selon rôle | Retenu |
| `formations` | `view`, `create`, `update`, `delete` | ADM : view/create/update ; consultations opérationnelles selon rôle | Retenu |
| `equipes` | `view`, `create`, `update`, `delete` | ADM : view/create/update ; consultations limitées | Retenu |
| `disponibilites` | `view`, `create`, `update`, `delete` | ADM : view/create/update ; consultations limitées | Retenu |
| `dossiers_rh` | `view`, `create`, `update`, `delete` | ADM : view/create/update ; SAL : view own | Retenu ; hors documents médicaux confidentiels |
| `dossiers_disciplinaires` | `view`, `create`, `update`, `delete` | SA conserve ses droits globaux sous restrictions applicables | Retenu ; données sensibles et scope restricted |
| `donnees_medicales` | Aucune permission générale de consultation détaillée à générer | DIR : seules informations légalement accessibles et strictement nécessaires ; ADM : traitement administratif ; GAF : informations nécessaires paie/administration de la paie | Exception ; documents médicaux détaillés détenus par les professionnels de santé exclus |
| `coordonnees_bancaires` | `view`, `create`, `update`, `delete`, `validate` | SA conserve ses droits ; GAF : `view` uniquement pour les données strictement nécessaires à la gestion administrative de la paie ; SAL : view own, request_update | Retenu ; aucun droit de paiement ou de virement pour GAF |
| `elements_variables_paie` | `view`, `create`, `update`, `delete`, `prepare`, `control`, `submit`, `validate` | ADM : préparation/soumission ; GAF : view/prepare/control | Retenu ; GAF prépare et contrôle les éléments variables, sans validation finale |
| `paies` | `view`, `create`, `update`, `delete`, `prepare`, `control`, `validate` | GAF : view/prepare/control ; SA conserve ses droits | Retenu ; interdiction d'auto-approbation |
| `bulletins_paie` | `view`, `create`, `update`, `delete`, `prepare`, `control`, `validate` | GAF : view/prepare/control ; SAL : view own ; SA conserve ses droits | Retenu ; confidentialité et conservation |
| `indemnites_grands_deplacements` | `view`, `create`, `update`, `delete`, `prepare`, `control`, `process`, `validate` | GAF conserve les droits administratifs et de préparation/contrôle paie attribués dans le workflow ; SAL : view own | Retenu ; validation finale indépendante |
| `indemnites_grands_deplacements` | `view`, `create`, `update`, `delete`, `prepare`, `control`, `process`, `validate` | SAL : view own ; ADM/GAF conservent leurs droits | Retenu |
| `grands_deplacements` | `view`, `create`, `update`, `delete`, `declare`, `control`, `prepare`, `process`, `validate` | CT/RA : déclaration de leurs équipes ; ADM/GAF/SAL conservent leurs droits | Retenu |
| `baremes_grands_deplacements` | `view`, `create`, `update`, `delete` | SA conserve ses droits globaux | Retenu ; barèmes datés/historisés, aucune modification rétroactive des périodes traitées |

**Règles transverses Workforce :** les suppressions sont conditionnées par les durées légales de conservation ; sinon privilégier archivage/désactivation si ces actions existent dans le workflow. Les changements de coordonnées bancaires doivent être validés indépendamment de leur demandeur/modificateur. Les documents médicaux détaillés restent exclus.

### 6.2 TimeTracking

| Ressource | Actions explicitement citées / candidates | Rôles hors DIR et portée | Statut / contraintes |
| --- | --- | --- | --- |
| `pointages` | `view`, `create`, `update`, `delete`, `submit`, `validate`, `reopen`, `supervise` ; `correct` en anomalie A-07 | CC/RA/SAL conservent leurs droits ; CT contrôle/corrige ; GAF : view paie | Retenu ; historique et motifs de correction obligatoires |
| `feuilles_de_temps` | `view`, `create`, `update`, `delete`, `submit`, `validate`, `reopen`, `supervise` ; `correct` en anomalie A-07 | CC/RA/SAL conservent leurs droits ; CT contrôle/corrige après CC ; GAF : view paie | Retenu ; candidat historique `timetracking.timesheets.validate` à normaliser vers la ressource canonique |
| `corrections` | `view`, `create`, `update`, `delete`, `submit`, `validate`, `reopen` | SAL, CC, RA, CT selon leurs périmètres | Retenu ; valeur initiale/nouvelle, auteur, date, motif et valideur à tracer |
| `periodes` | `view`, `create`, `update`, `delete`, `close`, `reopen` | SA conserve `reopen` | Retenu ; clôture après contrôles, réouverture motivée et auditée |
| `absences` | `view`, `create`, `update`, `delete`, `submit`, `review`, `validate`, `arbitrate` | SAL, CC, CT, RA, ADM selon responsabilités ; GAF : consultation paie | Retenu ; historisation des décisions |
| `justificatifs_medicaux` | Pas de droit général aux documents médicaux détaillés | ADM : traitement administratif ; GAF : informations nécessaires à paie/administration de la paie ; DIR : informations administratives/d'indisponibilité légalement accessibles | Exception secret médical ; accès restreint |
| `heures_supplementaires` | `view`, `create`, `update`, `delete`, `authorize`, `submit`, `validate`, `validate_excess`, `control`, `process` | SAL, CT, RA, ADM, GAF conservent leurs droits | Retenu ; distinguer heures autorisées, déclarées, réellement travaillées et validées ; un dépassement refusé reste tracé comme temps travaillé |

**Anomalie A-07 :** `correct` est cité dans la matrice mais absent du registre canonique. Ne pas générer `timetracking.pointages.correct` ni `timetracking.feuilles_de_temps.correct` avant décision ; vérifier si `update` suffit, en préservant l'événement de correction et son historique. Le scope de validation opérationnelle de CT ne doit pas être élargi : CT contrôle après CC et corrige/réouvre via `corrections`.

### 6.3 Workshop

| Ressource | Actions explicites / candidates | Rôles hors DIR | Statut / contraintes |
| --- | --- | --- | --- |
| `ordres_fabrication` | `view`, `create`, `update`, `delete`, `reopen`, `close`, `validate` | CT, CC, RA, SAL conservent leurs droits | Retenu ; historique de production |
| `dossiers_fabrication` | `view`, `create`, `update`, `delete`, `validate` | RA, CT, CC conservent leurs droits | Retenu |
| `operations` | `view`, `create`, `update`, `delete`, `validate` | RA, CT, CC conservent leurs droits | Retenu |
| `postes` | `view`, `create`, `update`, `delete`, `validate` | RA, CT, CC conservent leurs droits | Retenu |
| `capacites_atelier` | `view`, `create`, `update`, `delete`, `validate` | RA, CT, CC conservent leurs droits | Retenu |
| `demandes_matiere` | `view`, `create`, `update`, `delete`, `submit`, `validate` | RA conserve ses droits | Retenu |
| `comptes_rendus_production` | `view`, `create`, `update`, `delete`, `submit`, `validate` | RA, CT, CC, SAL conservent leurs droits | Retenu ; historique conservé |
| `colis_fabrication` | `view`, `create`, `update`, `delete`, `validate`, `close` | RA, CT conservent leurs droits | Retenu |
| `rebuts` | `view`, `create`, `update`, `delete`, `reopen`, `validate`, `close` | RA conserve ses droits | Retenu ; suivi non-conformités de production |
| `reprises` | `view`, `create`, `update`, `delete`, `reopen`, `validate`, `close` | RA conserve ses droits | Retenu ; suivi non-conformités de production |

### 6.4 Procurement

| Ressource | Actions explicitement citées / candidates | Rôles hors DIR | Statut / contraintes |
| --- | --- | --- | --- |
| `fournisseurs` | Actions fonctionnelles à décomposer à partir du CRUD et du workflow réellement disponibles | ADM, CT, CC, RA, GAF conservent leurs droits | Ressource retenue ; actions DIR globales à inventorier sans inventer les actions absentes |
| `sous_traitants` | Actions fonctionnelles à décomposer à partir du CRUD et du workflow réellement disponibles | ADM, CT, CC, RA, GAF conservent leurs droits | Ressource retenue |
| `demandes_achat` | Actions fonctionnelles à décomposer ; soumission à confirmer selon workflow | ADM, CT, RA conservent leurs droits | Ressource retenue ; scope opérationnel CHAN-42 |
| `besoins` | Actions fonctionnelles à décomposer | CC, CT, RA conservent leurs droits | Ressource retenue |
| `offres_fournisseurs` | Actions fonctionnelles à décomposer | ADM, RA conservent leurs droits | Ressource retenue |
| `commandes_achats` | `view`, `prepare`, `update`, `submit`, `approve` (approbation selon seuil et rôle autorisé) | GAF : `view`, `prepare`, `update`, `submit` ; aucun `approve` ; ADM/CT/RA conservent leurs droits selon le workflow | Retenu ; GAF assure le traitement administratif sans pouvoir d'approbation d'engagement |
| `lignes_commande` | `view`, `prepare`, `update`, `submit`, `approve` (à confirmer si action portée par la ligne ou la commande) | GAF : `view`, `prepare`, `update`, `submit` ; aucun `approve` ; ADM/CT/RA selon workflow | À préciser ; ne pas dupliquer l'approbation si elle appartient à la commande |
| `commandes_sous_traitance` | `view`, `prepare`, `update`, `submit`, `approve` (approbation selon seuil et rôle autorisé) | GAF : `view`, `prepare`, `update`, `submit` ; aucun `approve` ; ADM/CT/RA conservent leurs droits selon le workflow | Retenu ; GAF assure le traitement administratif sans pouvoir d'approbation d'engagement |
| `evaluations_fournisseurs` | Actions à décomposer selon les étapes d'évaluation effectivement disponibles | ADM, RA conservent leurs droits | Ressource retenue |
| `accords_cadres` | Actions à décomposer ; approbation uniquement si le workflow prévoit une action distincte | ADM, RA conservent leurs droits | Ressource retenue |
| `garanties_fournisseurs` | Actions à décomposer selon suivi, consultation et gestion des garanties | ADM, RA conservent leurs droits | Ressource retenue |
| `factures_fournisseurs` | `view`, `create`, `update`, `reconcile` | GAF : `view`, `create`, `update`, `reconcile` ; ADM conserve ses droits administratifs | Retenu ; `reconcile` désigne le rapprochement administratif commande/facture, jamais un rapprochement bancaire |
| `incidents_sous_traitance` | Actions à décomposer selon déclaration, traitement et clôture réellement disponibles | CC, CT, RA conservent leurs droits | Ressource retenue |

**Règle financière Procurement :** l'approbation des commandes d'achat et de sous-traitance suit le seuil cumulé de 100 000 € HT par opération, en agrégeant commandes et avenants et en empêchant le fractionnement artificiel. GAF peut préparer, modifier et soumettre les commandes dans le cadre de leur traitement administratif, sans pouvoir d'approbation d'engagement. Aucun workflow de préparation, d'autorisation ou d'exécution de paiement bancaire n'est inclus dans le périmètre.

### 6.5 Inventory

| Ressource | Actions explicites / candidates | Rôles hors DIR | Statut / contraintes |
| --- | --- | --- | --- |
| `articles` | Actions fonctionnelles à décomposer ; référentiel | RA, CT, CC, GAF conservent leurs droits | Retenu |
| `entrepots` | Actions fonctionnelles à décomposer ; référentiel | RA, CT, CC, GAF conservent leurs droits | Retenu |
| `emplacements` | Actions fonctionnelles à décomposer ; référentiel | RA, CT, CC, GAF conservent leurs droits | Retenu |
| `lots_stock` | Actions fonctionnelles à décomposer ; suivi des lots | RA, CT, CC, GAF conservent leurs droits | Retenu |
| `mouvements_stock` | `view`, `create`, `update`, `reverse`, `validate` si applicable | RA, CT, CC, GAF conservent leurs droits | Retenu ; inversion plutôt qu'effacement de l'historique |
| `receptions_stock` | Actions fonctionnelles à décomposer selon réception et contrôle réellement disponibles | RA, CT, CC conservent leurs droits | Retenu |
| `reservations_stock` | Actions fonctionnelles à décomposer selon réservation/libération réellement disponibles | RA, CT, CC conservent leurs droits | Retenu |
| `consommations` | `view`, `create`, `update`, `reverse`, `validate` si applicable | CC, RA, CT, GAF conservent leurs droits | Retenu ; slug canonique `inventory.consommations` |
| `bons_sortie` | Actions fonctionnelles à décomposer selon préparation, validation et émission réellement disponibles | RA, CC conservent leurs droits | Retenu |
| `inventaires_physiques` | Actions fonctionnelles à décomposer selon préparation, comptage, validation et clôture réellement disponibles | RA, GAF conservent leurs droits | Retenu |
| `ajustements` | `view`, `create`, `update`, `validate`, `reverse` ; `delete` uniquement si légalement et techniquement autorisé | RA conserve ses droits | Retenu ; piste d'audit obligatoire |

**Règle Inventory :** conserver la piste d'audit des mouvements, consommations, inventaires et ajustements. Privilégier `reverse` pour annuler une opération historisée ; la suppression physique ne doit pas effacer une preuve comptable ou opérationnelle.

### 6.6 Equipment

| Ressource | Actions explicites / candidates | Rôles hors DIR | Statut / contraintes |
| --- | --- | --- | --- |
| `equipements` | Actions fonctionnelles à décomposer selon les opérations réelles ; affectation/maintenance selon ressources dédiées | RA : `view`, `create`, `update`, `assign` ; CT, CC, SAL conservent leurs droits | Retenu |
| `affectations` | `view`, `create`, `update`, `assign` si action distincte dans le workflow | RA : `view`, `create`, `update`, `assign` ; CT, CC, SAL conservent leurs droits | Retenu ; historique d'affectation |
| `categories` | Actions fonctionnelles à décomposer selon la gestion du référentiel | RA conserve ses droits | Retenu |
| `plans_maintenance` | Actions fonctionnelles à décomposer selon création, mise à jour et suivi du plan | RA conserve ses droits | Retenu ; historique maintenance |
| `interventions` | Actions fonctionnelles à décomposer selon préparation, exécution, validation et clôture réellement disponibles | RA conserve ses droits | Retenu ; historique des interventions |
| `inspections_reglementaires` | Actions fonctionnelles à décomposer selon planification, réalisation, résultat et validation | RA conserve ses droits | Retenu ; échéances, résultats et justificatifs réglementaires |
| `pannes` | Actions fonctionnelles à décomposer selon déclaration, diagnostic, traitement et clôture | RA, CC, CT conservent leurs droits | Retenu ; historique panne/diagnostic/intervention |

## 7. Anomalies et précisions du lot 2

| Référence | Constat | Traitement avant gel |
| --- | --- | --- |
| A-07 | `correct` apparaît pour les pointages/feuilles de temps mais n'est pas une action canonique | Décider si `update` couvre la correction avec journalisation obligatoire, ou ajouter une action canonique après arbitrage |
| TimeTracking | `timetracking.timesheets.validate` utilise un alias de ressource | Normaliser vers `timetracking.feuilles_de_temps.validate` si cette permission historique est bien à conserver |
| Workforce | `donnees_medicales` et `justificatifs_medicaux` | Définir les métadonnées/champs accessibles et les restrictions M-17 ; aucune ouverture générale des documents médicaux détaillés |
| Workforce | Suppression de données RH, paie, coordonnées bancaires | Confirmer que les actions `delete` sont logiques et légalement autorisées ; conservation et audit prioritaires |
| Workforce | Validation de coordonnées bancaires et paie | Modéliser la séparation de tâches dans les policies/workflows ; aucune auto-approbation |
| Procurement | Fournisseurs, sous-traitants, besoins, offres, évaluations, accords-cadres, garanties et incidents | Décomposer les actions à partir du workflow réel avant génération des slugs |
| Procurement | `lignes_commande` | Confirmer si préparation/soumission/approbation sont portées par la commande ou par chaque ligne |
| Inventory | Annulation/inversion des mouvements et consommations | Utiliser `reverse` si l'opération est compensatoire ; ne pas supprimer les écritures historiques |
| Equipment | Affectations, maintenance, interventions, inspections et pannes | Décomposer les actions à partir des écrans et transitions réellement disponibles |
| DIR | Accès complet aux domaines du lot 2 | Associer DIR à chaque permission fonctionnelle retenue ; les limites légales, médicales et de séparation des tâches restent actives |




## 8. Lot 3 — Logistics, Quality, Safety, Documents, Handover et Reporting

> Les ressources et contraintes sont reprises des sections 5.13 à 5.19 de la matrice. Les formulations « toutes actions applicables » restent à décomposer à partir des opérations réellement disponibles ; aucune action supplémentaire n'est créée par simple déduction. DIR reçoit chaque permission fonctionnelle retenue, avec les exceptions de confidentialité, de séparation des tâches, de conservation et de preuve.

### 8.1 Logistics

| Ressource | Actions candidates | Rôles hors DIR / portée | Statut / contraintes |
| --- | --- | --- | --- |
| `demandes_transport` | À décomposer selon création, mise à jour, soumission, validation et traitement réellement disponibles | RA, CT conservent leurs droits | Retenu ; périmètres atelier/chantiers selon affectation |
| `plans_transport` | À décomposer selon préparation, modification, validation et clôture réellement disponibles | RA, CT conservent leurs droits | Retenu ; versions et historique à conserver |
| `tournees` | À décomposer selon planification, affectation, modification et clôture réellement disponibles | RA, CT conservent leurs droits | Retenu ; historique des tournées |
| `livraisons` | À décomposer selon préparation, expédition, suivi, preuve de livraison et traitement des écarts | RA, CT, CC conservent leurs droits | Retenu ; preuves et événements de livraison conservés |
| `receptions_chantier` | À décomposer selon réception, constat, réserves et validation réellement disponibles | RA, CT, CC conservent leurs droits | Retenu ; ne pas confondre avec la réception finale Handover |
| `retours` | À décomposer selon déclaration, traitement, réception retour et clôture | RA conserve ses droits | Retenu ; historique des retours |
| `acces_chantier` | `view`, `create`, `update`, `delete` candidats ; autres actions spécifiques à identifier | CT : `view` ; `update` à arbitrer ; CC : `view` | Retenu pour DIR ; CT update reste à arbitrer ; autorisations d'accès historisées |

### 8.2 Quality

| Ressource | Actions candidates | Rôles hors DIR / portée | Statut / contraintes |
| --- | --- | --- | --- |
| `plans_qualite` | À décomposer selon création, révision, validation et diffusion | CT, RA, CC conservent leurs droits | Retenu ; versions conservées |
| `plans_controle` | À décomposer selon définition, modification, validation et exécution | CT, RA, CC conservent leurs droits | Retenu |
| `controles_qualite` | À décomposer selon création, réalisation, revue et validation | CT, CC, RA conservent leurs droits | Retenu ; résultats et validations tracés |
| `non_conformites` | À décomposer selon déclaration, qualification, traitement, vérification et clôture | CT, CC, RA conservent leurs droits | Retenu ; historique complet du traitement et de la clôture |
| `actions_correctives` | À décomposer selon création, affectation, suivi, vérification et clôture | RA, CT conservent leurs droits | Retenu ; preuves conservées |
| `audits_qualite` | À décomposer selon planification, réalisation, constats, rapport et clôture | RA, CT conservent leurs droits | Retenu ; piste d'audit |
| `certificats_qualite` | À décomposer selon dépôt, consultation, renouvellement et archivage | RA, CT conservent leurs droits | Retenu ; échéances et versions conservées |
| `qualifications_techniques` | À décomposer selon gestion du référentiel et justificatifs | RA, CT conservent leurs droits | Retenu ; cohérence avec Workforce à vérifier sans dupliquer les objets |
| `signalements` | `create` SAL ; traitement des signalements à décomposer | SAL : `create` / own | Retenu ; distinct des non-conformités ; auteur et historique préservés |

### 8.3 Safety

| Ressource | Actions candidates | Rôles hors DIR / portée | Statut / contraintes |
| --- | --- | --- | --- |
| `analyses_risques` | À décomposer selon création, révision, validation et diffusion | RA, CT, CC conservent leurs droits | Retenu ; versions et preuves conservées |
| `plans_prevention` | À décomposer selon préparation, mise à jour, validation et diffusion | RA, CT, CC conservent leurs droits | Retenu |
| `inspections_securite` | À décomposer selon planification, réalisation, constat, suivi et clôture | CC, RA, CT conservent leurs droits | Retenu ; constats et suites tracés |
| `incidents` | À décomposer selon déclaration, traitement, analyse, action et clôture | CC, RA, CT conservent leurs droits | Retenu ; historique des incidents |
| `actions_securite` | À décomposer selon création, affectation, suivi, vérification et clôture | RA, CT conservent leurs droits | Retenu ; suivi et clôture tracés |
| `habilitations` | À décomposer selon création, contrôle, renouvellement, suspension et archivage | RA, ADM, CT, CC conservent leurs droits | Retenu ; validités et justificatifs conservés |
| `autorisations_travail` | À décomposer selon demande, délivrance, modification, suspension et clôture | RA, ADM, CT, CC conservent leurs droits | Retenu ; autorisations et preuves historisées |
| `inductions` | À décomposer selon planification, réalisation, validation et preuve de participation | RA, ADM, CT, CC conservent leurs droits | Retenu |
| `signalements` | `create` SAL ; traitement des signalements à décomposer | SAL : `create` / own | Retenu ; distinct des incidents ; auteur et historique préservés |

### 8.4 Documents

| Ressource | Actions candidates | Rôles hors DIR / portée | Statut / contraintes |
| --- | --- | --- | --- |
| `documents` | À décomposer : `view`, `create`, `update`, `delete` conditionnel, `download`, `sign`, `archive`, `validate` selon fonctionnalités présentes | ADM, CT, CC, RA, GAF, SAL conservent leurs droits selon périmètre | Retenu ; inclut les dossiers administratifs clients et leurs pièces ; M-17 reste ouvert |
| `versions` | À décomposer selon création de version, consultation et restauration si elle existe | Droits documentaires existants | Retenu ; versions et traces conservées |
| `dossiers_documentaires` | À décomposer selon création, classement, modification, validation et clôture | ADM, CT, CC, RA, GAF, SAL selon périmètre | Retenu ; ne pas créer de ressource séparée pour les dossiers administratifs clients |
| `types_document` | À décomposer selon gestion du référentiel | ADM conserve ses droits | Retenu |
| `regles_conservation` | À décomposer selon consultation, création et modification réellement disponibles | ADM conserve ses droits | Retenu ; aucune suppression contraire à une obligation légale |
| `diffusions` | À décomposer selon préparation, envoi, suivi et accusé de réception | ADM, CT, CC, RA, SAL conservent leurs droits | Retenu ; destinataires, dates, versions diffusées et accusés conservés |
| `download` / `sign` | Actions transverses à rattacher à la ressource documentaire selon le modèle technique, pas de ressource autonome présumée | SAL : téléchargement/signature own | À modéliser ; signature selon délégation, identité et preuve |
| `exports` | `export` candidat, avec génération/téléchargement selon le workflow | ADM, GAF conservent leurs droits | Retenu ; mêmes restrictions de confidentialité et d'accès que les documents sources |

**Restriction M-17 :** qualifier les catégories et champs documentaires sensibles avant de définir les permissions finales. L'accès DIR global ne lève ni secret médical, ni confidentialité légale, ni obligation de conservation.

### 8.5 Handover

| Ressource | Actions candidates | Rôles hors DIR / portée | Statut / contraintes |
| --- | --- | --- | --- |
| `dossiers_reception` | À décomposer ; `approve`, `validate`, `close` explicitement candidats | CT, CC conservent leurs droits | Retenu ; preuves, décisions, réserves et historique de clôture conservés |
| `reserves` | À décomposer selon création, affectation, suivi et clôture | CT, CC conservent leurs droits | Retenu |
| `levees_reserves` | À décomposer selon constat, preuve, vérification et validation | CT, CC conservent leurs droits | Retenu ; preuves, dates et responsables conservés |
| `doe` | À décomposer selon constitution, mise à jour, validation et remise | CT, CC conservent leurs droits | Retenu ; versions et preuves de remise conservées |
| `garanties_clients` | À décomposer selon enregistrement, suivi, déclaration et clôture | CT, ADM conservent leurs droits | Retenu ; échéances et historiques conservés |
| `dossiers_cloture` | À décomposer ; `close` explicitement candidat | CT, ADM conservent leurs droits | Retenu ; pièces justificatives historisées |

### 8.6 Reporting

| Ressource | Actions candidates | Rôles hors DIR / portée | Statut / contraintes |
| --- | --- | --- | --- |
| `rapports` | `view`, `create`, `update`, `delete` conditionnel, `export`, `validate` si disponibles | ADM, CT, CC, RA conservent leurs droits selon rapport | Retenu ; sources et historiques préservés |
| `indicateurs` | À décomposer selon définition, calcul, validation et publication | Droits existants selon rôle | Retenu ; définitions et périodes conservées |
| `tableaux_bord` | À décomposer selon consultation, configuration et partage | Droits existants selon rôle | Retenu |
| `tableaux_bord_strategiques` | À décomposer selon consultation et configuration | DIR global | Retenu |
| `snapshots` | À décomposer selon création, consultation, export et suppression techniquement permise | SAL : consultation own si applicable | Retenu ; horodatage, périmètre, source et intégrité préservés |
| `exports` | À décomposer selon préparation, génération, consultation, téléchargement et export | ADM, GAF conservent leurs droits | Retenu ; M-05 levé pour Reporting ; confidentialité et traçabilité restent actives |

## 9. Anomalies et précisions du lot 3

| Référence | Constat | Traitement avant gel |
| --- | --- | --- |
| Logistics | `acces_chantier.update` CT est à confirmer | Arbitrer le droit CT sans modifier l'accès DIR global |
| Quality / Safety | `signalements` existe dans les deux domaines | Confirmer s'il s'agit de deux flux distincts ou d'un objet commun catégorisé ; ne pas fusionner sans analyse |
| Documents | `download` et `sign` sont présentés comme actions transverses dans la matrice | Rattacher aux ressources documentaires ; ne pas créer de ressources autonomes sans modèle technique |
| Documents | M-17 catégories/champs sensibles | Définir les restrictions de consultation, téléchargement, export et signature ; secret médical exclu |
| Handover | Réception chantier logistique vs réception finale | Confirmer la frontière entre `logistics.receptions_chantier` et `handover.dossiers_reception` |
| Reporting | Exports du domaine Reporting | M-05 levé selon matrice ; garder les contrôles de confidentialité |
| DIR | Accès global au lot 3 | Attribuer explicitement chaque permission fonctionnelle retenue, sauf préparation/exécution des paiements et restrictions légales/documentaires |


## 10. Anomalies à résoudre avant gel

| Référence | Constat | Traitement |
| --- | --- | --- |
| A-07 | `treat` est cité pour les litiges, absent du registre | Déterminer si `process` le remplace ou si une action distincte est nécessaire |
| A-07 | `correct` est cité pour les pointages/corrections, absent du registre | Vérifier si `update` couvre la correction ; la traçabilité relève du workflow |
| A-07 | `refuse` apparaît dans le workflow paiement, absent du registre | Déterminer si le refus est un résultat de workflow ou une permission distincte |
| Identity | `financial_delegations` sous Identity, mais DIR n'administre pas les habilitations | Clarifier propriétaire et exception DIR |
| Costing | `marges` au statut « Proposé » | Exclure du catalogue initial ou obtenir validation |
| Projects | Rattachement de `lots_phases` validé par A-17 ; actions atomiques non définies | Décrire les workflows réels avant de générer les permissions définitives |
| DIR | « Toutes actions applicables » n'est pas une liste d'actions | Identifier les actions légitimes par ressource, puis associer explicitement DIR |


## 11. Lot 4 — déduplication, normalisation et contrôle de cohérence

### 11.1 Résultat de la revue transversale

La revue porte sur les 18 domaines fonctionnels inventoriés dans les lots 1 à 3, les huit rôles et les conventions A-01 à A-09. Elle constitue un contrôle documentaire, pas une validation technique issue d'un scan du code applicatif.

| Contrôle | Résultat | Conclusion |
| --- | --- | --- |
| Couverture des domaines | 6 domaines lot 1, 6 domaines lot 2, 7 domaines lot 3 | 18 domaines couverts dans l'inventaire |
| Couverture des rôles | SA, DIR, ADM, CT, CC, RA, SAL, GAF présents dans la matrice §6 | Matrice synthétique des 8 rôles existante ; associations atomiques à matérialiser au catalogue |
| Atomicité | Actions séparées par ressource dans les lots 1 et 2 ; plusieurs ressources lot 3 encore « à décomposer » | Non gelable à ce stade |
| Règle DIR | Règle globale documentée ; exceptions Identity, secret médical, paiements, auto-approbation, conservation et audit | Principe stable ; associations explicites à générer au catalogue |
| Slugs | A-01 à A-09 établissent les conventions | Mapping complet ressource/action encore à vérifier |
| Scopes | Portées opérationnelles décrites dans la matrice §8 | Implémentation des Policies et scopes réservée à CHAN-42 |
| Workflow | Seuils, validations et séparation des tâches décrits séparément | Ne pas transformer les règles de workflow en permissions génériques |
| Traçabilité | Événements sensibles recensés dans la matrice §10 | Stockage/audit technique non livré par CHAN-40 à ce stade |

### 11.2 Déduplication et frontières de propriété

| Objets ou fonctions proches | Décision de revue | Conséquence pour le catalogue |
| --- | --- | --- |
| Clients / facturation client | Propriétaire métier unique : Clients ; les pièces et leur suivi restent dans ce domaine, sans écriture comptable associée. | Conserver les permissions dans `clients`; ne créer aucune ressource comptable. |
| Budgets / révisions budgétaires | Budgets reste propriétaire des budgets et de leurs révisions ; aucun traitement comptable n'est géré. | Aucune permission comptable ; les révisions restent exclusivement dans Budgets. |
| Costing / données analytiques de gestion | Costing conserve chiffrages, coûts, écarts, marges, provisions et périodes analytiques comme outils de gestion opérationnelle, sans écritures comptables. | Aucune permission comptable ; les objets de gestion restent exclusivement dans Costing. |
| Documents / Reporting / exports | Distinguer export documentaire et rendu de rapport selon les workflows et données sources ; aucune extraction comptable n'est prévue. | Garder les ressources candidates en attente jusqu'à qualification des données sources, formats, acteurs et finalités. |
| Quality / Safety — signalements | La matrice attribue des signalements à chaque domaine et distingue les circuits qualité/sécurité. La ressemblance du nom ne suffit pas à conclure à un doublon. | Conserver deux candidats distincts jusqu'à confirmation du modèle : `quality.signalements` et `safety.signalements`. |
| Logistics / Handover — réceptions | La réception logistique sur chantier et la réception contractuelle/finale n'ont pas la même finalité. Projects possède également `receptions` contractuelles. | Trois objets candidats distincts à confirmer par modèle : `logistics.receptions_chantier`, `projects.receptions`, `handover.dossiers_reception`. Ne pas fusionner par homonymie. |
| Workforce / Safety — qualifications et habilitations | Workforce porte les qualifications/formations RH ; Safety porte les habilitations et autorisations de sécurité si elles ont un cycle réglementaire propre. | Référencer les justificatifs et statuts communs ; ne pas dupliquer une même entité sans distinction de cycle de vie. |
| Workforce / TimeTracking — absences et justificatifs | Workforce porte le dossier RH ; TimeTracking porte le workflow d'absence et ses justificatifs minimisés. | Séparer dossier administratif et workflow de temps ; données médicales détaillées exclues. |
| Planning / Equipment — affectations | Planning porte les affectations de ressources aux activités ; Equipment porte les affectations et la garde des équipements. | Slugs distincts si les objets et historiques sont distincts ; éviter une permission générique d'affectation commune. |
| Workshop / Inventory — mouvements et consommations | Workshop décrit la demande/consommation de production ; Inventory porte le mouvement de stock comptable/opérationnel. | Un workflow de consommation peut référencer un mouvement ; ne pas créer deux droits d'écriture sur le même événement stock. |

### 11.3 Normalisation des actions A-07

| Anomalie ou usage | Décision de normalisation | État |
| --- | --- | --- |
| `treat` sur les litiges de facturation | Utiliser `process` pour l'analyse, l'enregistrement des échanges et justificatifs, la proposition de solution/régularisation et le suivi opérationnel jusqu'à résolution ; `arbitrate` reste réservé à la décision d'arbitrage engageante. | **Validé** : workflow opérationnel GAF confirmé ; arbitrage distinct réservé à la Direction selon ses habilitations |
| `correct` sur les pointages | Ne pas créer une action supplémentaire : utiliser `update` sur le workflow de correction dédié, avec événement immuable contenant avant/après, auteur, date, motif et valideur. | **Validé** : correction par mise à jour tracée ; pas de permission `correct` ni d'auto-validation |
| `refuse` sur les paiements | Le refus est un résultat/état de la décision d'autorisation ; ne pas créer de permission `refuse`. Les paiements bancaires étant hors périmètre de CHAN-40, aucune permission de paiement n'est retenue dans ce catalogue. | **Hors périmètre** : aucun droit `refuse`, `authorize` ou d'exécution de paiement à créer dans CHAN-40 |
| `approve` / `authorize` | `approve` désigne une approbation métier ; `authorize` l'autorisation explicite d'une opération. Ne pas confondre ces actions ni introduire une autorisation de paiement hors périmètre. | Sémantique A-07 conservée ; application limitée aux workflows effectivement retenus |
| `delete` / `archive` / `deactivate` / `revoke` / `suspend` | Actions non interchangeables ; utiliser seulement selon le cycle de vie réel et les contraintes de conservation. | Sémantique A-07 conservée |
| `download` / `sign` | Actions rattachées à une ressource documentaire ou à un type de document autorisé ; pas de ressource autonome. | À relier aux objets/documents dans le modèle |

### 11.4 Cohérence de la matrice des huit rôles

La matrice §6 de `authorization-matrix.md` est la référence synthétique pour les huit rôles. Les principes à préserver lors de la génération des associations explicites sont :

| Rôle | Profil d'attribution à conserver | Contrôles structurants |
| --- | --- | --- |
| SA | Administration technique des habilitations et capacité métier globale | Secret médical, Policies CHAN-42, audit immuable, pas d'auto-approbation |
| DIR | Toutes permissions fonctionnelles retenues, scope global | Exclusion Identity administration, secret médical détaillé, préparation/exécution des paiements ; pas d'auto-autorisation |
| ADM | Administration et préparation administrative, RH courante et clients selon matrice | Pas d'approbation financière, de paiement, de validation finale paie, de données RH sensibles non autorisées |
| CT | Pilotage des affaires/chantiers affectés, préparation/suivi et validations explicitement prévues | Pas d'approbation financière générale ni d'auto-approbation de ses révisions ; scopes CHAN-42 |
| CC | Exécution quotidienne sur chantiers/équipes affectés | Pas de budgets/coûts/marges, finance, commande ou réception formelle ; scopes CHAN-42 |
| RA | Production/atelier, équipe, stocks, équipements, qualité/sécurité atelier | Pas d'engagement financier autonome ; validations personnelles auditées |
| SAL | Accès personnel `own` aux informations et opérations expressément prévues | Pas de panel, d'accès aux données d'autrui, d'auto-validation, de finance/commerce/comptabilité |
| GAF | Gestion administrative et financière opérationnelle : clients, achats, RH/paie, consultation et suivi des budgets/Costing selon les permissions de chaque ressource | Aucune fonction comptable ; aucun droit de préparation, d'autorisation ou d'exécution de paiement bancaire ; aucune approbation générale d'engagement ou de commande ; aucune validation finale de paie |

Cette table est un résumé de contrôle, pas un seeder ni une matrice exhaustive de permissions. Les associations finales doivent être explicites par permission atomique, sans héritage implicite.

### 11.5 Points consolidés et décisions non encore gelables

| Sujet | État lot 4 | Action avant gel |
| --- | --- | --- |
| A-01 à A-06, A-08, A-09 | Conventions documentées | Contrôle mécanique de toutes les clés du catalogue à effectuer au moment de sa construction |
| A-07 `treat`, `correct`, `refuse` | Mapping proposé | Confirmer les workflows réels ; ne pas ajouter ces actions au registre canonique |
| Identity `financial_delegations` | DIR exclu de l'administration des habilitations ; SA administre | Déterminer si cette ressource est une délégation financière métier ou un paramètre d'accès Identity ; déplacer vers le domaine financier si nécessaire |
| Costing `marges` | Statut source « proposé » | Exclure du catalogue initial tant que la ressource n'est pas confirmée |
| Projects `lots_phases` | A-17 validé le 24/11/2026 : Affaire 1—N Chantier, Chantier 1—N Lot, Lot 1—N Phase | Appliquer `assigned_sites` aux accès opérationnels CT/CC via le chantier parent ; définir les actions atomiques séparément |
| Procurement, Inventory, Equipment, Logistics, Quality, Safety, Documents, Handover, Reporting | Plusieurs lignes « à décomposer » | Reprendre les opérations métier et finaliser chaque action réelle |
| M-17 | Ouvert | Définir catégories/champs sensibles et droits download/sign/export par catégorie |
| M-01 à M-16 | Paramètres/workflows résiduels documentés dans la matrice | Résoudre ceux qui conditionnent les permissions concernées ; ne pas bloquer les permissions indépendantes |
| Matrice des 8 rôles | Synthèse existante, associations atomiques non générées | Décliner chaque ligne de ressource/action vers SA, DIR, ADM, CT, CC, RA, SAL, GAF |
| Audit | Événements définis, stockage technique non confirmé | Confirmer l'affectation CHAN-45 ou ticket dédié |

### 11.6 Décision de gel

**Le catalogue n'est pas gelé.** Les lots 1 à 3 couvrent le périmètre documentaire des 18 domaines, mais une partie des actions du lot 3 reste à décomposer, des choix de modèle et de propriété demeurent ouverts, et la matrice des huit rôles n'est pas encore convertie en associations atomiques exhaustives. Les anomalies A-07 ont un mapping proposé, pas une validation issue d'un test de workflow. Aucun code, migration, seeder ou test d'autorisation n'a été créé dans les lots documentaires.




## 12. Lot 5 — audit croisé avec le catalogue des objets métier et le dépôt

### 12.1 Sources et portée du contrôle

Contrôle documentaire réalisé le 24/11/2026 sur :
- `docs/development/authorization-matrix.md` ;
- `docs/architecture/business-objects.md` ;
- l'arborescence Git de la branche `chan-40-roles-permissions` ;
- `app/Models/User.php` et `config/permission.php`.

Le référentiel RBAC doit rester limité aux domaines métier retenus, sans domaine comptable. Les domaines `app/Domains/*` sont encore des répertoires vides contenant uniquement `.gitkeep` ; aucun workflow métier PHP ne permet donc de confirmer les actions candidates des lots 2 et 3. Le contrôle documentaire ne doit pas être présenté comme une revue du comportement applicatif.

### 12.2 Écarts entre le catalogue des objets et l'inventaire RBAC

| Sujet | Constat sourcé | Traitement requis avant gel |
| --- | --- | --- |
| Comptabilité | Le catalogue des objets métier ne comporte aucun objet comptable et la décision de périmètre exclut tout module comptable. | Ne créer aucun objet, ressource ou permission comptable. |
| Projects / `lots_phases` | L'objet `PRJ-03 LotPhase` existe dans le catalogue métier ; le rattachement a été validé par A-17 le 24/11/2026. | Modèle retenu : Affaire 1—N Chantier, Chantier 1—N Lot, Lot 1—N Phase. Un lot appartient à un seul chantier ; une phase appartient obligatoirement à un seul lot et hérite du chantier. Scope opérationnel `assigned_sites` via le chantier parent ; actions atomiques encore à définir. |
| Identity / `financial_delegations` | Le catalogue métier contient `IDN-05 Délégation`, tandis que la matrice place `financial_delegations` dans Identity et interdit à DIR l'administration technique des habilitations. | Distinguer la délégation de pouvoir financier métier de l'administration RBAC. Identifier le propriétaire du workflow, les acteurs, les catégories et les effets sur l'autorisation avant de fixer les permissions DIR/SA. |
| Costing / `marges` | `CST-05 Marge` figure parmi les 8 objets Costing, mais l'inventaire RBAC conserve la ressource au statut « à préciser / proposé ». | L'objet métier est identifié ; cela ne valide pas automatiquement une ressource autonome ni une permission `view`. Confirmer si la marge est une donnée calculée de Costing ou un objet consultable distinct. |
| Workforce | Le catalogue métier D07 liste 9 objets, mais la matrice/inventaire RBAC mentionne aussi paies, bulletins, écritures de paie, coordonnées bancaires, dossiers disciplinaires, données médicales et grands déplacements. | Qualifier chacun comme objet autonome, sous-objet du dossier RH ou donnée/processus géré par un autre domaine. Maintenir les restrictions médicales, bancaires et de paie pendant cette qualification. |
| TimeTracking | Le catalogue métier comprend l'imputation de temps, les corrections et les absences ; l'inventaire RBAC ne décrit pas encore clairement une ressource autonome pour l'imputation et mentionne en plus les heures supplémentaires et justificatifs médicaux. | Déterminer si l'imputation est une ressource autonome ou une capacité de pointage ; qualifier les heures supplémentaires comme workflow/objet ; garder les justificatifs médicaux hors des permissions générales de documents détaillés. |
| Workshop | Le catalogue métier comprend `DossierDeFabricationExterne` (WKS-08), absent des ressources listées dans l'inventaire RBAC. | Confirmer si l'objet est utilisé dans le périmètre CHAN-40 et, si oui, définir ses actions et rôles ; sinon le déclarer explicitement hors catalogue initial. |
| Procurement | Le catalogue des objets ne liste pas explicitement `besoins`, `factures_fournisseurs` et `incidents_sous_traitance`, alors que la matrice RBAC les cite. | Distinguer objets autonomes et processus d'approvisionnement ; confirmer la propriété métier avant d'attribuer des permissions. |
| Quality / Safety | Les ressources `signalements` sont présentes dans la matrice RBAC, mais ne figurent pas dans les catalogues d'objets D14/D15. | Confirmer leur autonomie et leur distinction entre signalement qualité et signalement sécurité, ou les rattacher à un objet existant avec une catégorie explicite. |
| Documents | L'inventaire RBAC ajoute `exports`, alors que le catalogue métier identifie les six objets DOC-01 à DOC-06 sans objet Export dédié. | Traiter l'export comme action sur une ressource documentaire ou confirmer un objet d'export autonome avec cycle de vie, destinataires et conservation. |
| Reporting | La matrice RBAC cite `tableaux_bord_strategiques` et `exports`, alors que le catalogue métier D18 liste `TableauDeBord` et `Export` sans distinction stratégique. | Déterminer si le tableau stratégique est une audience/configuration du tableau de bord ou un objet distinct ; séparer les exports uniquement si le workflow et les données sources diffèrent. |
| Annuaire / messagerie | `directory` et `messages` apparaissent dans la matrice Identity, sans objet correspondant au catalogue métier. | Garder ces permissions à arbitrer ; confirmer leur périmètre et leur propriétaire avant inclusion. |
| Sessions | Le catalogue RBAC les renvoie à CHAN-43. | Ne pas les intégrer à CHAN-40. |

### 12.3 Constat technique vérifié

| Élément | Constat sur la branche contrôlée | Conséquence |
| --- | --- | --- |
| Domaines métier | Les répertoires `app/Domains/*` ne contiennent que `.gitkeep`. | Impossible de déduire les actions réelles depuis les services métier ; les lignes « à décomposer » ne peuvent pas être complétées par une inspection de code. |
| Modèle utilisateur | `App\\Models\\User` utilise `HasRoles` et implémente `FilamentUser`. | Le socle Spatie est présent ; cela ne prouve aucune association de rôle ou permission métier. |
| Accès Filament | `canAccessPanel()` retourne actuellement `true`. | Le contrôle `identity.admin_panel.access` reste un livrable technique non implémenté. |
| Configuration Spatie | Guard par défaut, Teams désactivé et wildcard désactivé dans la configuration contrôlée. | Les principes de configuration sont conformes au cadrage ; catalogue, rôles et associations restent absents. |

### 12.4 Registre des blocages avant gel

| Priorité | Blocage | Pourquoi il bloque | Décision ou preuve attendue |
| --- | --- | --- | --- |
| P0 | Associations atomiques des 8 rôles incomplètes | Le catalogue ne peut pas être généré sans attribution explicite, notamment pour SA, ADM, CT, CC, RA, SAL et GAF | Matrice exhaustive permission × rôle, avec scopes documentés séparément |
| P0 | Ressources/actions des lots 2 et 3 non décomposées | Les lignes « toutes actions applicables » ne sont pas des permissions atomiques | Définition métier des actions et preuve du workflow ou de l'objet |
| P1 | A-17 — actions et scopes lots/phases | Le rattachement est validé ; les actions et attributions détaillées restent à établir | Décrire les workflows réels ; appliquer `assigned_sites` via le chantier parent pour CT/CC et le scope global DIR |
| P1 | M-17 — catégories documentaires sensibles | Les permissions de lecture, téléchargement, signature et export peuvent exposer des données protégées | Classification des catégories/champs et règles d'accès |
| P1 | Workforce / paie / données bancaires / médicales | Objets, sous-objets et processus ne sont pas distingués partout | Cartographie de propriété et matrice de confidentialité |
| P1 | Procurement / Inventory / Equipment / Logistics / Quality / Safety / Handover / Reporting | Les actions et parfois la propriété des objets restent à préciser | Décomposition par workflow, sans action générique |
| P1 | Frontières opérationnelles Clients / Procurement / Budgets / Costing | Vérifier que les pièces et workflows restent dans leur domaine propriétaire et qu'aucun traitement comptable n'est introduit | Référentiel métier et permissions opérationnelles cohérents |
| P2 | A-07 : `treat`, `correct`, `refuse` | Les mappings du lot 4 sont des propositions, pas des validations métier | Confirmation des workflows concernés |
| P2 | Identity : délégations financières, annuaire, messagerie | Propriété et périmètre fonctionnel non confirmés | Décisions métier et séparation Identity / Finance |

### 12.5 Ordre de résolution recommandé

1. Trancher les objets RBAC qui ne figurent pas dans le catalogue métier de 132 objets, sans introduire d'objet comptable.
2. Résoudre la propriété et la nature des ressources transverses ou sensibles : délégations financières, paie, données bancaires, signalements, exports.
3. Décomposer les actions réelles des ressources des lots 2 et 3 à partir de workflows métier validés ; le dépôt ne contient pas encore de code permettant cette vérification.
4. Définir les actions atomiques des lots/phases à partir des workflows réels et traiter M-17, sans étendre leurs effets aux permissions indépendantes.
5. Construire la matrice atomique des huit rôles, appliquer explicitement la règle DIR et ses exceptions, puis effectuer les contrôles de cohérence des slugs et des doublons.
6. Présenter le catalogue consolidé pour validation formelle ; aucun gel ni développement RBAC ne doit précéder cette validation.

**Conclusion du lot 5.** L'audit croisé met en évidence des écarts de référentiel et confirme que les domaines métier ne sont pas encore implémentés dans le dépôt. Il est donc possible de préciser les blocages et les décisions attendues, mais pas de transformer honnêtement les actions « à décomposer » en permissions atomiques sans arbitrages métier supplémentaires. Le catalogue reste non gelé ; aucune migration, aucun seeder, aucune permission métier et aucun test d'autorisation ne sont créés dans ce lot.


## 13. État des lots documentaires

- **Lot 1 :** Identity, Clients, Projects, Planning, Budgets et Costing.
- **Lot 2 :** Workforce, TimeTracking, Workshop, Procurement, Inventory et Equipment.
- **Lot 3 :** Logistics, Quality, Safety, Documents, Handover et Reporting.
- **Lot 4 :** revue transversale, déduplication et normalisation ; les associations atomiques des huit rôles ne sont pas encore générées.
- **Lot 5 :** audit croisé avec le catalogue des objets métier et le dépôt ; écarts et blocages consignés.

Les lots 1 à 5 sont documentés. Cette couverture ne signifie pas que toutes les ressources et actions sont gelées : les points ouverts sont regroupés en §11.5, §12.4 et §17 ci-dessous. Le rattachement A-17 est validé ; seules les actions atomiques et attributions détaillées des lots/phases restent à définir. M-17 demeure ouvert pour les catégories documentaires sensibles.

## 14. Critères de gel

1. Une entrée unique par triplet domaine/ressource/action.
2. Résolution des anomalies A-07 et des slugs ambigus.
3. Séparation entre permissions et règles de workflow.
4. Attribution explicite aux huit rôles, sans héritage implicite.
5. Application explicite de la règle DIR et de ses exceptions.
6. Scopes opérationnels documentés pour CHAN-42, hors slug.
7. Absence de doublons entre domaines propriétaires des pièces et workflows opérationnels.
8. Validation des ressources proposées ou exclusion explicite du catalogue initial.


## 15. Décision de périmètre — exclusion

Décision utilisateur : le logiciel C2ME ne comportera aucune partie comptable. Le domaine D19 Accounting n'est pas retenu dans le catalogue CHAN-40 ; aucune ressource, action ou permission comptable ne doit être ajoutée. Le rôle GAF est conservé comme profil de gestion administrative et financière opérationnelle ; aucune permission ni ressource comptable ne doit être créée. Les processus opérationnels de facturation client, achats/factures fournisseurs, budgets, costing et paie restent dans leurs domaines métier respectifs uniquement pour leurs besoins de gestion ; aucune écriture, journal, rapprochement, trésorerie comptable, déclaration, clôture, immobilisation ou amortissement comptable n'est géré dans le logiciel.


## 16. Définition du rôle GAF

Le rôle GAF remplace l'ancien rôle CPT. Il couvre les opérations administratives et financières opérationnelles : factures, avoirs, relances, échéanciers, litiges et suivi opérationnel des règlements clients ; traitement administratif des commandes et factures fournisseurs ; paie, bulletins, éléments variables et données nécessaires à la gestion administrative ; consultation et suivi opérationnel des budgets et du Costing selon les permissions définies pour chaque ressource.

Sont exclus : écritures comptables, journaux, plan comptable, rapprochements bancaires comptables, trésorerie comptable, déclarations, clôtures comptables, immobilisations et amortissements. Aucun droit de préparation, d'autorisation ou d'exécution de paiement bancaire n'est attribué à GAF.


## 17. Finalisation documentaire — synthèse de référence (24/11/2026)

Cette synthèse prévaut sur les formulations historiques des lots précédents. Elle ne vaut ni gel du catalogue ni validation métier des actions encore à décomposer.

### 17.1 État consolidé

- Les 18 domaines sont couverts par les lots documentaires 1 à 3 ; les lots 4 et 5 ont assuré la revue transversale et l'audit croisé.
- Les huit rôles sont définis dans la matrice. Le présent inventaire ne constitue pas encore une matrice atomique exhaustive permission × rôle.
- DIR reçoit toutes les permissions fonctionnelles atomiques effectivement retenues, avec scope global, sous réserve des exceptions documentées. Cette règle ne justifie pas d'inventer des actions.
- GAF est le rôle de gestion administrative et financière opérationnelle ; aucune permission comptable et aucun droit de préparation, d'autorisation ou d'exécution de paiement bancaire ne lui sont attribués.
- Les factures clients et avoirs restent dans Clients ; les factures fournisseurs et commandes fournisseurs relèvent de Procurement. Budgets et Costing restent dans leurs domaines respectifs. Ces processus opérationnels ne constituent pas un module comptable.
- Les obligations de conservation des pièces et preuves ne sont pas des fonctions comptables et ne créent aucune permission comptable.

### 17.2 Liste de sortie avant gel

| Référence | Travail restant | Règle de traitement |
| --- | --- | --- |
| A-07 | Confirmer les mappings proposés pour les litiges, corrections de pointage et refus | Ne pas ajouter `treat`, `correct` ou `refuse` au registre canonique sans workflow distinct confirmé ; `process` et `update` restent candidats selon la matrice. |
| A-17 | Rattachement des lots/phases validé le 24/11/2026 : Affaire 1—N Chantier, Chantier 1—N Lot, Lot 1—N Phase | `assigned_sites` via le chantier parent pour les accès opérationnels CT/CC ; DIR global. Définir les actions atomiques et les attributions restantes à partir des workflows réels. |
| M-01 à M-16 | Résoudre les paramètres/workflows qui conditionnent une permission | Ne bloquer que les ressources dépendantes ; conserver les permissions indépendantes. |
| M-17 | Qualifier les catégories/champs documentaires sensibles | Appliquer des droits par catégorie et opération ; aucun accès général par défaut. |
| Ressources transverses | Qualifier délégations financières, annuaire, messagerie, signalements, exports et sous-objets RH/paie | Confirmer propriétaire, autonomie, cycle de vie et confidentialité avant création de permissions. |
| Actions des domaines lots 2 et 3 | Décomposer les lignes « à décomposer » à partir des workflows réels | Aucun CRUD ou droit de validation ne doit être inféré de la seule existence d'une ressource. |
| Matrice des rôles | Produire les associations explicites de chaque permission atomique pour SA, DIR, ADM, CT, CC, RA, SAL et GAF | Pas d'héritage implicite ; appliquer les exceptions DIR et les scopes CHAN-42 séparément. |
| Audit métier | Confirmer le rattachement de l'audit métier immuable à CHAN-45 ou à un lot dédié | Ne pas confondre définition des événements et stockage technique. |

### 17.3 Critères de gel — contrôle final

Le catalogue pourra être présenté au gel lorsque :
1. chaque ressource est qualifiée comme objet autonome, sous-objet ou processus d'un domaine propriétaire ;
2. chaque permission correspond à un triplet unique domaine/ressource/action, justifié par un workflow ;
3. les slugs sont canoniques et les doublons inter-domaines supprimés ;
4. les actions conditionnelles ou proposées sont validées ou exclues explicitement ;
5. les associations des huit rôles sont explicites, avec DIR et ses exceptions ;
6. les scopes sont documentés séparément des permissions ;
7. les données sensibles et les règles de conservation sont traitées sans créer de droits trop larges ;
8. aucune ressource, permission ou workflow comptable n'est introduit.

**État à la fin de la finalisation documentaire :** lots 1 à 5 documentés, référentiel clarifié, catalogue non gelé, associations atomiques non finalisées, implémentation non commencée. Aucun code, migration, seeder ou test n'est créé par cette phase.

## 10. Arbitrage M-17 — catégories documentaires (24/11/2026)

**Statut : arbitrage fonctionnel clôturé pour DOC-01 à DOC-10.** Cette décision remplace les mentions historiques « M-17 reste ouvert » relatives à la classification et aux droits documentaires par catégorie ; elle ne signifie pas que le catalogue RBAC complet est gelé.

Les dix catégories retenues sont : DOC-01 Administratif entreprise ; DOC-02 Clients ; DOC-03 Affaires et chantiers ; DOC-04 Atelier et fabrication ; DOC-05 Ressources humaines ; DOC-06 Paie et rémunération ; DOC-07 Médical ; DOC-08 Banque et finance ; DOC-09 Sécurité et prévention ; DOC-10 Juridique et contentieux.

Pour chaque catégorie, les opérations `view`, `download`, `sign` et `export` conservent strictement les droits et scopes existants. Aucune extension ni réduction automatique n'est décidée. Si les associations atomiques existantes ne sont pas explicitement détaillées dans les sources, elles restent à vérifier lors de la consolidation de la matrice rôle × permission ; aucune attribution n'est inventée.

Garde-fous :
- SAL conserve uniquement les droits déjà prévus sur ses propres documents, notamment `download` et `sign` own lorsqu'ils s'appliquent.
- Secret médical et confidentialité des données de santé prévalent sur les droits généraux, y compris DIR ; aucun accès aux documents médicaux détaillés ne découle du seul accès global.
- Les données RH, paie/rémunération, bancaires/financières et juridiques/contentieuses restent soumises aux restrictions légales et de confidentialité existantes.
- `export` hérite des restrictions de la source et ne contourne ni scope ni confidentialité.
- `sign` exige une délégation valable, l'identité du signataire et une preuve conservée.
- Conservation légale, intégrité des versions, traçabilité, séparation des tâches et interdiction d'auto-approbation restent impératives.

**Conclusion :** les décisions métier M-17 sur les catégories et les quatre opérations sont terminées. La vérification technique des associations atomiques et scopes existants reste une tâche distincte de consolidation ; le catalogue global n'est pas gelé.


## 18. Arbitrages M-01 à M-16 — synthèse des décisions (24/11/2026)

Les décisions ci-dessous complètent le registre et prévalent sur les anciennes listes de points ouverts ; elles ne valent pas gel du catalogue ni attribution automatique de permissions.

| Référence | Décision consolidée | Résiduel |
| --- | --- | --- |
| M-01 | Seuil global 100 000 € HT ; validation DIR/SA au-delà ; aucun plafond individuel ni distinction supplémentaire des rôles dans la matrice ; cumul des bons de commande et avenants d'une même opération, sans fractionnement. | Vérifier les habilitations déjà documentées ; ne pas inventer d'attribution. |
| M-02 | Double contrôle uniforme pour tous les paiements, avec séparation préparation/autorisation/exécution et interdiction d'auto-autorisation. | Affectation concrète des acteurs à chaque étape à configurer. |
| M-03 | Déclenchement programmé ; contrôle et confirmation par RH ; clôture exécutée automatiquement par le système ; réouverture exceptionnelle DIR/SA tracée. RH ne reçoit pas le droit technique de clôture. | Date et rattachement du rôle RH à configurer ; aucun nouveau rôle créé implicitement. |
| M-04 | Distinction des accès DIR/SA, GAF et ADM maintenue ; ADM limité aux données RH administratives courantes ; secret médical prioritaire. | Cartographie technique des familles de données. |
| M-05 | Aucun export transversal/global implicite ; habilitations et confidentialité de la ressource source conservées. | Inventaire technique et vérification des associations existantes. |
| M-06 | Archivage privilégié ; suppression distincte de l'archivage et limitée aux suppressions justifiées, compatibles avec conservation et audit. | Qualification ressource par ressource. |
| M-07 | Signalement de besoin maintenu ; pas de signalement directement depuis le chantier ; aucun droit de commande fournisseur induit. | Canal et workflow à définir. |
| M-08 | CC crée/signale les incidents sous-traitants ; suivi par le rôle compétent ; aucun droit automatique de traitement/clôture. | Actions et responsable de traitement à définir. |
| M-09 | Deux circuits distincts qualité et sécurité, avec suivi et historique. | Responsables de traitement à désigner. |
| M-10 | Annuaire, messagerie et profil personnel SAL rattachés à Identity ; aucun domaine supplémentaire. | Conserver les attributions existantes. |
| M-11 | Reporting stratégique réservé à DIR ; autres accès opérationnels inchangés. | Ressources/snapshots à identifier techniquement. |
| M-12 | Paramétrage des barèmes grands déplacements réservé à DIR et SA ; pas de délégation ADM. | Datation et historisation maintenues. |
| M-13 | Ressources distinctes seulement si workflow distinct ; champs/statuts pour les différences administratives. | Décomposition selon les workflows réels. |
| M-14 | ADM voit les seuls documents administratifs nécessaires aux absences ; aucun justificatif médical ni donnée médicale détaillée. | Définir les champs administratifs accessibles. |
| M-15 | Dépassements d'heures supplémentaires validés uniquement par DIR ou SA ; aucune délégation opérationnelle automatique. | Séparer cette validation de la saisie et du suivi des temps. |
| M-16 | suspend temporaire et réactivable ; revoke retrait définitif ; delete technique conditionnel sans effacer l'audit ; administration DIR/SA. | Historisation obligatoire. |

**M-17 :** arbitrage fonctionnel déjà clôturé pour DOC-01 à DOC-10 et les opérations view, download, sign, export. La vérification technique des associations atomiques et scopes existants reste distincte. Les mentions historiques « M-17 ouvert » sont obsolètes pour la décision métier.

**État :** M-01 à M-06 et M-08 à M-16 sont arbitrés. M-07 reste partiellement ouvert (canal de signalement). Les responsables qualité/sécurité et certains détails techniques restent à préciser ; ne pas déduire de permission ou d'affectation de rôle.
