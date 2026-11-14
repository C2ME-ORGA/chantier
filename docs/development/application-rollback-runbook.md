# Runbook — rollback applicatif

Procédure opérateur du **rollback applicatif manuel** de C2ME Chantier.

- Ticket : CHAN-98 – lot 3.
- Référence : [`application-rollback.md`](application-rollback.md). En cas de divergence, les règles de la stratégie prévalent.
- Ce runbook décrit des gestes. **Aucune commande n'a été exécutée sur un serveur** dans le cadre de ce lot.

> **Rappels absolus**
>
> - Le rollback ne restaure jamais la base de données.
> - Aucun rollback automatique : la décision et l'exécution sont humaines.
> - Ne jamais utiliser `migrate:rollback`, `migrate:fresh`, `db:wipe` ou une restauration de sauvegarde dans cette procédure.
> - Ne jamais modifier `.env`, `shared/storage`, les jobs, le cron, Supervisor ou PHP-FPM via ce mécanisme.
> - Ne jamais utiliser `--force` : il n'existe pas.
> - En cas de doute sur la compatibilité N/N-1, le rollback est **NO-GO**.

## 1. Conventions

```bash
ENV=production
ROOT=/www/wwwroot/chantier.c2me.fr          # staging : /www/wwwroot/chantier-staging.c2me.ovh
DB_NAME=chantier_production                 # staging : chantier_staging
PHP=/chemin/verifie/php8.4
export C2ME_ROOT="$ROOT"
export C2ME_HOST_ID="$(hostname -s)"        # obligatoire : stable, unique, non réservé
export C2ME_PHP_BIN="$PHP"
```

Le script doit être exécuté avec le compte technique de l'environnement (`c2me-deploy-production` ou `c2me-deploy-staging`), depuis une copie de travail maîtrisée des scripts, sans `sudo`.

`flock` (util-linux) doit être disponible : il sérialise les mutations du verrou partagé et son absence bloque le rollback.

## 2. Préflight

1. Identifier l'incident et la release cible :

   ```bash
   readlink -f "$ROOT/current"
   cat "$ROOT/current/release.json"
   ls -1 "$ROOT/releases"
   ```

2. Choisir une release **antérieure**, complète, déjà déployée et lisible. Noter son identifiant exact.

3. Vérifier qu'aucun déploiement n'est en cours :

   ```bash
   find "$ROOT/releases" -maxdepth 1 -name '.incoming-*' -print
   ```

   Toute sortie interdit le rollback.

4. Arrêter les workers supervisés et vérifier l'absence de processus :

   ```bash
   supervisorctl status
   supervisorctl stop <programme-de-l-environnement>
   pgrep -af 'queue:work|queue:listen|horizon'
   ```

5. Mettre les files en pause et traiter les jobs en attente selon leur compatibilité avec la release cible. Consigner la décision.

6. Vérifier le mode maintenance (le rollback ne l'active pas lui-même) :

   ```bash
   test -f "$ROOT/shared/storage/framework/down" && echo 'maintenance actif' || echo 'maintenance inactif'
   ```

## 3. Attestation de compatibilité N/N-1

1. Exécuter la lecture de l'état des migrations depuis `current` et conserver la sortie exacte :

   ```bash
   cd "$ROOT/current"
   "$PHP" artisan migrate:status --no-ansi > "/tmp/migrate-status-$ENV.raw"
   ```

   Cette commande est une **lecture**. Aucune migration n'est exécutée.

2. Construire la preuve conservée, avec son en-tête de périmètre :

   ```bash
   PROOF="/tmp/attestation-$ENV.json.migrate-status.txt"
   RELEASE="$(basename "$(readlink -f "$ROOT/current")")"
   {
     printf 'C2ME-MIGRATE-STATUS-PROOF\n'
     printf 'version: 1\n'
     printf 'environment: %s\n' "$ENV"
     printf 'release: %s\n' "$RELEASE"
     printf 'database: %s\n' "$DB_NAME"
     printf 'captured_at: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
     printf -- '---\n'
     cat "/tmp/migrate-status-$ENV.raw"
   } > "$PROOF"
   chmod 0600 "$PROOF"
   sha256sum "$PROOF"
   ```

   Le nom de la preuve est **obligatoirement** `<attestation>.migrate-status.txt` : le validateur le déduit du chemin de l'attestation. Le SHA-256 affiché est celui du fichier complet, en-tête compris.

3. Appliquer la grille de [`database-migrations.md`](database-migrations.md) :
   - aucune migration en cours, partielle ou non vérifiée ;
   - aucune migration en attente incompatible avec la cible ;
   - aucune migration destructive ni Contract appliqué depuis la cible ;
   - le code cible lit et écrit correctement sur le schéma courant ;
   - les jobs en file sont compatibles ou ont été traités.

4. Rédiger l'attestation JSON, hors du dépôt, avec l'empreinte de la preuve conservée :

   ```json
   {
     "schema_version": 1,
     "environment": "production",
     "source_release": "<release active>",
     "target_release": "<release cible>",
     "database": "chantier_production",
     "checked_at": "<UTC ISO 8601>",
     "checked_by": "<compte technique>",
     "migrate_status_sha256": "<sha256 de la preuve complète>",
     "migrations": {
       "in_progress": false,
       "pending": false,
       "partial": false,
       "destructive_applied": false,
       "contract_applied": false,
       "compatible_with_target": true
     }
   }
   ```

   La validité par défaut est de 24 h. Une valeur à `true` interdit le rollback.

   La preuve doit être conservée à côté de l'attestation sous le nom exact `<attestation>.migrate-status.txt` (par exemple `/tmp/attestation-production.json.migrate-status.txt`). Le validateur recalcule son SHA-256 ; une preuve absente, modifiée ou incohérente bloque le rollback.

## 4. Contrôle à blanc

```bash
cd /chemin/vers/la/copie/des/scripts
bash scripts/ops/rollback.sh \
  --env "$ENV" \
  --to "<release-cible>" \
  --reason "régression constatée sur <fonctionnalité>" \
  --schema-attestation "/tmp/attestation-$ENV.json" \
  --confirm-workers-stopped \
  --confirm-queues-paused \
  --confirm-jobs-triaged \
  --dry-run
```

Le mode `--dry-run` valide la cible, les liens, l'attestation, les confirmations et la concurrence sans modifier `current`. Il n'écrit **ni journal, ni verrou, ni fichier temporaire**.

## 5. Exécution

Retirer `--dry-run` et exécuter la même commande. Le script :

1. prend le verrou partagé `shared/.release-operation.lock`, utilisé aussi par le déploiement ;
2. revérifie l'absence de déploiement et l'état de `current` ;
3. écrit l'entrée `started` ;
4. bascule `current` de façon atomique ;
5. appelle `/up` ;
6. écrit l'entrée `completed` ou `failed`.

Sortie attendue en cas de succès :

```text
ROLLBACK=ok
OPERATION_ID=...
SOURCE=...
TARGET=...
CURRENT_AFTER=...
HEALTH=ok
```

## 6. Après le rollback

1. Vérifier la release active et les liens :

   ```bash
   readlink -f "$ROOT/current"
   cat "$ROOT/current/release.json"
   ls -l "$ROOT/current/.env" "$ROOT/current/storage" "$ROOT/current/public/storage"
   ```

2. Vérifier le health check et les journaux applicatifs :

   ```bash
   curl -fsS -H 'Accept: application/json' "https://<domaine>/up"
   tail -n 100 "$ROOT/shared/storage/logs/laravel.log"
   ```

3. Redémarrer les workers avec la release restaurée, puis reprendre les files, selon la procédure de l'environnement. Le script ne le fait pas.

4. Vérifier les lectures et écritures représentatives, les files et le planificateur.

5. Ne jamais exécuter `migrate:rollback` pour « aligner » la base.

6. Consigner dans le ticket : opération, source, cible, raison, attestation, résultat du health check, état des workers et des files, décision sur les jobs.

## 7. Échec du health check après bascule

La release cible reste active, le journal indique `failed`, et le script affiche le retour manuel possible vers la release source.

1. **Ne pas** relancer automatiquement.
2. Analyser : erreur de configuration, cache, droits, dépendance externe, TLS, PHP-FPM.
3. Si le retour à la source est décidé et que la source est toujours exploitable :
   - arrêter de nouveau les workers et mettre les files en pause ;
   - produire une **nouvelle attestation** dont la source est la cible actuelle et la cible est l'ancienne source ;
   - relancer le script avec cette nouvelle attestation et une raison explicite.
4. Si la source n'est plus compatible ou si les données sont en cause : correction en avant ou restauration de sauvegarde (lot 2), avec décision écrite.

## 8. Interruption

- `INT`/`TERM` : le script journalise `interrupted`, termine ses enfants, supprime le fichier temporaire de health check, libère le verrou et sort avec `130`/`143`.
- Vérifier `readlink -f "$ROOT/current"` : la bascule peut avoir eu lieu avant l'interruption.
- Le journal permet de savoir si l'opération était avant ou après la bascule.
- Un `SIGKILL` peut laisser le verrou `shared/.release-operation.lock` et une entrée `started` sans fin. Vérifier qu'aucun processus `rollback.sh` ou `remote-deploy.sh` n'est actif, contrôler l'hôte et le PID enregistrés, puis libérer explicitement :
  ```bash
  bash scripts/ops/rollback.sh unlock --env "$ENV" --confirm-stale-lock
  ```
  La commande refuse un verrou actif, un hôte différent, un hôte absent ou réservé, et un PID invalide. Analyser ensuite le journal avant de recommencer. Ne jamais supprimer le répertoire du verrou par un `rm -rf` improvisé.

## 9. Refus fréquents

| Message | Cause | Action |
| --- | --- | --- |
| `release ... introuvable ou symbolique` | Cible absente ou lien | Corriger la cible, ne pas forcer |
| `release ... incomplète` | `artisan`, `public/index.php`, config compilée ou `release.json` absent | Choisir une release complète |
| `lien current ...` | `current` absent, non symbolique ou hors `releases/` | Analyser avant toute action |
| `déjà active` | Cible identique à la source | Vérifier la cible |
| `attestation ... refusée` | Migration en cours/attente/partielle, Contract, incompatibilité, péremption, périmètre | Refaire l'analyse N/N-1 |
| `workers non confirmés` / `files non confirmées` / `jobs non confirmés` | Confirmations absentes | Arrêter, mettre en pause, trier, confirmer |
| `déploiement en cours` | `.incoming-*` présent | Attendre la fin du déploiement |
| `déjà en cours` | Verrou actif | Ne pas supprimer ; vérifier |
| `health check en échec` | Application indisponible après bascule | Analyse ; retour manuel avec nouvelle attestation |
