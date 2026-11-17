<!--
Modèle de Pull Request. Les règles de branches, de commits, de fusion et de protection
restent définies dans docs/development/git-workflow.md. La revue technique complète est
décrite dans docs/development/pull-request-review.md.
-->

## Ticket

Refs: CHAN-XXX

## Résumé et comportement attendu

<!-- Décrire le changement, le résultat attendu et les impacts éventuels. -->

## Contrôles réellement exécutés

<!-- Indiquer les commandes réellement lancées et leur résultat, sur le commit concerné. -->

- [ ] `composer lint:check`
- [ ] `composer types:check`
- [ ] `php artisan test`
- [ ] `composer ci:check --no-interaction` (si applicable)
- [ ] `npm ci`, `npm run build`, `php scripts/ci/verify-vite-build.php` (si frontend concerné)
- [ ] Suite MariaDB (`phpunit.mariadb.xml`) si SQL, migration, contrainte ou comportement moteur concerné
- [ ] CI GitHub Actions verte sur le commit de la Pull Request

Résultats et remarques :

## Points d'attention

<!-- Risques, limites connues, décisions à prendre, points non couverts. -->

## Revue technique

- [ ] La checklist de revue technique a été appliquée : [docs/development/pull-request-review.md](docs/development/pull-request-review.md)
- [ ] Les sections sans objet sont identifiées et justifiées.
- [ ] Aucun secret ni donnée sensible n'est présent dans le diff.
