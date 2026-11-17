# Processus de hotfix

Ce document définit les règles de qualification, de décision, de validation et de traçabilité d'un **hotfix** de C2ME Chantier.

- Ticket : CHAN-99 – Définir et tester le processus de hotfix.
- Ticket parent : CHAN-92 – Définir le workflow Git, les releases et les déploiements.
- Dépôt : [`C2ME-ORGA/chantier`](https://github.com/C2ME-ORGA/chantier).
- Portée : éligibilité, criticité, conditions préalables, refus, responsabilités, versionnement correctif, contrôles, preuves et synchronisation `main` → `develop`.
- Hors portée : procédure de release, procédure de déploiement, procédure de migration, procédure de rollback et runbook opérateur. Les commandes Git détaillées sont décrites en section 17 ; les autres procédures restent définies dans leurs documents de référence.

> **Statut du document.**
>
> Ce document est **préparatoire**. Aucun hotfix réel n'a été exécuté, aucune release n'a été publiée et aucun déploiement n'a été déclenché dans le cadre de CHAN-99.
>
> À la date de rédaction, aucun tag stable, aucune release GitHub, aucun environnement GitHub et aucun déploiement réel n'existent. `main` ne contient pas encore l'historique de production ni les workflows de release et de déploiement. Le processus ne peut donc pas être exécuté en production avant une première livraison normale depuis `develop`.
>
> Le mécanisme de promotion exige une release candidate staging vérifiable. L'évolution minimale de [`release.yml`](../../.github/workflows/release.yml) est préparée au Lot 3 de CHAN-99 via [`validate-release-tag.sh`](../../.github/scripts/deploy/validate-release-tag.sh). Elle n'est ni fusionnée, ni publiée, ni déployée à ce stade. **Tant que cette évolution n'est pas fusionnée et que la première release stable n'est pas déployée, un hotfix est NO-GO pour un déploiement réel en production.**
>
> Les commandes Git du Lot 2 sont documentées en section 17. Les commandes de création de branche, de push, de Pull Request, de fusion et de synchronisation n'ont pas été exécutées dans le cadre de ce lot.

## Sources de vérité

| Sujet | Référence |
| --- | --- |
| Branches, commits et Pull Requests | [`git-workflow.md`](git-workflow.md) |
| Versionnement, tags et releases | [`release-process.md`](release-process.md) |
| Déploiements, artefacts et promotion | [`deployment-process.md`](deployment-process.md) |
| Environnements et protections | [`environments.md`](environments.md) |
| Migrations et compatibilité N/N-1 | [`database-migrations.md`](database-migrations.md) |
| Rollback applicatif | [`application-rollback.md`](application-rollback.md) |
| Runbook de rollback | [`application-rollback-runbook.md`](application-rollback-runbook.md) |
| Revue technique des Pull Requests | [`pull-request-review.md`](pull-request-review.md) |
| Tests et contrôles locaux | [`testing.md`](testing.md) |
| Contrôle d'intégration continue | [`tests.yml`](../../.github/workflows/tests.yml) |
| Workflow de release | [`release.yml`](../../.github/workflows/release.yml) |
| Validation des tags de release | [`validate-release-tag.sh`](../../.github/scripts/deploy/validate-release-tag.sh) |
| Workflow de staging | [`deploy-staging.yml`](../../.github/workflows/deploy-staging.yml) |
| Workflow de production | [`deploy-production.yml`](../../.github/workflows/deploy-production.yml) |
| Validation des tags | [`validate-tag.sh`](../../.github/scripts/deploy/validate-tag.sh) |
| Validation des releases | [`validate-release.sh`](../../.github/scripts/deploy/validate-release.sh) |
| Référence de la candidate staging | [`stable-candidate.sh`](../../.github/scripts/deploy/stable-candidate.sh) |
| Promotion staging → production | [`resolve-promotion.sh`](../../.github/scripts/deploy/resolve-promotion.sh) |
| Validation structurelle des workflows | [`validate-workflows.php`](../../.github/scripts/tests/validate-workflows.php) |
| Tests de l'automatisation de release | [`test-release-automation.sh`](../../.github/scripts/tests/test-release-automation.sh) |
| Tests de l'automatisation de déploiement | [`test-deployment-automation.sh`](../../.github/scripts/tests/test-deployment-automation.sh) |
| Règles impératives pour les agents et contributeurs | [`AGENTS.md`](../../AGENTS.md) |
| Présentation du projet et démarrage local | [`README.md`](../../README.md) |

En cas de divergence, les protections GitHub effectivement configurées, les tags publiés et les releases GitHub correspondantes font foi. Une divergence doit être constatée, documentée et corrigée ; elle ne doit jamais être contournée par une opération manuelle silencieuse.

## 1. Définitions

### 1.1 Hotfix, bugfix et feature

| Élément | Définition | Branche de création | Branche cible |
| --- | --- | --- | --- |
| **Hotfix** | Correction urgente d'un défaut présent dans la version stable réellement déployée en production, avec un correctif minimal et rétrocompatible. | `main` | `main`, puis `develop` par synchronisation. |
| **Bugfix** | Correction non urgente, pouvant attendre la prochaine livraison normale. | `develop` | `develop`. |
| **Feature** | Nouvelle fonctionnalité ou évolution fonctionnelle. | `develop` | `develop`. |

Un hotfix n'est ni une fonctionnalité, ni un refactoring, ni une mise à jour de dépendance majeure, ni une correction de confort. Un correctif qui impose une rupture de compatibilité avec le contrat public suit le processus normal de version majeure ou mineure, pas le processus de hotfix.

### 1.2 Version stable déployée et référence de production

- **Version stable déployée** : version dont le code est effectivement actif en production, attestée par le fichier `release.json` de la release active et par l'exécution de déploiement en production correspondante.
- **Référence de production** : commit exact associé à cette version déployée. Le couple `version` / `commit_sha` de `release.json` est la source de vérité ; le tag stable et la release GitHub sont des preuves complémentaires.
- **Tag stable** : tag annoté `vX.Y.Z` créé sur `main`, après succès de `ci`, conformément à [`release-process.md`](release-process.md).
- **Release stable** : release GitHub publiée, ni brouillon ni prérelease, associée au tag stable.
- **Candidate staging** : release candidate `vX.Y.Z-rc.N` déployée avec succès en staging, référencée dans la release stable par la ligne `Staging-Candidate: vX.Y.Z-rc.N`.

Le tag le plus récent n'est pas nécessairement la version déployée. Une release stable peut avoir été publiée sans avoir été déployée, ou un déploiement peut avoir échoué. Le hotfix part de la **version réellement déployée**, jamais d'un tag non déployé ni de `develop`.

### 1.3 Rollback et restauration de données

- Un **rollback applicatif** réactive une release antérieure par bascule du lien `current`. Il ne restaure jamais la base de données.
- Une **restauration de sauvegarde** est une opération distincte, avec perte de données assumée. Elle ne fait pas partie du processus de hotfix.

Le rollback est régi par [`application-rollback.md`](application-rollback.md) et son runbook. Un hotfix ne doit jamais être utilisé comme substitut à un rollback ou à une restauration.

### 1.4 Incident d'infrastructure

Un incident causé par un serveur, un certificat, un accès, une base, un worker, un cron ou un fournisseur externe ne justifie pas un hotfix de code. Il relève de l'exploitation, du rollback ou de la procédure de restauration appropriée.

## 2. Criticité et éligibilité

### 2.1 Niveaux de criticité

| Niveau | Définition | Exemples | Décision |
| --- | --- | --- | --- |
| **P1 — Critique** | Production indisponible, intégrité des données menacée, faille de sécurité active, impact financier, légal ou contractuel majeur. | Application inaccessible, corruption ou perte de données, contournement d'autorisation, fuite de données, calcul financier faux généralisé. | Hotfix éligible après qualification et autorisation explicite. |
| **P2 — Majeure** | Fonction métier critique bloquée ou fortement dégradée pour tout ou partie des utilisateurs, sans contournement raisonnable. | Saisie de chantier impossible pour tous les utilisateurs, export légal inutilisable, validation métier bloquante. | Hotfix éligible après qualification et autorisation explicite. |
| **P3 — Modérée** | Impact limité, utilisateurs restreints ou contournement acceptable. | Ergonomie dégradée, fonction secondaire indisponible, défaut disponible avec une procédure manuelle. | Pas de hotfix : `bugfix/*` depuis `develop`. |
| **P4 — Mineure** | Défaut cosmétique ou sans impact opérationnel significatif. | Libellé incorrect, alignement visuel, message perfectible. | Pas de hotfix : backlog ou prochaine livraison normale. |

Un hotfix est réservé aux niveaux **P1** et **P2**. La sévérité doit être justifiée par l'impact réel constaté en production, pas par l'urgence ressentie ou par la facilité de correction.

### 2.2 Éligibilité

Un hotfix est éligible si toutes les conditions suivantes sont réunies :

- le défaut est présent dans la version stable réellement déployée ;
- il est reproduit ou suffisamment caractérisé pour en comprendre la cause racine ;
- le correctif est minimal, isolé et rétrocompatible ;
- il ne contient ni fonctionnalité, ni refactoring large, ni mise à jour de dépendance majeure ;
- il ne modifie pas le contrat public de façon incompatible ;
- un test de non-régression peut démontrer le défaut et sa correction ;
- une validation en staging est possible sur le commit exact qui sera publié ;
- un plan de rollback est disponible ;
- les règles de migration et de compatibilité N/N-1 sont respectées ;
- une autorisation humaine explicite est obtenue avant fusion, tag, publication et déploiement ;
- aucun secret, aucune donnée personnelle réelle et aucun détail d'exploit de sécurité ne sont exposés dans un dépôt ou une release publique.

### 2.3 Évaluer le rollback avant le hotfix

Avant de décider un hotfix, vérifier si un rollback applicatif vers la release précédente résout l'incident :

- sans perte de données ;
- sans incompatibilité de schéma avec la release cible ;
- sans job en file incompatible ;
- sans effet métier irréversible.

Si le rollback est suffisant et autorisé, il est préféré au hotfix. Le hotfix est réservé aux cas où le retour en arrière n'est pas possible, pas suffisant ou pas souhaitable, ou lorsque le défaut doit être corrigé en avant.

### 2.4 Sécurité

Le dépôt est public. Un hotfix de sécurité ne doit pas publier de détail exploitable avant la divulgation coordonnée. Les éléments sensibles restent dans le canal privé défini par l'organisation et dans Jira ; la Pull Request et les notes de version décrivent le correctif sans fournir de mode opératoire d'attaque, de secret ou de donnée personnelle.

Si aucun canal privé n'est défini, le hotfix de sécurité est NO-GO jusqu'à décision explicite sur la gestion de la confidentialité.

## 3. Conditions préalables

Avant de créer une branche de hotfix, les contrôles suivants sont obligatoires.

### 3.1 Référence de production

- [ ] La version stable réellement déployée est identifiée.
- [ ] Le commit de production est identifié et correspond au couple `version` / `commit_sha` de `release.json`.
- [ ] Le tag stable correspondant existe, est annoté et pointe sur ce commit.
- [ ] La release stable correspondante est publiée, ni brouillon ni prérelease.
- [ ] Le déploiement en production associé est terminé avec succès.
- [ ] Le commit de production appartient à l'historique de `main`.
- [ ] `main` n'a pas avancé au-delà de la référence de production, ou une décision explicite a été prise pour traiter les commits intermédiaires.
- [ ] Le processus de hotfix n'inclut aucun commit non déployé par accident.

Si `main` contient des commits non déployés, le hotfix est **NO-GO** tant que la situation n'est pas régularisée : déploiement de ces commits, rollback, ou décision tracée de les inclure dans la prochaine version corrective. Un hotfix ne doit pas embarquer silencieusement des changements non validés en production.

### 3.2 État du dépôt et de l'automatisation

- [ ] Le dépôt local est propre et la branche de travail est à jour.
- [ ] Aucun tag stable ou release candidate du numéro cible n'existe déjà.
- [ ] Aucune release, aucun déploiement et aucun rollback n'est en cours.
- [ ] Le contrôle `ci` est vert sur la référence de production.
- [ ] Les workflows de release et de déploiement sont disponibles sur `main` et opérationnels.
- [ ] Les environnements GitHub et les secrets nécessaires existent et sont protégés.
- [ ] Le mécanisme de candidate staging pour hotfix est disponible et testé.

En l'état actuel du dépôt, ces trois derniers points ne sont pas satisfaits : `main` ne contient pas les workflows de release/déploiement, aucun environnement GitHub n'existe et l'évolution de `release.yml` préparée au Lot 3 n'est pas encore fusionnée. Le processus est donc préparatoire et ne peut pas être exécuté réellement.

### 3.3 Correctif et tests

- [ ] La cause racine est documentée.
- [ ] Le correctif est limité au strict nécessaire.
- [ ] Un test de non-régression échoue sans le correctif et passe avec.
- [ ] Les tests existants restent verts.
- [ ] Les contrôles Pint, Larastan et Pest sont exécutés.
- [ ] La suite MariaDB est exécutée si le correctif touche SQL, migration, contrainte ou comportement moteur.
- [ ] Le build frontend et la vérification Vite sont exécutés si des assets sont concernés.
- [ ] Aucun test n'est supprimé, affaibli ou ignoré pour masquer le défaut.

### 3.4 Migration et rollback

- [ ] La migration est classée : aucune, A ou B. Les classes C, D et E sont refusées pour un hotfix.
- [ ] Aucune migration destructive, aucun Contract et aucune opération de classe C, D ou E n'est incluse.
- [ ] La compatibilité N/N-1 est démontrée pour toute migration additive.
- [ ] Une migration sensible est répétée en staging sur MariaDB 10.11.
- [ ] Aucune migration n'est exécutée automatiquement par le déploiement.
- [ ] Le plan de migration manuelle est approuvé, avec son moment d'exécution et ses contrôles.
- [ ] Le plan de rollback est disponible et compatible avec le schéma laissé par le hotfix.
- [ ] Une attestation de compatibilité N/N-1 peut être produite si un rollback devient nécessaire.

Un hotfix dont le code ne peut pas démarrer sans une migration absente de la release déployée est **NO-GO** : il relève du processus normal de release, avec une phase Expand livrée dans la release précédente.

### 3.5 Autorisation

- [ ] Le demandeur a qualifié l'impact et la sévérité P1/P2.
- [ ] Le responsable release/production a rendu une décision GO explicite.
- [ ] La décision est enregistrée dans la Pull Request et/ou Jira, avec date et identité.
- [ ] L'approbateur de l'environnement `production` est identifié.
- [ ] Les rôles sont tracés même lorsqu'ils sont tenus par la même personne.

Les rulesets GitHub n'exigent aucune approbation. Une fusion n'est donc pas une autorisation implicite : l'autorisation humaine doit être explicite et enregistrée avant la fusion, le tag, la publication et le déploiement.

## 4. Informations obligatoires

Toute demande de hotfix doit fournir les informations suivantes. Une information manquante bloque la qualification.

| Information | Contenu attendu |
| --- | --- |
| Ticket Jira | Clé `CHAN-xxx`, lien vers l'incident, ticket parent si applicable. |
| Sévérité | P1 ou P2, avec justification de l'impact réel. |
| Version affectée | Version stable déployée, par exemple `v1.4.2`. |
| Référence de production | Commit exact, tag stable et release publiée. |
| Preuve de déploiement | Exécution de déploiement en production et `release.json` de la release active. |
| Impact | Utilisateurs, fonctions, données et conséquences métier concernés. |
| Reproduction | Étapes, résultat attendu, résultat observé, logs ou captures sans secret. |
| Cause racine | Analyse suffisante pour justifier le correctif minimal. |
| Correctif | Description, fichiers concernés, comportement attendu. |
| Test de non-régression | Test ajouté ou adapté, avec résultat avant/après. |
| Périmètre | Confirmation qu'aucun changement non lié n'est inclus. |
| Migration | Aucune, ou classification et plan détaillé. |
| Rollback | Plan de retour arrière, conditions, attestation nécessaire. |
| Risque | Risques résiduels, effets de bord, dépendances. |
| Validation staging | Scénario de recette, données de test, résultat attendu. |
| Sécurité | Analyse d'exposition, canal privé si nécessaire. |
| Autorisation | Décision GO, date, auteur, preuve. |
| Preuves | Liens vers PR, CI, tag, release, staging, production et contrôles. |

## 5. Déclenchement et refus

### 5.1 Déclenchement

Un hotfix peut être déclenché lorsque :

- le défaut est P1 ou P2 ;
- il est présent dans la version stable déployée ;
- la cause racine est suffisamment comprise ;
- le correctif minimal et rétrocompatible est identifié ;
- les conditions préalables de la section 3 sont satisfaites ;
- le responsable release/production a rendu un GO explicite.

### 5.2 Refus

Un hotfix est refusé, sans dérogation implicite, dans les cas suivants :

- aucune version stable n'a été réellement déployée ;
- la référence de production est inconnue, incohérente ou non vérifiable ;
- `main` contient des commits non déployés sans décision tracée ;
- le défaut n'est pas présent en production ou n'est pas reproductible ;
- la cause racine est inconnue et le correctif relève de l'expérimentation ;
- le correctif contient une fonctionnalité, un refactoring large ou une mise à jour de dépendance majeure ;
- le correctif impose une rupture de compatibilité du contrat public ;
- une migration destructive, un Contract, une migration restrictive de classe C ou une opération de classe D/E est nécessaire ;
- la compatibilité N/N-1 n'est pas démontrée ;
- le code ne peut pas démarrer sans une migration absente de la release déployée ;
- aucun test de non-régression ne démontre le défaut et sa correction ;
- la CI est rouge ou ne peut pas être exécutée ;
- la validation staging est impossible ;
- le numéro de version cible est déjà utilisé ;
- une release, un déploiement ou un rollback est en cours ;
- l'autorisation humaine explicite est absente ;
- des secrets, des données personnelles réelles ou des détails d'exploit seraient exposés ;
- le périmètre contient des modifications non liées ;
- le rollback est suffisant et préférable ;
- l'incident est d'origine exclusivement infrastructurelle ;
- le canal privé de sécurité n'est pas défini pour un correctif sensible.

En cas de doute sur l'un de ces points, la décision est **NO-GO**.

## 6. Responsabilités et validations

| Rôle | Responsabilités | Preuve attendue |
| --- | --- | --- |
| **Demandeur / propriétaire de l'incident** | Qualifier l'impact, fournir la reproduction, la version affectée et les preuves. | Ticket Jira et éléments de diagnostic. |
| **Auteur du hotfix** | Créer la branche depuis `main`, appliquer le correctif minimal, ajouter le test de non-régression, documenter le risque et préparer la PR. | Branche, commits, PR et contrôles exécutés. |
| **Relecteur technique** | Vérifier le périmètre, le test de régression, les impacts, la sécurité et les migrations. | Revue selon [`pull-request-review.md`](pull-request-review.md). |
| **Responsable release/production** | Qualifier la sévérité, rendre le GO, choisir la version, autoriser le tag, la publication et le déploiement. | Décision GO datée et signée dans la PR et/ou Jira. |
| **Opérateur** | Exécuter une migration manuelle ou un rollback si nécessaire, avec le compte technique de l'environnement. | Journal d'exploitation, attestation et preuves de contrôle. |
| **Approbateur de l'environnement `production`** | Approuver le job protégé de déploiement lorsque l'environnement GitHub est configuré. | Approbation GitHub de l'environnement. |

### 6.1 Développeur unique

Le projet a un développeur unique. Les rôles peuvent donc être tenus par la même personne. Cette situation ne dispense pas des décisions explicites :

- la revue technique est réalisée et tracée ;
- le GO est écrit dans la PR et/ou Jira ;
- la fusion, le tag, la publication et le déploiement restent des décisions distinctes ;
- aucune approbation n'est supposée acquise du seul fait que la CI est verte ;
- aucune fusion administrateur ni aucun bypass de ruleset n'est utilisé.

### 6.2 Portées des validations

- La revue technique ne remplace pas la CI.
- La CI ne remplace pas la validation fonctionnelle en staging.
- La validation staging ne remplace pas le contrôle post-déploiement.
- Le contrôle post-déploiement ne remplace pas la décision de clôture et le post-mortem.

## 7. Flux d'ensemble

Le flux cible retenu est l'**option A** : la release candidate est créée sur le commit de hotfix après sa synchronisation dans `develop`. Les commandes Git exactes sont définies en section 17 ; la procédure opérateur est décrite dans [`hotfix-runbook.md`](hotfix-runbook.md).

### 7.1 Qualification et décision

1. Ouvrir ou identifier le ticket Jira CHAN-xxx.
2. Qualifier la sévérité P1/P2 et l'impact réel.
3. Vérifier si un rollback suffit.
4. Rassembler les informations obligatoires de la section 4.
5. Vérifier les conditions préalables de la section 3.
6. Rendre une décision GO/NO-GO explicite et la consigner.

### 7.2 Préparation du correctif

1. Identifier la version stable déployée et son commit exact.
2. Vérifier que `main` est aligné sur cette référence.
3. Créer la branche `hotfix/CHAN-xxx-description` depuis `main`.
4. Appliquer le correctif minimal.
5. Ajouter le test de non-régression.
6. Documenter le périmètre, le risque, la migration et le rollback.
7. Exécuter les contrôles locaux adaptés.
8. Pousser la branche temporaire.

### 7.3 Pull Request et fusion

1. Ouvrir une Pull Request vers `main`.
2. Renseigner la référence Jira, le résumé, les contrôles réellement exécutés, les risques et la checklist.
3. Vérifier le contrôle `ci` et les éventuels commentaires de revue.
4. Corriger les remarques sans élargir le périmètre.
5. Obtenir l'autorisation humaine explicite.
6. Fusionner avec `merge` ou `rebase`, jamais avec `squash`.
7. Attendre le succès de `ci` sur `main`.
8. Identifier le commit de fusion `M` et le consigner.

### 7.4 Synchronisation `main` → `develop`

La synchronisation intervient après la fusion dans `main` et **avant** la création de la release candidate, car le mécanisme de promotion exige que la candidate appartienne à l'historique de `develop`.

1. Ouvrir une Pull Request de `main` vers `develop`.
2. Utiliser une fusion classique, jamais un rebase ni un force-push.
3. Vérifier que le correctif est présent dans `develop`.
4. Vérifier que la CI est verte.
5. Si la synchronisation directe est en conflit, utiliser une branche `bugfix/CHAN-xxx-synchronisation-hotfix` créée depuis `develop`, conformément à la section 12.

### 7.5 Release candidate et validation staging

1. Vérifier que `main` n'a pas avancé depuis le commit `M`.
2. Créer un tag annoté `vX.Y.Z-rc.N` sur `M`.
3. Pousser le tag.
4. Vérifier que `release.yml` accepte la RC de hotfix selon la règle de la section 10.
5. Vérifier que `deploy-staging` construit et déploie le paquet depuis `M`.
6. Exécuter la recette de non-régression et les contrôles de santé en staging.
7. Consigner l'exécution staging, l'artefact et le manifeste.
8. Ne pas créer le tag stable si la validation staging échoue.

Si `main` avance après la création de la RC, ne pas créer le tag stable : synchroniser `main` vers `develop` et créer une nouvelle RC sur le nouveau HEAD de `main`.

### 7.6 Version stable et publication

1. Vérifier que `main` pointe toujours sur `M`.
2. Créer le tag stable annoté `vX.Y.Z` sur `M`.
3. Pousser le tag.
4. Vérifier que `release.yml` crée une release en brouillon.
5. Vérifier la ligne `Staging-Candidate: vX.Y.Z-rc.N` dans les notes.
6. Vérifier le classement des notes, l'absence de changement non prévu et l'absence de secret.
7. Publier explicitement la release stable.

### 7.7 Déploiement en production

1. Vérifier que `deploy-production` retrouve la candidate, l'exécution staging, l'artefact et le manifeste.
2. Vérifier que l'arbre Git de la candidate et celui du tag stable sont identiques.
3. Obtenir l'approbation de l'environnement `production` lorsqu'il est configuré.
4. Laisser le workflow promouvoir l'artefact staging sans reconstruction.
5. Exécuter les contrôles post-déploiement de la section 13.
6. Consigner l'exécution de production, le `release.json` actif et le résultat des contrôles.

### 7.8 Clôture

1. Vérifier que le correctif est présent dans `develop`.
2. Vérifier qu'aucune release depuis `develop` n'a été ouverte avant la fin de la synchronisation.
3. Mettre à jour Jira avec les liens et les preuves.
4. Rédiger un post-mortem pour tout P1/P2.
5. Supprimer la branche temporaire fusionnée.
6. Conserver les preuves pendant la durée définie par l'organisation.

## 8. Versionnement correctif

### 8.1 Règle générale

Un hotfix produit une nouvelle version **PATCH** rétrocompatible, calculée à partir de la version stable réellement déployée.

Exemples :

| Version déployée | Hotfix | Version suivante |
| --- | --- | --- |
| `v1.4.2` | Correction rétrocompatible. | `v1.4.3` |
| `v1.4.3` | Nouvelle correction rétrocompatible. | `v1.4.4` |
| `v0.5.1` | Correction rétrocompatible en période 0.x. | `v0.5.2` |

### 8.2 Règles opposables

- Le numéro cible doit être strictement supérieur à la version déployée.
- Un numéro déjà utilisé ne doit jamais être réutilisé, même si la release correspondante a été supprimée.
- Un tag stable ne doit jamais être déplacé, réutilisé ou supprimé.
- Un hotfix ne produit jamais un incrément `MINOR` ou `MAJOR`.
- Une rupture de compatibilité impose le processus normal, pas un hotfix.
- Une release stable de hotfix sans candidate staging valide ne doit pas être publiée : elle ne serait pas déployable.
- Si `main` a avancé après la création de la RC, une nouvelle RC est obligatoire ; le tag stable ne doit pas être créé sur un arbre différent.
- Les notes de version sont générées, relues et vérifiées avant publication.
- La ligne `Staging-Candidate` ne doit jamais être ajoutée ou modifiée manuellement pour contourner une candidate absente ou invalide.

### 8.3 Période 0.x

Tant que la version majeure est `0`, le contrat public est considéré comme instable. Une correction rétrocompatible incrémente néanmoins le `PATCH`. Une rupture de compatibilité ou une fonctionnalité relève du processus normal et ne peut pas être qualifiée de hotfix.

### 8.4 Après le hotfix

La prochaine version issue de `develop` est calculée à partir du dernier tag stable, en tenant compte du `PATCH` déjà publié. Le hotfix ne doit pas être compté une seconde fois dans les notes de la prochaine livraison normale.

## 9. Migrations et rollback

### 9.1 Règles de migration

Les règles complètes sont définies dans [`database-migrations.md`](database-migrations.md). Pour un hotfix :

- aucune migration destructive n'est autorisée ;
- aucun Contract n'est autorisé ;
- les opérations de classe D ou E sont interdites ;
- une migration additive doit rester compatible avec N-1 ;
- les migrations restrictives de classe C (`NOT NULL`, index unique, clé étrangère, `CHECK`) sont interdites dans un hotfix ;
- une migration sensible est répétée en staging sur MariaDB 10.11 ;
- aucune migration n'est exécutée automatiquement par un workflow de déploiement ;
- la migration est exécutée manuellement, avec le compte technique de l'environnement, après validation et avec une trace ;
- `migrate:fresh`, `migrate:refresh`, `migrate:reset`, `db:wipe` et `migrate:rollback` sont interdits en staging et en production ;
- un hotfix qui ne peut pas démarrer sans une migration absente de la release déployée est refusé et renvoyé au processus normal.

### 9.2 Plan de rollback

Avant le déploiement, le plan de rollback doit préciser :

- la release cible du retour arrière ;
- la compatibilité N/N-1 du schéma ;
- l'état des jobs en file et des effets déjà produits ;
- la nécessité ou non de mettre les files en pause ;
- l'attestation de compatibilité à produire ;
- la décision en cas d'échec du health check.

Le rollback applicatif est manuel, outillé par [`application-rollback.md`](application-rollback.md) et [`application-rollback-runbook.md`](application-rollback-runbook.md). Il ne restaure jamais la base. Aucun rollback automatique n'est déclenché par un workflow, un health check ou un déploiement.

### 9.3 Cas d'un hotfix avec changement de schéma

Un changement de schéma dans un hotfix est exceptionnel. Il n'est autorisé que si :

- la migration est additive et non boot-critical ;
- N-1 reste compatible ;
- la migration a été répétée en staging sur MariaDB 10.11 ;
- le moment d'exécution et le contrôle sont explicitement approuvés ;
- le rollback reste possible sans restauration de base.

Si l'une de ces conditions n'est pas satisfaite, le hotfix est **NO-GO** et le correctif suit le processus normal de release.

## 10. Release candidate staging et évolution de `release.yml`

### 10.1 Constat

Le mécanisme de production exige une release candidate staging :

- de même version de base ;
- tag annoté ;
- ancêtre du tag stable ;
- arbre Git identique au tag stable ;
- commit appartenant à l'historique de `origin/develop` ;
- exécution `deploy-staging` réussie ;
- artefact et manifeste disponibles et intacts.

Une release candidate est normalement créée sur le HEAD de `develop`. Un hotfix issu de `main` n'est pas dans `develop` avant sa synchronisation, et après synchronisation, le HEAD de `develop` n'est pas le commit du hotfix. Sans règle spécifique, le mécanisme ne permet donc pas de créer une candidate valide pour un hotfix. L'option A ci-dessous lève cette limitation.

### 10.2 Décision retenue : option A

Le processus retient l'option A :

1. le hotfix est fusionné dans `main` ;
2. `main` est synchronisé vers `develop` par Pull Request de fusion ;
3. le tag RC est créé sur le commit de fusion du hotfix, qui doit être le HEAD de `main` et être présent dans l'historique de `develop` ;
4. `deploy-staging` déploie ce commit ;
5. le tag stable est créé sur le HEAD de `main` ;
6. la production promeut le même artefact.

### 10.3 Mise en œuvre au Lot 3

L'évolution est implémentée dans [`validate-release-tag.sh`](../../.github/scripts/deploy/validate-release-tag.sh), appelé par [`release.yml`](../../.github/workflows/release.yml). Le script accepte une release candidate qui pointe :

- soit sur le HEAD de `origin/develop`, cas normal ;
- soit sur le HEAD de `origin/main`, à condition que ce commit soit présent dans l'historique de `origin/develop`, cas hotfix ;
- le commit ne doit pas déjà être pointé par un tag stable ;
- les autres contrôles de format, de tag annoté, de version et de publication restent inchangés.

`deploy-staging`, `stable-candidate.sh` et `resolve-promotion.sh` acceptent déjà une candidate ancêtre : ils ne nécessitent pas de modification pour l'option A.

Les tests de [`test-release-automation.sh`](../../.github/scripts/tests/test-release-automation.sh) couvrent la RC normale, la RC de hotfix, l'absence de synchronisation dans `develop`, une RC sur un ancien HEAD de `main`, la collision avec un tag stable, le tag stable hors HEAD, le tag léger et le format invalide.

### 10.4 Statut de mise en service

L'évolution est implémentée et testée localement au Lot 3, mais elle n'est ni fusionnée, ni publiée, ni déployée. Le hotfix reste **NO-GO pour la production** tant que :

- la modification n'est pas fusionnée dans `main` ;
- la première release stable n'est pas publiée et déployée ;
- les environnements GitHub et les secrets ne sont pas configurés.

Aucune dérogation manuelle, aucun ajout manuel de `Staging-Candidate` et aucun déploiement parallèle ne sont autorisés pour contourner cette limite.

## 11. Contrôles de release et de déploiement

Les contrôles détaillés restent définis dans [`release-process.md`](release-process.md) et [`deployment-process.md`](deployment-process.md). Le hotfix applique les contrôles suivants.

### 11.1 Cohérence tag, commit et branche

- [ ] Le tag stable est annoté.
- [ ] Le tag stable pointe sur le HEAD de `main`.
- [ ] Le tag stable pointe sur le commit de fusion du hotfix.
- [ ] Le tag stable n'est pas déjà utilisé.
- [ ] Le commit correspond au `commit_sha` attendu.
- [ ] La release est publiée, ni brouillon ni prérelease.
- [ ] Le tag RC est annoté, ancêtre du tag stable et de même arbre.
- [ ] Le tag RC appartient à l'historique de `develop`.
- [ ] Aucun tag n'a été déplacé, recréé ou supprimé.

### 11.2 Provenance de l'artefact

- [ ] L'artefact de production est celui publié par l'exécution staging de la candidate.
- [ ] Aucune reconstruction n'a lieu en production.
- [ ] L'exécution staging est terminée avec succès pour le commit de la candidate.
- [ ] Le manifeste est présent et respecte le schéma attendu.
- [ ] L'identifiant d'artefact est cohérent.
- [ ] L'empreinte SHA-256 est vérifiée.
- [ ] L'artefact n'est pas expiré.
- [ ] Le commit et l'arbre Git sont identiques entre la candidate et le tag stable.

### 11.3 Absence de modifications non prévues

- [ ] Le diff entre la version déployée et le tag stable ne contient que le correctif, son test et la documentation strictement nécessaire.
- [ ] Aucune fonctionnalité, aucun refactoring et aucune dépendance majeure ne sont inclus.
- [ ] Aucun fichier généré, secret, `.env` ou donnée personnelle n'est présent.
- [ ] Les notes de version ne mentionnent que les changements réellement inclus.
- [ ] Aucun commit non lié au ticket n'est présent.

### 11.4 Validation de la version

- [ ] La version respecte Semantic Versioning.
- [ ] L'incrément est `PATCH`.
- [ ] La version est strictement supérieure à la version déployée.
- [ ] Le numéro n'a jamais été utilisé.
- [ ] La release n'est pas une prérelease.
- [ ] La ligne `Staging-Candidate` est présente et valide.
- [ ] Les notes sont relues et correctement classées.

### 11.5 Contrôle de santé après déploiement

- [ ] Le point `GET /up` répond `200` avec `{"status":"up"}` en `Accept: application/json`.
- [ ] `release.json` contient la version et le commit attendus.
- [ ] Les journaux applicatifs ne montrent pas de nouvelle erreur critique.
- [ ] Les files d'attente et les workers sont dans l'état attendu.
- [ ] Le planificateur fonctionne.
- [ ] Un test de fumée vérifie le comportement corrigé.
- [ ] Les fonctions critiques adjacentes ne sont pas régressées.
- [ ] Aucune donnée sensible n'est exposée dans les contrôles ou les journaux.

## 12. Synchronisation `main` → `develop`

### 12.1 Principe

Après la fusion d'un hotfix dans `main`, le correctif doit être reporté dans `develop` afin de ne pas être perdu lors de la prochaine livraison normale.

- La synchronisation passe par une Pull Request vers `develop`.
- Aucun push direct sur `main` ou `develop`.
- Aucun force-push.
- La fusion est une fusion classique, jamais un rebase.
- Aucun squash.
- La CI de la Pull Request de synchronisation doit être verte.
- La synchronisation intervient après la fusion dans `main` et avant la création de la release candidate de hotfix, conformément à l'option A.
- Aucune nouvelle release depuis `develop` ne doit être ouverte avant la fin de la synchronisation.
- Les commandes exactes de préflight, de synchronisation et de résolution des conflits sont documentées en section 17.

Deux parcours sont autorisés :

- **Cas A — Pull Request directe `main` → `develop`** : uniquement lorsque la fusion est propre, qu'aucune résolution locale n'est nécessaire et que la PR directe peut être créée. C'est le parcours le plus simple.
- **Cas B — branche de synchronisation `bugfix/CHAN-99-synchronisation-hotfix` depuis `develop`** : obligatoire si la PR directe est en conflit, si une résolution locale ou une vérification sur branche est nécessaire, ou si la PR directe ne peut pas être créée. La branche est ensuite fusionnée dans `develop` par une PR dédiée.

Le parcours par branche est recommandé dès qu'il existe un doute sur la propreté de la fusion ou qu'un contrôle local doit être exécuté avant la PR.

### 12.2 Préflight obligatoire

1. Récupérer les références :
   ```powershell
   git fetch origin main develop
   ```
2. Identifier et consigner `MAIN_SHA`, `DEVELOP_SHA` et `HOTFIX_COMMIT` (commit de fusion du hotfix).
3. Vérifier que `HOTFIX_COMMIT` est ancêtre de `origin/main`.
4. Vérifier si `HOTFIX_COMMIT` est déjà ancêtre de `origin/develop` :
   - si oui, vérifier le contenu et la CI ; la synchronisation reste nécessaire si `origin/main` n'est pas entièrement intégré ;
   - si non, la synchronisation doit l'intégrer.
5. Vérifier si `origin/main` est déjà ancêtre de `origin/develop` :
   - si oui, `main` est déjà intégré ; aucune PR n'est nécessaire ; vérifier le contenu et la CI ;
   - si non, poursuivre.
6. Vérifier que les références locales correspondent aux références distantes (`git ls-remote`). Si elles ont changé, refaire le fetch et recommencer.
7. Vérifier qu'aucune PR de synchronisation n'est déjà ouverte.
8. Choisir le parcours : PR directe si la fusion est propre et qu'aucune résolution locale n'est nécessaire ; branche de synchronisation dans tous les autres cas.
9. Consigner les SHA, le parcours choisi et la justification.

### 12.3 Cas A — sans conflit

**Variante directe** :

1. Ouvrir une Pull Request de `main` vers `develop`.
2. Renseigner le ticket, le commit de hotfix, le SHA de `main`, le SHA de `develop`, les contrôles et la décision de synchronisation.
3. Attendre la CI verte et la revue.
4. Fusionner avec une fusion classique (`merge`).
5. Récupérer `develop` et vérifier le contenu, l'historique et la CI.

**Variante par branche de synchronisation** (recommandée si un contrôle local est nécessaire) :

1. Créer `bugfix/CHAN-99-synchronisation-hotfix` depuis `origin/develop`.
2. Vérifier que `origin/develop` est ancêtre de la branche.
3. Fusionner `origin/main` dans la branche.
4. Vérifier l'absence de conflit et l'étendue du diff.
5. Exécuter les contrôles locaux.
6. Pousser la branche et ouvrir une Pull Request vers `develop`.
7. Attendre la CI verte et la revue.
8. Fusionner avec une fusion classique.
9. Récupérer `develop` et vérifier le contenu, l'historique et la CI.

### 12.4 Cas B — avec conflits

1. Créer `bugfix/CHAN-99-synchronisation-hotfix` depuis `origin/develop`.
2. Vérifier que `origin/develop` est ancêtre de la branche.
3. Fusionner `origin/main` dans la branche.
4. Identifier les fichiers en conflit.
5. Résoudre les conflits fichier par fichier, sans écraser les développements propres à `develop` et sans supprimer le hotfix.
6. Ne pas utiliser `-X ours`, `-X theirs`, `git checkout --ours` ou `git checkout --theirs` de façon globale sans revue explicite.
7. Vérifier que le hotfix de production est conservé et que les évolutions de `develop` ne sont pas supprimées.
8. Exécuter les tests et contrôles nécessaires.
9. Pousser la branche et ouvrir une Pull Request vers `develop`.
10. Attendre la CI verte et la revue.
11. Fusionner avec une fusion classique.
12. Récupérer `develop` et vérifier le contenu, l'historique et la CI.

Une résolution manuelle est nécessaire dès qu'un fichier est modifié des deux côtés, qu'un fichier est renommé ou supprimé d'un côté, ou que le conflit touche une migration, un fichier généré, un verrou de dépendances ou une règle métier. Si la résolution exige de choisir arbitrairement entre deux évolutions, la synchronisation est arrêtée et escaladée.

### 12.5 Vérification après synchronisation

- [ ] `HOTFIX_COMMIT` est ancêtre de `origin/develop`.
- [ ] Le `DEVELOP_SHA` enregistré avant la synchronisation est ancêtre de `origin/develop`.
- [ ] Le correctif est présent dans le contenu de `develop`.
- [ ] Le test de non-régression est présent et vert dans `develop`.
- [ ] Aucun fichier ou commit propre à `develop` n'a été supprimé.
- [ ] L'historique contient les commits de `main` et de `develop`.
- [ ] La CI de `develop` est verte après la fusion.
- [ ] Aucune nouvelle release depuis `develop` n'a été ouverte avant cette vérification.

### 12.6 Synchronisation impossible / NO-GO

La synchronisation est arrêtée si :

- le hotfix n'est pas présent dans `main` ;
- la branche de synchronisation n'est pas basée sur `origin/develop` ;
- les références distantes ont changé et la branche n'a pas été recréée sur la nouvelle base ;
- un conflit ne peut pas être résolu sans supprimer une évolution de `develop` ou le hotfix ;
- le conflit touche une migration, un schéma, un fichier généré ou une règle métier sans décision explicite ;
- les tests ou la CI échouent ;
- la PR ne cible pas `develop` ou ne respecte pas les règles de fusion ;
- l'autorisation humaine est absente.

Dans ces cas, le hotfix n'est pas considéré comme terminé, aucune nouvelle release depuis `develop` ne doit être ouverte, et une décision explicite doit être prise et tracée. Le correctif peut être reporté manuellement dans `develop` par une Pull Request dédiée, avec le test de non-régression rejoué.

## 13. Preuves et traçabilité

Les preuves suivantes doivent être conservées et liées dans Jira et/ou la Pull Request :

| Preuve | Contenu |
| --- | --- |
| Ticket Jira | Sévérité, impact, version affectée, décision GO/NO-GO, approbateur. |
| Référence de production | `release.json`, tag stable, release publiée et exécution de déploiement. |
| Pull Request | Résumé, périmètre, contrôles, risques, migration, rollback et revue. |
| CI | Exécution verte sur la PR, sur `main` après fusion et sur `develop` après synchronisation. |
| Correctif | Commits, fichiers, test de non-régression et résultat avant/après. |
| Tag RC | Tag annoté, commit, arbre, exécution staging, artefact et manifeste. |
| Validation staging | Scénario exécuté, résultat, preuves de santé et limites. |
| Tag stable | Tag annoté, commit, release publiée et notes. |
| Déploiement production | Exécution, artefact promu, manifeste, approbation et résultat. |
| Contrôles post-déploiement | `/up`, `release.json`, journaux, files, planificateur et test de fumée. |
| Synchronisation | PR, CI, présence du correctif dans `develop` et éventuelle branche de résolution. |
| Post-mortem | Cause racine, détection, correction, prévention et tests ajoutés. |

Règles :

- ne jamais consigner de secret, de token, de mot de passe, de clé privée ou de donnée personnelle réelle ;
- ne pas exposer de détail d'exploit de sécurité avant la divulgation coordonnée ;
- ne pas se contenter d'une case cochée : joindre la preuve vérifiable ;
- rattacher les résultats au commit concerné, pas à un état local antérieur ;
- conserver les liens vers les exécutions GitHub Actions et les artefacts pendant la durée de rétention prévue.

## 14. Points d'arrêt NO-GO

Les points d'arrêt suivants sont cumulatifs. Un seul point en échec bloque la suite.

### Avant la branche

- version stable déployée inconnue ;
- référence de production incohérente ;
- `main` non alignée sur la production ;
- sévérité P3/P4 ;
- correctif non minimal ou non rétrocompatible ;
- migration destructive ou boot-critical ;
- rollback suffisant et préférable.

### Avant la Pull Request

- test de non-régression absent ou rouge ;
- contrôles locaux en échec ;
- périmètre non maîtrisé ;
- secret ou donnée sensible dans le diff ;
- documentation obligatoire absente.

### Avant la fusion

- CI rouge ou en attente ;
- revue non terminée ;
- autorisation humaine absente ;
- branche en conflit non résolue ;
- `main` ayant avancé sans mise à jour de la branche.

### Avant la release candidate

- `main` non synchronisée avec `develop` ;
- tag RC déjà utilisé ;
- tag RC non annoté ;
- commit de hotfix qui n'est pas le HEAD de `main` ou qui est absent de `develop` ;
- évolution de `release.yml` non disponible ;
- release ou déploiement en cours.

### Avant le tag stable

- validation staging absente ou en échec ;
- `main` ayant avancé depuis la RC ;
- arbre Git différent entre la RC et le HEAD de `main` ;
- version déjà utilisée ;
- notes de version non relues ;
- candidate staging absente ou invalide.

### Avant la publication

- release en brouillon non vérifiée ;
- ligne `Staging-Candidate` absente ou invalide ;
- notes contenant un changement non prévu ;
- approbation de l'environnement `production` absente ;
- secret ou donnée sensible détecté.

### Après le déploiement

- health check en échec ;
- version ou commit incohérent dans `release.json` ;
- erreur critique dans les journaux ;
- régression fonctionnelle constatée ;
- files ou planificateur indisponibles.

En cas d'échec après activation, aucun rollback automatique n'est déclenché. La décision est humaine et suit [`application-rollback.md`](application-rollback.md).

## 15. Décisions retenues

| Réf. | Décision |
| --- | --- |
| D-01 | Option A : release candidate sur le HEAD de `main` après synchronisation dans `develop`, avec validation par `validate-release-tag.sh` appelé depuis `release.yml` au Lot 3. |
| D-02 | Hotfix limité aux niveaux P1 et P2. Les niveaux P3 et P4 suivent le processus `bugfix/*` ou le backlog. |
| D-03 | Migrations additives uniquement, avec compatibilité N/N-1 démontrée. Les migrations destructives ou boot-critical sont refusées. |
| D-04 | Les mises à jour croisées des documents existants seront réalisées après validation du contenu, au lot final. |
| D-05 | La simulation sera exécutée dans un dépôt Git temporaire, sans modification de `origin`. |

## 16. Limites et points restant à arbitrer

### 16.1 Limites actuelles

- Aucune version stable n'a été publiée ni déployée.
- Aucun tag, aucune release et aucun environnement GitHub n'existent.
- `main` est très en retard sur `develop` et ne contient pas les workflows de release/déploiement.
- L'évolution de `release.yml` pour l'option A est préparée au Lot 3 mais n'est pas encore fusionnée ni publiée.
- Les environnements `staging` et `production` et leurs secrets ne sont pas configurés.
- Aucun déploiement réel n'a été exécuté dans le cadre de CHAN-99.
- Aucune protection de tag n'est configurée ; l'immuabilité repose sur la convention et les droits des mainteneurs.
- Le projet a un développeur unique ; la séparation des rôles est limitée.
- Jira n'a pas pu être consulté directement dans l'environnement de rédaction ; les critères utilisés sont ceux du ticket fourni.
- Le canal privé de traitement des incidents de sécurité n'est pas défini.
- Un hotfix nécessitant une migration boot-critical n'est pas compatible avec le mécanisme de déploiement actuel.
- Le runbook opérateur est produit au Lot 5 ; la simulation est prévue au Lot 6.

### 16.2 Points à arbitrer

- Confirmer la mise en service de `validate-release-tag.sh` et son intégration dans `release.yml`.
- Confirmer la durée et le support de conservation des preuves.
- Confirmer le canal privé de sécurité et la procédure de divulgation.
- Confirmer la politique de protection des tags, hors périmètre de CHAN-99.
- Confirmer les critères de post-mortem et de clôture des incidents P1/P2.
- Confirmer la procédure de régularisation lorsque `main` contient des commits non déployés.

## 17. Procédure Git de référence

Cette section documente les commandes Git et GitHub CLI exactes pour préparer, ouvrir, fusionner et synchroniser un hotfix. Elle applique [`git-workflow.md`](git-workflow.md) au cas du hotfix et ne remplace ni les conventions de branches, ni les protections GitHub, ni les procédures de release et de déploiement.

Les commandes sont données pour **PowerShell** sur Windows, avec Git et GitHub CLI (`gh`) authentifié. Elles restent transposables dans Git Bash, WSL ou Linux en adaptant les variables. Toutes les commandes sont exécutées depuis la racine du dépôt.

**Les commandes de création de branche, de push, de Pull Request, de fusion et de synchronisation n'ont pas été exécutées dans le cadre de CHAN-99.** Seules des commandes de lecture (`git status`, `git log`, `gh api`, `gh ... --help`) ont servi à l'audit. Les commandes de tag, de release et de déploiement relèvent du Lot 3 et du runbook Lot 5.

### 17.1 Variables

```powershell
$Ticket = "CHAN-xxx"
$Slug = "description-courte"
$Branch = "hotfix/$Ticket-$Slug"
$ProdTag = "v1.4.2"          # version stable réellement déployée
$Version = "v1.4.3"          # version corrective cible (Lot 3)
$FixedFile = "app/Domains/.../Fichier.php"
$RegressionTest = "tests/Feature/.../RegressionTest.php"
$SyncTicket = "CHAN-99"      # ticket de synchronisation
$SyncBranch = "bugfix/$SyncTicket-synchronisation-hotfix"
$PrBody = Join-Path $env:TEMP "hotfix-$Ticket-pr.md"
$SyncBody = Join-Path $env:TEMP "sync-$SyncTicket.md"
$RunId = "0000000000"        # à remplacer par le databaseId affiché par gh run list
$RulesetId = "00000000"      # à remplacer par l'identifiant affiché par la première commande gh api
```

Règles :

- `$ProdTag` est la version **réellement déployée**, pas nécessairement le dernier tag.
- `$Branch` respecte `<type>/CHAN-<numéro>-<description>`.
- `$SyncTicket` est le ticket de la branche de synchronisation ; pour ce lot, `CHAN-99`.
- `$Version` est le prochain PATCH libre ; aucun tag n'est créé dans ce lot.
- Ne jamais utiliser de valeur par défaut pour `$Ticket`, `$Slug`, `$ProdTag` ou `$FixedFile`.

### 17.2 Préflight — identifier la référence de production

```powershell
gh auth status
git fetch origin main develop --tags
git status --short
git switch main
git pull --ff-only
```

`git status --short` doit être vide. Si des modifications locales existent, s'arrêter : ne pas les mélanger au hotfix.

Identifier la version déployée à partir du ticket d'incident et de la preuve d'exploitation :

```powershell
$ProdTag = "v1.4.2"
$ProdCommit = git rev-parse "$ProdTag^{commit}"
git cat-file -t "refs/tags/$ProdTag"
git tag --points-at $ProdCommit
git merge-base --is-ancestor $ProdCommit origin/main
if ($LASTEXITCODE -ne 0) { throw "Le commit de production n'appartient pas à main." }
if ((git rev-parse origin/main) -ne $ProdCommit) { throw "main n'est pas alignée sur la production." }
```

- `git cat-file -t` doit afficher `tag`, pas `commit` : le tag doit être annoté.
- `git tag --points-at` doit contenir `$ProdTag`.
- `main` doit pointer exactement sur le commit de production. Si `main` a avancé, le hotfix est NO-GO jusqu'à régularisation.

Vérifier la release GitHub :

```powershell
gh release view $ProdTag --json tagName,isDraft,isPrerelease,publishedAt,url
```

La release doit être publiée (`isDraft=false`), ne pas être une prérelease (`isPrerelease=false`) et porter le bon tag.

Comparer avec `release.json` de la release active en production. Cette preuve est fournie par l'exploitant ou extraite selon la procédure d'exploitation ; **ne pas se connecter au serveur dans ce lot**. Les champs `version`, `commit_sha` et `environment` doivent correspondre à `$ProdTag`, `$ProdCommit` et `production`. Sans cette preuve, le hotfix est NO-GO.

Vérifier que la version cible n'existe pas :

```powershell
$ExistingTag = git ls-remote --tags --refs origin "refs/tags/$Version"
if ($LASTEXITCODE -ne 0) { throw "Impossible de vérifier le tag distant : $Version" }
if ($ExistingTag) { throw "Le tag $Version existe déjà sur origin." }
gh release view $Version
if ($LASTEXITCODE -eq 0) { throw "La release $Version existe déjà." }
```

Si `gh release view` échoue pour une autre raison qu'une release absente (authentification, réseau), s'arrêter et diagnostiquer.

Vérifier la CI de référence et l'absence d'opération en cours :

```powershell
gh run list --workflow tests.yml --branch main --limit 5 --json databaseId,headSha,status,conclusion,createdAt
gh run list --limit 20 --json databaseId,name,status,conclusion,headBranch,createdAt
```

Aucune exécution `release`, `deploy-staging` ou `deploy-production` ne doit être en cours ou en attente. Si ces workflows ne sont pas disponibles sur `main`, l'automatisation n'est pas opérationnelle : NO-GO.

Vérifier l'attribution des commits :

```powershell
git config user.email
gh api user --jq '.login'
```

L'adresse retournée par `git config user.email` doit être associée au compte GitHub. Sinon, la règle `require_extra_approval_for_unattributed_changes` peut bloquer la PR faute d'approbateur disponible. Ne pas contourner la règle ; corriger l'adresse ou le compte.

### 17.3 Créer la branche hotfix depuis main

```powershell
git switch main
git pull --ff-only
git status --short
if ((git rev-parse HEAD) -ne $ProdCommit) { throw "main a avancé : hotfix NO-GO." }
git rev-parse --verify --quiet "refs/heads/$Branch"
if ($LASTEXITCODE -eq 0) { throw "La branche locale existe déjà : $Branch" }
$ExistingRemoteBranch = git ls-remote --heads origin $Branch
if ($LASTEXITCODE -ne 0) { throw "Impossible de vérifier la branche distante : $Branch" }
if ($ExistingRemoteBranch) { throw "La branche distante existe déjà : $Branch" }
git switch -c $Branch
git rev-parse --abbrev-ref HEAD
git merge-base --is-ancestor $ProdCommit HEAD
if ($LASTEXITCODE -ne 0) { throw "La branche ne part pas du commit de production." }
```

La branche part de `main`, jamais de `develop`. Elle doit être créée sur le commit exact de production. Si `git switch -c` échoue parce que la branche existe déjà, ne pas la réutiliser : vérifier son état et repartir d'une branche propre.

### 17.4 Développer le correctif minimal et le test de non-régression

Appliquer uniquement le correctif identifié. Ajouter ou adapter un test qui échoue sans le correctif.

```powershell
php artisan test $RegressionTest
```

Exécuter le test avant le correctif pour constater l'échec, puis après le correctif pour constater le succès. Si le test ne peut pas être exécuté avant, documenter pourquoi dans la PR.

Committer de façon atomique :

```powershell
git add $FixedFile $RegressionTest
git diff --cached --check
git commit -m "fix(scope): corriger ..." -m "Refs: $Ticket"
```

- Le type est `fix` ; la portée est obligatoire ; la description est en minuscules, à l'infinitif, sans point final.
- Si le correctif touche plusieurs fichiers, ajouter tous les fichiers concernés dans `git add`, pas seulement `$FixedFile`.
- Si le test mérite un commit séparé : `test(scope): ...` avec `Refs: $Ticket`.
- Ne jamais inclure de fichier non lié, de secret, de `.env` ou de donnée personnelle.

Relire le diff de la branche :

```powershell
git status --short
git diff --stat origin/main...HEAD
git diff origin/main...HEAD
git diff --check origin/main...HEAD
```

Le diff doit se limiter au correctif, au test et à la documentation strictement nécessaire.

### 17.5 Exécuter les contrôles locaux

```powershell
composer lint:check
composer types:check
php artisan test
composer ci:check --no-interaction
```

`composer ci:check` exécute déjà `php artisan test` via le script Composer `test`. L'exécution séparée de `php artisan test` sert au retour rapide ; le résultat final à consigner est celui de `composer ci:check`.

Si le correctif touche SQL, migration, contrainte ou comportement moteur :

```powershell
php artisan config:clear
php artisan migrate:status
vendor\bin\pest --configuration=phpunit.mariadb.xml
```

La base MariaDB locale doit être la base de test isolée décrite dans [`testing.md`](testing.md). Ne jamais exécuter `migrate:fresh`, `migrate:refresh`, `migrate:reset`, `db:wipe` ou `migrate:rollback` sur une base non explicitement isolée.

Si le correctif touche le frontend :

```powershell
npm ci
npm run build
php scripts/ci/verify-vite-build.php
```

Contrôles finaux :

```powershell
git diff --check origin/main...HEAD
git status --short
```

### 17.6 Pousser la branche temporaire

```powershell
git push -u origin $Branch
git ls-remote --heads origin $Branch
```

- Aucun `--force`, aucun `--force-with-lease`, aucun `--no-verify`.
- Le push d'une branche temporaire est autorisé ; les pushes directs sur `main` et `develop` restent interdits.
- Le push de la branche seule ne déclenche pas `tests.yml` : la CI sera déclenchée par la Pull Request vers `main`.

### 17.7 Ouvrir la Pull Request vers main

Remplir un corps de PR à partir de [`.github/PULL_REQUEST_TEMPLATE.md`](../../.github/PULL_REQUEST_TEMPLATE.md) et y ajouter les éléments hotfix : sévérité P1/P2, version déployée, commit de production, tag, release, version cible, migration, rollback, plan de validation staging et preuves.

```powershell
$PrUrl = gh pr create --base main --head $Branch --title "fix(scope): ... ($Ticket)" --body-file $PrBody
$Pr = gh pr view $PrUrl --json number --jq '.number'
gh pr view $Pr --json number,baseRefName,headRefName,isDraft,mergeable,mergeStateStatus,statusCheckRollup,url
```

Vérifier que la base est `main`, que la tête est `$Branch` et que la PR n'est pas en brouillon.

```powershell
gh pr diff $Pr
gh pr checks $Pr --watch
```

Le contrôle obligatoire est `ci`. Le processus exige en plus que les jobs `sqlite`, `mariadb-10.11` et `package-linux` soient verts. Une PR dont un job échoue ne doit pas être fusionnée.

Si `main` avance pendant la revue, mettre la branche à jour par fusion, jamais par rebase :

```powershell
git switch $Branch
git fetch origin main
git merge origin/main
git push origin $Branch
```

Résoudre les conflits si nécessaire, puis relancer les contrôles. Le ruleset n'exige pas une branche à jour, mais le processus l'exige.

### 17.8 Vérifier la revue et enregistrer l'autorisation humaine

Appliquer [`pull-request-review.md`](pull-request-review.md), puis enregistrer le GO :

```powershell
gh pr comment $Pr --body "GO hotfix — $(Get-Date -Format o) — VOTRE_NOM — version cible $Version"
```

La fusion n'est autorisée que si :

- [ ] la base est `main` et la tête est `$Branch` ;
- [ ] le contrôle `ci` est vert ;
- [ ] les jobs `sqlite`, `mariadb-10.11` et `package-linux` sont verts ;
- [ ] les commentaires de revue sont résolus ;
- [ ] le diff ne contient aucun secret ni donnée sensible ;
- [ ] le périmètre est minimal et le test de non-régression est présent ;
- [ ] la branche est à jour avec `main` ;
- [ ] l'email de commit est attribué au compte GitHub ;
- [ ] aucune release ou aucun déploiement n'est en cours ;
- [ ] la version cible n'existe pas ;
- [ ] le GO humain est enregistré.

Les rulesets n'exigent aucune approbation. Le GO ci-dessus est une décision de processus obligatoire, pas une approbation GitHub.

### 17.9 Fusionner la Pull Request

```powershell
gh pr merge $Pr --merge
```

- `--merge` est recommandé pour conserver un historique traçable.
- `--rebase` est autorisé par les rulesets, mais réécrit le SHA ; si cette méthode est utilisée, consigner le commit final.
- `--squash` est interdit sur `main` et `develop` par les rulesets.
- Ne jamais utiliser `--admin`, ni contourner un ruleset.
- L'auto-merge est désactivé sur le dépôt ; ne pas utiliser `--auto`.

Après la fusion :

```powershell
git switch main
git fetch origin main
git pull --ff-only
git log -1 --oneline
$MergeCommit = git rev-parse HEAD
gh pr view $Pr --json mergeCommit --jq '.mergeCommit.oid'
```

`$MergeCommit` doit correspondre au commit de fusion retourné par GitHub. Si la fusion a été faite par rebase, GitHub peut retourner `null` : utiliser alors le SHA de `HEAD` de `main` consigné ci-dessus. Attendre la CI sur `main` :

```powershell
gh run list --workflow tests.yml --branch main --limit 5 --json databaseId,headSha,status,conclusion,createdAt
gh run watch $RunId
```

Ne pas créer de tag RC ou stable avant le succès de cette CI. Les tags relèvent du Lot 3.

Supprimer la branche temporaire après fusion :

```powershell
git branch -d $Branch
git push origin --delete $Branch
```

Si la fusion a été faite par rebase et que `git branch -d` refuse, vérifier que la PR est bien fusionnée avant d'utiliser `git branch -D`. Ne jamais supprimer `main` ou `develop`.

### 17.10 Préflight et synchronisation main vers develop

La synchronisation intervient après la fusion dans `main` et avant la création de la RC, conformément à l'option A. Le parcours direct est autorisé si la fusion est propre ; le parcours par branche est obligatoire en cas de conflit ou de vérification locale.

#### 17.10.1 Préflight et décision

```powershell
git fetch origin main develop
$MainSha = git rev-parse origin/main
$DevelopSha = git rev-parse origin/develop
$DevelopBeforeSync = $DevelopSha
$HotfixCommit = $MergeCommit   # défini en 17.9 ; sinon renseigner le SHA du hotfix

git merge-base --is-ancestor $HotfixCommit origin/main
if ($LASTEXITCODE -ne 0) { throw "Le hotfix n'est pas dans main." }

git merge-base --is-ancestor $HotfixCommit origin/develop
if ($LASTEXITCODE -eq 0) { Write-Output "Le hotfix est déjà dans develop : vérifier le contenu et la CI. La synchronisation reste nécessaire si main n'est pas entièrement intégré." }

git merge-base --is-ancestor origin/main origin/develop
if ($LASTEXITCODE -eq 0) { throw "main est déjà intégré dans develop : vérifier le contenu et la CI, aucune PR." }

$RemoteMain = (git ls-remote origin refs/heads/main).Split("`t")[0]
$RemoteDevelop = (git ls-remote origin refs/heads/develop).Split("`t")[0]
if ($MainSha -ne $RemoteMain -or $DevelopSha -ne $RemoteDevelop) {
  throw "Références distantes modifiées : refaire le fetch et recommencer."
}

gh pr list --base develop --head main --state open --json number,title,url
gh pr list --base develop --head $SyncBranch --state open --json number,title,url
```

Consigner `$MainSha`, `$DevelopSha`, `$HotfixCommit` et le parcours choisi. Si une PR de synchronisation est déjà ouverte, ne pas en créer une seconde : l'analyser et la traiter.

- **Parcours direct** : si la fusion est propre et qu'aucune résolution locale n'est nécessaire.
- **Parcours par branche** : si la PR directe est en conflit, si une résolution locale ou un contrôle sur branche est nécessaire, ou si la PR directe ne peut pas être créée.

#### 17.10.2 Cas A — PR directe sans conflit

```powershell
$SyncUrl = gh pr create --base develop --head main --title "chore(sync): reporter le hotfix $Ticket dans develop" --body-file $SyncBody
$SyncPr = gh pr view $SyncUrl --json number --jq '.number'
gh pr view $SyncPr --json number,baseRefName,headRefName,isDraft,mergeable,mergeStateStatus,statusCheckRollup,url
gh pr checks $SyncPr --watch
gh pr merge $SyncPr --merge
```

Le corps de la PR doit contenir : ticket, PR hotfix, commit de fusion, SHA de `main` et de `develop`, raison de la synchronisation, contrôles exécutés et décision de parcours.

Ne jamais utiliser `--rebase` ni `--squash`. Avant la fusion, vérifier que la base est `develop`, que la tête est `main`, que la CI est verte, que la revue est traitée et que l'autorisation humaine est enregistrée.

#### 17.10.3 Cas A — branche de synchronisation sans conflit

```powershell
git switch develop
git pull --ff-only
git status --short
if ((git rev-parse HEAD) -ne $DevelopSha) { throw "develop local n'est pas sur le SHA attendu." }
git rev-parse --verify --quiet "refs/heads/$SyncBranch"
if ($LASTEXITCODE -eq 0) { throw "La branche locale $SyncBranch existe déjà." }
$ExistingSyncBranch = git ls-remote --heads origin $SyncBranch
if ($ExistingSyncBranch) { throw "La branche distante $SyncBranch existe déjà." }

git switch -c $SyncBranch origin/develop
git rev-parse --abbrev-ref HEAD
git merge-base --is-ancestor origin/develop HEAD
if ($LASTEXITCODE -ne 0) { throw "La branche de synchronisation n'est pas basée sur develop." }

git fetch origin main
git merge --no-edit origin/main
git status --short
git diff --name-only --diff-filter=U
```

Si la fusion est propre :

```powershell
git merge-base --is-ancestor $HotfixCommit HEAD
if ($LASTEXITCODE -ne 0) { throw "Le hotfix n'est pas dans la branche de synchronisation." }
git merge-base --is-ancestor $DevelopBeforeSync HEAD
if ($LASTEXITCODE -ne 0) { throw "Le develop initial n'est pas dans la branche de synchronisation." }
git diff --name-only origin/develop...HEAD
git diff --check
php artisan test $RegressionTest
composer ci:check --no-interaction
git push -u origin $SyncBranch
$SyncUrl = gh pr create --base develop --head $SyncBranch --title "chore(sync): reporter le hotfix $Ticket dans develop" --body-file $SyncBody
$SyncPr = gh pr view $SyncUrl --json number --jq '.number'
gh pr checks $SyncPr --watch
gh pr merge $SyncPr --merge
```

- `git status --short` doit être vide avant la création de la branche ; sinon, arrêter.
- Le diff `origin/develop...HEAD` doit contenir le hotfix et les éventuels fichiers de résolution, sans suppression de fichiers propres à `develop`.
- Si un conflit apparaît, passer à 17.11.
- Après fusion, passer à 17.12. Si le parcours par branche a été utilisé, supprimer `$SyncBranch` après la fusion, localement et sur le dépôt distant.

### 17.11 Traiter les conflits de synchronisation

Si une PR directe `main` → `develop` est ouverte et en conflit, la fermer sans la fusionner :

```powershell
gh pr close $SyncPr --comment "Conflits : reprise par la branche $SyncBranch."
```

Ne pas pousser sur `main`, ne pas forcer et ne pas rebaser.

1. Récupérer les références et créer la branche depuis `origin/develop` :

   ```powershell
   git fetch origin main develop
   git rev-parse --verify --quiet "refs/heads/$SyncBranch"
   if ($LASTEXITCODE -eq 0) { throw "La branche locale $SyncBranch existe déjà." }
   $ExistingSyncBranch = git ls-remote --heads origin $SyncBranch
   if ($ExistingSyncBranch) { throw "La branche distante $SyncBranch existe déjà." }
   git switch -c $SyncBranch origin/develop
   git merge-base --is-ancestor origin/develop HEAD
   if ($LASTEXITCODE -ne 0) { throw "La branche de synchronisation n'est pas basée sur develop." }
   ```

2. Fusionner `main` dans la branche :

   ```powershell
   git merge --no-edit origin/main
   git status --short
   git diff --name-only --diff-filter=U
   ```

3. Identifier les fichiers en conflit. Une résolution manuelle est nécessaire dès qu'un fichier est modifié des deux côtés, renommé, supprimé d'un côté, ou que le conflit touche une migration, un fichier généré, un verrou de dépendances ou une règle métier.

4. Résoudre les conflits fichier par fichier. Ne pas supprimer le correctif et ne pas écraser les évolutions propres à `develop`. Ne pas utiliser `-X ours`, `-X theirs`, `git checkout --ours` ou `git checkout --theirs` de façon globale sans revue explicite.

5. Finaliser la fusion :

   ```powershell
   git status --short
   git add -u
   git commit --no-edit
   git diff --check
   git merge-base --is-ancestor $HotfixCommit HEAD
   if ($LASTEXITCODE -ne 0) { throw "Le hotfix a disparu de la résolution." }
   git merge-base --is-ancestor $DevelopBeforeSync HEAD
   if ($LASTEXITCODE -ne 0) { throw "Le develop initial a disparu de la résolution." }
   git diff --name-only origin/develop...HEAD
   php artisan test $RegressionTest
   composer ci:check --no-interaction
   ```

   `git add -u` ne prend que les fichiers déjà suivis. Vérifier `git status --short` avant de committer et ne pas ajouter de fichier non lié. Si un fichier nouveau fait partie de la résolution, l'ajouter explicitement avec `git add chemin/du/fichier`.

6. Pousser et ouvrir la PR vers `develop` :

   ```powershell
   git push -u origin $SyncBranch
   $SyncUrl = gh pr create --base develop --head $SyncBranch --title "chore(sync): reporter le hotfix $Ticket dans develop" --body-file $SyncBody
   $SyncPr = gh pr view $SyncUrl --json number --jq '.number'
   gh pr checks $SyncPr --watch
   ```

7. Fusionner avec `gh pr merge $SyncPr --merge`.
8. Vérifier la présence du correctif, l'historique et la CI de `develop` (section 17.12).

Si les conflits ne peuvent pas être résolus sans casser des évolutions de `develop`, ou si la résolution exige de choisir arbitrairement entre deux évolutions, s'arrêter : aucune nouvelle release depuis `develop` ne doit être ouverte avant une décision explicite.

### 17.12 Vérifier la présence du correctif et l'historique dans develop

```powershell
git fetch origin develop

git merge-base --is-ancestor $HotfixCommit origin/develop
if ($LASTEXITCODE -ne 0) { throw "Le commit de hotfix n'est pas dans develop." }

git merge-base --is-ancestor $DevelopBeforeSync origin/develop
if ($LASTEXITCODE -ne 0) { throw "Le develop initial n'est pas conservé dans develop." }

git switch develop
git pull --ff-only
git log --oneline --decorate --graph -15
git show --stat $HotfixCommit
git diff "$HotfixCommit^" $HotfixCommit -- $FixedFile
php artisan test $RegressionTest
```

Attendre et vérifier la CI sur `develop` :

```powershell
gh run list --workflow tests.yml --branch develop --limit 5 --json databaseId,headSha,status,conclusion,createdAt
gh run watch $RunId
```

La synchronisation n'est terminée que si les deux SHA (`$HotfixCommit` et `$DevelopBeforeSync`) sont ancêtres de `origin/develop`, que le correctif est présent, que le test de non-régression est vert, que l'historique contient les deux branches et que la CI de `develop` est verte. Aucune nouvelle release depuis `develop` ne doit être ouverte avant ces vérifications.

### 17.13 Scénarios d'échec et points d'arrêt

| Situation | Décision |
| --- | --- |
| Dépôt local non propre | Arrêter et nettoyer ; ne pas mélanger les modifications. |
| `main` différente du commit de production | NO-GO jusqu'à régularisation. |
| Tag de production non annoté ou release non publiée | NO-GO. |
| `release.json` absent ou incohérent | NO-GO. |
| Version cible déjà utilisée | Choisir le PATCH suivant ; ne jamais réutiliser un tag. |
| CI rouge sur la PR | Corriger et relancer ; ne pas fusionner. |
| `ci` vert mais un autre job rouge | Ne pas fusionner ; le processus exige tous les jobs verts. |
| `main` avance pendant la revue | Fusionner `main` dans la branche, jamais rebaser ; relancer les contrôles. |
| Fusion bloquée par un ruleset | Diagnostiquer ; ne jamais utiliser `--admin` ni contourner. |
| Email de commit non attribué | Corriger l'adresse ou le compte ; ne pas contourner. |
| Conflit de synchronisation | Branche `bugfix/CHAN-xxx-synchronisation-hotfix` depuis `develop`. |
| CI rouge sur la synchronisation | Corriger et relancer ; ne pas fusionner. |
| Correctif absent de `develop` | Arrêter ; aucune release depuis `develop`. |
| Release ou déploiement en cours | Attendre la fin. |
| Doute sur la sécurité ou les données | NO-GO et escalade. |

### 17.14 Cohérence avec les protections GitHub réelles

Protections vérifiées le **17 novembre 2026** via l'API GitHub, en lecture seule. `protect-main` couvre la branche par défaut ; `protect-develop` couvre `refs/heads/develop`.

#### Rulesets de branches

| Règle | `protect-main` | `protect-develop` | Conséquence sur les commandes |
| --- | --- | --- | --- |
| Pull Request obligatoire | Oui | Oui | `gh pr create`, jamais de push direct. |
| Méthodes de fusion | `merge`, `rebase` | `merge`, `rebase` | `gh pr merge --merge` ou `--rebase`, jamais `--squash`. |
| Contrôle requis | `ci` | `ci` | `gh pr checks --watch` avant fusion. |
| Approbations obligatoires | 0 | 0 | Le GO humain est enregistré par commentaire. |
| Approbation supplémentaire pour commits non attribués | Oui | Oui | Vérifier `git config user.email` et l'attribution GitHub. |
| Résolution des commentaires | Non exigée par le ruleset | Non exigée par le ruleset | Le processus exige la résolution des commentaires. |
| Branche à jour avant fusion | Non exigé par le ruleset | Non exigé par le ruleset | Le processus exige la fusion de `main` dans la branche avant fusion. |
| Force-push | Interdit | Interdit | Aucun `--force` ni `--force-with-lease`. |
| Suppression de branche | Interdite | Interdite | Supprimer uniquement les branches temporaires. |
| Bypass | Aucun | Aucun | Aucun `--admin`, aucun contournement. |

#### Réglages du dépôt

| Réglage | Valeur constatée | Conséquence sur les commandes |
| --- | --- | --- |
| `allow_merge_commit` | `true` | `gh pr merge --merge` autorisé par le dépôt et les rulesets. |
| `allow_rebase_merge` | `true` | `gh pr merge --rebase` autorisé par le dépôt et les rulesets. |
| `allow_squash_merge` | `true` | `gh pr merge --squash` techniquement disponible, mais refusé par les rulesets sur `main` et `develop`. |
| `allow_auto_merge` | `false` | Ne pas utiliser `gh pr merge --auto`. |
| `delete_branch_on_merge` | `false` | Supprimer manuellement la branche temporaire après fusion. |
| Protection des tags | Aucune | Les tags restent soumis à la convention ; ils relèvent du Lot 3. |

Commandes de vérification, en lecture seule :

```powershell
gh api repos/C2ME-ORGA/chantier/rulesets --jq '.[] | {id,name,target,enforcement}'
gh api "repos/C2ME-ORGA/chantier/rulesets/$RulesetId" --jq '{name,conditions,rules:[.rules[]|{type,parameters}],bypass_actors}'
gh api repos/C2ME-ORGA/chantier --jq '{allow_merge_commit,allow_squash_merge,allow_rebase_merge,allow_auto_merge,delete_branch_on_merge}'
```

Les protections effectivement configurées font foi. Si elles changent, ce document doit être corrigé.

### 17.15 Récapitulatif des commandes

| Étape | Commande principale |
| --- | --- |
| Préflight | `git fetch origin main develop --tags`, `git switch main`, `git pull --ff-only`, `git rev-parse`, `git merge-base --is-ancestor`, `gh release view`. |
| Branche | `git switch -c $Branch`. |
| Commit | `git add`, `git diff --cached --check`, `git commit -m "fix(scope): ..." -m "Refs: $Ticket"`. |
| Contrôles | `composer lint:check`, `composer types:check`, `php artisan test`, `composer ci:check --no-interaction`. |
| Push | `git push -u origin $Branch`. |
| PR main | `gh pr create --base main --head $Branch`, `gh pr checks $Pr --watch`. |
| GO | `gh pr comment $Pr --body "GO hotfix ..."`. |
| Fusion main | `gh pr merge $Pr --merge`. |
| CI main | `gh run list --workflow tests.yml --branch main`, `gh run watch`. |
| Sync develop | `gh pr create --base develop --head main`, `gh pr checks $SyncPr --watch`, `gh pr merge $SyncPr --merge`. |
| Conflits | `git switch -c $SyncBranch`, `git merge origin/main`, `git push -u origin $SyncBranch`, `gh pr create --base develop --head $SyncBranch`. |
| Vérification | `git merge-base --is-ancestor $MergeCommit origin/develop`, `git show --stat $MergeCommit`, `php artisan test $RegressionTest`. |

### 17.16 Ce que le Lot 2 ne fait pas

- Aucune commande de tag, de release ou de déploiement : Lot 3.
- Aucune modification des workflows `release.yml`, `deploy-staging.yml` ou `deploy-production.yml`.
- Aucun push réel, aucune PR réelle, aucune fusion réelle.
- Aucune modification Jira.
- Aucun accès serveur.

## 18. Références

- [`AGENTS.md`](../../AGENTS.md) — règles impératives du dépôt.
- [`README.md`](../../README.md) — présentation, installation et workflow Git.
- [`git-workflow.md`](git-workflow.md) — branches, commits, Pull Requests et protections.
- [`release-process.md`](release-process.md) — versionnement, tags et releases.
- [`deployment-process.md`](deployment-process.md) — artefacts, promotion et déploiement.
- [`environments.md`](environments.md) — environnements, secrets et protections.
- [`database-migrations.md`](database-migrations.md) — migrations et compatibilité N/N-1.
- [`application-rollback.md`](application-rollback.md) — rollback applicatif.
- [`application-rollback-runbook.md`](application-rollback-runbook.md) — procédure opérateur de rollback.
- [`pull-request-review.md`](pull-request-review.md) — checklist de revue technique.
- [`testing.md`](testing.md) — suites de tests et commandes.
- [`tests.yml`](../../.github/workflows/tests.yml) — contrôle d'intégration continue.
- [`release.yml`](../../.github/workflows/release.yml) — automatisation des releases.
- [`validate-release-tag.sh`](../../.github/scripts/deploy/validate-release-tag.sh) — validation des tags de release.
- [`deploy-staging.yml`](../../.github/workflows/deploy-staging.yml) — déploiement staging.
- [`deploy-production.yml`](../../.github/workflows/deploy-production.yml) — déploiement production.
- [`validate-tag.sh`](../../.github/scripts/deploy/validate-tag.sh) — validation des tags.
- [`validate-release.sh`](../../.github/scripts/deploy/validate-release.sh) — validation des releases.
- [`stable-candidate.sh`](../../.github/scripts/deploy/stable-candidate.sh) — référence de la candidate staging.
- [`resolve-promotion.sh`](../../.github/scripts/deploy/resolve-promotion.sh) — promotion staging → production.
- [`validate-workflows.php`](../../.github/scripts/tests/validate-workflows.php) — validation structurelle des workflows.
- [`test-release-automation.sh`](../../.github/scripts/tests/test-release-automation.sh) — tests de l'automatisation de release.
- [`test-deployment-automation.sh`](../../.github/scripts/tests/test-deployment-automation.sh) — tests de l'automatisation de déploiement.
- [`composer.json`](../../composer.json) — scripts de qualité et de test.
