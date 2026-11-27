# Rétention du journal de sécurité Identity

## Durées de conservation

- Les événements de sécurité sont conservés pendant 12 mois à compter de `occurred_at`.
- Les événements liés à un incident ou à une investigation peuvent être préservés sans limite automatique de durée.
- Les appareils révoqués sont conservés pendant 12 mois à compter de `revoked_at`.
- Les appareils actifs ou non révoqués ne sont jamais concernés par la purge des appareils.

## Préserver un événement

La préservation doit être motivée et effectuée depuis le domaine Identity :

```php
app(\App\Domains\Identity\Actions\PreserveSecurityEvent::class)
    ->handle($event, 'Investigation INC-2026-0042');
```

Le motif est obligatoire (1 à 500 caractères). Une préservation existante est définitive et idempotente : une seconde demande ne remplace ni la date ni le motif initial. Les champs métier de l'événement restent immuables.

## Exécuter la purge

La commande est volontairement en simulation par défaut :

```bash
php artisan identity:purge-security-events
```

Pour exécuter effectivement la purge :

```bash
php artisan identity:purge-security-events --execute
```

Le traitement s'effectue par lots de 500 lignes. La taille peut être adaptée :

```bash
php artisan identity:purge-security-events --execute --chunk=1000
```

La taille doit être comprise entre 1 et 10000. La commande affiche le nombre d'événements et d'appareils éligibles en simulation, puis les nombres réellement supprimés en exécution. Elle est idempotente : les lignes supprimées ne sont plus sélectionnées lors d'un passage ultérieur.

## Relations et intégrité

Les événements préservés sont exclus de la purge même si leur date dépasse 12 mois. La purge des appareils révoqués utilise la clé étrangère `user_security_events.user_device_id` configurée en `nullOnDelete` : un événement encore dans sa période de conservation reste disponible, avec son utilisateur et ses métadonnées, mais sans relation vers la fiche appareil supprimée.

La suppression des événements est une opération de maintenance explicite qui contourne les garde-fous Eloquent append-only. Les interfaces ordinaires et les actions métier ne peuvent ni modifier ni supprimer le journal.

## Exploitation

- Exécuter d'abord la simulation et examiner les volumes annoncés.
- N'ajouter `--execute` qu'après validation de la simulation.
- Conserver la sortie de commande dans le journal d'exploitation prévu par l'environnement.
- Ne pas planifier automatiquement la commande tant que la fréquence et la procédure d'approbation de purge n'ont pas été validées.
