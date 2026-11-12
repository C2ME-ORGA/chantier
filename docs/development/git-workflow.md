# Conventions Git

Ce document définit les conventions de branches, de commits et de Pull Requests du projet **C2ME Chantier**.

- Ticket : CHAN-93 – Documenter les conventions de branches et de nommage.
- Ticket parent : CHAN-92 – Définir le workflow Git, les releases et les déploiements.
- Dépôt : [`C2ME-ORGA/chantier`](https://github.com/C2ME-ORGA/chantier).
- Portée : conventions applicables à toutes les contributions au dépôt.

Les règles de branches, de commits et de Pull Requests décrites ici sont applicables à compter de CHAN-93. Le versionnement, les tags et le processus de release sont définis dans [`release-process.md`](release-process.md) depuis CHAN-95. Les environnements et leurs protections sont définis dans [`environments.md`](environments.md) depuis CHAN-96. Les déploiements restent hors périmètre et relèvent de CHAN-97.

## Sources de vérité

| Sujet | Référence |
| --- | --- |
| Versionnement, tags et releases | [`release-process.md`](release-process.md) |
| Environnements et protections | [`environments.md`](environments.md) |
| Règles impératives pour les agents et contributeurs | [`AGENTS.md`](../../AGENTS.md) |
| Présentation du projet et démarrage local | [`README.md`](../../README.md) |
| Contrôle d'intégration continue | [`.github/workflows/tests.yml`](../../.github/workflows/tests.yml) |
| Automatisation des releases | [`.github/workflows/release.yml`](../../.github/workflows/release.yml) |

En cas de divergence, les protections GitHub effectivement configurées font foi pour les règles qu'elles appliquent. Ce document doit alors être corrigé.

## Branches permanentes

| Branche | Rôle | Alimentation | Fusion sortante |
| --- | --- | --- | --- |
| `main` | Branche de référence des versions de production. | Pull Request depuis `develop` ou `hotfix/*`. | Vers `develop` pour reporter un hotfix. |
| `develop` | Branche d'intégration continue. | Pull Request depuis `feature/*` et `bugfix/*`, et synchronisation depuis `main`. | Vers `main` pour les livraisons. |

`main` est la branche par défaut du dépôt. Elle ne doit contenir que du code destiné à la production.

Les pushes directs sur `main` et `develop` sont interdits et bloqués par les rulesets GitHub. Toute modification passe par une Pull Request.

## Branches temporaires

| Préfixe | Usage | Branche de création | Branche cible de la Pull Request |
| --- | --- | --- | --- |
| `feature/` | Nouvelle fonctionnalité. | `develop` | `develop` |
| `bugfix/` | Correction non urgente. | `develop` | `develop` |
| `hotfix/` | Correction urgente issue de la production. | `main` | `main` (PR), puis `develop` (PR de synchronisation) |

Une branche temporaire ne doit servir qu'à un seul ticket Jira et à un seul sujet fonctionnel.

### Règles de nommage

Format obligatoire :

```text
<type>/CHAN-<numéro>-<description>
```

- `<type>` : `feature`, `bugfix` ou `hotfix`. Le préfixe est obligatoire et doit correspondre à la nature du travail.
- `CHAN-<numéro>` : clé Jira obligatoire, avec un numéro sans zéros superflus.
- `<description>` : description courte et explicite, en minuscules, en ASCII, avec des tirets pour séparer les mots.
- La description ne doit contenir ni espace, ni underscore, ni accent, ni majuscule, ni tiret en début ou en fin.
- Éviter les descriptions vagues du type `misc`, `update` ou `fix`.

Exemples valides :

```text
feature/CHAN-93-branch-conventions
feature/CHAN-101-saisie-chantiers
bugfix/CHAN-118-permissions-devis
hotfix/CHAN-125-calcul-tva
```

Exemples invalides :

| Exemple | Motif du rejet |
| --- | --- |
| `feature/chantiers` | Clé Jira absente. |
| `Feature/CHAN-93-branch-conventions` | Préfixe en majuscules. |
| `fix/CHAN-93-correction` | Préfixe non autorisé. |
| `feature/CHAN-93_Branch_Conventions` | Underscore et majuscules. |
| `feature/CHAN-93-ajout des chantiers` | Espaces dans le nom. |
| `feature/CHAN-93-échéances` | Accent dans le nom. |
| `feature/CHAN-93-` | Description absente. |
| `feature/CHAN-93-misc` | Description non explicite. |

## Cycle de vie des branches

1. **Créer la branche depuis la branche cible à jour.**
   - `feature/*` et `bugfix/*` depuis `develop`.
   - `hotfix/*` depuis `main`.

   ```powershell
   git switch develop
   git pull --ff-only
   git switch -c feature/CHAN-123-description
   ```

   Pour un hotfix :

   ```powershell
   git switch main
   git pull --ff-only
   git switch -c hotfix/CHAN-123-description
   ```

2. **Développer et committer** en respectant les [conventions de commits](#conventions-de-commits).

3. **Mettre à jour la branche depuis sa branche cible si nécessaire.** La mise à jour se fait par fusion de la branche cible dans la branche de travail :

   ```powershell
   git switch feature/CHAN-123-description
   git merge develop
   ```

   Pour un `hotfix/*`, fusionner `main` au lieu de `develop`. Ne pas rebaser une branche déjà poussée : cela imposerait un force-push, interdit. Le rebase proposé par GitHub comme méthode de fusion de la Pull Request reste autorisé (voir étape 6).

4. **Pousser la branche temporaire et ouvrir une Pull Request** vers la branche cible.

5. **Attendre le succès du contrôle `ci`** et traiter les éventuels commentaires.

6. **Fusionner via GitHub** avec une méthode autorisée par les rulesets (`merge` ou `rebase`). Le squash n'est pas autorisé sur les branches protégées par les rulesets.

7. **Supprimer la branche temporaire** après la fusion, localement et sur le dépôt distant.

Après la fusion d'un `hotfix/*` dans `main`, synchroniser `develop` avec `main` afin que la correction ne soit pas perdue lors de la prochaine livraison. La synchronisation passe par une Pull Request de `main` vers `develop`, avec une fusion et non un rebase. Un push direct sur `develop` reste interdit. Si des ajustements sont nécessaires, utiliser une branche `bugfix/CHAN-<numéro>-synchronisation-hotfix` créée depuis `develop`.

## Conventions de commits

Le projet applique les [Conventional Commits](https://www.conventionalcommits.org/).

### Types autorisés

| Type | Usage |
| --- | --- |
| `feat` | Nouvelle fonctionnalité. |
| `fix` | Correction de bug. |
| `refactor` | Modification interne sans changement de comportement fonctionnel. |
| `test` | Ajout ou modification de tests. |
| `docs` | Documentation uniquement. |
| `chore` | Maintenance, outillage ou tâche sans impact fonctionnel direct. |
| `build` | Système de build ou dépendances. |
| `ci` | Configuration d'intégration continue. |
| `perf` | Amélioration de performance. |

### Format

```text
type(scope): description
```

La portée `scope` est obligatoire pour les nouveaux commits. Elle identifie le domaine, le module ou le composant concerné. Pour un changement transverse, utiliser une portée générique telle que `repo`.

Règles :

- Le type est obligatoire et doit appartenir à la liste ci-dessus.
- La portée est obligatoire, en minuscules, sans espace, et désigne le domaine concerné : `chantiers`, `auth`, `users`, `git`, `ci`, `deps`, `repo`, etc.
- La description est en minuscules, à l'infinitif, sans point final et sans majuscule initiale.
- La description doit être courte et explicite ; viser 72 caractères maximum pour la première ligne.
- Un commit doit représenter une modification atomique et cohérente.
- Le corps du commit est facultatif. Il explique le **pourquoi** et les conséquences, pas seulement le **quoi**.
- Les références Jira peuvent être ajoutées dans le corps ou dans un footer, par exemple `Refs: CHAN-93`.
- Ne jamais inclure de secret, de token, de mot de passe ou de donnée personnelle réelle dans un message de commit.

### Exemples

```text
feat(chantiers): ajouter la gestion des chantiers
fix(auth): corriger le contrôle des permissions
test(users): ajouter les tests des permissions
docs(git): documenter le workflow
chore(repo): mettre à jour la configuration de l'éditeur
```

L'historique initial contient des commits sans portée (`feat:`, `docs:`, `chore:`). Ils sont antérieurs à cette convention et ne doivent pas être réécrits.

### Breaking changes

Un changement incompatible avec l'existant doit être signalé :

- ajouter `!` après le type ou la portée dans la première ligne ;
- ajouter un footer `BREAKING CHANGE:` décrivant l'impact et la migration nécessaire.

Exemple :

```text
feat(api)!: remplacer l'identifiant de chantier par un UUID

BREAKING CHANGE: les clients doivent utiliser le champ `uuid` à la place de `id`.
```

## Conventions de Pull Requests

### Branche source et branche cible

| Travail | Branche source | Branche cible |
| --- | --- | --- |
| Fonctionnalité | `feature/CHAN-123-description` | `develop` |
| Correction non urgente | `bugfix/CHAN-123-description` | `develop` |
| Correction urgente | `hotfix/CHAN-123-description` | `main`, puis synchronisation de `develop` |
| Livraison | `develop` | `main` |
| Synchronisation après hotfix | `main` | `develop` |

### Contenu obligatoire

Chaque Pull Request doit contenir :

- la **référence Jira** du ticket, par exemple `CHAN-93` ou un lien vers le ticket ;
- un **résumé des changements** et du comportement attendu ;
- la liste des **tests et contrôles effectués**, avec leur résultat réel ;
- les **points d'attention**, limites connues ou décisions restant à prendre ;
- une checklist de validation.

Le titre de la Pull Request doit rester explicite et reprendre la clé Jira. Exemple :

```text
docs(git): documenter les conventions de branches (CHAN-93)
```

### Critères de validation

Une Pull Request ne peut être fusionnée que si :

- la branche source et la branche cible correspondent au tableau ci-dessus ;
- la référence Jira est présente ;
- tous les commits de travail respectent les conventions de commits, hors commits de fusion générés par GitHub ;
- le contrôle GitHub Actions `ci` est terminé avec succès ;
- les tests et contrôles annoncés ont réellement été exécutés ;
- aucun secret ni donnée sensible n'est présent dans le diff ;
- les éventuels commentaires de revue ont été traités.

Le contrôle `ci` correspond au job `ci` du workflow [`.github/workflows/tests.yml`](../../.github/workflows/tests.yml). Il est obligatoire sur `main` et `develop`. Une Pull Request dont la CI est en échec ou en attente ne doit pas être fusionnée.

Aucune approbation n'est exigée pour les changements attribués au développeur, le projet ayant un développeur unique. La Pull Request et la CI restent néanmoins obligatoires.

## Cycle de livraison

Le flux d'intégration est le suivant :

```text
feature/* ou bugfix/*  ──PR──>  develop  ──PR──>  main
hotfix/*               ──PR──>  main     ──PR──>  develop (synchronisation)
```

- Les fonctionnalités et corrections ordinaires sont intégrées dans `develop`.
- Une livraison consiste à ouvrir une Pull Request de `develop` vers `main`.
- Un hotfix est fusionné dans `main`, puis reporté dans `develop`.

Ce flux décrit l'intégration du code. La sélection de version, les tags, les notes de version et la publication GitHub sont définis dans [`release-process.md`](release-process.md). Les environnements sont décrits dans [`environments.md`](environments.md). Le déploiement n'est pas couvert par ce flux et relève de CHAN-97.

### Pratiques actuelles

Sont actuellement opérationnels :

- les branches permanentes `main` et `develop` ;
- les branches temporaires `feature/*`, `bugfix/*` et `hotfix/*` ;
- les Pull Requests obligatoires vers `main` et `develop` ;
- le contrôle `ci` obligatoire ;
- les rulesets `protect-main` et `protect-develop` ;
- l'interdiction du force-push et de la suppression des branches protégées.

Seuls les workflows de tests [`.github/workflows/tests.yml`](../../.github/workflows/tests.yml) et de release [`.github/workflows/release.yml`](../../.github/workflows/release.yml) sont présents dans `.github/workflows/`. Le workflow de tests valide les Pull Requests et les pushes sur `main`. Le workflow de release est déclenché par un tag de release et crée la release GitHub correspondante. Aucun workflow de déploiement n'y est défini : une fusion dans `main` ou un tag ne déclenche aucun déploiement automatique.

Les environnements `staging` et `production` et leurs protections GitHub sont documentés dans [`environments.md`](environments.md). Aucun environnement GitHub ni aucun déploiement n'est configuré à ce stade.

### Versionnement et releases

Le versionnement Semantic Versioning, les conventions de tags, la génération des notes de version et le processus de publication sont définis dans [`release-process.md`](release-process.md).

### Environnements

Les environnements de recette et de production, leur séparation MySQL, leurs fichiers `.env`, leurs variables et secrets, les données de recette, les accès, les sauvegardes et les protections GitHub sont définis dans [`environments.md`](environments.md).

### Sujets restant à définir

Les sujets suivants restent hors périmètre de CHAN-95 et CHAN-96 et ne doivent pas être considérés comme applicables :

- procédure et automatisation des déploiements (CHAN-97) ;
- déclencheur exact du déploiement, branche ou tag stable (CHAN-97) ;
- procédure de rollback (CHAN-97).

Toute évolution du workflow Git, de la release ou des environnements devra être reportée dans ce document, dans [`release-process.md`](release-process.md), dans [`environments.md`](environments.md) et, si nécessaire, dans [`AGENTS.md`](../../AGENTS.md) et [`README.md`](../../README.md).

## Protections GitHub actives

Les règles suivantes sont appliquées par les rulesets du dépôt. Elles ont été vérifiées via l'API GitHub le 12 novembre 2026, y compris les règles effectives des branches `main` et `develop`.

Paramètres généraux du dépôt : `allow_merge_commit`, `allow_squash_merge` et `allow_rebase_merge` sont activés. Les rulesets restreignent cependant les fusions vers `main` et `develop` à `merge` et `rebase`.

| Règle | `protect-main` | `protect-develop` |
| --- | --- | --- |
| Branche couverte | Branche par défaut (`main`) | `develop` |
| Ruleset actif | Oui | Oui |
| Pull Request obligatoire | Oui | Oui |
| Approbations obligatoires (commits attribués) | 0 | 0 |
| Approbation supplémentaire pour commits non attribués | Oui | Oui |
| Contrôle `ci` obligatoire | Oui | Oui |
| Branche à jour avant fusion | Non exigé par le ruleset | Non exigé par le ruleset |
| Force-push | Interdit | Interdit |
| Suppression de la branche | Interdite | Interdite |
| Bypass | Aucun | Aucun |
| Méthodes de fusion autorisées sur les branches protégées | `merge`, `rebase` | `merge`, `rebase` |

Le paramètre `require_extra_approval_for_unattributed_changes` ne crée pas une approbation obligatoire par un second développeur. Il impose une approbation supplémentaire, par un utilisateur autre que le dernier pusher, uniquement lorsqu'un commit n'est pas attribué à un compte GitHub, par exemple lorsque l'adresse email de l'auteur n'est associée à aucun compte. Tant que tous les commits de la Pull Request sont attribués au compte GitHub du développeur, le nombre d'approbations requis reste 0. Avec un développeur unique, l'adresse `user.email` doit donc correspondre à une adresse associée au compte GitHub (le `user.name` n'intervient pas dans l'attribution) ; sinon la Pull Request peut être bloquée faute d'approbateur disponible.

Conséquences pratiques :

- un push direct sur `main` ou `develop` est rejeté ;
- un force-push est rejeté ;
- la suppression de `main` ou `develop` est rejetée ;
- la fusion est possible sans approbation pour les commits attribués, mais uniquement après le succès de `ci` ;
- le squash merge est refusé sur `main` et `develop` par les rulesets, bien que le paramètre général du dépôt l'autorise.

Ne pas modifier ces règles sans décision documentée. Toute évolution doit être répercutée dans ce document.

## Checklist rapide

Avant d'ouvrir une Pull Request :

- [ ] La branche respecte le format `<type>/CHAN-<numéro>-<description>`.
- [ ] La branche part de la bonne branche cible.
- [ ] Les commits suivent `type(scope): description`.
- [ ] Les tests et contrôles pertinents ont été exécutés.
- [ ] La documentation est mise à jour si nécessaire.
- [ ] Aucun secret ni donnée sensible n'est présent.
- [ ] La Pull Request contient la référence Jira, le résumé et les contrôles effectués.
- [ ] Le contrôle `ci` est vert avant la fusion.
