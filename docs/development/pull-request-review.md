# Revue technique des Pull Requests

Ce document définit la checklist de revue technique des Pull Requests de **C2ME Chantier**.

- Ticket : CHAN-37 — Documenter la checklist de revue technique des Pull Requests.
- Ticket parent : CHAN-11 — Qualité logicielle et CI.
- Portée : contrôles techniques de qualité, d'architecture, de sécurité, de tests, d'outillage et de documentation applicables à une Pull Request.
- Hors portée : branches, commits, approbations, protections GitHub, règles de fusion, releases, déploiements et environnements. Ces sujets relèvent de CHAN-92 et de ses documents spécialisés.

Cette checklist ne remplace pas les contrôles automatisés. Elle sert à vérifier ce qu'une analyse statique, une suite de tests ou un build ne peuvent pas démontrer seuls : pertinence fonctionnelle, respect des frontières, sécurité effective des opérations et maintenabilité du changement.

## Sources de vérité

| Sujet | Référence |
| --- | --- |
| Règles impératives du dépôt | [`AGENTS.md`](../../AGENTS.md) |
| Branches, commits, contenu des Pull Requests et protections | [`git-workflow.md`](git-workflow.md) |
| Organisation et commandes de test | [`testing.md`](testing.md) |
| Responsabilités internes des domaines | [`domain-conventions.md`](../architecture/domain-conventions.md) |
| Contrats et événements inter-domaines | [`domain-communication.md`](../architecture/domain-communication.md) |
| Tests d'architecture | [`architecture-tests.md`](../architecture/architecture-tests.md) |
| Périmètre du Core | [`app/Core/README.md`](../../app/Core/README.md) |
| Périmètre des domaines | [`app/Domains/README.md`](../../app/Domains/README.md) |
| Migrations et compatibilité N/N-1 | [`database-migrations.md`](database-migrations.md) |
| Releases, environnements et déploiements | [`release-process.md`](release-process.md), [`environments.md`](environments.md), [`deployment-process.md`](deployment-process.md) |

En cas de divergence, les documents listés ci-dessus et les protections GitHub effectivement configurées font foi. La présente checklist ne modifie aucune de leurs règles.

## Utilisation

### Auteur de la Pull Request

1. Relire son propre diff avant d'ouvrir la Pull Request.
2. Renseigner le ticket, le résumé, les contrôles réellement exécutés et les points d'attention.
3. Indiquer les sections de la checklist sans objet et la raison de cette absence d'objet.
4. Rattacher les résultats annoncés au commit concerné, en particulier pour la CI.

### Relecteur

1. Lire le ticket, ses critères d'acceptation et le résumé de la Pull Request.
2. Examiner le diff complet, y compris les fichiers de configuration, les migrations et les tests.
3. Vérifier les preuves fournies ; ne pas considérer une case cochée comme une preuve suffisante.
4. Formuler chaque remarque selon le format défini ci-dessous, avec un emplacement précis.
5. Limiter la revue au périmètre du changement et à ses impacts directs. Une amélioration hors périmètre reste possible, mais elle est classée en suggestion.

Une Pull Request documentaire n'a pas besoin d'exécuter les contrôles PHP, base de données ou frontend sans rapport avec le changement. Les sections concernées sont alors marquées sans objet, sans supprimer les contrôles applicables.

## Preuves attendues

Les résultats doivent être vérifiables et correspondre au commit de la Pull Request :

- commandes exécutées localement, avec leur résultat réel ;
- jobs GitHub Actions pertinents terminés avec succès sur le commit de la Pull Request ;
- tests ajoutés ou modifiés clairement identifiables dans le diff ;
- captures, journaux ou liens uniquement lorsqu'ils apportent une preuve utile et ne contiennent aucune donnée sensible.

Un résultat local antérieur au dernier commit ne constitue pas une preuve pour ce commit. La CI reste la validation de référence pour les deux moteurs de base de données et pour le build frontend, conformément à [`testing.md`](testing.md). Les commandes exactes, leurs prérequis et le périmètre de chaque suite sont définis dans ce document ; la checklist se limite à vérifier qu'elles ont été exécutées et que leurs résultats sont cohérents avec le changement.

## Classification des remarques

| Niveau | Définition | Exemples | Traitement attendu |
| --- | --- | --- | --- |
| **Bloquant** | Défaut critique de sécurité, d'intégrité ou de fonctionnement qui rend le changement dangereux ou inutilisable. | Contournement d'autorisation, perte ou corruption de données, secret exposé, régression majeure, migration destructive non maîtrisée, contrôle qualité requis en échec. | Correction indispensable avant de considérer la revue technique comme traitée. |
| **Majeur** | Défaut important qui produit un comportement incorrect, fragile ou non conforme aux règles du projet. | Cas limite non géré, règle métier au mauvais endroit, frontière inter-domaines franchie, validation serveur absente, test critique manquant, compatibilité de migration incomplète. | Correction attendue avant la fusion ; une dérogation exige une justification explicite et traçable. |
| **Mineur** | Amélioration recommandée qui ne remet pas en cause le comportement principal. | Nom peu explicite, duplication localisée, test secondaire manquant, documentation incomplète, message d'erreur perfectible. | Correction recommandée ; peut être reportée avec un suivi explicite. |
| **Suggestion** | Proposition facultative, alternative de conception ou préférence personnelle. | Optimisation non nécessaire, factorisation possible, variante de nommage, amélioration future. | Aucune correction exigée ; l'auteur peut décliner en expliquant son choix. |

La classification oriente la priorité de correction. Elle ne définit ni les approbations requises, ni les conditions de fusion, qui restent régies par [`git-workflow.md`](git-workflow.md) et les protections GitHub.

### Format d'une remarque

Chaque remarque doit contenir au minimum :

```text
[Niveau] — chemin/fichier:ligne

Problème : ce qui est incorrect, incomplet ou risqué.
Impact : conséquence concrète sur le comportement, la sécurité, les données ou la maintenance.
Correction suggérée : action attendue, suffisamment précise pour être vérifiable.
```

Une preuve ou une référence peut être ajoutée lorsque le constat n'est pas évident :

```text
Preuve : commande, test, extrait de configuration ou lien vers la règle concernée.
```

## Checklist de revue

Les cases servent de support à la revue ; elles ne remplacent ni les tests ni l'analyse du diff. Une case non applicable doit être explicitement indiquée comme telle dans la Pull Request.

### 1. Périmètre fonctionnel et conception

- [ ] La Pull Request référence le ticket Jira et reprend ses critères d'acceptation.
- [ ] Le comportement attendu est décrit de façon vérifiable dans le résumé de la Pull Request.
- [ ] Le diff se limite au périmètre du ticket ; tout changement fonctionnel non lié est absent ou justifié.
- [ ] Les cas limites pertinents sont identifiés : absence de données, valeurs nulles, limites de taille, doublons, concurrence ou échec partiel selon le besoin.
- [ ] Les impacts sur les comportements existants sont décrits, y compris les ruptures de compatibilité éventuelles.
- [ ] Aucun code mort, code commenté, contournement temporaire ou fonctionnalité partielle non annoncée ne subsiste.
- [ ] Aucune abstraction, interface ou couche n'est ajoutée sans au moins un usage réel dans le changement ou une justification écrite dans la Pull Request.

### 2. Architecture modulaire et séparation des responsabilités

- [ ] Les classes ajoutées sont placées dans `app/Core/` ou `app/Domains/{Domaine}/` selon leur responsabilité, conformément à [`AGENTS.md`](../../AGENTS.md) et aux READMEs Core/Domains.
- [ ] Aucun composant métier n'est placé dans `app/Core/` ; le Core ne dépend d'aucun domaine.
- [ ] Un consommateur inter-domaines n'importe que les surfaces publiques `Contracts/` ou `Events/Integration/` ; aucun Model, Action, Service, DTO interne, Policy ou événement local d'un autre domaine n'est importé.
- [ ] Aucun accès direct aux tables d'un autre domaine n'est introduit par SQL, `DB::table()` ou une relation Eloquent traversant la frontière.
- [ ] Aucune transaction inter-domaines implicite n'est ajoutée ; une atomicité inter-domaines éventuelle est explicitement décidée et documentée.
- [ ] Les responsabilités Action, Service, Model, DTO, Event et Policy respectent [`domain-conventions.md`](../architecture/domain-conventions.md), sans God Model, God Service ni règle métier critique dans Livewire, Filament ou un contrôleur.
- [ ] Aucun dossier, contrat, événement, DTO, service ou provider n'est créé sans usage réel ; aucun dossier vide ni classe « pour plus tard » n'est ajouté.
- [ ] Les namespaces PSR-4 correspondent exactement aux chemins et une classe reste par fichier.
- [ ] Aucune nouvelle dépendance circulaire, résolution dynamique non maîtrisée ou abstraction prématurée n'est introduite.
- [ ] Les tests d'architecture de `tests/Architecture/` passent lorsque les frontières ou les namespaces sont concernés.

### 3. Qualité Laravel et PHP

- [ ] Le code ajouté respecte le style Laravel contrôlé par Pint ; aucun fichier modifié n'est exclu du périmètre sans justification.
- [ ] Les types ajoutés sont compatibles avec Larastan au niveau configuré dans `phpstan.neon` ; aucune nouvelle exclusion, baseline ou ignorance non justifiée n'est introduite.
- [ ] Les signatures, propriétés et retours ajoutés sont typés ; aucun `mixed` ou tableau non typé ne traverse un contrat public.
- [ ] Les conventions Laravel sont respectées : injection de dépendances, validation d'entrée dans la couche d'entrée, invariants métier dans le domaine, absence de logique applicative dans les fichiers de configuration.
- [ ] Les transactions sont gérées au niveau approprié, par défaut dans l'Action, et les événements métier sont publiés après commit lorsque nécessaire.
- [ ] Les relations Eloquent nécessaires sont préchargées lorsqu'un risque de N+1 est visible dans le changement.
- [ ] Le code ne contient ni `dd()`, ni `dump()`, ni `var_dump()`, ni instruction de débogage, ni code commenté sans justification.
- [ ] Aucune dépendance n'est ajoutée sans besoin démontré, sans mise à jour cohérente de `composer.lock` ou `package-lock.json`, et sans vérification de sa provenance.
- [ ] Les noms de classes, méthodes, tables, variables et fichiers respectent les conventions du projet et le vocabulaire métier existant.
- [ ] Les valeurs de configuration passent par `config()` et les variables d'environnement ; aucun secret ni paramètre d'environnement n'est codé en dur.

### 4. Sécurité et autorisations

- [ ] Toute opération sensible vérifie l'autorisation côté serveur avec une Policy ou un Gate avant d'écrire ; le masquage d'un bouton ou d'un lien n'est jamais considéré comme une protection.
- [ ] Une Action sensible vérifie explicitement l'autorisation avec l'acteur concerné, y compris lorsqu'elle est appelée depuis un job, une commande ou un test.
- [ ] Le diff ne contient aucun secret, token, mot de passe, clé privée, fichier `.env`, export ou donnée personnelle réelle.
- [ ] Les logs, exceptions, messages d'erreur et réponses n'exposent ni données sensibles, ni SQL, ni trace interne, ni identifiant de sécurité.
- [ ] Les données venant du navigateur ou d'un mécanisme hors connexion sont traitées comme non fiables et validées côté serveur.
- [ ] Les affectations massives sont limitées (`$fillable`, `$guarded` ou équivalent) et les champs sensibles ne sont pas modifiables librement.
- [ ] Les requêtes SQL utilisent des paramètres liés ; aucune donnée utilisateur n'est concaténée dans une requête.
- [ ] Les sorties HTML échappent les données non fiables ; aucun contenu utilisateur n'est injecté comme HTML sûr sans justification.
- [ ] Les fichiers privés ou téléversés sont protégés par une autorisation explicite, et leur type, taille et emplacement sont contrôlés.
- [ ] Les routes d'écriture conservent les protections standard de Laravel, notamment la protection CSRF lorsqu'elle s'applique.

### 5. Validation des données et gestion des erreurs

- [ ] Toute entrée utilisateur est validée côté serveur dans la couche d'entrée appropriée : Form Request, composant Livewire, ressource ou action Filament.
- [ ] Les règles métier critiques et les invariants sont appliqués dans le domaine, même si l'Action est appelée directement sans passer par le formulaire.
- [ ] Les cas d'erreur attendus ont un comportement défini et testé : validation invalide, refus d'autorisation, ressource absente, conflit d'état et échec technique.
- [ ] Les erreurs présentées à l'utilisateur sont compréhensibles, accessibles et ne révèlent aucune information sensible.
- [ ] Les exceptions ne sont pas interceptées silencieusement ; aucun `catch (Throwable)` ne masque une erreur sans traitement explicite.
- [ ] Une opération comportant plusieurs écritures est transactionnelle et laisse un état cohérent en cas d'échec.
- [ ] Une synchronisation hors connexion, si elle est introduite, est idempotente et traçable ; aucun mécanisme générique de « last-write-wins » n'est appliqué aux données financières ou aux validations métier.
- [ ] Les valeurs absentes, inconnues et non applicables sont distinguées ; un `null` ne porte pas plusieurs significations.

### 6. Tests unitaires et fonctionnels

- [ ] Des tests sont ajoutés ou adaptés pour le comportement modifié, la régression corrigée ou la règle introduite.
- [ ] Le cas nominal, les cas limites, les erreurs attendues et les refus d'autorisation pertinents sont couverts.
- [ ] Pour une correction de bug, un test de régression échoue sans le correctif lorsque cela est réalisable.
- [ ] Les tests vérifient un comportement observable et une raison d'échouer ; ils ne se limitent pas à reproduire l'implémentation.
- [ ] Les tests sont indépendants, déterministes et exécutables seuls comme dans la suite complète.
- [ ] Les tests ne dépendent ni d'un service externe non maîtrisé, ni d'une donnée réelle, ni d'un ordre d'exécution.
- [ ] L'emplacement et le nommage respectent [`testing.md`](testing.md) : `tests/Unit`, `tests/Feature`, `tests/MariaDb` ou `tests/Architecture` selon la dépendance réelle.
- [ ] Aucun test existant n'est supprimé, ignoré ou affaibli pour masquer une régression ; tout test ignoré est justifié et traçable.
- [ ] Les tests d'architecture sont adaptés et exécutés lorsque les frontières ou les namespaces sont modifiés.

### 7. Tests SQLite et MariaDB selon les dépendances

- [ ] Toute modification du SQL, des migrations, des contraintes, des index, des types, des collations ou des transactions est couverte par la suite MariaDB appropriée.
- [ ] La suite SQLite reste verte pour les changements applicatifs concernés.
- [ ] La migration est compatible avec une livraison progressive et ne casse pas la compatibilité N/N-1 définie dans [`database-migrations.md`](database-migrations.md).
- [ ] La migration est réversible lorsque cela est possible ; sinon, la stratégie de rollback ou de réparation est documentée.
- [ ] Les contraintes et comportements dont la sémantique diffère entre SQLite et MariaDB sont testés sur MariaDB.
- [ ] Aucune commande destructive n'est exécutée sur une base non explicitement isolée ; les tests utilisent la base de test dédiée et des identifiants jetables.
- [ ] Le job `sqlite` est vert sur le commit de la Pull Request, et le job `mariadb-10.11` l'est lorsque le changement touche le moteur.
- [ ] Aucune donnée réelle, aucun secret et aucun identifiant d'environnement ne figure dans les tests ou les fixtures.

### 8. Résultats Pint, Pest et Larastan

- [ ] `composer lint:check` a été exécuté et a réussi.
- [ ] `composer types:check` a été exécuté et a réussi.
- [ ] `php artisan test` a été exécuté et a réussi.
- [ ] `composer ci:check --no-interaction` a été exécuté lorsque la Pull Request touche le socle PHP ou la CI, ou le job `ci` correspondant est vert sur le commit.
- [ ] Les résultats annoncés correspondent au commit de la Pull Request, et non à un état local antérieur.
- [ ] Aucun `|| true`, `continue-on-error`, baseline, exclusion ou test ignoré ne masque un échec.
- [ ] Tout échec préexistant est identifié, justifié et ne masque pas une régression introduite par la Pull Request.

### 9. Build Vite et assets frontend si concernés

- [ ] Si `resources/css/`, `resources/js/`, `vite.config.js`, `package.json` ou `package-lock.json` changent, `npm ci`, `npm run build` et `php scripts/ci/verify-vite-build.php` ont été exécutés avec succès.
- [ ] Le manifest Vite et tous les assets qu'il référence existent après le build.
- [ ] Aucun fichier généré dans `public/build/` n'est commité.
- [ ] Tailwind CSS 4 reste la base CSS-first ; aucun Bootstrap, second framework CSS ou `tailwind.config.js` n'est introduit sans décision d'architecture explicite.
- [ ] Les changements d'interface préservent les états de chargement, les états d'erreur et l'accessibilité.
- [ ] Le JavaScript inline inutile est évité et les modules dédiés sont privilégiés.
- [ ] Le rendu des parcours concernés est vérifié aux tailles d'écran pertinentes lorsque l'interface change.
- [ ] Le job `ci` est vert après le build ; les tests d'assets Vite ne sont pas ignorés à tort.

### 10. Documentation et maintenabilité

- [ ] La documentation impactée est mise à jour : `README.md`, `docs/development/`, `docs/architecture/` ou `AGENTS.md` selon la nature du changement.
- [ ] Les nouvelles commandes, variables d'environnement, migrations ou décisions sont documentées sans recopier les procédures de CHAN-92.
- [ ] Les commentaires expliquent le pourquoi et restent exacts ; aucun commentaire obsolète ou trompeur ne subsiste.
- [ ] Aucun `TODO` ou `FIXME` n'est ajouté sans ticket ou justification explicite.
- [ ] Aucune duplication de logique métier n'est introduite ; toute abstraction ajoutée est utilisée par au moins deux appelants réels ou justifiée dans la Pull Request.
- [ ] Les liens Markdown ajoutés sont valides et pointent vers la source de vérité appropriée.
- [ ] La Pull Request décrit les limites connues, les risques résiduels et les points non couverts.
- [ ] La documentation ne promet pas un comportement qui n'est pas réellement implémenté.

## Sortie de revue technique

La revue technique est considérée comme traitée lorsque :

- toutes les remarques bloquantes et majeures ont été corrigées ou font l'objet d'une dérogation explicite et traçable ;
- les remarques mineures et suggestions ont été acceptées, corrigées ou explicitement déclinées ;
- les contrôles applicables ont été exécutés sur le commit concerné et leurs résultats sont reportés ;
- les sections sans objet sont identifiées comme telles ;
- la documentation et les références impactées sont à jour.

Cette sortie de revue ne constitue ni une approbation formelle ni une autorisation de fusion. Les règles de fusion, d'approbation et de protection des branches restent définies par [`git-workflow.md`](git-workflow.md) et les protections GitHub.

## Références

- [`AGENTS.md`](../../AGENTS.md) — règles générales du dépôt.
- [`README.md`](../../README.md) — présentation, installation et commandes.
- [`git-workflow.md`](git-workflow.md) — branches, commits, Pull Requests et protections.
- [`testing.md`](testing.md) — suites de tests, commandes, CI et Larastan.
- [`database-migrations.md`](database-migrations.md) — migrations, compatibilité et rollback.
- [`domain-conventions.md`](../architecture/domain-conventions.md) — conventions internes des domaines.
- [`domain-communication.md`](../architecture/domain-communication.md) — contrats et événements inter-domaines.
- [`architecture-tests.md`](../architecture/architecture-tests.md) — tests d'architecture.
- [`app/Core/README.md`](../../app/Core/README.md) — périmètre du Core.
- [`app/Domains/README.md`](../../app/Domains/README.md) — périmètre des domaines.
- [`.github/PULL_REQUEST_TEMPLATE.md`](../../.github/PULL_REQUEST_TEMPLATE.md) — modèle compact de Pull Request.
