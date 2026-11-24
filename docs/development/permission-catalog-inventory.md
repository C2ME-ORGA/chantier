# Inventaire canonique des permissions — CHAN-40

> **Statut :** inventaire en cours — lot 1 (Identity, Clients, Projects, Planning, Budgets, Costing).
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
| `admin_panel` | `access` | SA, ADM, CT, CC, RA, CPT / global | Retenu ; SAL exclu du panel |
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
| `factures_clients` | `view`, `create`, `update`, `issue` ; `delete` conditionnel | CPT : view/create/update/issue | Retenu ; conservation comptable |
| `avoirs` | `view`, `create`, `update`, `issue` ; `delete` conditionnel | CPT : view/create/update/issue | Retenu ; conservation comptable |
| `relances` | `view`, `create`, `update`, `issue`, `close` ; `delete` conditionnel | CPT : view/create/update | Retenu |
| `echeanciers` | `view`, `create`, `update`, `validate`, `close` ; `delete` conditionnel | CPT : view/create/update | Retenu |
| `litiges_facturation` | `view`, `create`, `update`, `arbitrate`, `close` ; traitement à normaliser | CPT : view/create/update | Anomalie A-07 : `treat` absent du registre ; régularisation financière distincte |
| `reglements` | `view`, `create`, `update`, `validate`, `reconcile`, `close` ; `delete` conditionnel | CPT : view/reconcile | Retenu ; aucun droit de préparation/exécution de paiement |

**Propriété des ressources :** les documents de facturation et de gestion client restent dans `clients`. `accounting` ne duplique pas ces ressources.

### Projects

| Ressource | Actions candidates | Rôles hors DIR / portée | Statut |
| --- | --- | --- | --- |
| `affaires` | `view`, `create`, `update` | CT : view/create/update ; ADM, CC, CPT : view | Retenu |
| `chantiers` | `view`, `create`, `update` | CT : view/create/update ; ADM, CC, CPT : view | Retenu |
| `lots_phases` | — | — | À arbitrer ; A-17, aucun scope déduit |
| `etudes` | `view`, `create`, `update` | CT : view/create/update | Retenu |
| `commandes_clients` | `view`, `approve` | ADM, CT, CPT : view ; SA : approve | Retenu ; DIR approuve toutes les commandes, sans seuil |
| `avenants` | `view`, `prepare`, `submit`, `approve` | CT : view/prepare/submit ; SA : approve | Retenu ; DIR n'assure ni préparation ni soumission |
| `contrats` | `view`, `approve` | ADM, CT, CPT : view ; SA : approve | Retenu ; DIR approuve tous les contrats, sans seuil |
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
| `budgets` | `view`, `create`, `update`, `submit`, `approve` | CT : view/create/update/submit ; ADM/CPT : view ; SA : approve | Retenu ; approbation DIR sans seuil |
| `lignes_budgetaires` | `view`, `create`, `update`, `submit`, `validate`, `approve` ; delete conditionnel | CT : view/create/update ; ADM/CPT : view | Retenu ; accès complet DIR |
| `revisions_budgetaires` | `view`, `create`, `update`, `submit`, `approve` | CT : view/create/update/submit ; ADM/CPT : view ; SA : approve | Retenu ; approbation DIR sans seuil |
| `contingences` | `view`, `create`, `update`, `approve` | CT : view/create/update | Retenu ; approbation DIR sans seuil |

### Costing

| Ressource | Actions candidates | Rôles hors DIR / portée | Statut |
| --- | --- | --- | --- |
| `chiffrages` | `view`, `create`, `update`, `validate` | ADM/CT/RA/CPT : view ; CT/RA : create/update selon objet | Retenu |
| `couts` | `view`, `create`, `update`, `validate` | ADM/CT/RA/CPT : view ; CT/RA : create/update selon objet | Retenu |
| `ecarts` | `view`, `create`, `update`, `validate` | ADM/CT/RA/CPT : view ; CT/RA : create/update selon objet | Retenu |
| `engagements` | `view`, `approve` | CT/CPT : view ; SA : approve selon seuil | Retenu ; DIR/SA approuvent seulement au-delà de 100 000 € HT cumulés par opération |
| `marges` | `view` | CT/RA/CPT : view selon matrice | À préciser ; source au statut « Proposé » |
| `provisions_analytiques` | `view`, `approve` | CT/CPT : view ; SA : approve | Retenu ; approbation sans seuil |
| `periodes_analytiques` | `view`, `lock`, `unlock`, `close` | CPT : view/lock/unlock/close | Retenu |


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
| `donnees_medicales` | Aucune permission générale de consultation détaillée à générer | DIR : seules informations légalement accessibles et strictement nécessaires ; ADM : traitement administratif ; CPT : informations nécessaires paie/comptabilité sociale | Exception ; documents médicaux détaillés détenus par les professionnels de santé exclus |
| `coordonnees_bancaires` | `view`, `create`, `update`, `delete`, `validate` | SA et CPT conservent leurs droits ; SAL : view own, `request_update` | Retenu ; validation indépendante du demandeur/modificateur et historique sécurisé |
| `elements_variables_paie` | `view`, `create`, `update`, `delete`, `prepare`, `control`, `submit`, `validate` | ADM : préparation/soumission ; CPT : view | Retenu ; séparation des tâches maintenue |
| `paies` | `view`, `create`, `update`, `delete`, `prepare`, `control`, `validate` | CPT : view/prepare/control ; SA conserve ses droits | Retenu ; interdiction d'auto-approbation |
| `bulletins_paie` | `view`, `create`, `update`, `delete`, `prepare`, `control`, `validate` | CPT : view/prepare/control ; SAL : view own ; SA conserve ses droits | Retenu ; confidentialité et conservation |
| `ecritures_paie` | `view`, `create`, `update`, `delete`, `prepare`, `control`, `validate` | CPT : view/prepare/control ; SA conserve ses droits | Retenu ; validation finale indépendante |
| `indemnites_grands_deplacements` | `view`, `create`, `update`, `delete`, `prepare`, `control`, `process`, `validate` | SAL : view own ; ADM/CPT conservent leurs droits | Retenu |
| `grands_deplacements` | `view`, `create`, `update`, `delete`, `declare`, `control`, `prepare`, `process`, `validate` | CT/RA : déclaration de leurs équipes ; ADM/CPT/SAL conservent leurs droits | Retenu |
| `baremes_grands_deplacements` | `view`, `create`, `update`, `delete` | SA conserve ses droits globaux | Retenu ; barèmes datés/historisés, aucune modification rétroactive des périodes traitées |

**Règles transverses Workforce :** les suppressions sont conditionnées par les durées légales de conservation ; sinon privilégier archivage/désactivation si ces actions existent dans le workflow. Les changements de coordonnées bancaires doivent être validés indépendamment de leur demandeur/modificateur. Les documents médicaux détaillés restent exclus.

### 6.2 TimeTracking

| Ressource | Actions explicitement citées / candidates | Rôles hors DIR et portée | Statut / contraintes |
| --- | --- | --- | --- |
| `pointages` | `view`, `create`, `update`, `delete`, `submit`, `validate`, `reopen`, `supervise` ; `correct` en anomalie A-07 | CC/RA/SAL conservent leurs droits ; CT contrôle/corrige ; CPT : view paie | Retenu ; historique et motifs de correction obligatoires |
| `feuilles_de_temps` | `view`, `create`, `update`, `delete`, `submit`, `validate`, `reopen`, `supervise` ; `correct` en anomalie A-07 | CC/RA/SAL conservent leurs droits ; CT contrôle/corrige après CC ; CPT : view paie | Retenu ; candidat historique `timetracking.timesheets.validate` à normaliser vers la ressource canonique |
| `corrections` | `view`, `create`, `update`, `delete`, `submit`, `validate`, `reopen` | SAL, CC, RA, CT selon leurs périmètres | Retenu ; valeur initiale/nouvelle, auteur, date, motif et valideur à tracer |
| `periodes` | `view`, `create`, `update`, `delete`, `close`, `reopen` | SA conserve `reopen` | Retenu ; clôture après contrôles, réouverture motivée et auditée |
| `absences` | `view`, `create`, `update`, `delete`, `submit`, `review`, `validate`, `arbitrate` | SAL, CC, CT, RA, ADM selon responsabilités ; CPT : consultation paie | Retenu ; historisation des décisions |
| `justificatifs_medicaux` | Pas de droit général aux documents médicaux détaillés | ADM : traitement administratif ; CPT : informations nécessaires à paie/comptabilité sociale ; DIR : informations administratives/d'indisponibilité légalement accessibles | Exception secret médical ; accès restreint |
| `heures_supplementaires` | `view`, `create`, `update`, `delete`, `authorize`, `submit`, `validate`, `validate_excess`, `control`, `process` | SAL, CT, RA, ADM, CPT conservent leurs droits | Retenu ; distinguer heures autorisées, déclarées, réellement travaillées et validées ; un dépassement refusé reste tracé comme temps travaillé |

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
| `fournisseurs` | Actions fonctionnelles à décomposer à partir du CRUD et du workflow réellement disponibles | ADM, CT, CC, RA, CPT conservent leurs droits | Ressource retenue ; actions DIR globales à inventorier sans inventer les actions absentes |
| `sous_traitants` | Actions fonctionnelles à décomposer à partir du CRUD et du workflow réellement disponibles | ADM, CT, CC, RA, CPT conservent leurs droits | Ressource retenue |
| `demandes_achat` | Actions fonctionnelles à décomposer ; soumission à confirmer selon workflow | ADM, CT, RA conservent leurs droits | Ressource retenue ; scope opérationnel CHAN-42 |
| `besoins` | Actions fonctionnelles à décomposer | CC, CT, RA conservent leurs droits | Ressource retenue |
| `offres_fournisseurs` | Actions fonctionnelles à décomposer | ADM, RA conservent leurs droits | Ressource retenue |
| `commandes_achats` | `view`, `prepare`, `update`, `submit`, `approve` (actions citées dans l'arbitrage) | ADM, CT, RA, CPT, SA conservent leurs droits | Retenu ; DIR approuve uniquement au-delà de 100 000 € HT cumulés par opération |
| `lignes_commande` | `view`, `prepare`, `update`, `submit`, `approve` (à confirmer si action portée par la ligne ou la commande) | ADM, CT, RA, CPT, SA conservent leurs droits | À préciser ; ne pas dupliquer l'approbation si elle appartient à la commande |
| `commandes_sous_traitance` | `view`, `prepare`, `update`, `submit`, `approve` (actions citées dans l'arbitrage) | ADM, CT, RA, CPT, SA conservent leurs droits | Retenu ; même seuil cumulé que les achats |
| `evaluations_fournisseurs` | Actions à décomposer selon les étapes d'évaluation effectivement disponibles | ADM, RA conservent leurs droits | Ressource retenue |
| `accords_cadres` | Actions à décomposer ; approbation uniquement si le workflow prévoit une action distincte | ADM, RA conservent leurs droits | Ressource retenue |
| `garanties_fournisseurs` | Actions à décomposer selon suivi, consultation et gestion des garanties | ADM, RA conservent leurs droits | Ressource retenue |
| `factures_fournisseurs` | `view`, `create`, `update`, `reconcile` | CPT et ADM conservent leurs droits | Retenu ; aucun droit d'exécution des paiements n'est impliqué |
| `incidents_sous_traitance` | Actions à décomposer selon déclaration, traitement et clôture réellement disponibles | CC, CT, RA conservent leurs droits | Ressource retenue |

**Règle financière Procurement :** l'approbation DIR des commandes d'achat et de sous-traitance est exigée uniquement lorsque le seuil cumulé de 100 000 € HT par opération est dépassé, en agrégeant commandes et avenants et en empêchant le fractionnement artificiel. La préparation et l'exécution des paiements restent séparées et réservées au workflow financier dédié.

### 6.5 Inventory

| Ressource | Actions explicites / candidates | Rôles hors DIR | Statut / contraintes |
| --- | --- | --- | --- |
| `articles` | Actions fonctionnelles à décomposer ; référentiel | RA, CT, CC, CPT conservent leurs droits | Retenu |
| `entrepots` | Actions fonctionnelles à décomposer ; référentiel | RA, CT, CC, CPT conservent leurs droits | Retenu |
| `emplacements` | Actions fonctionnelles à décomposer ; référentiel | RA, CT, CC, CPT conservent leurs droits | Retenu |
| `lots_stock` | Actions fonctionnelles à décomposer ; suivi des lots | RA, CT, CC, CPT conservent leurs droits | Retenu |
| `mouvements_stock` | `view`, `create`, `update`, `reverse`, `validate` si applicable | RA, CT, CC, CPT conservent leurs droits | Retenu ; inversion plutôt qu'effacement de l'historique |
| `receptions_stock` | Actions fonctionnelles à décomposer selon réception et contrôle réellement disponibles | RA, CT, CC conservent leurs droits | Retenu |
| `reservations_stock` | Actions fonctionnelles à décomposer selon réservation/libération réellement disponibles | RA, CT, CC conservent leurs droits | Retenu |
| `consommations` | `view`, `create`, `update`, `reverse`, `validate` si applicable | CC, RA, CT, CPT conservent leurs droits | Retenu ; slug canonique `inventory.consommations` |
| `bons_sortie` | Actions fonctionnelles à décomposer selon préparation, validation et émission réellement disponibles | RA, CC conservent leurs droits | Retenu |
| `inventaires_physiques` | Actions fonctionnelles à décomposer selon préparation, comptage, validation et clôture réellement disponibles | RA, CPT conservent leurs droits | Retenu |
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




## 8. Lot 3 — Logistics, Quality, Safety, Documents, Handover, Reporting et Accounting

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
| `documents` | À décomposer : `view`, `create`, `update`, `delete` conditionnel, `download`, `sign`, `archive`, `validate` selon fonctionnalités présentes | ADM, CT, CC, RA, CPT, SAL conservent leurs droits selon périmètre | Retenu ; inclut les dossiers administratifs clients et leurs pièces ; M-17 reste ouvert |
| `versions` | À décomposer selon création de version, consultation et restauration si elle existe | Droits documentaires existants | Retenu ; versions et traces conservées |
| `dossiers_documentaires` | À décomposer selon création, classement, modification, validation et clôture | ADM, CT, CC, RA, CPT, SAL selon périmètre | Retenu ; ne pas créer de ressource séparée pour les dossiers administratifs clients |
| `types_document` | À décomposer selon gestion du référentiel | ADM conserve ses droits | Retenu |
| `regles_conservation` | À décomposer selon consultation, création et modification réellement disponibles | ADM conserve ses droits | Retenu ; aucune suppression contraire à une obligation légale |
| `diffusions` | À décomposer selon préparation, envoi, suivi et accusé de réception | ADM, CT, CC, RA, SAL conservent leurs droits | Retenu ; destinataires, dates, versions diffusées et accusés conservés |
| `download` / `sign` | Actions transverses à rattacher à la ressource documentaire selon le modèle technique, pas de ressource autonome présumée | SAL : téléchargement/signature own | À modéliser ; signature selon délégation, identité et preuve |
| `exports` | `export` candidat, avec génération/téléchargement selon le workflow | ADM, CPT conservent leurs droits | Retenu ; mêmes restrictions de confidentialité et d'accès que les documents sources |

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
| `exports` | À décomposer selon préparation, génération, consultation, téléchargement et export | ADM, CPT conservent leurs droits | Retenu ; M-05 levé pour Reporting ; confidentialité et traçabilité restent actives |

### 8.7 Accounting

| Ressource | Actions candidates | Rôles hors DIR / portée | Statut / contraintes |
| --- | --- | --- | --- |
| `ecritures` | À décomposer : `view`, `create`, `update`, `validate`, `reverse`, `delete` conditionnel | CPT conserve ses droits | Retenu ; piste d'audit et périodes comptables |
| `journaux` | À décomposer selon consultation et gestion du référentiel | CPT conserve ses droits | Retenu |
| `plan_comptable` | À décomposer selon consultation et gestion du référentiel | CPT conserve ses droits | Retenu |
| `periodes` | `view`, `create`, `update`, `lock`, `unlock`, `close` ; réouverture à préciser | CPT conserve ses droits | Retenu ; déverrouillage/réouverture tracés |
| `rapprochements_bancaires` | À décomposer : `view`, `create`, `update`, `validate`, `close` | CPT conserve ses droits | Retenu ; relevés, écarts et justificatifs conservés |
| `payments` / `paiements` | DIR/SA : autorisation et refus selon workflow ; CPT : `prepare`, `execute` | CPT : préparation/exécution ; SA : autorisation selon workflow | Exception impérative ; nom canonique anglais/français à arbitrer ; DIR ne prépare ni n'exécute ; aucun préparateur ne s'auto-autorise |
| `tresorerie` | À décomposer selon consultation et opérations de trésorerie réellement disponibles | CPT conserve ses droits | Retenu |
| `declarations` | À décomposer selon préparation, validation, soumission et suivi | CPT conserve ses droits | Retenu ; obligations et échéances légales |
| `clotures` | À décomposer selon préparation, validation et clôture | CPT conserve ses droits | Retenu ; historique des clôtures |
| `analytique` | À décomposer selon consultation et opérations analytiques réellement disponibles | CPT conserve ses droits | Retenu ; vérifier le non-recouvrement avec Costing |
| `revisions_budgetaires` | À décomposer selon consultation, préparation, validation et intégration | CPT conserve ses droits | Retenu ; vérifier l'articulation avec Budgets |
| `immobilisations` | À décomposer selon création, mise à jour, mise en service, sortie et archivage | CPT conserve ses droits | Retenu |
| `amortissements` | À décomposer selon calcul, contrôle, validation et clôture | CPT conserve ses droits | Retenu ; plans et historiques conservés |
| `donnees_financieres` | Ressource transverse à préciser ; ne pas créer de permission contournant les droits des ressources sources | CPT conserve ses droits selon source | À préciser ; éviter une permission générique d'accès qui élargirait les droits |
| `exports` | À décomposer selon préparation, génération, consultation, téléchargement et export | CPT conserve ses droits | Retenu ; confidentialité, conservation et traçabilité |
| `relations_organismes` | À décomposer selon gestion des organismes, échanges et justificatifs | CPT conserve ses droits | Retenu ; échanges et pièces conservés |

**Séparation des paiements :** CPT prépare et exécute ; DIR/SA autorisent ou refusent. L'absence de permission DIR de préparation/exécution doit être explicitement représentée dans le catalogue et les contrôles d'autorisation. L'auto-approbation est interdite.

**Frontières inter-domaines :**
- Documents possède les documents administratifs clients et leurs pièces ; Clients conserve les processus de facturation client ; Accounting conserve les écritures et processus comptables.
- Accounting `revisions_budgetaires` ne doit pas dupliquer Budgets `revisions` sans distinction fonctionnelle explicite.
- Accounting `analytique` ne doit pas dupliquer Costing `provisions_analytiques` et `periodes_analytiques` ; les objets et responsabilités doivent être distingués avant gel.
- Reporting `exports`, Documents `exports` et Accounting `exports` restent des ressources de domaines distincts uniquement si leurs workflows et données sources sont réellement distincts ; sinon déduplication au lot 4.

## 9. Anomalies et précisions du lot 3

| Référence | Constat | Traitement avant gel |
| --- | --- | --- |
| Logistics | `acces_chantier.update` CT est à confirmer | Arbitrer le droit CT sans modifier l'accès DIR global |
| Quality / Safety | `signalements` existe dans les deux domaines | Confirmer s'il s'agit de deux flux distincts ou d'un objet commun catégorisé ; ne pas fusionner sans analyse |
| Documents | `download` et `sign` sont présentés comme actions transverses dans la matrice | Rattacher aux ressources documentaires ; ne pas créer de ressources autonomes sans modèle technique |
| Documents | M-17 catégories/champs sensibles | Définir les restrictions de consultation, téléchargement, export et signature ; secret médical exclu |
| Handover | Réception chantier logistique vs réception finale | Confirmer la frontière entre `logistics.receptions_chantier` et `handover.dossiers_reception` |
| Reporting | Exports du domaine Reporting | M-05 levé selon matrice ; garder les contrôles de confidentialité |
| Accounting | `payments` vs `paiements` | Choisir un slug canonique et traiter le refus comme permission ou résultat de workflow (A-07) |
| Accounting | `revisions_budgetaires` | Distinguer ou dédupliquer avec Budgets `revisions` |
| Accounting | `analytique` | Distinguer ou dédupliquer avec Costing |
| Accounting | `donnees_financieres` | Préciser les données réellement propres à cette ressource ; aucun contournement des permissions sources |
| Accounting | `exports` | Dédupliquer avec les exports Documents/Reporting si mêmes opérations |
| DIR | Accès global au lot 3 | Attribuer explicitement chaque permission fonctionnelle retenue, sauf préparation/exécution des paiements et restrictions légales/documentaires |


## 10. Anomalies à résoudre avant gel

| Référence | Constat | Traitement |
| --- | --- | --- |
| A-07 | `treat` est cité pour les litiges, absent du registre | Déterminer si `process` le remplace ou si une action distincte est nécessaire |
| A-07 | `correct` est cité pour les pointages/corrections, absent du registre | Vérifier si `update` couvre la correction ; la traçabilité relève du workflow |
| A-07 | `refuse` apparaît dans le workflow paiement, absent du registre | Déterminer si le refus est un résultat de workflow ou une permission distincte |
| Identity | `financial_delegations` sous Identity, mais DIR n'administre pas les habilitations | Clarifier propriétaire et exception DIR |
| Costing | `marges` au statut « Proposé » | Exclure du catalogue initial ou obtenir validation |
| Projects | `lots_phases` sans modèle de rattachement | A-17 ; ne pas générer de permission définitive |
| DIR | « Toutes actions applicables » n'est pas une liste d'actions | Identifier les actions légitimes par ressource, puis associer explicitement DIR |

## 9. Lots suivants

- **Lot 2 :** Workforce, TimeTracking, Workshop, Procurement, Inventory, Equipment.
- **Lot 3 :** Logistics, Quality, Safety, Documents, Handover, Reporting, Accounting.
- **Lot 4 :** déduplication, normalisation finale des actions, matrice complète des huit rôles, contrôles de cohérence et proposition de gel.

M-17 (catégories/champs documentaires sensibles) et A-17 (lots/phases) restent isolés ; ils ne bloquent pas les permissions indépendantes.

## 10. Critères de gel

1. Une entrée unique par triplet domaine/ressource/action.
2. Résolution des anomalies A-07 et des slugs ambigus.
3. Séparation entre permissions et règles de workflow.
4. Attribution explicite aux huit rôles, sans héritage implicite.
5. Application explicite de la règle DIR et de ses exceptions.
6. Scopes opérationnels documentés pour CHAN-42, hors slug.
7. Absence de doublons entre domaines (notamment Clients/Accounting et Budgets/Accounting).
8. Validation des ressources proposées ou exclusion explicite du catalogue initial.
