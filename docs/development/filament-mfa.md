# Authentification multifacteur du panel administrateur

Le panel Filament `/admin` impose le MFA TOTP natif de Filament à tous les utilisateurs autorisés par la permission `identity.admin_panel.access`.

## Enrôlement

1. Se connecter au panel avec son identifiant et son mot de passe.
2. Lors de la première connexion, suivre l'étape de configuration MFA obligatoire.
3. Scanner le QR code avec une application TOTP compatible (Microsoft Authenticator, Google Authenticator, 1Password, etc.).
4. Valider le code généré par l'application.
5. Conserver les codes de récupération hors du poste de travail et de la boîte mail.

La page de profil Filament permet ensuite de gérer l'authentification par application et les codes de récupération.

## Connexion et protections

Après validation du mot de passe, le panel exige un code TOTP. Le challenge applique une limite de cinq tentatives par utilisateur avant throttling. Le compteur MFA est distinct de la limitation des tentatives de mot de passe et est associé à l'identifiant utilisateur scoped par Filament. Le mécanisme natif de Filament mémorise l'horodatage du dernier code TOTP accepté et rejette ce code ainsi que les périodes antérieures : un code déjà accepté ne peut donc pas être rejoué.

En cas de perte de l'application, un code de récupération peut être utilisé une seule fois. Les codes consommés ne doivent pas être réutilisés. Leur consommation est protégée par un verrou de cache et une transaction avec verrouillage de la ligne utilisateur (`lockForUpdate`).

Il n'existe aucun repli par SMS ou e-mail.

## Procédure de récupération administrative

Cette procédure s'applique uniquement si l'utilisateur a perdu l'accès à son application TOTP et à tous ses codes de récupération.

1. Recevoir une demande via un canal professionnel déjà connu de l'entreprise. Ne pas utiliser une nouvelle adresse ou un numéro fourni uniquement dans la demande.
2. Vérifier l'identité de la personne par un moyen indépendant (appel au numéro déjà enregistré ou vérification en présence).
3. Faire approuver l'intervention par un second administrateur habilité, distinct du demandeur.
4. Consigner dans le journal d'intervention : identité vérifiée, compte concerné, motif, date/heure, opérateurs et approbateur. Ne jamais consigner le secret TOTP ni les codes de récupération.
5. Depuis un accès serveur sécurisé, réinitialiser uniquement les attributs MFA du compte concerné (`app_authentication_secret` et `app_authentication_recovery_codes`) après sauvegarde/validation de la cible. Ne jamais modifier son mot de passe dans le cadre de cette seule opération.
6. Invalider les sessions actives du compte selon la procédure d'exploitation de l'application.
7. Demander à l'utilisateur de se reconnecter avec son mot de passe et de terminer immédiatement le nouvel enrôlement MFA obligatoire.
8. Vérifier avec l'utilisateur que le nouvel enrôlement fonctionne et qu'il a stocké ses nouveaux codes de récupération de façon sûre.

La réinitialisation doit être effectuée par un opérateur autorisé disposant d'un accès serveur contrôlé. Ne jamais demander à l'utilisateur de transmettre son code TOTP, son QR code, son secret ou ses codes de récupération.

## Stockage et exploitation

- Le secret TOTP est chiffré avec le cast Eloquent `encrypted`.
- Les codes de récupération sont chiffrés avec `encrypted:array`. Filament stocke chaque code sous forme de hash avant ce chiffrement.
- Les deux attributs sont masqués lors de la sérialisation du modèle.
- Le cache par défaut de l'application est `database` (`CACHE_STORE=database`). Ce backend fournit les verrous utilisés par Filament. En environnement multi-instance, toutes les instances doivent partager le même backend de cache et de verrous (base de cache partagée ou Redis).
- Ne pas utiliser les drivers `array` ou `null` en production : ils ne fournissent pas de verrou partagé entre workers.
- Vérifier que les tables de cache et de verrous nécessaires sont migrées avant déploiement. Toute modification du backend de cache doit être validée en environnement multi-instance avant production.

## Périmètre

Cette configuration protège l'authentification du panel Filament. Elle ne protège pas les authentifications Laravel effectuées ailleurs, ni les jetons Sanctum/API. Ces flux restent hors du périmètre CHAN-44.
