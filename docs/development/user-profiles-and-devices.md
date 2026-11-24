# Profils utilisateurs et appareils

Ce document décrit les données de profil et l'inventaire des appareils associés aux comptes utilisateurs dans C2ME Chantier.

- Ticket : [CHAN-41](https://sarlc2me.atlassian.net/browse/CHAN-41).
- Domaine : Identity.
- Migration : Expand, additive.
- Hors périmètre : authentification API (CHAN-39), autorisations par ressource (CHAN-42), journalisation des événements de sécurité (CHAN-45).

## Profil utilisateur

La table `user_profiles` porte les informations complémentaires au compte technique stocké dans `users`.

| Colonne | Règle |
| --- | --- |
| `id` | Clé primaire auto-incrémentée. |
| `user_id` | Clé étrangère unique vers `users.id` : un profil au maximum par utilisateur. |
| `first_name` | Prénom, nullable pour permettre un profil partiellement renseigné. |
| `last_name` | Nom, nullable pour permettre un profil partiellement renseigné. |
| `phone` | Téléphone, nullable. |
| `job_title` | Fonction, nullable. |
| `avatar_path` | Chemin de stockage de l'avatar, nullable ; le fichier n'est pas stocké dans la base. |
| `created_at`, `updated_at` | Horodatages Eloquent. |

La relation est exposée par `User::profile()` et inversement par `UserProfile::user()`.

## Appareils utilisateurs

La table `user_devices` recense les appareils associés à un utilisateur.

| Colonne | Règle |
| --- | --- |
| `id` | Clé primaire auto-incrémentée. |
| `user_id` | Clé étrangère vers `users.id`. Un utilisateur peut posséder plusieurs appareils. |
| `uuid` | UUID obligatoire et unique globalement. |
| `name` | Nom lisible de l'appareil, nullable. |
| `platform` | Plateforme (par exemple Windows, Android ou iOS), nullable. |
| `device_type` | Type d'appareil (ordinateur, mobile ou tablette), nullable. |
| `last_seen_at` | Dernière activité connue, nullable. |
| `trusted_at` | Date de confiance explicite, nullable. |
| `revoked_at` | Date de révocation logique, nullable. |
| `created_at`, `updated_at` | Horodatages Eloquent. |

Un index composite sur `user_id, revoked_at` facilite le filtrage des appareils actifs ou révoqués. La relation est exposée par `User::devices()` et inversement par `UserDevice::user()`.

## Cycle de vie et sécurité

- La suppression d'un utilisateur entraîne la suppression de ses profils et appareils par clé étrangère `ON DELETE CASCADE`.
- La révocation d'un appareil est représentée par `revoked_at` ; elle ne supprime pas la ligne et conserve l'état utile à la gestion des appareils.
- La confiance est représentée par `trusted_at` et reste distincte de la révocation.
- Un appareil n'est pas un token d'accès : les jetons Sanctum restent stockés dans `personal_access_tokens` et suivent leur propre cycle de vie.
- Les événements détaillés (création, changement de confiance, révocation, détection d'activité suspecte) relèvent du ticket CHAN-45.
- Les colonnes descriptives facultatives permettent d'enregistrer un appareil avant que toutes ses métadonnées soient connues. Les règles de validation d'entrée seront définies avec les cas d'usage consommateurs.

## Migrations et tests

Les migrations `2026_11_24_190000_create_user_profiles_table.php` et `2026_11_24_190001_create_user_devices_table.php` sont additives et annotées `@phase expand` / `@ticket CHAN-41`.

Les tests Feature couvrent les relations Eloquent, l'unicité du profil, l'unicité de l'UUID, le typage des dates et la suppression en cascade. La suite MariaDB vérifie le schéma et les contraintes sur le moteur cible.

Aucune migration n'est exécutée sur staging ou production par ce changement. Appliquer la procédure opérateur décrite dans [la stratégie de migrations](database-migrations.md).
