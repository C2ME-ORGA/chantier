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


## 8. Anomalies à résoudre avant gel

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
