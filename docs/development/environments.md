# Environnements de recette et de production

Ce document prépare l'architecture, la séparation et les protections des environnements **staging** et **production** de C2ME Chantier.

- Ticket : CHAN-96 – Préparer la documentation des environnements.
- Ticket parent : CHAN-92 – Définir le workflow Git, les releases et les déploiements.
- Dépôt : [`C2ME-ORGA/chantier`](https://github.com/C2ME-ORGA/chantier).
- Portée : architecture des environnements, séparation des données et des secrets, GitHub Environments, données de recette, accès, sauvegardes et contrôles.
- Hors portée : recette fonctionnelle, migrations et rollback (CHAN-98). La stratégie de migrations et de compatibilité N/N-1 est définie dans [`database-migrations.md`](database-migrations.md) (lot 1 de CHAN-98). Les déploiements automatisés sont définis dans [`deployment-process.md`](deployment-process.md) (CHAN-97).

Ce document est préparatoire. Il ne crée aucun environnement, ne configure aucun serveur, ne crée aucune base de données, aucun sous-domaine, aucun secret et ne déclenche aucun déploiement.

## Sources de vérité

| Sujet | Référence |
| --- | --- |
| Environnements et protections | Ce document |
| Branches, commits et Pull Requests | [`git-workflow.md`](git-workflow.md) |
| Versionnement, tags et releases | [`release-process.md`](release-process.md) |
| Migrations, compatibilité N/N-1 et rollback applicatif | [`database-migrations.md`](database-migrations.md) |
| Contrôle d'intégration continue | [`.github/workflows/tests.yml`](../../.github/workflows/tests.yml) |
| Workflow de release | [`.github/workflows/release.yml`](../../.github/workflows/release.yml) |
| Règles impératives pour les agents et contributeurs | [`AGENTS.md`](../../AGENTS.md) |

## État constaté

État vérifié le 12 novembre 2026, lors de CHAN-96 :

- le dépôt `C2ME-ORGA/chantier` est **public** ;
- aucun GitHub Environment `staging` ou `production` n'est configuré ;
- aucun secret ni aucune variable d'action ne sont configurés au niveau du dépôt ;
- aucun workflow de déploiement n'existait dans `.github/workflows/` à cette date ;
- le domaine de production n'était présent ni dans la documentation ni dans la configuration du dépôt ;
- le domaine de staging est fourni par le ticket : `https://chantier-staging.c2me.ovh`.

Depuis CHAN-97, les workflows `deploy-staging` et `deploy-production` existent et sont documentés dans [`deployment-process.md`](deployment-process.md). Les environnements GitHub, variables et secrets restent à créer manuellement.

Aucune connexion au serveur, à aaPanel, à MySQL ou aux environnements GitHub n'a été effectuée pour produire ce document.

Les documents `AGENTS.md`, `README.md`, `docs/development/git-workflow.md`, `docs/development/release-process.md`, `.env.example`, `.github/workflows/tests.yml` et `.github/workflows/release.yml` ont été examinés lors de CHAN-96.

> **Domaines et chemins :** les deux sites aaPanel existent déjà. Les chemins définitifs sont `/www/wwwroot/chantier-staging.c2me.ovh` et `/www/wwwroot/chantier.c2me.fr` ; ils sont imposés par les scripts et workflows de déploiement. Les anciens chemins `/www/wwwroot/chantier-staging` et `/www/wwwroot/chantier` sont refusés.

## Architecture cible

Un seul serveur **Ubuntu 24.04** administré avec **aaPanel** héberge deux installations Laravel indépendantes :

```text
Serveur Ubuntu 24.04 / aaPanel
├── chantier-staging.c2me.ovh
│   ├── /www/wwwroot/chantier-staging.c2me.ovh
│   ├── base chantier_staging
│   ├── utilisateur MySQL dédié
│   └── .env, stockage, logs, workers et tâches planifiées dédiés
└── chantier.c2me.fr
    ├── /www/wwwroot/chantier.c2me.fr
    ├── base chantier_production
    ├── utilisateur MySQL dédié
    └── .env, stockage, logs, workers et tâches planifiées dédiés
```

Les deux environnements partagent le serveur physique, mais aucun élément d'exécution ne doit être partagé :

- aucun secret ou fichier `.env` commun ;
- aucune base de données ni aucun utilisateur MySQL commun ;
- aucun stockage de fichiers commun ;
- aucun journal, cache, session ou worker commun ;
- aucun accès SQL croisé ;
- aucun lien symbolique entre les deux répertoires.

Le serveur est un Ubuntu 24.04.5 LTS avec aaPanel, PHP-FPM 8.4 (pool `www`, socket `/tmp/php-cgi-84.sock`) et MariaDB 10.11. Les deux sites aaPanel existent et conservent leurs répertoires actuels.

## Domaines, répertoires et données

| Élément | Staging | Production |
| --- | --- | --- |
| Rôle | Validation fonctionnelle et recette. | Exploitation réelle. |
| URL | `https://chantier-staging.c2me.ovh` | `https://chantier.c2me.fr` |
| Répertoire cible | `/www/wwwroot/chantier-staging.c2me.ovh` | `/www/wwwroot/chantier.c2me.fr` |
| DocumentRoot aaPanel | `/www/wwwroot/chantier-staging.c2me.ovh/current/public` | `/www/wwwroot/chantier.c2me.fr/current/public` |
| Base de données | `chantier_staging` | `chantier_production` |
| Utilisateur MySQL | Dédié au staging, distinct. | Dédié à la production, distinct. |
| Fichier `.env` | `/www/wwwroot/chantier-staging.c2me.ovh/shared/.env` | `/www/wwwroot/chantier.c2me.fr/shared/.env` |
| Stockage applicatif | `/www/wwwroot/chantier-staging.c2me.ovh/shared/storage` | `/www/wwwroot/chantier.c2me.fr/shared/storage` |
| Journaux | `/www/wwwroot/chantier-staging.c2me.ovh/shared/storage/logs` | `/www/wwwroot/chantier.c2me.fr/shared/storage/logs` |
| Données | Fictives ou anonymisées. | Données réelles. |
| Accès HTTP | Réservé à l'équipe C2ME. | Application publique, administration protégée. |
| GitHub Environment | `staging` | `production` |

Le répertoire cible Laravel est la racine de l'installation ; le DocumentRoot du site aaPanel pointe vers `<ROOT>/current/public`, jamais vers la racine Laravel. L'installation suit la structure `releases/`, `shared/` et `current` décrite dans [`deployment-process.md`](deployment-process.md).

## Comptes système, groupes et permissions

### Comptes et groupes

| Élément | Staging | Production |
| --- | --- | --- |
| Compte SSH de déploiement | `c2me-deploy-staging` | `c2me-deploy-production` |
| Groupe principal du compte | `c2me-staging` | `c2me-production` |
| Racine aaPanel | `/www/wwwroot/chantier-staging.c2me.ovh` | `/www/wwwroot/chantier.c2me.fr` |
| Processus PHP-FPM et Nginx | `www:www`, pool commun | `www:www`, pool commun |

- Les deux comptes de déploiement sont dédiés, sans connexion interactive par mot de passe et **sans privilège `sudo`**.
- Les racines appartiennent au compte de déploiement de leur environnement, avec le groupe de l'environnement, en mode `2770` : le compte écrit, le groupe lit et traverse, les autres utilisateurs n'ont aucun droit.
- Le compte `www` exécute PHP-FPM 8.4 et Nginx. Il appartient actuellement aux deux groupes afin de servir les deux sites.
- `www` n'est jamais utilisé comme compte SSH de déploiement.

### Modèle de permissions

Les modes ci-dessous sont le modèle attendu. Le déploiement vérifie les répertoires créés manuellement et applique lui-même les modes de la release qu'il prépare.

| Chemin | Propriétaire | Groupe | Mode | Justification |
| --- | --- | --- | --- | --- |
| `<ROOT>` | compte de déploiement | groupe de l'environnement | `2770` | écriture du déploiement, traversée du groupe PHP-FPM. |
| `<ROOT>/releases` | compte de déploiement | groupe de l'environnement | `2770` | création et publication des releases. |
| `<ROOT>/releases/<release>` | compte de déploiement | groupe de l'environnement | `2750` | code en lecture seule pour le groupe : PHP-FPM lit, ne modifie pas. |
| `<ROOT>/releases/<release>/bootstrap/cache` | compte de déploiement | groupe de l'environnement | `2770` | PHP-FPM écrit les caches de compilation et de paquets. |
| `<ROOT>/shared` | compte de déploiement | groupe de l'environnement | `2770` | journal, liens `.env` et `storage`. |
| `<ROOT>/shared/.env` | compte de déploiement | groupe de l'environnement | `0600` (recommandé) ou `0640` | secrets non lisibles par les autres ; `0600` retire aussi la lecture au groupe, inutile à l'exécution. |
| `<ROOT>/shared/storage` | compte de déploiement | groupe de l'environnement | `2770` | logs, sessions, caches et vues écrits par PHP-FPM. |
| `<ROOT>/shared/deployment.log` | compte de déploiement | groupe de l'environnement | `0600` | journal du déploiement non lisible par le groupe ni par les autres. |
| `<ROOT>/current` | compte de déploiement | groupe de l'environnement | lien symbolique | pointe vers `<ROOT>/releases/<release>`. |

Le bit setgid (`2`) sur les répertoires garantit que les fichiers créés héritent du groupe de l'environnement, y compris ceux écrits par PHP-FPM dans `storage/`.

L'état actuel du serveur utilise `2770` sur les racines. L'écriture de groupe n'est pas nécessaire à PHP-FPM sur `<ROOT>`, `releases/` et `shared/` : un passage à `2750` (lecture et traversée du groupe, aucune écriture) durcit l'intégrité du code déployé, du lien `current` et du journal. Le déploiement accepte les deux modes ; toute modification reste manuelle et hors de cette correction. `shared/storage` et `bootstrap/cache` doivent en revanche conserver l'écriture de groupe.

Le déploiement force `umask 027` avant l'extraction : les fichiers du paquet sont créés en `0640` ou `0750` et restent lisibles par le groupe sans être accessibles aux autres utilisateurs.

Règles absolues :

- aucun mode `777` ni aucune écriture pour les autres utilisateurs ;
- aucun `.env` lisible ou modifiable par les autres utilisateurs ;
- aucun `.env` modifiable par le groupe ;
- aucun accès croisé entre les comptes de déploiement ;
- aucun mode `660` ou `664` sur `.env` ;
- le mode `0600` est recommandé : il retire une lecture de groupe dont PHP-FPM n'a pas besoin ;
- le mode `0640` reste accepté pour compatibilité, mais n'est pas nécessaire.

### `.env`, `config:cache` et exécution PHP

Le déploiement exécute `config:cache` avec le compte technique, propriétaire du `.env`. Laravel compile alors toute la configuration dans `bootstrap/cache/config.php`. Le framework ne charge `.env` que lorsque cette configuration n'est pas en cache (`LoadEnvironmentVariables` sort immédiatement si `configurationIsCached()` est vrai). L'application est servie avec la configuration compilée : PHP-FPM n'a donc **pas besoin de lire `shared/.env`**.

Le code applicatif ne contient aucun appel `env()` hors de `config/` ; les valeurs sont lues via `config()`, donc depuis le cache compilé. Les commandes Artisan exécutées par le cron (`schedule:run`) et les workers de file d'attente reposent sur la même configuration compilée.

Conséquences :

- `.env` peut rester en `0600`, propriété du compte de déploiement ;
- `bootstrap/cache/config.php` doit exister dans chaque release activée et rester lisible par le groupe (`0640`), car PHP-FPM le lit ;
- si `config:cache` est annulé manuellement (`config:clear`, `optimize:clear`), l'application retombe sur la lecture de `.env` et cesse de fonctionner avec un `.env` en `0600` ; il faut alors recompiler la configuration avec le compte de déploiement, ou redéployer ;
- le déploiement vérifie l'existence de la configuration compilée avant et après activation.

### Rôle de `www` et limite d'isolation PHP

Le pool PHP-FPM `www` est **commun aux deux sites** et le compte `www` appartient actuellement aux deux groupes. Conséquences :

- chaque site peut être servi correctement : `www` traverse la release (`2750`) et lit le code, écrit dans son `storage/` (`2770`) et dans `bootstrap/cache/` (`2770`) ;
- `www` ne lit pas `shared/.env` lorsque celui-ci est en `0600` ; avec le mode `0640`, il le lirait ;
- l'isolation au niveau de l'exécution PHP n'est **pas complète** : un processus PHP compromis sur staging peut accéder, via les appartenances de groupe du compte `www`, au `storage/` de production (écriture de groupe) et aux fichiers de code lisibles par le groupe ;
- l'isolation réellement garantie porte sur les comptes SSH de déploiement, les racines, les secrets `.env`, les bases et les vhosts.

Deux évolutions sont possibles :

1. **Conserver le pool commun** et accepter la limite d'isolation ci-dessus. C'est la situation actuelle, documentée ici.
2. **Créer un pool PHP-FPM par environnement**, chacun avec son propre utilisateur et son propre socket, puis associer chaque vhost à son pool dans aaPanel. Cette évolution n'est pas réalisée : elle doit être évaluée avec l'impact sur les autres sites hébergés sur le serveur.

Aucune configuration PHP-FPM n'est modifiée par cette correction.

Un changement de groupe n'est pris en compte que par les nouveaux processus : après toute modification des groupes de `www`, un rechargement ou redémarrage de PHP-FPM et de Nginx est nécessaire. Cette opération reste manuelle et hors du périmètre du déploiement.

### Chemins refusés

Les anciens chemins `/www/wwwroot/chantier-staging` et `/www/wwwroot/chantier` sont refusés par les scripts serveur et par les workflows, y compris lorsque l'environnement ou le compte correspondent. Les chemins définitifs sont ceux du tableau des domaines.

## Séparation MySQL

### Bases et utilisateurs

- Chaque environnement possède sa propre base : `chantier_staging` et `chantier_production`.
- Chaque base possède son propre utilisateur MySQL, utilisé uniquement par l'application de l'environnement concerné.
- Les deux utilisateurs ont des mots de passe distincts, générés indépendamment et jamais partagés.
- Les utilisateurs se connectent depuis `localhost` ou `127.0.0.1`. Aucun accès MySQL public n'est requis.
- Les privilèges sont limités à la base de l'environnement et aux opérations nécessaires à l'application et aux migrations.
- Aucun accès global, `GRANT OPTION`, `FILE`, `PROCESS` ou `SUPER` n'est accordé à l'application.
- Le compte `root` ou l'administrateur MySQL ne doit jamais être utilisé dans le fichier `.env` de l'application.

### Contrôles attendus

Lors de la configuration, vérifier avec l'utilisateur de chaque environnement :

```sql
SELECT DATABASE(), CURRENT_USER();
SHOW GRANTS FOR CURRENT_USER();
```

L'utilisateur de staging ne doit pouvoir accéder ni à `chantier_production`, ni aux bases système. L'utilisateur de production ne doit pouvoir accéder ni à `chantier_staging`, ni aux bases système.

Une restauration de sauvegarde de production vers staging est interdite sans anonymisation préalable.

## Séparation des fichiers `.env`

Chaque installation dispose de son propre fichier `.env`, dans son répertoire `shared/` :

- `/www/wwwroot/chantier-staging.c2me.ovh/shared/.env` ;
- `/www/wwwroot/chantier.c2me.fr/shared/.env`.

Chaque release active y accède par un lien symbolique interne. Le fichier partagé n'est jamais remplacé par un déploiement.

Règles :

- les fichiers `.env` ne sont jamais versionnés dans le dépôt ;
- ils ne sont jamais copiés d'un environnement à l'autre ;
- ils ne sont jamais échangés par lien symbolique ;
- ils sont lisibles uniquement par l'utilisateur du site et l'administrateur ; l'écriture par le groupe et tout accès des autres utilisateurs sont interdits. Le mode recommandé est `0600` (propriétaire = compte de déploiement) ; `0640` reste accepté mais n'est pas nécessaire, la configuration étant compilée par le déploiement ;
- chaque environnement possède une `APP_KEY` distincte ;
- les secrets de production ne sont jamais utilisés pour staging et inversement ;
- un déploiement ne doit pas écraser ni afficher le contenu du `.env` ;
- les commandes `php artisan config:cache` et `php artisan optimize:clear` sont exécutées dans le répertoire de l'environnement concerné, jamais depuis l'autre installation.

## Stockage, journaux, cache, sessions et files d'attente

### Fichiers et stockage

- Chaque installation utilise son propre répertoire `shared/storage/`, sous son répertoire cible.
- Les fichiers privés restent dans `shared/storage/app/private` et les fichiers publics dans `shared/storage/app/public`.
- Le lien `public/storage` est créé dans chaque release et pointe uniquement vers le stockage partagé de son propre environnement.
- Aucun lien symbolique ne doit pointer de staging vers la production, ou inversement.
- Les documents et pièces jointes de production ne sont jamais copiés dans staging sans anonymisation.
- Si un stockage objet est ajouté plus tard, chaque environnement doit utiliser un bucket ou un préfixe distinct et des identifiants distincts.

### Journaux

- Les journaux sont écrits dans le `storage/logs` de chaque installation.
- Le niveau et la rotation sont adaptés à l'environnement ; les journaux de production ne sont pas mélangés avec ceux de staging.
- Les journaux ne doivent jamais contenir de secret, de token, de mot de passe, de fichier `.env` ou de donnée personnelle réelle non masquée.
- Les journaux de staging peuvent être plus verbeux que ceux de production, sans exposer de secret.

### Cache et sessions

La configuration par défaut de Laravel utilise la base de données pour le cache et les sessions. Ce choix est acceptable si chaque environnement utilise sa propre base.

Si Redis est installé et retenu :

- chaque environnement utilise une base Redis distincte et un préfixe distinct (`CACHE_PREFIX`, `REDIS_PREFIX`, `REDIS_DB`, `REDIS_CACHE_DB`) ;
- les mots de passe Redis sont distincts si l'authentification est activée ;
- aucun cache, verrou ou session n'est partagé entre staging et production.

Les cookies de session sont limités au domaine de l'environnement et configurés en HTTPS. Aucun cookie de production ne doit être accepté par staging.

### Files d'attente et workers

- Chaque environnement dispose de ses propres workers de queue.
- Avec la connexion `database`, les jobs sont stockés dans la base de l'environnement et sont donc isolés.
- Si Redis est utilisé, les files, la base Redis et les préfixes sont distincts.
- Les workers sont supervisés séparément, avec un nom de programme, un répertoire de travail et un fichier de log propres à l'environnement.
- Un worker de staging ne doit jamais traiter les jobs de production.
- Les jobs échoués et les tentatives sont consultés dans le contexte de l'environnement concerné.

### Tâches planifiées

Chaque environnement possède sa propre entrée cron pour Laravel :

```text
* * * * * cd /www/wwwroot/chantier-staging.c2me.ovh/current && <php> artisan schedule:run >> /www/wwwroot/chantier-staging.c2me.ovh/shared/storage/logs/scheduler.log 2>&1
* * * * * cd /www/wwwroot/chantier.c2me.fr/current && <php> artisan schedule:run >> /www/wwwroot/chantier.c2me.fr/shared/storage/logs/scheduler.log 2>&1
```

`<php>` doit être remplacé par le binaire PHP 8.4 validé sur le serveur. La commande doit s'exécuter avec l'utilisateur du site concerné et depuis le bon répertoire.

Chaque environnement écrit ses sorties standard et ses erreurs dans son propre fichier `storage/logs/scheduler.log`.

Une seule entrée `schedule:run` doit exister par environnement. Aucune tâche planifiée ne doit être partagée, dupliquée ou exécutée depuis le mauvais répertoire. Les sorties et les erreurs sont dirigées vers le `storage/logs/scheduler.log` de l'environnement.

## Matrice des variables et secrets

Aucune valeur de secret n'est documentée. Les valeurs sont créées directement sur le serveur ou dans les GitHub Environments, jamais dans le dépôt.

### Variables serveur non sensibles

Ces variables sont définies dans le `.env` de chaque installation.

| Variable | Staging | Production | Fonction |
| --- | --- | --- | --- |
| `APP_NAME` | `C2ME Chantier` | `C2ME Chantier` | Nom affiché de l'application. |
| `APP_ENV` | `staging` | `production` | Environnement Laravel. |
| `APP_DEBUG` | `false` | `false` | Aucun détail d'erreur exposé publiquement. |
| `APP_URL` | `https://chantier-staging.c2me.ovh` | `https://chantier.c2me.fr` | URL de base et génération des liens. |
| `APP_MAINTENANCE_DRIVER` | `file` | `file` | Mode maintenance local à l'installation. |
| `LOG_CHANNEL` | `stack` | `stack` | Canal de journalisation. |
| `LOG_STACK` | `daily` | `daily` | Rotation quotidienne recommandée. |
| `LOG_LEVEL` | `debug` | `warning` | Niveau de détail adapté à l'environnement. |
| `DB_CONNECTION` | `mysql` | `mysql` | Connexion MySQL/MariaDB. |
| `DB_HOST` | `127.0.0.1` | `127.0.0.1` | Connexion locale au serveur de base. |
| `DB_PORT` | `3306` | `3306` | Port MySQL/MariaDB local. |
| `DB_DATABASE` | `chantier_staging` | `chantier_production` | Base dédiée à l'environnement. |
| `DB_USERNAME` | Utilisateur MySQL dédié au staging. | Utilisateur MySQL dédié à la production. | Compte applicatif à privilèges limités. |
| `SESSION_DRIVER` | `database` ou `redis`. | `database` ou `redis`. | Stockage des sessions, isolé par base ou Redis. |
| `SESSION_DOMAIN` | `chantier-staging.c2me.ovh` | `chantier.c2me.fr` | Domaine du cookie de session. |
| `SESSION_SECURE_COOKIE` | `true` | `true` | Cookie uniquement transmis en HTTPS. |
| `SESSION_COOKIE` | Nom distinct du staging. | Nom distinct de la production. | Évite toute ambiguïté de cookie. |
| `CACHE_STORE` | `database` ou `redis`. | `database` ou `redis`. | Stockage du cache. |
| `CACHE_PREFIX` | Préfixe propre au staging. | Préfixe propre à la production. | Isolation des clés de cache. |
| `QUEUE_CONNECTION` | `database` ou `redis`. | `database` ou `redis`. | Connexion des files d'attente. |
| `DB_QUEUE` | File propre au staging si la connexion database est utilisée. | File propre à la production si la connexion database est utilisée. | Nom de file d'attente. |
| `FILESYSTEM_DISK` | `local` | `local` | Disque par défaut pour les fichiers. |
| `MAIL_MAILER` | `log` ou bac à sable. | `smtp` ou fournisseur validé. | Transport des emails. |
| `MAIL_HOST` | Hôte de test ou vide selon le transport. | Hôte SMTP de production. | Serveur d'envoi. |
| `MAIL_PORT` | Port du transport de test. | Port du serveur SMTP de production. | Port d'envoi. |
| `MAIL_FROM_ADDRESS` | `<adresse-expediteur-staging>` | `<adresse-expediteur-production>` | Expéditeur des emails. |
| `MAIL_FROM_NAME` | `C2ME Chantier Staging` | `C2ME Chantier` | Nom affiché de l'expéditeur. |
| `REDIS_HOST` | `127.0.0.1` si Redis. | `127.0.0.1` si Redis. | Serveur Redis local. |
| `REDIS_PORT` | `6379` si Redis. | `6379` si Redis. | Port Redis local. |
| `REDIS_DB` | Base Redis propre au staging. | Base Redis propre à la production. | Connexion Redis par défaut. |
| `REDIS_CACHE_DB` | Base Redis de cache propre au staging. | Base Redis de cache propre à la production. | Cache Redis. |
| `REDIS_PREFIX` | Préfixe propre au staging. | Préfixe propre à la production. | Isolation des clés Redis. |
| `VITE_APP_NAME` | `C2ME Chantier Staging` | `C2ME Chantier` | Nom exposé au frontend. |

Les valeurs `MAIL_*` de staging doivent utiliser un transport qui n'envoie aucun email réel à un client. Les adresses d'expédition de production ne sont pas documentées dans le dépôt.

### Secrets serveur

Ces valeurs sont stockées uniquement dans le `.env` de l'environnement concerné.

| Secret | Staging | Production | Fonction |
| --- | --- | --- | --- |
| `APP_KEY` | Valeur distincte. | Valeur distincte. | Chiffrement Laravel, signatures et sessions. |
| `DB_PASSWORD` | Mot de passe de l'utilisateur MySQL de staging. | Mot de passe de l'utilisateur MySQL de production. | Authentification MySQL. |
| `MAIL_USERNAME` | Identifiant du transport de test si nécessaire. | Identifiant SMTP de production. | Authentification SMTP. |
| `MAIL_PASSWORD` | Mot de passe du transport de test si nécessaire. | Mot de passe SMTP de production. | Authentification SMTP. |
| `REDIS_PASSWORD` | Mot de passe Redis de staging si activé. | Mot de passe Redis de production si activé. | Authentification Redis. |
| `AWS_ACCESS_KEY_ID` | Identifiant dédié si un stockage S3 est utilisé. | Identifiant dédié si un stockage S3 est utilisé. | Accès au stockage objet. |
| `AWS_SECRET_ACCESS_KEY` | Secret dédié si un stockage S3 est utilisé. | Secret dédié si un stockage S3 est utilisé. | Accès au stockage objet. |

Règles :

- aucun secret n'est identique entre staging et production ;
- aucun secret n'est commité, affiché dans un journal, un artefact ou une réponse HTTP ;
- une rotation de `APP_KEY` nécessite une analyse d'impact sur les données chiffrées et les sessions ;
- les secrets ne sont jamais copiés dans un ticket, un commentaire de Pull Request ou un fichier de documentation.

### Variables et secrets GitHub Environment

Les noms ci-dessous sont la configuration retenue par CHAN-97. Les environnements ne sont pas encore créés : leur création et le renseignement de ces valeurs restent manuels.

Variables non sensibles, définies par environnement :

| Variable | Staging | Production | Fonction |
| --- | --- | --- | --- |
| `DEPLOY_ENVIRONMENT` | `staging` | `production` | Environnement ciblé par le workflow. |
| `DEPLOY_PATH` | `/www/wwwroot/chantier-staging.c2me.ovh` | `/www/wwwroot/chantier.c2me.fr` | Répertoire de l'installation. |
| `APP_URL` | `https://chantier-staging.c2me.ovh` | `https://chantier.c2me.fr` | URL publique de contrôle. |
| `DEPLOY_PHP_BIN` | Binaire PHP 8.4 à relever et confirmer sur le serveur. | Binaire PHP 8.4 à relever et confirmer sur le serveur. | Interpréteur des commandes Artisan. |
| `DEPLOY_ROUTE_CACHE` | `true` ou `false`. | `true` ou `false`. | Active `route:cache` après vérification de compatibilité. |
| `DEPLOY_QUEUE_RESTART` | `false` par défaut. | `false` par défaut. | Active `queue:restart` uniquement si des workers sont supervisés. |

Secrets, définis par environnement et jamais au niveau du dépôt :

| Secret | Staging | Production | Fonction |
| --- | --- | --- | --- |
| `SSH_HOST` | Hôte du serveur. | Hôte du serveur. | Connexion SSH de déploiement. |
| `SSH_PORT` | Port SSH. | Port SSH. | Port de connexion SSH. |
| `SSH_USER` | Utilisateur de déploiement staging. | Utilisateur de déploiement production. | Compte SSH à privilèges limités. |
| `SSH_PRIVATE_KEY` | Clé de déploiement staging. | Clé de déploiement production. | Authentification SSH par clé. |
| `SSH_KNOWN_HOSTS` | Empreinte du serveur pour staging. | Empreinte du serveur pour production. | Vérification de l'hôte SSH. |

Les secrets applicatifs (`APP_KEY`, `DB_PASSWORD`, `MAIL_PASSWORD`, etc.) restent dans le `.env` du serveur et ne sont pas dupliqués dans GitHub. CHAN-97 ne les déplace pas vers GitHub : seuls les secrets de connexion SSH sont stockés dans les environnements GitHub.

## Gestion des données de recette

Le staging ne doit jamais contenir de données réelles identifiantes ou financières exploitables.

Règles :

- utiliser en priorité des données fictives générées par des seeders ou des factories ;
- ne jamais restaurer directement un dump de production dans `chantier_staging` ;
- si un jeu de données de production est nécessaire, l'anonymiser de manière irréversible avant import ;
- supprimer ou pseudonymiser les noms, prénoms, adresses, téléphones, emails, identifiants clients, données bancaires, montants réels et pièces jointes sensibles ;
- conserver toute table de correspondance d'anonymisation hors du dépôt et hors du serveur de production ;
- vérifier les fichiers, images et PDF importés, qui peuvent contenir des données personnelles ;
- ne jamais envoyer d'email réel depuis le staging : utiliser `log`, un bac à sable ou une adresse de test ;
- ne jamais importer les données de staging en production ;
- limiter les exports et les sauvegardes de staging aux personnes habilitées.

Les données de staging doivent pouvoir être réinitialisées sans impacter la production.

## Accès équipe C2ME

### Accès HTTP

- Le staging est réservé à l'équipe C2ME. Une protection d'accès doit être activée avant sa mise en service : authentification HTTP, liste d'adresses IP autorisées ou accès via VPN. La méthode exacte sera confirmée lors de la configuration.
- Le staging ne doit pas être indexé par les moteurs de recherche.
- La production est accessible publiquement, mais l'administration et les fonctions sensibles restent protégées par l'authentification et les autorisations applicatives.
- Les accès administrateur ne doivent pas être partagés entre plusieurs personnes.

### Serveur et aaPanel

- L'accès au panneau aaPanel est restreint aux administrateurs et ne doit pas être exposé librement sur Internet.
- Les accès SSH utilisent des clés et des comptes nominatifs ou des comptes de déploiement dédiés, avec le minimum de privilèges.
- Les identifiants MySQL ne sont jamais communiqués aux utilisateurs applicatifs.
- Les droits sur les répertoires de staging et de production sont attribués séparément.
- Toute arrivée ou départ dans l'équipe doit entraîner une revue des accès.

### Principe du moindre privilège

- Aucun membre de l'équipe ne doit disposer d'un accès production s'il n'en a pas besoin.
- Les accès de déploiement sont distincts des accès d'administration quotidienne.
- Les secrets de production ne sont accessibles qu'après approbation de l'environnement GitHub `production`.
- Aucun secret de production ne doit être visible dans les logs ou les artefacts d'un workflow.

## GitHub Environments et protections

Les environnements GitHub sont prévus mais ne sont pas configurés à ce jour. La configuration cible est la suivante.

| Paramètre | `staging` | `production` |
| --- | --- | --- |
| Rôle | Validation fonctionnelle. | Livraison réelle. |
| Approbateur obligatoire | Aucun. | Le propriétaire du dépôt, unique approbateur. Le compte GitHub personnel reste à confirmer. |
| Nombre d'approbateurs | 0. | 1. |
| Auto-approbation | Sans objet. | Autorisée : `Prevent self-review` désactivé. |
| Bypass administrateur | Sans objet. | Désactivé. |
| Délai d'attente | Aucun. | Aucun délai supplémentaire requis. |
| Secrets et variables | Propres au staging. | Propres à la production. |
| Accès aux secrets | Immédiat pour un job autorisé. | Uniquement après approbation. |
| Restriction de branche ou de tag | Tags `v*-rc.*`. | Tags `v*` (release publiée). |

### Staging

- Aucun approbateur obligatoire.
- Les secrets et variables de staging sont distincts de ceux de production.
- Un job qui référence `environment: staging` peut accéder aux secrets de staging sans validation manuelle.
- Les secrets de production ne sont jamais accessibles depuis l'environnement `staging`.

### Production

- Un seul approbateur obligatoire : le propriétaire du dépôt. Le compte GitHub personnel qui portera cette approbation reste à confirmer ; aucun identifiant n'est inventé dans ce document.
- Le paramètre `Prevent self-review` doit être **désactivé** pour que le propriétaire puisse approuver son propre déploiement. S'il restait activé, un second approbateur serait nécessaire, ce qui est exclu par l'organisation retenue.
- Le bypass administrateur doit être désactivé afin que l'approbation reste obligatoire.
- Les secrets de production ne sont injectés dans un job qu'après approbation de l'environnement `production`.
- Aucun secret de production n'est accessible depuis `staging`, ni depuis un job qui ne référence pas l'environnement `production`.

### Restriction de branche ou de tag

CHAN-97 a retenu les déclencheurs suivants, documentés dans [`deployment-process.md`](deployment-process.md) :

- **staging** : push d'un tag `vX.Y.Z-rc.N` rattaché au HEAD de `develop` ;
- **production** : publication d'une release stable `vX.Y.Z` rattachée au HEAD de `main`, avec une référence `Staging-Candidate` vérifiable.

La restriction de déploiement de l'environnement `production` doit être limitée aux tags `v*` lorsque GitHub le permet. Une fusion dans `main` ou un tag ne déploie rien sans release publiée et sans artefact staging valide.

### Dépôt public

Le dépôt étant public :

- aucun secret ne doit être stocké dans le code, les fichiers de documentation, les artefacts ou les logs ;
- les secrets de production doivent rester scoped à l'environnement GitHub `production` ;
- les Pull Requests issues de forks ne doivent pas recevoir de secrets ;
- les workflows ne doivent pas exécuter de code non approuvé avec accès aux secrets de production ;
- les secrets de production ne doivent être accessibles qu'après l'approbation du propriétaire.

## Sauvegardes et isolation des tâches planifiées

### Sauvegardes

- La base `chantier_production` et le stockage de production disposent de sauvegardes dédiées, chiffrées et stockées hors du répertoire de l'application.
- La base `chantier_staging` et son stockage disposent de sauvegardes ou d'un mécanisme de réinitialisation séparés.
- Les sauvegardes de production ne sont jamais accessibles depuis staging.
- Une sauvegarde de production n'est restaurée en staging qu'après anonymisation.
- Les accès aux sauvegardes suivent le principe du moindre privilège.
- Une restauration de production doit être testée avant de considérer la procédure comme opérationnelle.
- La politique de rétention, la fréquence et le support de sauvegarde restent à confirmer lors de la configuration.

### Tâches planifiées

- Chaque environnement possède son propre cron `schedule:run`, exécuté depuis son répertoire.
- Les tâches planifiées de staging ne doivent jamais écrire dans la base ou le stockage de production.
- Les workers de queue sont séparés et supervisés indépendamment.
- Les commandes Artisan de maintenance (`down`, `up`, `optimize:clear`, `config:cache`, `migrate`) sont exécutées dans le répertoire de l'environnement concerné.
- Les caches de configuration, de routes et de vues restent dans le `bootstrap/cache` et le `storage` de l'installation concernée.
- Aucun script partagé ne doit déduire l'environnement à partir d'une variable globale non fiable.

## Contrôles de validation

Les contrôles suivants doivent être exécutés lors de la mise en place des environnements, puis vérifiés avant le premier déploiement automatique.

### Configuration serveur

- [ ] Le domaine de production existant a été identifié et reporté dans ce document.
- [ ] Les deux vhosts pointent vers les bons répertoires.
- [ ] Les certificats TLS sont valides pour les deux domaines.
- [ ] Chaque installation possède son propre `.env`, non versionné et non lisible publiquement.
- [ ] Les deux `APP_KEY` sont distinctes.
- [ ] `APP_ENV`, `APP_DEBUG` et `APP_URL` correspondent à l'environnement.
- [ ] Chaque base utilise son propre utilisateur MySQL.
- [ ] Les privilèges MySQL sont limités à la base de l'environnement.
- [ ] Aucun accès SQL croisé entre staging et production n'est possible.
- [ ] Les répertoires `storage`, `bootstrap/cache` et `storage/logs` sont séparés et accessibles en écriture au bon utilisateur.
- [ ] Les racines sont en `2770` avec le compte et le groupe de leur environnement.
- [ ] `shared/.env` est en `0600` (recommandé) ou `0640` : aucune écriture de groupe, aucun accès des autres utilisateurs.
- [ ] `shared/storage` et `bootstrap/cache` sont inscriptibles par le groupe PHP-FPM (`2770`).
- [ ] `bootstrap/cache/config.php` existe dans la release active et reste lisible par le groupe (`0640`).
- [ ] Aucun répertoire ni fichier déployé n'est en `777` ou accessible en écriture aux autres utilisateurs.
- [ ] Aucun compte de déploiement ne dispose de `sudo` et `www` n'est pas un compte SSH.
- [ ] Le lien `public/storage` de chaque site pointe vers son propre stockage.
- [ ] Les workers de queue sont séparés et supervisés.
- [ ] Un seul cron `schedule:run` existe par environnement.
- [ ] Les emails de staging ne partent pas vers de vrais destinataires.
- [ ] L'accès HTTP au staging est protégé.
- [ ] Le staging n'est pas indexé.
- [ ] Les sauvegardes de production sont indépendantes et protégées.
- [ ] Une restauration de sauvegarde a été testée ou planifiée.

### Données

- [ ] Aucune donnée réelle identifiable n'est présente dans `chantier_staging`.
- [ ] Les données de production ne sont jamais importées directement en staging.
- [ ] Les fichiers et pièces jointes de staging sont fictifs ou anonymisés.
- [ ] Aucun export de données réelles n'est présent dans le dépôt.

### GitHub Environments

- [ ] L'environnement `staging` existe et ne possède aucun approbateur obligatoire.
- [ ] L'environnement `production` existe et possède un seul approbateur obligatoire, le propriétaire du dépôt, dont le compte GitHub personnel reste à confirmer.
- [ ] `Prevent self-review` est désactivé pour `production`.
- [ ] Le bypass administrateur est désactivé pour `production`.
- [ ] Les secrets de staging et de production sont distincts et scoped aux bons environnements.
- [ ] Aucun secret de production n'est configuré au niveau du dépôt.
- [ ] Les workflows `deploy-staging` et `deploy-production` référencent explicitement l'environnement correspondant.
- [ ] La restriction de branche ou de tag de `production` est limitée aux tags `v*` lorsque GitHub le permet.

### Dépôt

- [ ] Aucun secret n'est présent dans le dépôt ou dans l'historique.
- [ ] Les liens Markdown sont valides.
- [ ] `git diff --check` ne signale aucune erreur.

## Points à finaliser

- Vérifier dans aaPanel que les deux vhosts pointent vers `<ROOT>/current/public` et que les certificats TLS sont actifs.
- Appliquer et vérifier les permissions du modèle ci-dessus sur les racines, `releases/`, `shared/`, `shared/.env` et `shared/storage` (commandes proposées dans [`deployment-process.md`](deployment-process.md)).
- Vérifier que `www` est bien membre des deux groupes et que les processus PHP-FPM et Nginx ont été rechargés depuis l'ajout au groupe.
- Arbitrer l'évolution vers deux pools PHP-FPM séparés, avec analyse d'impact sur les autres sites hébergés.
- Créer les environnements GitHub `staging` et `production`, y définir les variables et secrets, et configurer les protections.
- Confirmer l'identifiant du compte GitHub personnel de l'approbateur unique de production.
- Relever et renseigner `DEPLOY_PHP_BIN` pour chaque environnement.
- Vérifier l'empreinte SSH hors bande et renseigner `SSH_KNOWN_HOSTS`.
- Définir la politique de sauvegarde, de rétention et de test de restauration (CHAN-98, lot 2).
- Définir la méthode de protection HTTP du staging.
- Décider si Redis est utilisé et, le cas échéant, attribuer les bases et préfixes.
- Décrire la procédure d'anonymisation des données de recette.
- Confirmer les workers supervisés avant d'activer `DEPLOY_QUEUE_RESTART`.
