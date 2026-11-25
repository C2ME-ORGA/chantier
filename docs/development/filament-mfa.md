# Authentification multifacteur du panel administrateur

Le panel Filament `/admin` impose le MFA TOTP natif de Filament à tous les utilisateurs autorisés par la permission `identity.admin_panel.access`.

## Enrôlement

1. Se connecter au panel avec son identifiant et son mot de passe.
2. Lors de la première connexion, suivre l'étape de configuration MFA obligatoire.
3. Scanner le QR code avec une application TOTP compatible (Microsoft Authenticator, Google Authenticator, 1Password, etc.).
4. Valider le code généré par l'application.
5. Conserver les codes de récupération hors du poste de travail et de la boîte mail.

La page de profil Filament permet ensuite de gérer l'authentification par application et les codes de récupération.

## Connexion et récupération

Après le mot de passe, le panel exige un code TOTP. En cas de perte de l'application, un code de récupération peut être utilisé une seule fois. Les codes consommés ne doivent pas être réutilisés.

Il n'existe aucun repli par SMS ou e-mail. Une perte simultanée de l'application et des codes de récupération nécessite une procédure de récupération administrative vérifiant l'identité de l'utilisateur avant toute réinitialisation du MFA.

## Stockage et exploitation

- Le secret TOTP est chiffré avec le cast Eloquent `encrypted`.
- Les codes de récupération sont chiffrés avec `encrypted:array`.
- Les deux attributs sont masqués lors de la sérialisation du modèle.
- Les verrous atomiques Filament empêchent la consommation concurrente d'un même code de récupération. Le cache par défaut de l'application est `database`; en environnement multi-instance, toutes les instances doivent partager le même backend de cache/verrous (database ou Redis).
- Ne jamais basculer le cache de production sur le driver `array`, qui ne fournit pas de verrou partagé entre workers.

## Périmètre

Cette configuration protège l'authentification du panel Filament. Elle ne protège pas les authentifications Laravel effectuées ailleurs, ni les jetons Sanctum/API. Ces flux restent hors du périmètre CHAN-44.
