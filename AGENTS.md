# AGENTS.md — C2ME Chantier

## Objectif

Développer et maintenir l'application de gestion opérationnelle des chantiers de SARL C2ME. Toute modification doit préserver la cohérence métier, la sécurité des données, les frontières des domaines et la maintenabilité.

Ce fichier donne les règles générales applicables aux agents et contributeurs. Les documents spécialisés référencés ci-dessous restent les sources de vérité pour leur sujet ; ne pas recopier leurs procédures ici.

## Stack technique de référence

Les contraintes déclarées dans les manifestes du dépôt sont la référence :

- PHP : `^8.4.1`.
- Laravel : `^13.17`.
- Livewire : `^4.1`.
- Filament : `~5.0`.
- Base de données applicative : MySQL / MariaDB.
- Tests : Pest 5.
- Qualité PHP : Laravel Pint et Larastan.
- Frontend : Tailwind CSS 4 avec le plugin Vite dédié.
- Build frontend : Vite Plus (`vite-plus`) et Laravel Vite Plugin.

Avant d'utiliser une API, une commande ou une dépendance, vérifier les versions effectivement installées dans `composer.json`, `composer.lock`, `package.json` et `package-lock.json`. Ne pas supposer qu'une dépendance est disponible ni inventer une API.

Les versions de Node.js et npm ne sont pas fixées par un champ `engines` dans le manifeste : ne pas présenter une version précise comme une contrainte officielle du projet sans décision explicite.

## Architecture applicative

Le projet suit une architecture **Modular Monolith** organisée exclusivement sous `app/Core/` et `app/Domains/` pour le code structurant :

- `app/Core/` contient uniquement des composants techniques transverses, génériques et indépendants du métier.
- `app/Domains/{Domain}/` contient le code métier appartenant au domaine concerné.
- Aucun dossier racine concurrent `modules/` ne doit être créé ou utilisé comme emplacement de domaines.
- Le mapping PSR-4 `App\\` vers `app/` couvre déjà ces emplacements ; ne le dupliquer pas sans nécessité démontrée.

Les 18 domaines initiaux constituent un cadre de départ, pas une définition figée de tous leurs contenus. Leurs périmètres détaillés, objets, composants et interactions sont précisés progressivement au fil des cas d'usage réellement développés. Un domaine peut être précisé, étendu, scindé ou réorganisé si le besoin le justifie et si les règles de propriété et d'isolation sont préservées.

Ne pas créer de répertoires, classes, contrats, événements ou abstractions « pour plus tard ». Un domaine peut rester vide tant qu'aucun besoin concret ne nécessite d'implémentation.

### Dépendances entre domaines

- Chaque domaine est propriétaire de ses règles métier, invariants, états et données.
- Un consommateur utilise uniquement les capacités et contrats publics exposés par le domaine propriétaire.
- Ne pas accéder directement aux Models, Actions, Services, DTO, Policies ou tables internes d'un autre domaine.
- Ne pas contourner les invariants ou autorisations du domaine propriétaire par une écriture directe.
- Ne pas introduire de transaction inter-domaines implicite ni de dépendance circulaire.
- Le Core ne dépend d'aucun domaine métier ; les domaines peuvent utiliser les composants publics du Core.
- Les relations documentées comme admissibles dans l'architecture cible ne constituent pas une autorisation de créer immédiatement un contrat : confirmer le besoin lors de l'implémentation du cas d'usage.

Références : [CHAN-27 — conventions internes](https://sarlc2me.atlassian.net/browse/CHAN-27), [CHAN-28 — communication inter-domaines](https://sarlc2me.atlassian.net/browse/CHAN-28), [CHAN-29 — frontières et dépendances](https://sarlc2me.atlassian.net/browse/CHAN-29), [conventions internes des domaines](docs/architecture/domain-conventions.md), [communication inter-domaines](docs/architecture/domain-communication.md), [organisation de Core](app/Core/README.md) et [organisation des domaines](app/Domains/README.md).

## Conventions PHP et Laravel

- Respecter les conventions Laravel et le formatage contrôlé par Laravel Pint.
- Respecter PSR-4 : namespace cohérent avec le chemin et une classe par fichier.
- À l'intérieur d'un domaine, organiser les classes par responsabilité et uniquement lorsque le besoin existe.
- Une Action représente une opération métier identifiable ; un Service porte une logique réutilisable qui ne correspond pas à une opération unique.
- Les DTO ne sont créés que lorsqu'ils clarifient réellement le transport de données.
- Les événements locaux restent distincts des événements d'intégration inter-domaines.
- Les Policies portent les décisions d'autorisation ; les Actions sensibles vérifient explicitement l'autorisation et les invariants métier.
- La validation de format et de saisie relève de la couche d'entrée (Livewire, Filament, Form Request selon le cas) ; les invariants métier restent protégés dans le domaine.
- Éviter les abstractions, interfaces et couches supplémentaires sans besoin réel.

Consulter [docs/architecture/domain-conventions.md](docs/architecture/domain-conventions.md) pour les règles détaillées CHAN-27 et [docs/architecture/domain-communication.md](docs/architecture/domain-communication.md) pour les contrats et événements inter-domaines CHAN-28.

## Frontend et assets

- Tailwind CSS 4 est le socle CSS du projet.
- La configuration Tailwind actuelle est CSS-first dans `resources/css/app.css`, avec `@import 'tailwindcss'` et le plugin `@tailwindcss/vite`.
- Ne pas réintroduire Bootstrap 5 ni ajouter un second framework CSS ou JavaScript sans décision d'architecture explicite.
- La configuration Vite est dans `vite.config.js` et utilise Vite Plus ; les scripts du projet passent par `vp`.
- Les entrées frontend déclarées sont `resources/css/app.css` et `resources/js/app.js`.
- Préserver l'accessibilité, les états de chargement/erreur et la validation côté serveur.
- Éviter le JavaScript inline inutile ; privilégier les modules dédiés.

Commandes frontend définies dans `package.json` :

```bash
npm run dev
npm run build
```

Ne pas créer de `tailwind.config.js` par réflexe : il n'est pas requis par la configuration CSS-first actuellement présente.

### Organisation et conventions des tests

- Organiser les tests selon leur dépendance réelle : `tests/Unit` pour la logique isolée, `tests/Feature` pour l'intégration Laravel sur SQLite en mémoire et `tests/MariaDb` pour les comportements spécifiques au moteur MariaDB.
- Nommer les fichiers selon le sujet testé avec le suffixe `Test.php` ; éviter les noms génériques et les tests démonstratifs sans valeur de régression.
- Écrire des tests indépendants, déterministes, ciblés et exécutables seuls comme dans la suite complète.
- Nettoyer les ressources temporaires même en cas d'échec ; ne jamais dépendre de données réelles ou d'un service externe non maîtrisé.
- Ne pas confondre la validation SQLite avec la validation MariaDB. Toute modification touchant SQL, contraintes, migrations ou comportement moteur doit être couverte par la suite MariaDB appropriée.
- Le guide de référence des suites, conventions et commandes est [docs/development/testing.md](docs/development/testing.md).

## Sécurité et données

- Appliquer le principe du moindre privilège.
- Vérifier côté serveur les autorisations de toute opération sensible ; ne jamais faire confiance aux données du navigateur.
- Le serveur reste l'autorité pour les calculs, droits, invariants et transitions d'état.
- Protéger les fichiers privés par une autorisation explicite.
- Ne jamais versionner de secrets, tokens, mots de passe, clés privées, fichiers `.env`, exports ou données personnelles réelles.
- Ne jamais exposer de données sensibles dans les logs, réponses ou exceptions.
- Utiliser des transactions pour les opérations multi-écritures qui doivent réussir ou échouer ensemble.
- Les migrations doivent être compatibles avec une livraison progressive et réversibles lorsque cela est possible.
- Ne jamais exécuter une commande destructive sur une base qui n'est pas explicitement isolée.
- Toute synchronisation hors connexion doit être idempotente et traçable ; ne pas appliquer un mécanisme générique « last-write-wins » aux données financières ou aux validations métier.
- Le socle global de rôles et permissions est documenté dans [docs/development/authorization.md](docs/development/authorization.md) ; les autorisations par ressource relèvent des Policies.

## Tests, qualité et contrôles

Les outils et contrôles qualité sont suivis dans [CHAN-11 — qualité logicielle et CI](https://sarlc2me.atlassian.net/browse/CHAN-11). Le workflow actuellement associé est [tests.yml](.github/workflows/tests.yml).

Scripts Composer déclarés dans `composer.json` :

```bash
composer lint:check
composer types:check
composer test
php artisan test
```

Build frontend :

```bash
npm run build
```

- Ajouter ou adapter des tests Pest pour les comportements métier et les régressions.
- Couvrir les autorisations, validations, invariants, transitions, cas limites et échecs pertinents.
- Exécuter les contrôles adaptés à la modification ; ne pas déclarer un contrôle réussi s'il n'a pas été exécuté.
- Ne pas confondre un test SQLite avec une validation du comportement MariaDB : exécuter la suite moteur appropriée lorsque le changement touche les spécificités SQL ou les migrations.
- Les contrôles CI doivent rester exploitables et échouer explicitement en cas d'erreur.

Les procédures de branches, commits, Pull Requests, fusion, versionnement, releases, environnements et déploiements ne sont pas définies ici. Elles relèvent de [CHAN-92](https://sarlc2me.atlassian.net/browse/CHAN-92) et de leurs documents de référence :
- [workflow Git](docs/development/git-workflow.md) ;
- [processus de release](docs/development/release-process.md) ;
- [environnements](docs/development/environments.md) ;
- [processus de déploiement](docs/development/deployment-process.md).

Ne pas recopier ni redéfinir ces procédures dans ce fichier. Pour les questions de migrations et de rollback, consulter également les documents spécialisés correspondants dans `docs/development/`.

## Méthode de travail

1. Examiner le code, la configuration et la documentation existants avant toute modification.
2. Identifier le ticket Jira, son périmètre et ses critères d'acceptation.
3. Respecter les frontières métier et les décisions d'architecture déjà validées.
4. Privilégier la modification minimale qui répond au besoin réel.
5. Ajouter ou adapter les tests pertinents.
6. Exécuter les contrôles disponibles et rapporter exactement leurs résultats.
7. Signaler les hypothèses, limites et décisions qui restent à arbitrer.
8. Ne jamais affirmer qu'une tâche, un test, une revue ou une opération a été réalisé sans preuve.
