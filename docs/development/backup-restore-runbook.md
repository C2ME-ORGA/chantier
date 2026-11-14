# Runbook — sauvegarde et restauration

Procédure opérateur de **C2ME Chantier**, à exécuter par l'administrateur habilité.

- Ticket : CHAN-98 – lot 2.
- Document de référence : [`backup-restore.md`](backup-restore.md). En cas de divergence, les règles du document de stratégie prévalent.
- Ce runbook décrit des gestes. **Aucune commande n'a été exécutée sur un serveur** dans le cadre de ce lot.

> **Rappels absolus**
>
> - Ne jamais écraser, déplacer ou supprimer une sauvegarde existante.
> - Ne jamais exécuter une restauration sur `chantier_production` ou `chantier_staging`.
> - Ne jamais copier la clé privée `age` sur le serveur.
> - Ne jamais écrire de données déchiffrées dans une release, un répertoire public ou `shared/storage`.
> - Ne jamais modifier `.env`, cron, comptes ou permissions sans validation explicite.
> - Ne jamais annoncer une sauvegarde fiable sans preuve de restauration.
> - Ne jamais déclarer une restauration réussie sans manifeste, checksums, journaux et rapport.

## 1. Conventions utilisées

```bash
# Environnement : staging ou production
ENV=production
ROOT=/www/wwwroot/chantier.c2me.fr          # adapter : /www/wwwroot/chantier-staging.c2me.ovh
BACKUP_ROOT=/var/backups/c2me/$ENV
PHP=/chemin/verifie/php8.4                   # relevé sur le serveur, jamais deviné
DUMP=/usr/bin/mariadb-dump                   # vérifié par `command -v mariadb-dump`
MYSQL=/usr/bin/mariadb                       # vérifié par `command -v mariadb`
```

Les identifiants MySQL ne sont jamais saisis en ligne de commande. Ils proviennent d'un fichier d'options `0600` :

```bash
# Exporter les variables utilisées par les scripts (adapter les chemins)
export C2ME_ROOT=/www/wwwroot/chantier.c2me.fr
export C2ME_BACKUP_ROOT=/var/backups/c2me/production
export C2ME_DB_DEFAULTS_FILE=/home/c2me-backup-production/.my.cnf
export C2ME_AGE_RECIPIENT_FILE="$C2ME_BACKUP_ROOT/keys/recipient.pub"
export C2ME_PHP_BIN=/chemin/verifie/php8.4
export C2ME_MYSQL_BIN=/usr/bin/mariadb
export C2ME_DB_DUMP_BIN=/usr/bin/mariadb-dump
export C2ME_AGE_BIN=/usr/bin/age

# Identité d'hôte stable : obligatoire pour le verrou.
# Si `hostname -s` n'est pas fiable (conteneur, nom vide, "unknown"), définir
# explicitement une valeur stable et unique par serveur.
export C2ME_HOST_ID="$(hostname -s)"

# Exemple de structure — les valeurs ne sont jamais affichées ni commitées
# /home/c2me-backup-production/.my.cnf
[client]
user=c2me_backup_production
password=<secret>
host=127.0.0.1
```

Le fichier appartient au compte de sauvegarde et n'est lisible que par lui (`0600`). Pour une restauration, `C2ME_RESTORE_DB_DEFAULTS_FILE` pointe vers un utilisateur MySQL limité aux bases `chantier_restore_*`.

## 2. Sauvegarde

### 2.1 Préflight

1. Vérifier que l'on est sur le bon serveur, le bon compte et le bon environnement :

   ```bash
   hostname
   id
   readlink -f "$ROOT/current"
   cat "$ROOT/current/release.json"
   ```

2. Exécuter le préflight outillé (outils, base InnoDB, espace disque, clé publique, absence de clé privée) :

   ```bash
   bash scripts/ops/backup.sh preflight --env "$ENV"
   ```

   Le mode maintenance n'est pas encore actif à cette étape : le préflight le signale sans échouer, mais la production du jeu le refusera.

3. Vérifier le binaire PHP et les outils :

   ```bash
   "$PHP" -v
   command -v mariadb-dump mariadb age zstd tar sha256sum
   ```

3. Vérifier la clé privée `age` n'est **pas** sur le serveur :

   ```bash
   test -e "$BACKUP_ROOT/keys/recipient.pub" || echo 'NO-GO : clé publique absente'
   find "$BACKUP_ROOT" "$ROOT" -name '*.key' -o -name 'age-identity*' 2>/dev/null
   ```

   Toute clé privée trouvée est un incident de sécurité : arrêt immédiat, retrait, revue.

4. Vérifier les tables non InnoDB :

   ```bash
   "$MYSQL" --defaults-extra-file="$HOME/.my.cnf" -N -B -e \
     "SELECT table_name, engine FROM information_schema.tables
      WHERE table_schema = DATABASE() AND engine <> 'InnoDB';" "$DB_NAME"
   ```

   Toute sortie non vide est un **NO-GO**.

5. Vérifier l'espace disque :

   ```bash
   df -h "$BACKUP_ROOT"
   du -sh "$ROOT/shared/storage"
   ```

   L'espace libre doit couvrir au moins 2,5 fois la taille estimée du prochain jeu.

### 2.2 Arrêt des écritures

1. Activer le mode maintenance :

   ```bash
   cd "$ROOT/current"
   "$PHP" artisan down --retry=60
   ```

2. Mettre les files en pause :

   ```bash
   cd "$ROOT/current"
   "$PHP" artisan queue:pause --all
   ```

3. Arrêter les workers supervisés. La commande dépend du superviseur réellement installé ; elle est fournie à titre d'exemple et doit être adaptée :

   ```bash
   supervisorctl status
   supervisorctl stop <programme-de-l-environnement>
   ```

4. Vérifier qu'aucun processus de file d'attente ne subsiste :

   ```bash
   pgrep -af 'queue:work|queue:listen|horizon' || echo 'aucun worker actif'
   ```

5. Neutraliser l'entrée cron `schedule:run` de l'environnement (commenter la ligne dans la crontab du compte technique), puis vérifier :

   ```bash
   crontab -l
   pgrep -af 'schedule:run' || echo 'aucune tâche planifiée active'
   ```

6. Vérifier qu'aucune migration n'est en cours et qu'aucune n'est planifiée :

   ```bash
   cd "$ROOT/current"
   "$PHP" artisan migrate:status
   ```

   `migrate:status` est une lecture. Aucune migration n'est exécutée par ce runbook.

### 2.3 Production du jeu complet

```bash
cd /chemin/vers/le/depot   # copie de travail des scripts, hors release si possible
bash scripts/ops/backup.sh set \
  --env "$ENV" \
  --trigger scheduled \
  --confirm-workers-stopped \
  --confirm-scheduler-disabled
```

Le script refuse de démarrer si le marqueur de maintenance est absent, si les confirmations manquent, si un outil est absent, si une table n'est pas InnoDB, si un lien symbolique est présent, si l'espace disque est insuffisant ou si une autre opération est en cours.

À la fin, le script affiche l'identifiant du jeu et le chemin du manifeste. **Noter ces deux valeurs dans le ticket d'exploitation.**

### 2.4 Contrôle du jeu

```bash
SET=<identifiant-du-jeu>
php scripts/ops/lib/manifest.php validate "$BACKUP_ROOT/sets/$SET/manifest.json"
bash scripts/ops/backup.sh verify --env "$ENV" --set "$SET"
```

Vérifier dans le manifeste :

- `scope: full` et `restorable_as_complete: true` ;
- `consistency.file_changes_detected: false` ;
- `consistency.workers_verified: true` et `consistency.scheduler_verified: true` ;
- `status: complete` ;
- la présence des deux artefacts et de leurs SHA-256.

Un jeu dont le déchiffrement n'a pas été testé est **valide mais non prouvé**. Ne jamais le présenter comme restaurable avec certitude.

### 2.5 Reprise du service

1. Rétablir l'entrée cron `schedule:run`.
2. Redémarrer les workers supervisés.
3. Reprendre les files :

   ```bash
   cd "$ROOT/current"
   "$PHP" artisan queue:resume --all
   ```

4. Désactiver le mode maintenance :

   ```bash
   cd "$ROOT/current"
   "$PHP" artisan up
   ```

5. Vérifier :

   ```bash
   curl -fsS https://<domaine-de-l-environnement>/up
   supervisorctl status
   crontab -l
   ```

6. Consigner dans le ticket : identifiant du jeu, manifeste, durée de la fenêtre, opérateur, incidents éventuels.

## 3. Vérification d'intégrité à la demande

```bash
bash scripts/ops/backup.sh verify --env "$ENV" --set "$SET"
```

Contrôles effectués : présence des artefacts, SHA-256 contre le manifeste et `SHA256SUMS`, validité du manifeste, cohérence du nommage et de l'environnement, cohérence de `scope`.

Une altération, même minime, invalide le jeu. Le jeu est conservé pour analyse, jamais « réparé ».

## 4. Restauration isolée

### 4.1 Préparation

1. Choisir un jeu **complet** (`scope: full`) et d'intégrité vérifiée.
2. Obtenir la clé privée `age` auprès d'un détenteur habilité. La déposer temporairement dans un répertoire personnel, en `0600` :

   ```bash
   install -m 0600 /dev/stdin "$HOME/.age-restore.key"
   chmod 0600 "$HOME/.age-restore.key"
   ```

3. Vérifier que la clé n'est pas dans un emplacement interdit :

   ```bash
   realpath "$HOME/.age-restore.key"
   ```

   Le chemin ne doit pas être sous `$ROOT`, `$ROOT/releases`, `$ROOT/public`, `$ROOT/shared` ni `$BACKUP_ROOT`.

4. Vérifier que la base cible n'existe pas :

   ```bash
   "$MYSQL" --defaults-extra-file="$HOME/.my-restore.cnf" -N -B \
     -e "SHOW DATABASES LIKE 'chantier_restore_%';"
   ```

5. Choisir un identifiant unique conforme :

   ```text
   chantier_restore_<AAAAMMJJ>_<hex8>
   ```

### 4.2 Restauration de la base

```bash
bash scripts/ops/restore.sh db \
  --env "$ENV" \
  --set "$SET" \
  --target-db "chantier_restore_20261113_a1b2c3d4" \
  --identity "$HOME/.age-restore.key"
```

Le script refuse une cible préexistante, une cible qui ne respecte pas le motif, une cible applicative, une clé mal protégée et un jeu incomplet.

### 4.3 Restauration des fichiers

```bash
bash scripts/ops/restore.sh files \
  --env "$ENV" \
  --set "$SET" \
  --target-dir "/var/tmp/c2me-restore/$SET" \
  --owner "c2me-deploy-production:c2me-production" \
  --identity "$HOME/.age-restore.key"
```

Le script refuse un répertoire préexistant, un chemin sous une racine applicative ou publique, et applique un remappage explicite vers le compte et le groupe fournis. Aucun mode `777` n'est appliqué.

### 4.4 Vérifications

```bash
# Tables et lignes : comparer au manifeste
"$MYSQL" --defaults-extra-file="$HOME/.my-restore.cnf" -N -B -e \
  "SELECT table_name, table_rows FROM information_schema.tables
   WHERE table_schema = 'chantier_restore_20261113_a1b2c3d4';"

# Inventaire des fichiers restaurés
cd "/var/tmp/c2me-restore/$SET"
sha256sum -c inventory.sha256

# Permissions finales : aucune écriture pour les autres
find "/var/tmp/c2me-restore/$SET" ! -type l -perm -0002 -print
```

Vérification applicative (localhost uniquement, aucun vhost public) :

1. préparer un fichier d'environnement de vérification **hors** des racines publiées, en `0600`, avec `APP_ENV=local`, `DB_DATABASE` pointant sur la base restaurée et un utilisateur MySQL limité à cette base ;
2. exécuter :

   ```bash
   "$PHP" artisan about
   "$PHP" artisan config:cache
   "$PHP" artisan route:list
   ```

3. servir l'application sur `127.0.0.1` avec un port non public, vérifier `/up` et la page de connexion ;
4. ne jamais exposer ce service sur Internet ;
5. supprimer le fichier d'environnement de vérification et les caches produits à la fin.

### 4.5 Rapport et clôture

```bash
bash scripts/ops/restore.sh report \
  --env "$ENV" \
  --set "$SET" \
  --work-dir "/var/tmp/c2me-restore/$SET"
```

Le rapport est horodaté, haché et chaîné dans `ledger/chain.jsonl`. Il n'est **pas signé** cryptographiquement : il est détecteur d'altération, pas authentifiant.

À consigner : durée de chaque étape, durée totale (RTO mesuré), écarts de cohérence, résultat de la vérification applicative, décision sur les données restaurées.

### 4.6 Nettoyage

1. Supprimer la zone de travail déchiffrée :

   ```bash
   rm -rf "/var/tmp/c2me-restore/$SET"
   ```

2. Retirer la clé privée temporaire :

   ```bash
   rm -f "$HOME/.age-restore.key"
   test -e "$HOME/.age-restore.key" && echo 'ANOMALIE : clé encore présente'
   ```

3. Supprimer la base de restauration uniquement après décision explicite et conservation des preuves ; ne jamais la supprimer pendant l'analyse.

## 5. Rétention

```bash
# Simulation obligatoire en premier
bash scripts/ops/backup.sh prune --env "$ENV" --dry-run

# Déplacement en quarantaine
bash scripts/ops/backup.sh prune --env "$ENV" --confirm

# Suppression réelle après 7 jours de quarantaine
bash scripts/ops/backup.sh prune --env "$ENV" --confirm --delete-expired
```

Ne sont jamais supprimés : le jeu le plus récent, un jeu référencé par un rapport de restauration, un jeu `pre-migration` non clos.

### 5.1 Verrou orphelin

Un arrêt brutal (`SIGKILL`, arrêt du serveur, coupure) peut laisser `<BACKUP_ROOT>/.lock`. Le verrou n'est jamais supprimé automatiquement.

1. Vérifier qu'aucune opération n'est en cours :

   ```bash
   pgrep -af 'backup.sh|restore.sh' || echo 'aucun processus backup/restore'
   ```

2. Vérifier l'hôte enregistré dans le verrou (il est déjà affiché par la commande précédente) :

   - hôte différent de l'hôte courant : **ne pas libérer localement**. Se connecter à l'hôte enregistré, y vérifier l'absence de processus, puis y retirer le verrou après confirmation. Si cet hôte n'existe plus, la décision revient à l'administrateur et doit être consignée.
   - champ `host` absent, vide ou égal à `unknown` : verrou non fiable, résolution manuelle obligatoire.
   - identité locale `unknown` ou vide : le script refuse toute libération ; corriger `C2ME_HOST_ID` avant de recommencer.

3. Vérifier l'état du PID :

   ```bash
   ps -p "$(cat "$BACKUP_ROOT/.lock/pid")" -o pid,etime,cmd
   ```

   Si le processus existe encore, **ne rien libérer** : attendre ou analyser.

4. Vérifier `incoming/` : un répertoire de travail résiduel est analysé puis supprimé manuellement, jamais promu dans `sets/`.

5. Libérer explicitement le verrou orphelin :

   ```bash
   bash scripts/ops/backup.sh unlock --env "$ENV" --confirm-stale-lock
   ```

   `restore.sh unlock --env "$ENV" --confirm-stale-lock` existe pour le même verrou.

6. Ne jamais supprimer `.lock` par un `rm -rf` improvisé : le script refuse un verrou dont le PID est vivant et conserve la trace.

## 6. Checklist d'exécution

### Sauvegarde

- [ ] Bon environnement, bon compte, bonne release.
- [ ] Aucune clé privée sur le serveur.
- [ ] Aucune table non InnoDB.
- [ ] Espace disque suffisant.
- [ ] Mode maintenance actif.
- [ ] Workers arrêtés et vérifiés.
- [ ] Cron neutralisé et vérifié.
- [ ] Aucune migration en cours ou planifiée.
- [ ] Jeu produit, manifeste valide, checksums vérifiés.
- [ ] Service rétabli et vérifié.
- [ ] Manifeste consigné dans le ticket.

### Restauration

- [ ] Jeu complet, valide, d'intégrité vérifiée.
- [ ] Clé privée fournie, protégée, hors emplacement interdit.
- [ ] Base cible unique, inexistante, non applicative.
- [ ] Répertoire cible neuf et hors racine applicative.
- [ ] Zone de travail en `0700`.
- [ ] Restauration base effectuée, tables et lignes contrôlées.
- [ ] Restauration fichiers effectuée, inventaire vérifié.
- [ ] Appartenance remappée, modes appliqués, aucun `777`.
- [ ] Cohérence base/fichiers contrôlée et écarts expliqués.
- [ ] Vérification applicative en localhost réussie.
- [ ] Rapport horodaté, haché et chaîné.
- [ ] Preuves copiées hors serveur.
- [ ] Zone de travail et clé temporaire supprimées.
- [ ] RTO mesuré consigné.

## 7. En cas d'échec

| Situation | Action |
| --- | --- |
| Sauvegarde interrompue par `INT` ou `TERM` | Code retour 130 ou 143 attendu ; vérifier que `incoming/` et `.lock` sont absents ; aucun jeu n'est promu |
| Arrêt brutal (`SIGKILL`, serveur) | Verrou et zone de travail possibles ; appliquer §5.1, ne jamais promouvoir le jeu incomplet |
| Sauvegarde interrompue | Ne pas promouvoir le jeu ; vérifier `incoming/`, relancer après diagnostic |
| Fichier modifié pendant l'opération | Invalider le jeu, vérifier l'arrêt réel des workers et du cron, recommencer |
| Checksum différent | Invalider le jeu, conserver les artefacts, analyser le support et le transfert |
| Restauration interrompue | Ne pas réutiliser la cible, analyser les journaux, recréer une cible neuve |
| Base cible préexistante | Refus attendu : choisir un nouvel identifiant, ne jamais réutiliser |
| Permissions non remappables | Arrêter ; ne jamais utiliser `777` comme solution |
| Clé privée dans un emplacement interdit | Arrêter, retirer la clé, ouvrir un incident de sécurité |
| Écart de cohérence base/fichiers | Consigner, ne rien supprimer, arbitrer avec le responsable technique |

Tout incident est consigné dans le ticket avec horodatage, opérateur, état constaté et décision. Une restauration partielle n'est jamais annoncée comme réussie.
