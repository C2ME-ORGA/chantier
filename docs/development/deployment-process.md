# Processus de déploiement

Ce document décrit l'automatisation des déploiements **staging** et **production** de C2ME Chantier.

- Ticket : CHAN-97 – Déploiements.
- Ticket parent : CHAN-92 – Définir le workflow Git, les releases et les déploiements.
- Dépôt : [`C2ME-ORGA/chantier`](https://github.com/C2ME-ORGA/chantier).
- Portée : construction des paquets, publication des artefacts, promotion d'une release candidate vers la production, workflows GitHub Actions, comptes SSH, contrôles post-déploiement et procédure initiale de configuration serveur.
- Hors portée : recette fonctionnelle, sauvegardes et restauration, automatisation du rollback. La stratégie de migrations, la politique de rollback applicatif et les règles de compatibilité N/N-1 sont définies dans [`database-migrations.md`](database-migrations.md) (lot 1 de CHAN-98). La sauvegarde, l'intégrité et la restauration isolée sont définies dans [`backup-restore.md`](backup-restore.md) (lot 2 de CHAN-98).

Ce document décrit une automatisation **préparée mais non exécutée depuis ce dépôt** : aucun déploiement réel n'a été déclenché. Les comptes SSH, groupes Linux et racines aaPanel existent déjà et sont documentés ici ; aucune de leurs propriétés n'a été modifiée par cette correction. Les sections « configuration manuelle » restent à réaliser ou à vérifier.

## Sources de vérité

| Sujet | Référence |
| --- | --- |
| Déploiements, artefacts et promotion | Ce document |
| Migrations, compatibilité N/N-1 et rollback applicatif | [`database-migrations.md`](database-migrations.md) |
| Sauvegarde, intégrité et restauration | [`backup-restore.md`](backup-restore.md) |
| Rollback applicatif manuel | [`application-rollback.md`](application-rollback.md) |
| Environnements, isolation et protections | [`environments.md`](environments.md) |
| Branches, commits et Pull Requests | [`git-workflow.md`](git-workflow.md) |
| Versionnement, tags et releases | [`release-process.md`](release-process.md) |
| Workflow de staging | [`.github/workflows/deploy-staging.yml`](../../.github/workflows/deploy-staging.yml) |
| Workflow de production | [`.github/workflows/deploy-production.yml`](../../.github/workflows/deploy-production.yml) |
| Workflow de release | [`.github/workflows/release.yml`](../../.github/workflows/release.yml) |
| Construction du paquet | [`.github/scripts/package/build-package.sh`](../../.github/scripts/package/build-package.sh) |
| Promotion staging → production | [`.github/scripts/deploy/resolve-promotion.sh`](../../.github/scripts/deploy/resolve-promotion.sh) |
| Déploiement serveur | [`.github/scripts/deploy/remote-deploy.sh`](../../.github/scripts/deploy/remote-deploy.sh) |
| Contrôle serveur | [`.github/scripts/deploy/remote-check.sh`](../../.github/scripts/deploy/remote-check.sh) |
| Règles impératives | [`AGENTS.md`](../../AGENTS.md) |

## Principes

- Le package déployé en production est **exactement** celui publié et déployé en staging. La production ne reconstruit jamais l'application.
- Un artefact est **immuable** : un tag publié n'est jamais déplacé et l'artefact associé n'est jamais remplacé.
- Les deux environnements sont strictement indépendants : comptes SSH, chemins, secrets, bases, stockage, journaux, workers et tâches planifiées distincts.
- Le serveur reste l'autorité. Le workflow ne transmet jamais un chemin arbitraire : le chemin cible est déduit d'une table fixe dans le script serveur et comparé à la variable d'environnement.
- Aucune migration n'est exécutée par un déploiement. Le rollback applicatif est manuel et outillé depuis le lot 3 ([`application-rollback.md`](application-rollback.md)) ; il n'est jamais déclenché par un workflow, un déploiement ou un health check. La stratégie de migrations et les règles de compatibilité N/N-1 restent définies dans [`database-migrations.md`](database-migrations.md).
- Aucune commande n'est exécutée avec une élévation de privilèges : les scripts serveur tournent avec les comptes techniques dédiés.

## Architecture serveur

| Élément | Staging | Production |
| --- | --- | --- |
| Serveur | Ubuntu 24.04.5 LTS, aaPanel, PHP-FPM 8.4, MariaDB 10.11, `164.132.192.216`, port SSH `5679` | Identique |
| Compte de déploiement | `c2me-deploy-staging` | `c2me-deploy-production` |
| Groupe Linux | `c2me-staging` | `c2me-production` |
| Racine | `/www/wwwroot/chantier-staging.c2me.ovh` | `/www/wwwroot/chantier.c2me.fr` |
| URL | `https://chantier-staging.c2me.ovh` | `https://chantier.c2me.fr` |
| Base | `chantier_staging` | `chantier_production` |
| GitHub Environment | `staging` | `production` |

Le compte `ubuntu` est réservé à l'administration initiale. Les workflows utilisent exclusivement les deux comptes techniques.

Les anciens chemins `/www/wwwroot/chantier-staging` et `/www/wwwroot/chantier` sont refusés par les scripts et les workflows, même avec le bon compte ou le bon environnement. Les deux sites aaPanel existent déjà et conservent leurs répertoires actuels.

### Structure des installations

```text
<DEPLOY_PATH>/                     2770  compte:groupe-environnement
├── releases/                      2770
│   ├── <release-id>/              2750
│   │   ├── artisan
│   │   ├── bootstrap/cache/       2770  (PHP-FPM écrit)
│   │   ├── public/                # dont le lien public/storage
│   │   ├── release.json           # marqueur non public
│   │   ├── .env -> ../../shared/.env
│   │   └── storage -> ../../shared/storage
│   └── ...
├── shared/                        2770
│   ├── .env                       0600  (recommandé, jamais écrasé)
│   ├── storage/                   2770  (jamais déplacé)
│   └── deployment.log             0600  (journal des déploiements)
└── current -> releases/<release-id>
```

Le DocumentRoot du vhost aaPanel doit pointer vers `<DEPLOY_PATH>/current/public`, ce qui suit automatiquement la release active.

### Permissions

Le modèle complet est décrit dans [`environments.md`](environments.md). Points appliqués par le déploiement :

- `umask 027` avant l'extraction : fichiers `0640`/`0750`, lisibles par le groupe seulement ;
- répertoire de release en `2750` : le groupe PHP-FPM lit et traverse, sans pouvoir modifier le code ;
- `bootstrap/cache` en `2770` : PHP-FPM écrit ses caches d'exécution ;
- vérification que la racine, `releases/`, `shared/` et `shared/storage/` n'accordent aucun droit aux autres utilisateurs ;
- vérification que `shared/.env` n'accorde aucune écriture de groupe ni aucun accès aux autres utilisateurs (`0600` recommandé, `0640` accepté) ;
- vérification de la présence et de la lisibilité par le groupe de `bootstrap/cache/config.php`, qui porte la configuration à l'exécution ;
- vérification que `shared/storage/` et `bootstrap/cache` sont inscriptibles par le groupe ;
- vérification ciblée que `artisan` et `public/index.php` sont lisibles par le groupe.

Le fichier `.env` peut être en `0600` : `config:cache` est exécuté pendant le déploiement par le compte technique, propriétaire du fichier, et Laravel ne recharge pas `.env` lorsque la configuration est en cache. `bootstrap/cache/config.php` doit donc être présent dans la release activée et lisible par le groupe. Le déploiement échoue avant publication si cette configuration compilée est absente. Aucun appel `env()` n'existe hors de `config/` dans l'application ; les valeurs d'exécution proviennent de `config()` et du cache compilé.

Le déploiement ne modifie ni le propriétaire, ni le groupe, et n'utilise jamais `sudo` : les changements de propriété et d'appartenance relèvent de l'administrateur. Les racines sont actuellement en `2770` ; le déploiement accepte également `2750` sur `<ROOT>`, `releases/` et `shared/`, ce qui retire l'écriture de groupe non nécessaire au code déployé, au lien `current` et au journal. `shared/storage/` et `bootstrap/cache` doivent rester inscriptibles par le groupe.

Le compte `www`, qui exécute PHP-FPM 8.4 et Nginx, appartient aux deux groupes. L'isolation des comptes SSH est réelle, mais **le pool PHP-FPM est commun aux deux sites** : l'isolation de l'exécution PHP n'est donc pas complète. Cette limite est documentée dans [`environments.md`](environments.md) ; aucune configuration PHP-FPM n'est modifiée par cette correction.

### Séparation des environnements

- Les deux racines sont distinctes et ne partagent aucun lien symbolique.
- Un script lancé pour `staging` refuse le chemin de `production`, et inversement.
- Chaque compte technique n'a accès qu'à sa racine ; aucun privilège global n'est accordé.
- Chaque racine appartient au compte de déploiement et au groupe de son environnement (`2770`). Les comptes de déploiement n'ont aucun accès à l'autre racine.
- Le compte `www` (PHP-FPM et Nginx) appartient aux deux groupes pour servir les deux sites. L'isolation des comptes SSH est réelle, mais le pool PHP-FPM commun ne permet pas une isolation complète de l'exécution PHP. Cette limite est assumée et documentée dans [`environments.md`](environments.md).
- Les fichiers `.env` et `shared/storage` ne sont jamais copiés, écrasés ni remplacés par un déploiement.

## Déclencheurs

### Staging

Déclenchement automatique sur le push d'un tag de release candidate :

```text
vX.Y.Z-rc.N   (exemple : v0.2.0-rc.1)
```

Le workflow vérifie successivement :

1. le format SemVer de la release candidate ;
2. le caractère **annoté** du tag et le type `commit` de l'objet pointé ;
3. l'appartenance du commit du tag à l'historique de `origin/develop` ;
4. la provenance du commit et de son arbre Git enregistrés dans la suite du workflow.

Un tag léger, un format invalide, un tag stable ou un commit absent de l'historique de `develop` est refusé.

### Avancée de branche entre le tag et le workflow

Le tag identifie le contenu déployé ; il reste immuable. Le contrôle de déploiement exige que le commit du tag appartienne à l'historique de la branche de référence, pas qu'il soit encore le HEAD courant.

- Si `develop` avance après la création du tag, le déploiement staging reste possible : l'artefact est construit depuis le commit tagué, et la provenance est vérifiée par `head_sha`, le workflow et le tag.
- Un tag créé sur une branche divergente, non fusionnée, est refusé.
- Le workflow de release conserve, lui, l'exigence d'un tag créé sur le HEAD de `develop` ou `main` au moment de la publication. Cette exigence n'est pas affaiblie.
- La promotion en production conserve la comparaison des arbres Git et la référence `Staging-Candidate`.

### Production

Déclenchement automatique sur l'événement GitHub `release.published`.

Sont refusés :

- les releases brouillons ;
- les préreleases ;
- les tags `vX.Y.Z-rc.N` ;
- les tags stables non conformes à `vX.Y.Z` ;
- un tag stable absent de l'historique de `origin/main` ;
- toute release qui ne contient pas la référence explicite à une candidate staging.

### Référence obligatoire de la candidate

La release stable doit contenir une ligne unique :

```text
Staging-Candidate: vX.Y.Z-rc.N
```

- Le workflow de release ajoute automatiquement cette ligne aux notes d'une version stable lorsqu'une candidate vérifiable existe.
- Une candidate n'est retenue que si elle porte la même version de base, qu'elle est un tag annoté ancêtre du tag stable et que **son arbre Git est identique** à celui du tag stable.
- Sans candidate vérifiable, la ligne est remplacée par une mention explicite et le déploiement en production est refusé. La release reste publiable, mais elle n'est pas déployable.

## Construction du paquet

La construction a lieu **uniquement** en staging, sur un runner GitHub hébergé.

| Élément | Version ou commande |
| --- | --- |
| PHP | 8.4 |
| Composer | v2 |
| Node | 22 |
| Dépendances PHP | `composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader --no-progress` |
| Dépendances JS | `npm ci` |
| Assets | `npm run build` |

Le paquet contient le code Laravel, `vendor/` et les assets Vite compilés. Il exclut notamment :

- `.env` et tout fichier `.env.*` ;
- `node_modules/` ;
- `storage/` (partagé via `shared/storage`) ;
- les journaux, sessions, caches et fichiers temporaires ;
- `tests/`, `docs/`, les fichiers de configuration de développement ;
- les fichiers `.phpunit.cache`, `phpunit.xml`, `phpstan.neon`, `pint.json` ;
- les répertoires et fichiers locaux : `.idea/`, `.vscode/`, `.fleet/`, `.nova/`, `.zed/`, `.mcp.json`, `boost.json`, `opencode.json`, `CLAUDE.md`, `.phpactor.json`, `auth.json`, `public/fonts-manifest.dev.json`, fichiers `.DS_Store`, `Thumbs.db`, `*.iml`, `*.swp` ;
- les secrets et fichiers locaux : `.envrc`, `secrets.json`, `*.pem`, `*.key`, `id_rsa*`, `id_ed25519*`, `*.p12`, `*.pfx`, `*.jks`, `*.crt` ;
- `vendor/bin`, qui contient des liens symboliques Composer et n'est pas nécessaire à l'exécution.

Le paquet refuse tout lien symbolique, lien physique ou fichier spécial **hors `vendor/bin`**. `vendor/bin` est exclu en amont ; `vendor/autoload.php` et les dépendances de production restent présentes. Le tag reçu est validé avant toute création de fichier : seuls `vX.Y.Z` et `vX.Y.Z-rc.N` sont acceptés, sans séparateur de chemin ni traversée. Le job CI `package-linux` exécute un vrai build Ubuntu avec PHP 8.4, Composer, Node 22, vérifie les liens `vendor/bin`, l'assemblage et le refus des liens hors `vendor/bin`.

Les fichiers `composer.lock` et `package-lock.json` ne sont jamais modifiés. Le script de build compare leurs empreintes avant et après installation et échoue en cas de changement.

Le script [`assemble-package.sh`](../../.github/scripts/package/assemble-package.sh) contrôle ensuite :

- la présence des fichiers obligatoires (`artisan`, `vendor/autoload.php`, `public/index.php`, assets Vite) ;
- l'absence de chemins absolus ou de traversée de répertoire ;
- l'absence de `.env`, de `node_modules/`, de `.git/` et de journaux ;
- la production de l'empreinte SHA-256.

## Artefact et manifeste

L'artefact est publié avant le déploiement, avec une conservation de 90 jours lorsque les limites du dépôt le permettent (GitHub peut réduire cette durée si la limite du dépôt est inférieure).

| Artefact | Nom | Contenu |
| --- | --- | --- |
| Paquet | `chantier-package-<tag>` | `chantier-<tag>.tar.gz` et son fichier `.sha256` |
| Manifeste | `chantier-manifest-<tag>` | `manifest.json` |

Le manifeste contient au minimum :

- la version et le tag source ;
- le commit SHA et le tree SHA ;
- l'identifiant de l'exécution du workflow ;
- l'identifiant et le nom de l'artefact ;
- l'empreinte SHA-256 du paquet ;
- le statut du déploiement staging et son identifiant d'exécution.

Le manifeste de production reprend ces informations et ajoute la candidate staging, l'exécution de staging d'origine et l'identifiant de son manifeste.

### Schéma strict

Le script [`manifest.php`](../../.github/scripts/lib/manifest.php) valide le schéma avant toute publication. Un champ obligatoire absent ou vide, un type incorrect ou un format invalide bloque le déploiement.

| Champ | Format attendu |
| --- | --- |
| `schema_version` | `1` |
| `environment` | `staging` ou `production` |
| `version` / `tag` | SemVer `vX.Y.Z` ou `vX.Y.Z-rc.N`, identiques entre eux |
| `channel` | `rc` en staging, `stable` en production |
| `commit_sha`, `tree_sha` | 40 caractères hexadécimaux |
| `workflow.name` | `deploy-staging` ou `deploy-production`, cohérent avec l'environnement |
| `workflow.run_id`, `workflow.run_attempt` | identifiants numériques |
| `artifact.name` | nom non vide commençant par `chantier-` |
| `artifact.id` | identifiant numérique |
| `artifact.sha256` | 64 caractères hexadécimaux |
| `staging_deployment.status` | `success`, `failure` ou `pending` |
| `staging_deployment.run_id` | identifiant numérique |
| `staging_deployment.job` | `deploy` en staging |
| `created_at` | date UTC ISO 8601 `YYYY-MM-DDTHH:MM:SSZ` |
| `staging.candidate_tag` | release candidate cohérente avec la version stable (production uniquement) |
| `staging.run_id`, `staging.manifest_artifact_id` | identifiants numériques (production uniquement) |

Le manifeste de staging et le manifeste de production existants respectent ce schéma. `resolve-promotion.sh` conserve en plus les vérifications croisées entre manifeste, exécution de staging et artefact téléchargé.

Le manifeste staging est finalisé après la publication de l'artefact et le déploiement : l'identifiant de l'artefact n'est attribué par GitHub qu'au moment de l'upload. L'ordre `build → publication → déploiement → manifeste` ne change pas le contenu du package.

L'exécution de staging retenue est la plus récente pour le commit de la candidate. Si elle a échoué, la promotion est refusée même si une tentative antérieure avait réussi : le workflow ne suppose jamais qu'un état staging antérieur est toujours actif.

## Promotion RC vers stable

La promotion ne reconstruit rien. Le workflow de production :

1. valide l'événement `release.published` et le tag stable ;
2. extrait `Staging-Candidate` du corps de la release ;
3. vérifie que le tag de candidate est annoté et appartient à l'historique de `origin/develop` ;
4. compare le **tree SHA** de la candidate et du tag stable : des commits différents avec le même arbre sont acceptés, des arbres différents sont refusés ;
5. retrouve l'exécution la plus récente du workflow de staging pour le commit de la candidate, en parcourant toutes les pages de l'API ;
6. exige que cette exécution soit terminée, réussie, déclenchée par un push sur le tag, issue du fichier de workflow attendu, portant sur le bon commit et le bon tag ;
7. vérifie que l'exécution porte bien sur le commit de la candidate ;
8. recherche les artefacts `chantier-package-<tag>` et `chantier-manifest-<tag>` en parcourant toutes les pages, et refuse tout artefact expiré, manquant ou ambigu (plusieurs artefacts du même nom) ;
9. télécharge l'artefact d'origine avec le `GITHUB_TOKEN` (`actions: read`) ;
10. recalcule l'empreinte SHA-256 et la compare au manifeste et au fichier `.sha256` ;
11. vérifie l'ensemble des champs du manifeste (version, tag, commit, arbre, exécution, identifiant d'artefact, empreinte, statut staging).

Un artefact expiré, introuvable, incohérent ou invalide bloque le déploiement. Aucun paquet n'est reconstruit silencieusement.

## Workflows

### `.github/workflows/deploy-staging.yml`

- Déclencheur : `push` sur les tags `v*-rc.*`.
- Environnement GitHub : `staging`.
- Permissions : `contents: read`, `actions: read`. Aucun accès en écriture au contenu.
- Concurrence : groupe `deploy-staging`, `cancel-in-progress: false`.
- Étapes : validation du tag, contrôle de la configuration, build, publication de l'artefact, résolution de l'identifiant d'artefact, configuration SSH, transfert, déploiement, contrôle serveur, contrôle HTTP, manifeste, résumé.
- Conserve le paquet et le manifeste 90 jours.

### `.github/workflows/deploy-production.yml`

- Déclencheur : `release.published`.
- Une prérelease publiée ne déclenche aucun job : le garde `if` des jobs exclut les préreleases et les brouillons. Les scripts de validation refusent également ces cas par défense en profondeur.
- **Job `validate-promotion`** : sans GitHub Environment, il valide la release, le tag stable, la candidate staging, l'exécution de staging, le manifeste et l'artefact. Il transmet au job suivant les identifiants et métadonnées validés (candidate, commit, arbre, exécution, artefact, empreinte).
- **Job `deploy-production`** : dépend de `validate-promotion` et déclare `environment: production`. L'approbation intervient donc **après** la validation technique, juste avant le déploiement, et seuls ce job et ses étapes accèdent aux secrets SSH de production.
- Le job protégé revalide lui-même le tag stable : format, tag annoté, appartenance à l'historique de `origin/main`. Il compare le commit et l'arbre recalculés aux valeurs validées par `validate-promotion` et échoue en cas d'écart.
- Le job protégé retélécharge l'artefact exact identifié par l'exécution validée, vérifie son identifiant, son absence d'expiration et son empreinte SHA-256, puis le transfère. Aucune reconstruction.
- Permissions : `contents: read`, `actions: read`.
- Concurrence : groupe `deploy-production`, `cancel-in-progress: false`.
- Contrôle HTTP, manifeste de production et résumé dans le job protégé.
- Aucun build, aucune installation de dépendances, aucune compilation.

### `.github/workflows/release.yml`

Le workflow de release est conservé :

- release candidate publiée en **pre-release** ;
- version stable créée en **brouillon**, publiée manuellement ;
- les règles de versionnement et de tags ne changent pas.

Seule adaptation : une section `Déploiement` est ajoutée aux notes d'une version stable pour référencer la candidate staging vérifiable. Sans candidate, la section l'indique explicitement.

### Actions épinglées

Les actions utilisées sont épinglées sur un SHA complet et documentées par un commentaire de version :

| Action | Version |
| --- | --- |
| `actions/checkout` | `v7.0.1` |
| `actions/upload-artifact` | `v7.0.2` |
| `shivammathur/setup-php` | `v2` |
| `actions/setup-node` | `v7.1.0` |

Le téléchargement des artefacts utilise la CLI GitHub officielle (`gh`) déjà présente sur les runners, avec `GH_TOKEN`. Aucune action tierce de déploiement n'est ajoutée.

## GitHub Environments

Les environnements GitHub ne sont **pas créés**. La configuration suivante doit être réalisée manuellement.

### Variables

| Variable | `staging` | `production` |
| --- | --- | --- |
| `DEPLOY_ENVIRONMENT` | `staging` | `production` |
| `DEPLOY_PATH` | `/www/wwwroot/chantier-staging.c2me.ovh` | `/www/wwwroot/chantier.c2me.fr` |
| `APP_URL` | `https://chantier-staging.c2me.ovh` | `https://chantier.c2me.fr` |
| `DEPLOY_PHP_BIN` | Chemin du binaire PHP 8.4 à relever sur le serveur | Idem |
| `DEPLOY_ROUTE_CACHE` | `true` ou `false` | `true` ou `false` |
| `DEPLOY_QUEUE_RESTART` | `false` tant qu'aucun worker n'est supervisé | `false` tant qu'aucun worker n'est supervisé |

`DEPLOY_PHP_BIN` ne doit pas être deviné. Il doit être relevé et confirmé sur le serveur (`command -v php8.4`, configuration aaPanel ou service PHP CLI). Si la variable est vide, le script tente `command -v php8.4` puis échoue explicitement.

### Secrets

Les secrets sont **propres à chaque environnement** et ne sont jamais définis au niveau du dépôt :

| Secret | Rôle |
| --- | --- |
| `SSH_HOST` | Hôte SSH (`164.132.192.216`) |
| `SSH_PORT` | Port SSH (`5679`) |
| `SSH_USER` | Compte technique de l'environnement |
| `SSH_PRIVATE_KEY` | Clé privée dédiée à l'environnement |
| `SSH_KNOWN_HOSTS` | Empreinte d'hôte vérifiée hors bande |

Le workflow de staging ne référence que les secrets de l'environnement `staging` ; le workflow de production ne les lit qu'après approbation de l'environnement `production`.

### Protections de `production`

- un approbateur obligatoire : le propriétaire du dépôt ;
- auto-approbation autorisée (`Prevent self-review` désactivé) ;
- bypass administrateur désactivé ;
- restriction de déploiement aux tags `v*` lorsque GitHub le permet ;
- aucun secret au niveau du dépôt.

### Checklist de configuration manuelle

- [ ] Créer l'environnement `staging` et y définir ses variables et secrets.
- [ ] Créer l'environnement `production` et y définir ses variables et secrets.
- [ ] Configurer l'approbateur unique de `production`.
- [ ] Désactiver `Prevent self-review` pour `production`.
- [ ] Désactiver le bypass administrateur pour `production`.
- [ ] Vérifier qu'aucun secret n'existe au niveau du dépôt.
- [ ] Vérifier que les secrets staging et production diffèrent.
- [ ] Relever et renseigner `DEPLOY_PHP_BIN`.

## Comptes SSH et sécurité

### Clés

- Une paire de clés **par environnement**, générée sur un poste de confiance.
- La clé publique est ajoutée au fichier `authorized_keys` du compte technique correspondant, avec `restrict` si la version d'OpenSSH le permet.
- La clé privée n'existe que dans le secret GitHub de son environnement.
- Les clés sont révoquées en cas de départ ou de compromission.

### Vérification de l'hôte

`SSH_KNOWN_HOSTS` doit être construit à partir d'une empreinte **vérifiée hors bande** (console du fournisseur, aaPanel ou accès physique). Un `ssh-keyscan` seul n'est pas une preuve.

```bash
# Relever l'empreinte annoncée par le serveur
ssh-keygen -lf <(ssh-keyscan -p 5679 -t ed25519 164.132.192.216 2>/dev/null)

# Comparer avec l'empreinte affichée par la console du fournisseur ou aaPanel
# Puis stocker la ligne d'hôte correspondante dans SSH_KNOWN_HOSTS
```

Les workflows utilisent `StrictHostKeyChecking=yes`, `BatchMode=yes`, `IdentitiesOnly=yes` et un `UserKnownHostsFile` dédié. `StrictHostKeyChecking=no` est interdit.

### Privilèges

- Aucun `sudo` général n'est accordé aux comptes techniques.
- Les comptes ne peuvent écrire que dans leur racine et n'ont aucun accès à l'autre environnement.
- Les scripts serveur refusent un utilisateur qui ne correspond pas à l'environnement.
- Les fichiers déployés restent au propriétaire du compte technique et au groupe de l'environnement ; le déploiement ne change ni propriétaire ni groupe.
- `www` n'est jamais un compte de connexion SSH et ne dispose d'aucun accès interactif.

## Procédure initiale d'administration

Cette procédure est à exécuter **manuellement** par l'administrateur, avec un accès autorisé. Aucune commande n'a été exécutée pour produire cette documentation.

Les commandes ci-dessous utilisent `$ENV`, `$ROOT`, `$USER` et `$GROUP` pour éviter toute duplication. Les chemins et les comptes définitifs figurent dans le tableau d'architecture. Les chemins `/www/wwwroot/chantier-staging` et `/www/wwwroot/chantier` ne doivent plus être utilisés.

1. **Créer les comptes techniques** (si absents) et interdire leur connexion interactive par mot de passe. Ne pas accorder de `sudo`.
2. **Créer ou conserver les racines aaPanel** `/www/wwwroot/chantier-staging.c2me.ovh` et `/www/wwwroot/chantier.c2me.fr`. Les sites existent déjà : ne pas renommer les répertoires.
3. **Créer `releases/` et `shared/`** dans chaque racine, puis appliquer les modes attendus :

   ```bash
   # Staging (adapter les quatre variables pour la production)
   ENV=staging
   ROOT=/www/wwwroot/chantier-staging.c2me.ovh
   USER=c2me-deploy-staging
   GROUP=c2me-staging

   install -d -m 2770 -o "$USER" -g "$GROUP" "$ROOT" "$ROOT/releases" "$ROOT/shared"
   install -d -m 2770 -o "$USER" -g "$GROUP" "$ROOT/shared/storage"
   chmod 2770 "$ROOT" "$ROOT/releases" "$ROOT/shared" "$ROOT/shared/storage"
   ```

4. **Créer `shared/.env`** pour chaque environnement à partir de la matrice de [`environments.md`](environments.md), avec `APP_ENV` et `APP_URL` corrects, puis appliquer les permissions suivantes :

   ```bash
   chown "$USER:$GROUP" "$ROOT/shared/.env"
   chmod 0600 "$ROOT/shared/.env"
   ```

   Le mode `0600` est recommandé : `config:cache` est exécuté par le compte technique, qui lit le fichier pendant le déploiement. À l'exécution, Laravel utilise la configuration compilée et PHP-FPM n'a pas besoin de lire `.env`. Le mode `0640` reste accepté mais n'est pas nécessaire. Les modes `660`, `664`, `644` et tout accès des autres utilisateurs sont refusés.
5. **Créer l'arborescence de stockage** : `shared/storage/app/public`, `shared/storage/app/private`, `shared/storage/framework/cache`, `shared/storage/framework/sessions`, `shared/storage/framework/views`, `shared/storage/logs`. Ces répertoires appartiennent au compte technique, ont le groupe de l'environnement et sont en `2770`, afin que PHP-FPM puisse y écrire.

   ```bash
   install -d -m 2770 -o "$USER" -g "$GROUP" \
     "$ROOT/shared/storage/app/public" \
     "$ROOT/shared/storage/app/private" \
     "$ROOT/shared/storage/framework/cache" \
     "$ROOT/shared/storage/framework/sessions" \
     "$ROOT/shared/storage/framework/views" \
     "$ROOT/shared/storage/logs"
   ```

6. **Configurer les vhosts aaPanel** : DocumentRoot `/www/wwwroot/chantier-staging.c2me.ovh/current/public` et `/www/wwwroot/chantier.c2me.fr/current/public`, certificats TLS actifs.
7. **Vérifier l'appartenance de `www` aux deux groupes** (`id www`). `www` exécute PHP-FPM et Nginx. Si l'appartenance vient d'être ajoutée, recharger PHP-FPM et Nginx : les processus déjà lancés ne prennent pas en compte un nouveau groupe.
8. **Rattacher les clés publiques** aux comptes techniques, restreindre les sources si possible.
9. **Relever le binaire PHP 8.4** et le renseigner dans `DEPLOY_PHP_BIN`.
10. **Créer une entrée cron `schedule:run` par environnement**, exécutée par le compte technique depuis `current` :

   ```text
   * * * * * cd /www/wwwroot/chantier-staging.c2me.ovh/current && <php-8.4> artisan schedule:run >> /www/wwwroot/chantier-staging.c2me.ovh/shared/storage/logs/scheduler.log 2>&1
   * * * * * cd /www/wwwroot/chantier.c2me.fr/current && <php-8.4> artisan schedule:run >> /www/wwwroot/chantier.c2me.fr/shared/storage/logs/scheduler.log 2>&1
   ```

11. **Configurer les workers** dans aaPanel/Supervisor si l'application en utilise. Chaque environnement doit avoir un programme distinct, un répertoire `current`, et redémarrer via `queue:restart` uniquement après activation.
12. **Vérifier les droits** avec les commandes de contrôle ci-dessous : aucun `777`, aucun `.env` lisible par les autres utilisateurs ni par le groupe (`0600`), `www` peut écrire dans `shared/storage` et lire `bootstrap/cache/config.php`, et les comptes de déploiement ne peuvent pas accéder à l'autre racine.
13. **Ne pas exécuter de migration** dans cette procédure : la stratégie de migration relève de CHAN-98.

### Commandes de contrôle des permissions

À exécuter manuellement par l'administrateur après la configuration initiale et après tout changement de groupe :

```bash
# Modes et propriétaires attendus
stat -c '%U:%G %a %n' \
  /www/wwwroot/chantier-staging.c2me.ovh \
  /www/wwwroot/chantier-staging.c2me.ovh/releases \
  /www/wwwroot/chantier-staging.c2me.ovh/shared \
  /www/wwwroot/chantier-staging.c2me.ovh/shared/.env \
  /www/wwwroot/chantier-staging.c2me.ovh/shared/storage

# Mêmes contrôles pour la production
stat -c '%U:%G %a %n' \
  /www/wwwroot/chantier.c2me.fr \
  /www/wwwroot/chantier.c2me.fr/releases \
  /www/wwwroot/chantier.c2me.fr/shared \
  /www/wwwroot/chantier.c2me.fr/shared/.env \
  /www/wwwroot/chantier.c2me.fr/shared/storage

# PHP-FPM ne lit pas .env : il lit la configuration compilée et écrit dans le stockage
# (contrôles de current à exécuter après le premier déploiement)
sudo -u www test -w /www/wwwroot/chantier-staging.c2me.ovh/shared/storage && echo 'staging storage inscriptible'
sudo -u www test -r /www/wwwroot/chantier-staging.c2me.ovh/current/bootstrap/cache/config.php && echo 'staging config compilée lisible'
sudo -u www test -w /www/wwwroot/chantier.c2me.fr/shared/storage && echo 'production storage inscriptible'
sudo -u www test -r /www/wwwroot/chantier.c2me.fr/current/bootstrap/cache/config.php && echo 'production config compilée lisible'

# Avec .env en 0600, www ne doit pas pouvoir le lire (les deux commandes doivent échouer)
sudo -u www test -r /www/wwwroot/chantier-staging.c2me.ovh/shared/.env && echo 'ANOMALIE: .env staging lisible par www'
sudo -u www test -r /www/wwwroot/chantier.c2me.fr/shared/.env && echo 'ANOMALIE: .env production lisible par www'

# Isolation des comptes SSH (les deux commandes doivent échouer)
sudo -u c2me-deploy-staging test -r /www/wwwroot/chantier.c2me.fr && echo 'ANOMALIE: accès croisé staging -> production'
sudo -u c2me-deploy-production test -r /www/wwwroot/chantier-staging.c2me.ovh && echo 'ANOMALIE: accès croisé production -> staging'

# Aucun 777 ni écriture pour les autres utilisateurs
find /www/wwwroot/chantier-staging.c2me.ovh /www/wwwroot/chantier.c2me.fr \
  ! -type l -perm -0002 -print
```

Ces commandes sont fournies à titre de procédure : elles n'ont pas été exécutées dans le cadre de cette correction.

## Processus de déploiement serveur

Le script [`remote-deploy.sh`](../../.github/scripts/deploy/remote-deploy.sh) est transmis par SSH et exécuté sans privilège élevé. Il réalise :

1. contrôle de l'environnement, de l'utilisateur et du chemin cible (table fixe) ;
2. contrôle du format de la release, du commit, de l'arbre et de l'empreinte ;
3. vérification que le paquet provient d'un répertoire temporaire autorisé ;
4. vérification SHA-256 ;
5. inspection des entrées : refus des liens symboliques, liens physiques, périphériques, chemins absolus, `../`, `.env` et `storage/` ;
6. vérification de l'existence de `shared/.env`, `shared/storage` et du bon `APP_ENV` ;
7. refus si la release existe déjà ;
8. extraction dans un répertoire temporaire créé par `mktemp -d` sous `releases/.incoming-*`, avec vérification du type, de l'absence de lien et de l'appartenance à l'utilisateur courant, puis contrôle qu'aucune entrée ne sort de ce répertoire ;
9. liaison de `.env` et `storage` vers `shared/`, et `public/storage` vers le stockage partagé ;
10. application des permissions de la release (`2750`) et de `bootstrap/cache` (`2770`), puis contrôle de la racine, de `releases/`, de `shared/`, du stockage et de `.env` (`0600` ou `0640`, aucune écriture de groupe, aucun accès des autres) ;
11. vérification explicite du binaire PHP 8.4 avant toute commande Artisan ;
12. `config:cache`, `view:cache`, puis `route:cache` si activé ; un échec de cache interrompt le déploiement **avant** publication ;
13. `queue:restart` si activé ;
14. écriture du marqueur `release.json` ;
15. publication atomique du répertoire de release, puis activation atomique de `current` ;
16. journalisation dans `shared/deployment.log`.

Le script installe des traps `EXIT`, `HUP`, `TERM` et `INT`. Le nettoyage ne supprime un répertoire que si l'exécution courante l'a créé (`incoming_created` ou `release_created`), et jamais s'il est actif. Une collision avec une release ou un répertoire temporaire préexistant provoque un arrêt sans suppression.

Les erreurs précoces (paquet invalide, empreinte, archive) sont journalisées dans `shared/deployment.log` dès que ce chemin est sûr et accessible. Dès que `shared` existe, le journal est obligatoire : un `shared` symbolique, non inscriptible, un journal symbolique, non régulier ou non inscriptible provoque un arrêt explicite. Le journal n'est jamais écrit dans `.env` ni dans `storage`, et un journal symbolique n'est jamais créé ni remplacé.

Les sections critiques de création du répertoire temporaire, de publication de la release et d'activation de `current` masquent temporairement `HUP`, `INT` et `TERM`. Ainsi, un signal ne peut pas laisser un indicateur de création incohérent avec l'état du système de fichiers. En cas d'arrêt non rattrapable (par exemple `SIGKILL`), un résidu inactif peut rester : il n'est jamais supprimé sur la seule base de son nom.

Le script [`remote-check.sh`](../../.github/scripts/deploy/remote-check.sh) revérifie ensuite la release active, les liens, les permissions et le marqueur.

### Sécurité de l'archive

- Les entrées sont inspectées avant extraction avec `tar -tvzf` : tout type autre qu'un fichier ou un répertoire (`l`, `h`, `b`, `c`, `p`) est refusé.
- Les chemins absolus, la traversée de répertoire, `.env` et `storage/` sont refusés.
- L'extraction a lieu dans un répertoire temporaire dédié, sous `releases/`, puis un contrôle `realpath` vérifie qu'aucun fichier ne sort de ce répertoire.
- Aucune archive contenant un lien symbolique ou physique n'est acceptée : aucun besoin technique démontré ne justifie leur présence dans le paquet.

### Échec avant activation et nettoyage

- Toute erreur avant l'activation (extraction, contrôle, permissions, caches Artisan) supprime uniquement le répertoire temporaire et la release créés par l'exécution courante.
- Une release préexistante, une release active, `current` et `shared/` ne sont jamais supprimés, y compris lors d'un signal `HUP`, `TERM` ou `INT`.
- `shared/.env` et `shared/storage` ne sont jamais supprimés ni déplacés.
- Le rollback applicatif est **manuel et outillé** depuis le lot 3 ([`application-rollback.md`](application-rollback.md)) : il bascule `current` vers une release antérieure après contrôles, attestation N/N-1 et confirmations. Il n'est jamais déclenché par un workflow, un déploiement ou un health check, et ne restaure jamais la base.

### Échec du contrôle HTTP après activation

Si le health check échoue après l'activation de `current`, le déploiement est signalé en échec mais **aucun rollback automatique** n'est exécuté. La nouvelle release reste active, l'ancienne reste disponible dans `releases/`, et une décision manuelle est nécessaire. Ce comportement est volontaire pour ne pas masquer un incident. Le retour manuel est outillé par [`application-rollback.md`](application-rollback.md) ; il exige une attestation de compatibilité N/N-1 et ne restaure jamais la base.

### Cache Laravel

- `config:cache` et `view:cache` sont exécutés systématiquement.
- `config:cache` est **obligatoire** : il produit `bootstrap/cache/config.php`, seule source de configuration à l'exécution lorsque `.env` est en `0600`. Le déploiement échoue avant publication si ce fichier est absent ou n'est pas lisible par le groupe.
- `route:cache` est contrôlé par `DEPLOY_ROUTE_CACHE`. L'application actuelle n'utilise que des routes et des vues compatibles, mais toute évolution doit être revérifiée avant de conserver l'option.
- Aucun cache n'est partagé entre staging et production : ils restent dans la release et le stockage de l'environnement.
- Aucun `optimize:clear` global n'est exécuté.
- Une commande manuelle `config:clear` ou `optimize:clear` supprime la configuration compilée : l'application tenterait alors de relire `.env` et échouerait avec un `.env` en `0600`. Après une telle commande, recompiler avec le compte de déploiement (`<php-8.4> artisan config:cache`) ou redéployer.

### Migrations de base de données

La stratégie complète, les conventions de rédaction, les exemples et les procédures d'échec sont définis dans [`database-migrations.md`](database-migrations.md). Les règles essentielles applicables à un déploiement sont les suivantes.

- **Aucune migration n'est exécutée par `deploy-staging`, `deploy-production`, `release`, `remote-deploy.sh` ou `remote-check.sh`.** Aucun hook de migration n'est ajouté au mécanisme CHAN-97.
- Une migration est une opération d'exploitation **manuelle, explicite et tracée**, exécutée depuis le répertoire `current` avec le compte technique de l'environnement et le binaire PHP 8.4.
- La base est partagée par toutes les releases. **Un rollback applicatif ne restaure jamais la base de données.** Un retour à la release N-1 n'est autorisé que si le schéma N reste compatible avec N-1.
- Toute évolution suit **Expand → Migrate → Contract**. Une suppression ou un renommage n'est jamais livré avec l'ajout qui le remplace.
- Une migration dont l'absence empêche le démarrage de la nouvelle release doit être livrée dans la release **précédente**, puis appliquée avant le déploiement de la nouvelle release.
- Les opérations destructrices (`DROP`, `RENAME`, `TRUNCATE`, rétrécissement de type) sont interdites hors Contract validé, après expiration de la fenêtre de rollback et vérification d'une sauvegarde restaurable.
- `migrate:fresh`, `migrate:refresh`, `migrate:reset`, `db:wipe` et `migrate:rollback` sont interdits en staging et en production.
- `php artisan migrate --force` n'est utilisé qu'après validation, avec un périmètre vérifié ; il n'est jamais une étape générique de déploiement.
- La commande de contrôle `migrate:status` et la table `migrations` sont la source de vérité de l'état appliqué. Le résultat est consigné dans le ticket d'exploitation.
- Une migration sensible est répétée en staging sur MariaDB 10.11 avant la production. Une base SQLite de test ne constitue pas une preuve.
- Un échec de migration ne déclenche ni rollback automatique ni modification manuelle silencieuse de la table `migrations`.

Séquence recommandée pour une release N :

1. répéter la migration en staging ;
2. appliquer l'Expand selon la règle de compatibilité (dans N-1 si N ne peut pas démarrer sans lui, sinon juste après l'activation de N) ;
3. déployer et activer N selon la procédure CHAN-97 ;
4. appliquer les transformations bornées, puis les traitements longs via une commande dédiée ;
5. vérifier `migrate:status`, la structure, les invariants, `/up`, les journaux et les files ;
6. planifier le Contract dans une release ultérieure, après la fenêtre de rollback.

Le détail des commandes, des verrous MariaDB, des transactions DDL et des procédures d'échec figure dans [`database-migrations.md`](database-migrations.md).

### Workers et planificateur

- `queue:restart` n'est exécuté que si `DEPLOY_QUEUE_RESTART` vaut `true`.
- Le superviseur réellement utilisé n'est pas supposé : il doit être configuré par l'administrateur (aaPanel/Supervisor).
- Le cron `schedule:run` et les workers sont exécutés avec le compte de déploiement de l'environnement, depuis `current`. Ils utilisent la configuration compilée ; aucun ne doit dépendre d'une lecture directe de `.env`.
- Une seule entrée cron `schedule:run` existe par environnement ; le déploiement n'en crée aucune.

## Contrôles post-déploiement

1. **SSH** : connexion avec l'hôte vérifié et le compte de l'environnement.
2. **Intégrité du package** : empreinte SHA-256 revérifiée avant transfert et côté serveur.
3. **Release active** : `current` pointe sur `releases/<release-id>`.
4. **Liens symboliques** : `.env`, `storage` et `public/storage` pointent vers le stockage de l'environnement.
5. **Permissions** : `.env` non lisible par le groupe ni par les autres utilisateurs (`0600` recommandé), `bootstrap/cache/config.php` lisible par le groupe, stockage et `bootstrap/cache` accessibles en écriture au groupe, release non inscriptible par le groupe.
6. **Disponibilité HTTP** : appel de `APP_URL/up`, code 200 attendu.
7. **Version et commit** : vérifiés via `release.json` en SSH, jamais exposés publiquement.

### Endpoint de santé

Aucun endpoint n'a été créé dans CHAN-97. L'application déclare déjà le point de santé Laravel natif dans [`bootstrap/app.php`](../../bootstrap/app.php) :

```text
GET /up
```

Contrat :

- réponse `200` avec un contenu HTML minimal lorsque l'application répond ;
- réponse `200` avec `{"status":"up"}` lorsque le client envoie `Accept: application/json` ;
- réponse `500` si un listener `DiagnosingHealth` échoue ;
- route exclue du mode maintenance ;
- aucune authentification, aucune information sensible, aucune version ni commit exposé.

Le contrôle HTTP du workflow exige exactement le code `200` et `{"status":"up"}`. Le numéro de version et le commit sont contrôlés via `release.json`.

## Journaux et erreurs

- **Journaux du workflow** : chaque étape échoue explicitement avec un message sans secret.
- **Journal serveur** : `shared/deployment.log`, une ligne JSON par déploiement (environnement, release, version, commit, identifiant d'artefact, empreinte, statut, utilisateur).
- **Journaux applicatifs** : `shared/storage/logs`, distincts par environnement.
- Aucun secret, contenu de `.env` ou clé privée n'est écrit dans un journal.

### Conditions d'échec

Le déploiement échoue notamment si :

- le tag est invalide, léger, mal placé ou d'un mauvais canal ;
- la release est un brouillon, une prérelease ou sans candidate staging ;
- les arbres Git de la candidate et du tag stable diffèrent ;
- l'exécution de staging est absente, non terminée, en échec ou incohérente ;
- un artefact est expiré ou introuvable, ou plusieurs artefacts portent le même nom ;
- le manifeste ne respecte pas le schéma strict ou est incohérent avec le run et l'artefact ;
- l'empreinte SHA-256 diffère ;
- l'environnement, l'utilisateur, le chemin ou le paquet ne correspondent pas ;
- l'archive contient un lien symbolique, un lien physique, un chemin interdit, un `.env` ou `storage/` ;
- `shared/.env` est absent, incohérent ou trop permissif ;
- le binaire configuré n'est pas PHP 8.4 ;
- une commande de cache Laravel échoue ;
- le contrôle HTTP ne renvoie pas `200` et `up`.

## Protection contre les rétrogradations (recommandation, non implémentée)

Un contrôle anti-rétrogradation n'est **pas implémenté** dans CHAN-97.

- **Version actuellement déployée** : elle peut être lue via `releases/current/release.json` (`version`, `commit_sha`) en SSH. Cette information est déjà produite par `remote-deploy.sh`.
- **Règle proposée** : comparer la version stable demandée à la version active. Refuser une version strictement inférieure ; autoriser une version supérieure et un redéploiement de la même version.
- **Rétrogradation accidentelle ou volontaire** : une dérogation explicite est nécessaire pour une version inférieure. Elle doit être réservée aux mainteneurs, traçable (raison, ticket, approbateur) et journalisée. Un simple `workflow_dispatch` ou une variable d'environnement `ALLOW_DEPLOYMENT_DOWNGRADE=true` ne doit être accepté qu'après approbation et avec une justification.
- **Maintenance autorisée** : un redéploiement de la version courante ou une restauration d'urgence validée doit rester possible sans bloquer l'exploitation.
- **Hors périmètre CHAN-97** : `release.published` ne fournit aucune saisie pour une dérogation motivée, et le contrôle nécessite l'état du serveur et une décision d'exploitation. L'implémentation est laissée à un ticket dédié (recommandé : CHAN-98 ou ticket de maintenance), avec documentation et tests.

En l'état, une release stable publiée peut donc être rejouée, y compris une version antérieure. Aucun déploiement réel n'ayant eu lieu, ce risque reste opérationnel et non exploitable par un acteur externe sans droits de publication.

## Limites et dépendances

### Limites de CHAN-97

- Aucun serveur n'a été configuré, aucun compte Linux créé, aucun vhost modifié.
- Aucun environnement GitHub, variable ou secret n'a été créé.
- Aucun déploiement réel n'a été exécuté.
- Aucune configuration PHP-FPM, Nginx ou aaPanel n'a été modifiée.
- Les propriétaires et groupes des racines, de `shared/` et du stockage partagé restent configurés manuellement ; le déploiement les vérifie mais ne les modifie pas. Seuls les modes de la release qu'il crée et de son `bootstrap/cache` sont appliqués automatiquement.
- Le pool PHP-FPM `www` reste **commun aux deux environnements**. L'isolation des comptes SSH, des secrets et des racines est effective ; l'isolation complète de l'exécution PHP ne l'est pas. Une séparation en deux pools par environnement reste à évaluer.
- Un changement d'appartenance de groupe n'est pris en compte qu'après rechargement des processus PHP-FPM et Nginx ; cette opération est manuelle.
- La procédure de contrôle des permissions documentée n'a pas été exécutée sur le serveur.
- Aucune migration de base de données n'est exécutée par un déploiement.
- La stratégie de migrations et de compatibilité N/N-1 est documentée dans [`database-migrations.md`](database-migrations.md) (lot 1 de CHAN-98). Aucun script de migration ou de rollback n'est ajouté par ce lot.
- Aucun rollback automatique n'est implémenté : une release précédente reste disponible dans `releases/`, et son activation relève d'une décision et de la procédure manuelle outillée du lot 3 ([`application-rollback.md`](application-rollback.md)). Un rollback applicatif ne restaure jamais la base de données.
- En cas d'échec avant activation, le répertoire incomplet est nettoyé sans toucher à la release active ni à `shared/`.
- En cas d'échec du health check après activation, la nouvelle release reste active et le déploiement est signalé en échec ; aucune restauration automatique n'est effectuée.
- Le mode maintenance n'est pas activé automatiquement.
- Le superviseur des workers et les entrées cron doivent être confirmés sur le serveur.
- La politique `.env` en `0600` dépend de la présence de `bootstrap/cache/config.php` dans la release active. Une commande manuelle `config:clear` ou `optimize:clear` casse ce fonctionnement jusqu'à recompilation ou redéploiement.
- `DEPLOY_PHP_BIN`, les empreintes SSH et les protections GitHub restent à relever ou configurer manuellement.
- Les 90 jours de rétention dépendent des limites du dépôt.
- Aucun contrôle anti-rétrogradation n'est implémenté (recommandation documentée ci-dessus).

### Dépendances

- **CHAN-98, lot 1** : stratégie de migrations, compatibilité N/N-1, conventions et politique de rollback, documentées dans [`database-migrations.md`](database-migrations.md). Les points d'intégration sont le marqueur `release.json`, le répertoire `releases/` et le lien `current`.
- **CHAN-98, lot 2** : sauvegarde, intégrité et restauration isolée, définies dans [`backup-restore.md`](backup-restore.md) et [`backup-restore-runbook.md`](backup-restore-runbook.md). Les scripts [`scripts/ops`](../../scripts/ops) ne sont ni planifiés ni appelés par un déploiement. Aucune sauvegarde réelle n'a été produite et aucune restauration réelle n'a été démontrée : la stratégie reste requise avant toute migration destructive en production.
- **Automatisation du rollback** : non implémentée. Un rollback applicatif reste manuel et ne restaure jamais la base de données.
- **CHAN-99** : dépendance de suivi mentionnée par le ticket parent. Son périmètre n'est pas décrit dans ce dépôt à la date de rédaction ; aucun élément de CHAN-99 n'est intégré ici.

## Vérifications locales

```bash
php .github/scripts/tests/validate-workflows.php
bash .github/scripts/tests/test-deployment-automation.sh
bash .github/scripts/tests/test-release-automation.sh
shellcheck .github/scripts/deploy/*.sh .github/scripts/tests/*.sh
actionlint
php artisan test tests/Unit/Migrations tests/Unit/Documentation
composer ci:check
```

Les tests couvrent la validation des tags (y compris l'avancée de branche et les tags divergents), le refus des préreleases, l'absence de candidate staging, les artefacts expirés, manquants ou ambigus, la pagination de l'API, le schéma strict des manifestes, les empreintes incorrectes, la provenance, la comparaison des arbres Git, les environnements et chemins interdits (dont les chemins aaPanel exacts et le refus des anciens chemins), les archives malveillantes (liens symboliques et physiques), le nettoyage sécurisé (release préexistante, release active, `.incoming` préexistant, signaux, masquage des sections critiques), les permissions de `.env` (`0600` recommandé, `0640` accepté, `0660`/`0664`/`0644` refusés), le modèle de permissions des racines, de `shared/`, du stockage et de `bootstrap/cache` (setgid, écriture de groupe, absence de `777` et de droits pour les autres), l'absence d'appel `env()` hors de `config/`, la présence obligatoire de `bootstrap/cache/config.php`, l'échec avant activation, les scénarios de journalisation (`shared` absent, non inscriptible, journal absent/inscriptible/non inscriptible/symbolique/répertoire, `shared` symbolique), les exclusions locales et sensibles, les tags malveillants à l'assemblage, l'exclusion de `vendor/bin`, le refus des liens hors `vendor/bin`, le contrôle PHP 8.4, l'absence de migration automatique et l'absence de fuite de secrets. Les tests de politique de migration contrôlent en plus les conventions de rédaction, l'absence d'opération destructrice non annotée, la présence de la documentation et son lien depuis ce document. Un job `package-linux` exécute le build Ubuntu réel décrit ci-dessus.
