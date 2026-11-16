# Lot F — Revue finale et préparation de clôture

- Ticket : CHAN-29 — Documenter les frontières et dépendances autorisées.
- Date de revue : 16/11/2026.
- Base examinée : branche `develop`, après fusion de la PR #32 (Lot E).
- Portée : revue documentaire et vérification des preuves disponibles ; aucune implémentation métier.

## 1. Conclusion exécutive

Les livrables des Lots 1 à E sont présents et les PR #27 à #32 sont fusionnées dans `develop`. Les contrôles CI associés aux commits de tête des PR #27 à #32 sont terminés avec succès (3 jobs sur 3 à chaque fois).

La documentation décrit de façon cohérente les responsabilités métier, les règles de communication inter-domaines, les relations candidates, les cycles documentaires et les scénarios représentatifs. Les 18 domaines et le Core disposent de documents de périmètre dédiés.

**CHAN-29 n'est toutefois pas démontré intégralement clôturable à cette date.** Le critère d'acceptation relatif aux dépendances autorisées/interdites n'est que partiellement démontré : les règles générales d'interdiction sont explicites, mais aucune dépendance technique individuelle n'est autorisée, conditionnelle ou classée interdite. Les 130 interactions restent « À qualifier » faute de contrats, événements ou usages implémentés à examiner. Cette prudence est cohérente avec CHAN-28 et avec l'état réel des domaines ; elle ne doit pas être remplacée par une classification déduite de la seule documentation métier.

Le rapport est donc une revue finale et un état des preuves, pas une validation artificielle de tous les critères. Le ticket Jira reste « En cours » et aucun changement Jira n'est effectué par ce lot.

## 2. Revue croisée des références

### CHAN-27 — Conventions internes

- `docs/architecture/domain-conventions.md` distingue les responsabilités des Models, Actions, Services, DTO, événements locaux et Policies.
- Le document réserve explicitement les contrats inter-domaines à CHAN-28 et les frontières de dépendance à CHAN-29.
- Il indique que les exemples sont illustratifs et que `app/Domains/` ne contient pas encore de classes métier.
- La responsabilité technique transverse de `app/Core` est renvoyée à `app/Core/README.md`.

**Résultat : cohérent.** Les Lots C à E ne créent pas de conventions concurrentes et ne déplacent pas les règles internes définies par CHAN-27.

### CHAN-28 — Communication inter-domaines

- `docs/architecture/domain-communication.md` est la référence des contrats synchrones, événements d'intégration, transactions, publication après commit, idempotence, erreurs et évolution.
- CHAN-29 renvoie à CHAN-28 pour le mécanisme d'échange et ne redéfinit pas les contrats, DTO, événements ou politiques de fiabilité.
- CHAN-28 précise que ses exemples sont pédagogiques et qu'aucun contrat, événement, listener, job, worker, Outbox ou provider de domaine n'est implémenté à ce stade.

**Résultat : cohérent.** Les modes mentionnés dans les matrices et scénarios restent des orientations à confirmer, pas des preuves d'implémentation.

### CHAN-31 — Tests d'architecture

- Le ticket CHAN-31 est distinct et son statut Jira est « À faire ».
- Ses travaux portent sur les règles vérifiables automatiquement, les dépendances interdites, le respect des contrats et l'indépendance du Core.
- Les tests d'architecture ne sont pas ajoutés au périmètre de CHAN-29.

**Résultat : séparation respectée, contrôle automatisé non encore livré.** La checklist du Lot E est documentaire et ne remplace pas les tests CHAN-31.

### Organisation `app/Core` et `app/Domains`

- `app/Core/README.md` réserve le Core aux composants techniques transverses, indépendants des domaines métier ; il interdit d'y déplacer des règles métier.
- `app/Domains/README.md` définit les 18 domaines initiaux, leurs namespaces et leur structuration progressive.
- Les conventions CHAN-27 et le catalogue des domaines s'alignent sur ces emplacements.

**Résultat : cohérent au niveau des documents de référence.** L'audit du Lot D constate que les 18 répertoires de domaines ne contiennent que des fichiers `.gitkeep` ; aucune implémentation inter-domaines n'est donc disponible pour un audit des imports ou des accès directs.

**Écart documentaire hors périmètre :** `AGENTS.md` mentionne encore `modules/` comme emplacement des domaines et CHAN-27 signale également une formulation historique dans le README racine. L'emplacement effectif documenté est `app/Domains/`. Cette harmonisation générale relève de CHAN-30 et n'est pas corrigée dans CHAN-29.

## 3. Vérification des critères d'acceptation Jira

| Critère | État de la preuve | Conclusion |
| --- | --- | --- |
| Responsabilités et frontières documentées et cohérentes | Catalogue des 18 domaines, processus, objets, registre INT, décisions V-01 à V-59 et exemples E-01 à E-09 présents ; revue croisée effectuée | **Démontré** |
| Dépendances autorisées/interdites explicites et justifiées | Les interdictions générales (accès direct aux Models, Actions, Services, DTO internes, Policies et tables d'un autre domaine, écritures hors propriété, couplage circulaire et transaction partagée implicite) sont documentées. Aucune dépendance technique individuelle n'est classée autorisée, conditionnelle ou interdite ; les 130 lignes restent « À qualifier » | **Partiellement démontré — critère non soldé** |
| Règles d'accès inter-domaines cohérentes avec CHAN-28 | Contrats publics et événements explicites, propriété fournisseur, UUID stables, absence de Model Eloquent traversant une frontière, transaction portée par le fournisseur et absence de transaction partagée implicite | **Démontré au niveau documentaire** |
| Exemples et schémas conformes à l'organisation retenue | Neuf scénarios et neuf diagrammes Mermaid ; propriétaires et limites métier explicités ; distinction entre flux conceptuel et appel technique ; références aux 18 domaines | **Démontré au niveau documentaire** |

### Conséquence

Le deuxième critère ne peut pas être déclaré satisfait sans preuve technique et décisions de classification validées. Il ne faut pas créer artificiellement des dépendances « autorisées » pour cocher le critère : l'état « À qualifier » est actuellement le seul état justifié par les éléments présents.

## 4. État de la qualification et des questions ouvertes

- 130 identifiants d'interaction sont recensés dans le Lot C.
- Les 130 classes techniques restent « À qualifier ».
- Le Lot D recense 95 paires de domaines candidates, 17 paires réciproques et six interactions sans paire explicite ; ces éléments décrivent le graphe documentaire, pas des appels PHP démontrés.
- Les questions Q-11 (taux horaires), Q-24 (capacité atelier), Q-29 (EPI/habilitations), Q-31 (DOE) et Q-44 (garanties) restent ouvertes.
- Les points de vigilance identifiés au Lot B — notamment Q-35, INT-074, INT-076, INT-102 et les agrégats INT-114/115/123/124 — ne sont pas réputés arbitrés par la présente revue.
- Aucune relation ne doit être déclarée « Interdite » sur la seule base d'une paire réciproque ou d'un cycle du graphe documentaire.

## 5. Revue des PR et de la CI

| Lot | PR | État GitHub | Commit de tête vérifié | CI |
| --- | --- | --- | --- | --- |
| Arbitrages métier | [#27](https://github.com/C2ME-ORGA/chantier/pull/27) | Fusionnée | `63970fa42ffc33c49de1b7f2d3cc2346ebcd45dc` | 3/3 succès |
| A — Cohérence documentaire | [#28](https://github.com/C2ME-ORGA/chantier/pull/28) | Fusionnée | `ecd06dd9d557846ae603e66bc1fe0a21a11c8f17` | 3/3 succès |
| B — Qualification métier | [#29](https://github.com/C2ME-ORGA/chantier/pull/29) | Fusionnée | `80c6a1631f0452704e5481d7810df8f57bb6aaed` | 3/3 succès |
| C — Matrice technique | [#30](https://github.com/C2ME-ORGA/chantier/pull/30) | Fusionnée | `0f7f659ded8eb77535ce1b1d2263ba31937ae4cf` | 3/3 succès |
| D — Matrice et cycles | [#31](https://github.com/C2ME-ORGA/chantier/pull/31) | Fusionnée | `22e0ee4680de91c556d72b945999b4f115988e83` | 3/3 succès |
| E — Exemples et checklist | [#32](https://github.com/C2ME-ORGA/chantier/pull/32) | Fusionnée | `5541ac8d0d0f458e51dd5e928fbfaf9714244470` | 3/3 succès |

Pour chacune des six PR, les jobs `ci`, `mariadb-10.11` et `package-linux` sont terminés avec la conclusion `success`. La CI confirme l'intégration des changements ; elle ne prouve pas l'absence d'accès internes futurs et ne remplace pas CHAN-31.

La PR #32 a été corrigée après revue : les quatre observations relatives à V-30/V-32, V-24, Q-11 et V-26 ont été prises en compte avant sa fusion.

## 6. Contrôles documentaires effectués pour le Lot F

- Revue des documents d'architecture référencés dans `docs/architecture/README.md`, des conventions CHAN-27, de la communication CHAN-28 et des README `app/Core` / `app/Domains`.
- Vérification des liens Markdown locaux relevés dans les documents de référence ; les chemins contrôlés existent dans `develop`.
- Contrôle structurel du document Lot E : neuf blocs Mermaid et neuf paires de fences de code (18 fences).
- Vérification de l'état Jira de CHAN-31 : « À faire ».
- Vérification des métadonnées GitHub des PR #27 à #32 et de leurs runs CI associés.

**Limites :** cette revue ne constitue pas une exécution locale de `git diff --check`, un rendu Mermaid par moteur externe, un audit statique des imports PHP ou un test d'architecture. Aucun de ces contrôles n'est revendiqué comme exécuté dans le cadre du Lot F.

## 7. Recommandations avant clôture de CHAN-29

1. Conserver les 130 interactions au statut technique « À qualifier » tant que les domaines n'ont pas d'implémentations et que les contrats/événements consommés ne sont pas observables.
2. Traiter le critère d'acceptation n° 2 comme un point restant à démontrer, ou faire arbitrer explicitement son interprétation au regard de l'état initial du Modular Monolith.
3. Livrer CHAN-31 lorsque les règles automatisables et les tests négatifs représentatifs pourront être exécutés sur le code réel.
4. Traiter l'incohérence historique `modules/` / `app/Domains/` dans CHAN-30, sans étendre CHAN-29 à cette harmonisation.
5. Ne proposer la clôture Jira qu'après décision explicite sur le critère restant et validation des preuves correspondantes.

## 8. Traçabilité et périmètre du Lot F

- Lot : F — revue finale et préparation de clôture.
- Base : `develop` après fusion de la PR #32.
- Périmètre : rapport documentaire de revue finale et indexation dans `docs/architecture/README.md`.
- Aucun code PHP, contrat, DTO, événement, listener, job, provider, service, migration ou test d'architecture ajouté.
- Aucune décision V-xx ou question Q-xx modifiée.
- Aucun changement Jira, aucun nouveau ticket et aucun sous-ticket.
- Aucun changement de statut Jira ; CHAN-29 reste « En cours ».
