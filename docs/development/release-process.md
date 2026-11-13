# Processus de release et de versionnement

Ce document définit le versionnement, les tags, les notes de version et le processus de publication de **C2ME Chantier**.

- Ticket : CHAN-95 – Définir le processus de release et de versionnement.
- Ticket parent : CHAN-92 – Définir le workflow Git, les releases et les déploiements.
- Dépôt : [`C2ME-ORGA/chantier`](https://github.com/C2ME-ORGA/chantier).
- Portée : versionnement de l'application, tags Git, notes de version et releases GitHub.
- Hors portée : recette, migrations et rollback (CHAN-98). Les environnements de recette et de production et leurs protections sont définis dans [`environments.md`](environments.md) (CHAN-96). Les déploiements automatisés et la promotion des artefacts sont définis dans [`deployment-process.md`](deployment-process.md) (CHAN-97).

## Sources de vérité

| Sujet | Référence |
| --- | --- |
| Branches, commits et Pull Requests | [`git-workflow.md`](git-workflow.md) |
| Environnements et protections | [`environments.md`](environments.md) |
| Déploiements et promotion des artefacts | [`deployment-process.md`](deployment-process.md) |
| Versionnement, tags et releases | Ce document |
| Workflow de release | [`.github/workflows/release.yml`](../../.github/workflows/release.yml) |
| Génération des notes de version | [`.github/scripts/generate-release-notes.sh`](../../.github/scripts/generate-release-notes.sh) |
| Contrôle d'intégration continue | [`.github/workflows/tests.yml`](../../.github/workflows/tests.yml) |
| Règles impératives pour les agents et contributeurs | [`AGENTS.md`](../../AGENTS.md) |

En cas de divergence entre ce document et les tags effectivement publiés, les tags publiés et les releases GitHub correspondantes font foi. Une divergence doit être corrigée dans ce document.

## Principes

- Le **tag Git** est la seule source de vérité de la version. Aucune version n'est dupliquée dans `composer.json` ou `package.json`.
- Les versions suivent le [Semantic Versioning 2.0.0](https://semver.org/lang/fr/).
- Un tag publié est **immuable** : il n'est jamais déplacé, réutilisé ni supprimé.
- La sélection de version, la création du tag et la publication d'une release stable sont des décisions humaines explicites.
- Les notes de version sont générées automatiquement à partir des commits, puis relues avant la publication d'une version stable.
- Un tag de release candidate déclenche le déploiement en staging ; la publication d'une release stable déclenche la promotion du même artefact en production, selon [`deployment-process.md`](deployment-process.md) (CHAN-97).

## Contrat public

Une rupture de compatibilité s'apprécie par rapport au **contrat public** de l'application, notamment :

- les routes HTTP et les contrats d'API consommés par des clients ;
- le format des données échangées par le mode hors connexion ;
- les formats d'export et d'import ;
- les clés de configuration et les interfaces utilisées par des intégrations externes ;
- les règles métier dont le résultat est observable par un utilisateur ou un système externe.

Les changements internes sans impact observable sur ce contrat n'imposent pas à eux seuls une version majeure.

## Règles Semantic Versioning

Une version est au format `MAJOR.MINOR.PATCH`, sans zéro initial.

| Incrément | Cas d'usage | Exemples |
| --- | --- | --- |
| `MAJOR` | Rupture de compatibilité avec le contrat public. | Suppression ou renommage d'une route, format d'API modifié sans compatibilité, migration imposant une adaptation des clients hors connexion. |
| `MINOR` | Nouvelle fonctionnalité rétrocompatible. | Nouveau module, nouvelle route, nouveau champ optionnel, nouvelle action sans modifier les contrats existants. |
| `PATCH` | Correction rétrocompatible. | Correction de bug, amélioration de performance, correctif de sécurité sans rupture de contrat, documentation ou outillage publiés avec l'application. |

Une correction de sécurité qui modifie le contrat public de façon incompatible suit la règle `MAJOR`, pas la règle `PATCH`.

### Choix de la prochaine version

Depuis le dernier tag stable, dans cet ordre :

1. s'il existe au moins un changement incompatible, incrémenter `MAJOR` et remettre `MINOR` et `PATCH` à zéro ;
2. sinon, s'il existe au moins une fonctionnalité (`feat`), incrémenter `MINOR` et remettre `PATCH` à zéro ;
3. sinon, incrémenter `PATCH`.

Un changement interne publié sans fonctionnalité ni correction observable peut être différé. S'il est publié, il utilise un incrément `PATCH`.

Une release candidate ne consomme pas de version supplémentaire : `v1.3.0-rc.1` et `v1.3.0-rc.2` préparent la même version stable `v1.3.0`. Les tags de prérelease ne sont pas pris en compte pour le calcul de la prochaine version stable.

### Première version et période 0.x

La première version publiée est `v0.1.0`. Le passage à `v1.0.0` est une décision explicite qui marque la stabilisation du contrat public.

Tant que la version majeure est `0`, le contrat public est considéré comme instable, conformément à SemVer. Par exception documentée :

- une rupture de compatibilité incrémente la version **mineure** (`0.Y.0`) et reste classée dans les changements incompatibles des notes de version ;
- une fonctionnalité rétrocompatible incrémente également la version mineure (`0.Y.0`) ;
- une correction rétrocompatible incrémente la version `PATCH`.

À partir de `v1.0.0`, les règles `MAJOR`, `MINOR` et `PATCH` du tableau ci-dessus s'appliquent strictement.

Exemples en période 0.x :

| Version actuelle | Changement | Version suivante |
| --- | --- | --- |
| `v0.1.0` | Rupture de compatibilité. | `v0.2.0` |
| `v0.2.0` | Nouvelle fonctionnalité. | `v0.3.0` |
| `v0.3.0` | Correction de bug. | `v0.3.1` |

## Conventions de tags

### Formats autorisés

| Type | Format | Exemple |
| --- | --- | --- |
| Version stable | `vX.Y.Z` | `v1.4.0` |
| Release candidate | `vX.Y.Z-rc.N` | `v1.4.0-rc.1` |

Règles :

- le préfixe `v` est obligatoire ;
- `X`, `Y`, `Z` et `N` sont des entiers positifs ou nuls, sans zéro initial ;
- `N` commence à `1` et s'incrémente pour chaque nouvelle candidate de la même version ;
- les métadonnées de build (`+build`) et les autres suffixes de prérelease ne sont pas utilisés ;
- un tag stable ne doit jamais porter de suffixe ;
- un tag de release candidate ne doit jamais être transformé en tag stable : la version stable est un nouveau tag.

### Nature et cible des tags

Les tags de release sont des tags **annotés**, avec pour message le nom du tag :

```powershell
git tag -a v1.4.0 -m "v1.4.0"
git tag -a v1.4.0-rc.1 -m "v1.4.0-rc.1"
```

| Type de tag | Commit cible | Branche de référence |
| --- | --- | --- |
| Stable `vX.Y.Z` | Commit de `main` issu de la Pull Request de livraison ou du hotfix, après succès de `ci`. | `main` |
| Release candidate `vX.Y.Z-rc.N` | Commit de tête de `develop` après intégration des changements de la version. | `develop` |

Le workflow de release vérifie que le tag pointe exactement sur le HEAD de `origin/main` pour une version stable et sur le HEAD de `origin/develop` pour une release candidate. Un tag créé sur un autre commit, une branche temporaire ou un HEAD dépassé est refusé.

### Immuabilité

- Ne jamais déplacer, réutiliser ou supprimer un tag de release publié.
- Ne jamais réutiliser un numéro de version, même après suppression d'une release GitHub.
- Si une release candidate est erronée, créer `N+1`. Si une version stable est erronée, publier une nouvelle version `PATCH`, puis documenter l'incident.
- Ne jamais utiliser de force-push sur un tag.
- Les protections de branches documentées dans [`git-workflow.md`](git-workflow.md) ne couvrent pas les tags. Leur création doit rester réservée aux mainteneurs du dépôt. Aucune protection de tag n'est configurée à ce jour (vérifié le 12 novembre 2026).

## Notes de version

### Source

Les notes sont générées à partir des commits Conventional Commits compris entre le tag précédent et le tag publié :

```text
<tag-précédent>..<tag>
```

Les commits de fusion sont exclus. Les commits antérieurs aux conventions actuelles restent affichés : s'ils ne respectent pas le format Conventional Commits, ils sont classés dans « Autres changements ».

### Classement

| Section | Commits concernés |
| --- | --- |
| Changements incompatibles | Commit marqué `!` après le type ou la portée, ou contenant un footer `BREAKING CHANGE:` ou `BREAKING-CHANGE:`. |
| Fonctionnalités | Commits de type `feat` non incompatibles. |
| Corrections | Commits de type `fix` non incompatibles. |
| Autres changements | Types `perf`, `refactor`, `build`, `ci`, `docs`, `chore`, `test`, `revert`, commits non conventionnels et commits sans type reconnu. |

Un commit incompatible est affiché uniquement dans « Changements incompatibles » afin d'éviter les doublons. Le footer de rupture doit décrire l'impact et la migration attendue.

Une note de version ne remplace pas une Pull Request : les détails de migration restent dans la Pull Request et dans la documentation concernée.

### Tag précédent

- Pour une version stable `vX.Y.Z`, les notes couvrent les changements depuis le dernier tag **stable ancêtre** du tag courant.
- Pour une release candidate `vX.Y.Z-rc.N`, les notes couvrent les changements depuis la release candidate précédente de la même version qui est ancêtre du tag courant. Pour `rc.1`, le dernier tag stable ancêtre est utilisé.
- Un tag de version supérieure situé sur un historique divergent est ignoré. Le script refuse explicitement un tag précédent qui ne serait pas un ancêtre du tag courant.
- S'il n'existe aucun tag stable ancêtre, les notes couvrent l'historique complet et indiquent qu'il s'agit de la première version publiée. Si un tag stable existe mais n'est pas ancêtre, synchroniser `develop` depuis `main` avant de créer la release candidate ; aucune comparaison entre historiques divergents n'est effectuée.

### Génération automatisée

Le script [`.github/scripts/generate-release-notes.sh`](../../.github/scripts/generate-release-notes.sh) produit les notes Markdown. Il est appelé par le workflow de release et peut être exécuté localement depuis Git Bash, WSL ou Linux pour prévisualiser le résultat. Le tag doit exister localement après un `git fetch --tags` :

```bash
git fetch --tags
bash .github/scripts/generate-release-notes.sh v1.4.0 release-notes.md
```

Le fichier produit est un artefact local : il ne doit pas être versionné. Aucun fichier `CHANGELOG.md` n'est maintenu manuellement à ce stade ; les releases GitHub constituent le journal publié des versions.

Les tests de l'automatisation de release sont exécutés par le workflow `tests`. Ils peuvent aussi être lancés localement avec :

```bash
bash .github/scripts/tests/test-release-automation.sh
```

## Processus de publication

### 1. Intégration sur `develop`

Les fonctionnalités et corrections sont intégrées dans `develop` par Pull Request, conformément à [`git-workflow.md`](git-workflow.md). Le contrôle `ci` doit être vert avant chaque fusion.

`develop` est la source de la prochaine version. Avant de préparer une release, vérifier que :

- toutes les Pull Requests prévues pour la version sont fusionnées ;
- la dernière Pull Request fusionnée dans `develop` a un contrôle `ci` vert ;
- aucun correctif bloquant n'est en attente ;
- les migrations et les changements de configuration sont documentés.

### 2. Déterminer la version

Lister les commits depuis le dernier tag stable :

```powershell
git fetch --tags
git log --oneline --no-merges v0.4.0..develop
```

Appliquer les [règles de versionnement](#règles-semantic-versioning), puis noter la version cible, par exemple `v0.5.0`. La version n'est pas inscrite dans les fichiers du projet : elle sera portée par le tag.

### 3. Publier éventuellement une release candidate

Une release candidate est recommandée pour les versions importantes, les migrations sensibles ou les changements touchant le mode hors connexion. Elle est facultative pour une correction simple.

Le workflow `tests` ne se déclenche pas sur un push vers `develop` : la validation de la candidate s'appuie sur le `ci` vert de la dernière Pull Request fusionnée. En cas de doute, exécuter `composer test` sur le commit de `develop` avant de créer le tag.

Depuis `develop` à jour :

```powershell
git switch develop
git pull --ff-only
git status
git tag -a v0.5.0-rc.1 -m "v0.5.0-rc.1"
git push origin v0.5.0-rc.1
```

Le tag doit être créé sur le HEAD courant de `develop`. Ne pas fusionner d'autre changement avant la fin du workflow : la vérification exige une correspondance exacte entre le tag et le HEAD de `origin/develop`.

Le push du tag déclenche le workflow de release. Celui-ci :

1. vérifie le format du tag, son caractère annoté et sa correspondance exacte avec le HEAD de `develop` ;
2. génère les notes de version ;
3. crée ou met à jour une release GitHub marquée **pre-release**.

La release candidate est ensuite déployée automatiquement en recette par le workflow `deploy-staging`, conformément à [`deployment-process.md`](deployment-process.md). Le résultat de ce déploiement et le paquet publié servent de base à la future promotion en production.

Si une correction est nécessaire :

1. ouvrir une branche `bugfix/CHAN-<numéro>-<description>` ou `feature/CHAN-<numéro>-<description>` depuis `develop` ;
2. fusionner la correction dans `develop` par Pull Request avec `ci` vert ;
3. créer `v0.5.0-rc.2` sur le nouveau commit de tête de `develop`.

Ne jamais déplacer `rc.1` ni réutiliser son numéro.

Pendant la validation d'une release candidate, `develop` doit rester concentré sur les correctifs de cette version. Les changements sans lien avec la release ne doivent pas être fusionnés avant la publication stable, sinon la Pull Request de stabilisation emporterait du code non validé. Si un changement doit être intégré malgré tout, une nouvelle release candidate est obligatoire.

### 4. Ouvrir la Pull Request de stabilisation

Lorsque `develop` contient exactement le contenu validé, ouvrir une Pull Request de `develop` vers `main`.

Titre recommandé :

```text
chore(release): publier v0.5.0 (CHAN-123)
```

La Pull Request doit contenir :

- la version cible et le tag prévu ;
- le résumé des changements depuis la dernière version stable ;
- les releases candidates testées, s'il y en a ;
- les tests et contrôles réellement exécutés ;
- les migrations et les changements de configuration à surveiller ;
- les ruptures de compatibilité et leur migration ;
- les risques connus et les points d'attention ;
- la checklist de validation ci-dessous.

Le contrôle `ci` est obligatoire. La fusion se fait avec `merge` ou `rebase`, jamais avec `squash`, conformément aux règles de branches protégées.

### 5. Créer le tag stable et publier la release

Après la fusion de la Pull Request dans `main` :

1. attendre le succès du workflow `tests` déclenché par le push sur `main` ;
2. récupérer `main` et vérifier le commit cible ;
3. créer le tag stable annoté ;
4. pousser le tag ;
5. vérifier la release GitHub générée en brouillon ;
6. publier la release après validation des notes.

```powershell
git switch main
git pull --ff-only
git log -1 --oneline
git tag -a v0.5.0 -m "v0.5.0"
git push origin v0.5.0
```

Le tag doit être créé sur le HEAD courant de `main`. Ne pas fusionner d'autre changement avant la fin du workflow : la vérification exige une correspondance exacte entre le tag et le HEAD de `origin/main`.

Le workflow de release génère les notes et crée une release GitHub en **brouillon** pour une version stable. Le brouillon doit être relu puis publié explicitement :

```powershell
gh release view v0.5.0
gh release edit v0.5.0 --draft=false
```

La publication peut aussi se faire depuis l'interface GitHub. Tant que la release stable est un brouillon, elle ne doit pas être considérée comme publiée.

Le workflow ajoute automatiquement une section `Déploiement` aux notes d'une version stable. Lorsqu'une release candidate vérifiable existe (même version de base, tag annoté ancêtre, arbre Git identique), elle contient la ligne :

```text
Staging-Candidate: v0.5.0-rc.2
```

Cette référence est obligatoire pour le déploiement en production. Sans candidate vérifiable, la release reste publiable mais n'est pas déployable ; le workflow de production échoue explicitement. Ne jamais ajouter cette ligne manuellement pour contourner une candidate absente ou invalide.

Les notes peuvent être corrigées avant publication si le classement ou une description est incorrect. Ne jamais modifier le tag pour corriger des notes, ni la référence `Staging-Candidate` pour forcer un déploiement.

### 6. Cas d'un hotfix

Un hotfix corrige une anomalie urgente en production et ne doit contenir ni fonctionnalité ni rupture de compatibilité. Il suit le flux décrit dans [`git-workflow.md`](git-workflow.md) :

1. créer `hotfix/CHAN-<numéro>-<description>` depuis `main` ;
2. ouvrir une Pull Request vers `main` et obtenir un `ci` vert ;
3. fusionner avec `merge` ou `rebase` ;
4. attendre le `ci` sur `main` ;
5. créer le tag `PATCH` sur `main`, par exemple `v0.5.1` ;
6. vérifier et publier la release en brouillon ;
7. synchroniser `develop` depuis `main` par une Pull Request dédiée.

Si le correctif impose une rupture de compatibilité, ce n'est pas un hotfix : il suit le processus normal de version majeure.

Après un hotfix, la prochaine version issue de `develop` doit être calculée à partir du dernier tag stable, en tenant compte du `PATCH` déjà publié.

### 7. Après la publication

- Supprimer les branches temporaires fusionnées.
- Vérifier que la release GitHub est publiée, avec le bon tag et les bonnes notes.
- Ne créer aucun tag stable sur `develop` : la version stable est toujours taguée sur `main`.
- Ne déclencher aucun déploiement manuel en dehors du processus défini par CHAN-97.

## Validation avant publication stable

Une version stable ne peut être publiée que si :

- [ ] Tous les changements de la version sont intégrés dans `develop` par Pull Request.
- [ ] Le contrôle `ci` est vert sur la dernière Pull Request de `develop` et sur le commit de `main` fusionné.
- [ ] La version respecte les règles Semantic Versioning et n'a jamais été utilisée.
- [ ] La release candidate a été validée, si une release candidate a été publiée.
- [ ] Aucun défaut bloquant connu n'est ouvert sur le périmètre de la version.
- [ ] Les changements incompatibles sont documentés avec leur migration.
- [ ] Les migrations de base de données ont été relues et sont compatibles avec la livraison prévue.
- [ ] Les notes de version générées sont relues et correctement classées.
- [ ] Aucun secret, token, mot de passe ou donnée personnelle réelle n'est présent dans le diff ou les notes.
- [ ] La documentation impactée est mise à jour.
- [ ] Le tag est créé sur `main`, au format attendu, puis poussé.
- [ ] La release GitHub en brouillon est relue puis publiée explicitement.

## Automatisation

Le workflow [`.github/workflows/release.yml`](../../.github/workflows/release.yml) est déclenché par le push d'un tag correspondant à `vX.Y.Z` ou `vX.Y.Z-rc.N`.

Il :

- valide le format du tag et vérifie qu'il est annoté ;
- refuse un tag stable qui ne pointe pas exactement sur le HEAD de `main` et une release candidate qui ne pointe pas exactement sur le HEAD de `develop` ;
- génère les notes avec le script dédié ;
- crée une release **pre-release** publiée pour une release candidate ;
- crée une release **brouillon** pour une version stable ;
- ajoute aux notes d'une version stable la référence `Staging-Candidate` vérifiable, ou une mention explicite d'absence de candidate ;
- met à jour la release existante si le workflow est relancé pour le même tag.

Caractéristiques de sécurité et de maintenance :

- le workflow ne dispose que de la permission `contents: write`, nécessaire à la création de la release ;
- il utilise le `GITHUB_TOKEN` fourni par GitHub Actions, sans secret supplémentaire ;
- la seule action externe est `actions/checkout`, épinglée par SHA comme dans le workflow de tests ;
- aucune action tierce de release, aucun gestionnaire de changelog et aucune dépendance supplémentaire ne sont ajoutés ;
- le workflow ne déploie rien lui-même et ne modifie pas les branches : les déploiements sont assurés par des workflows distincts, documentés dans [`deployment-process.md`](deployment-process.md) ;
- un tag publié n'est jamais déplacé par l'automatisation.

Le workflow de release ne rejoue pas les tests. Le succès de `ci` sur le commit tagué est un prérequis humain vérifié avant la création du tag. En cas d'échec transitoire du workflow, relancer le job sans recréer le tag. Si le workflow lui-même doit être corrigé, exécuter le script localement puis mettre à jour la release avec `gh release edit` ; ne jamais déplacer le tag.

## Points hors périmètre et limites connues

- Les environnements de recette et de production et leurs protections sont définis dans [`environments.md`](environments.md) (CHAN-96).
- Les déploiements et la promotion des artefacts sont définis dans [`deployment-process.md`](deployment-process.md) (CHAN-97). La recette fonctionnelle, les migrations et le rollback relèvent de CHAN-98.
- Le déploiement en production exige une release candidate vérifiable référencée dans la release stable ; une version stable sans candidate reste publiable mais n'est pas déployable.
- Aucune protection de tag n'est configurée (vérifié le 12 novembre 2026). Les tags ne sont donc protégés que par la convention et les droits des collaborateurs.
- La version n'est pas exposée par l'application à l'exécution. Le tag reste la source de vérité.
- Aucun fichier `CHANGELOG.md` n'est maintenu. Les releases GitHub portent les notes publiées.
- La cadence des releases n'est pas imposée : une version stable est publiée lorsqu'un ensemble de changements cohérent est prêt et validé.
