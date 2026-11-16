# CHAN-29 — Revue finale des critères d'acceptation après Lot G

- Ticket : CHAN-29 — Documenter les frontières et dépendances autorisées.
- Base : branche `develop`, après fusion de la PR #35.
- Date : 16/11/2026.
- Portée : revue documentaire des quatre critères Jira, à partir des livrables CHAN-27, CHAN-28 et CHAN-29.
- Nature : validation de l'architecture cible documentée ; aucune certification de conformité du code futur.

## 1. Conclusion exécutive

La revue du Lot F doit être actualisée à la lumière du Lot G et de la décision de conception progressive intégrée par la PR #35.

**Conclusion : les quatre critères d'acceptation de CHAN-29 sont démontrés au niveau documentaire de l'architecture cible.** Le deuxième critère ne doit plus être considéré comme bloquant au seul motif qu'aucune dépendance PHP n'est encore implémentée : CHAN-29 demande de documenter les frontières et les dépendances attendues, pas de certifier une implémentation qui n'existe pas encore.

Cette conclusion ne signifie pas que les dépendances réelles sont déjà vérifiées. Les domaines seront développés progressivement ; leurs périmètres détaillés, objets et interactions effectives seront confirmés au moment de la programmation. Les règles d'isolation et de communication restent obligatoires. La vérification automatique et la conformité du code relèvent notamment de CHAN-31 et des revues d'implémentation.

Le ticket peut donc être présenté pour validation de clôture sur son périmètre documentaire, sous réserve de la revue finale du responsable du projet. Aucun changement de statut Jira n'est effectué par ce rapport.

## 2. Revue des quatre critères Jira

| Critère d'acceptation | Éléments de preuve | Évaluation |
|---|---|---|
| Les responsabilités et frontières des domaines sont documentées et cohérentes entre les documents. | Catalogue des 18 domaines, processus, objets, décisions V-01 à V-59, registre des interactions et principe de périmètres progressifs intégré dans la PR #35. | **Démontré** |
| Les dépendances autorisées/interdites sont explicites et justifiées. | Lot G : 105 interactions admissibles sous contrat public (cible), 19 conditionnelles, 4 à décomposer et 2 hors périmètre inter-domaines. Les règles générales interdisent les accès aux composants internes/tables, les écritures hors propriété, les contournements métier et les transactions partagées implicites. | **Démontré au niveau de l'architecture cible** |
| Les règles d'accès inter-domaines sont cohérentes avec CHAN-28. | Contrats publics ou événements explicites, sens consommateur → fournisseur, propriété des données et invariants conservée par le fournisseur, identifiants publics stables, absence de Model Eloquent traversant une frontière, absence de transaction partagée implicite. | **Démontré au niveau documentaire** |
| Les exemples et schémas reflètent l'organisation réellement retenue. | Neuf scénarios et neuf diagrammes du Lot E ; règles de propriété et frontières cohérentes avec les décisions métier et CHAN-28 ; distinction explicite entre flux conceptuels et appels techniques. | **Démontré au niveau de l'organisation cible retenue** |

## 3. Interprétation du critère 2 — autorisations et interdictions

Le critère est satisfait par la combinaison de deux niveaux documentaires complémentaires :

1. **Relations cibles entre domaines :** le Lot G qualifie les 130 interactions et explicite leur admissibilité, leurs conditions, leur décomposition ou leur exclusion du périmètre inter-domaines.
2. **Règles générales d'interdiction :** la matrice et le Lot G interdisent les accès directs aux Models, Actions, Services, DTO internes, Policies et tables d'un autre domaine, les écritures à la place du propriétaire, le contournement des règles métier et les transactions partagées implicites.

Aucune interaction métier individuelle n'est artificiellement classée « Interdite » faute de contournement concret démontré. Cela ne réduit pas la portée des interdictions générales : elles s'appliqueront à toute implémentation, quelle que soit l'interaction fonctionnelle concernée.

La classe « Admissible sous contrat public (cible) » exprime une admissibilité d'architecture et non l'existence d'un contrat ou une autorisation d'implémentation immédiate. Les interactions conditionnelles restent soumises à la résolution de leur condition.

## 4. Décision de conception progressive

La cartographie des 18 domaines est un cadre initial de responsabilités, pas une spécification figée de tous leurs contenus fonctionnels et techniques.

Au fil de la programmation :
- les périmètres précis et les objets effectivement détenus seront confirmés ;
- les interactions seront retenues lorsqu'un cas d'usage réel les justifiera ;
- les contrats publics et événements seront conçus au moment opportun selon CHAN-28 ;
- un domaine pourra être précisé, étendu, scindé ou réorganisé si les besoins le justifient ;
- chaque évolution devra préserver la propriété métier, l'isolation des domaines et les règles de dépendance.

Cette décision est intégrée dans :
- `app/Domains/README.md` ;
- `docs/architecture/domain-dependency-qualification-lot-g.md` ;
- `docs/architecture/README.md`.

Référence : PR #35, fusionnée dans `develop`.

## 5. Limites et travaux qui restent hors du critère documentaire

L'arborescence examinée contient les 18 répertoires de domaines sans implémentation métier. Il n'est donc pas possible de certifier aujourd'hui les imports PHP, accès aux tables ou contrats effectivement utilisés.

Les limites suivantes sont explicites et ne constituent pas un défaut de la documentation cible :
- les dépendances réellement implémentées seront vérifiées au fil du développement ;
- les tests automatiques des frontières relèvent de CHAN-31 ;
- les questions Q-11, Q-24, Q-29, Q-31 et Q-44 restent conditionnelles pour les interactions concernées ;
- les interactions génériques à décomposer ne doivent pas être transformées en contrats universels ;
- les conventions internes restent définies par CHAN-27 et les échanges par CHAN-28.

Aucune garantie d'exécution, d'absence de cycle PHP ou de conformité future n'est revendiquée par ce rapport.

## 6. Références documentaires

- `docs/architecture/domain-responsibilities.md` — responsabilités et frontières métier.
- `docs/architecture/domain-boundary-decisions.md` — arbitrages et questions ouvertes.
- `docs/architecture/domain-dependency-matrix.md` — règles et matrice de dépendances.
- `docs/architecture/domain-dependency-examples-lot-e.md` — neuf scénarios et schémas.
- `docs/architecture/domain-dependency-qualification-lot-g.md` — qualification cible des 130 interactions.
- `docs/architecture/domain-communication.md` — communication inter-domaines CHAN-28.
- `app/Core/README.md` et `app/Domains/README.md` — organisation du Core et des domaines.
- PR #35 — décision de conception progressive : https://github.com/C2ME-ORGA/chantier/pull/35.

## 7. Conclusion et proposition

Sur le périmètre documentaire défini par CHAN-29, les quatre critères d'acceptation sont démontrés. Le critère 2 est satisfait au niveau de l'architecture cible grâce à la qualification des relations et aux interdictions générales explicites ; il ne requiert pas de fabriquer des preuves de code avant que les domaines soient développés.

**Proposition : présenter CHAN-29 pour validation de clôture**, sans modifier le statut Jira dans le cadre de ce rapport. Les contrôles de conformité du code réel continueront dans le cadre de CHAN-31 et des revues des futures implémentations.
