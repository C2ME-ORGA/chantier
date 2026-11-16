# Domaines métier

Ce répertoire accueille les **domaines métier** de C2ME Chantier. Chaque sous-répertoire matérialise un espace de responsabilité fonctionnelle clairement identifié, conformément à la décision d'architecture prise dans Jira CHAN-10 (modular monolith).

## Finalité

`app/Domains` constitue l'emplacement cible pour l'organisation du code métier par domaine. Il permet de :

- regrouper par domaine les règles, modèles et traitements qui partagent le même langage métier ;
- rendre explicites les frontières entre domaines ;
- éviter la dispersion du code fonctionnel dans les répertoires techniques de Laravel ;
- préparer une structuration interne progressive, guidée par les besoins réels.

Le répertoire `app/Core` reste réservé aux composants **techniques transverses** décrits dans [`app/Core/README.md`](../Core/README.md). Aucun domaine métier ne doit y être placé.

## Emplacement et compatibilité PSR-4

Les domaines sont placés dans `app/Domains`, et non dans un dossier racine `modules/`.

Le mapping PSR-4 existant `App\\` vers `app/` couvre déjà ces répertoires. Un domaine `Identity` situé dans `app/Domains/Identity` correspond donc au namespace `App\\Domains\\Identity\\`. Aucune modification de `composer.json` n'est nécessaire.

## Convention de nommage

- Un domaine par répertoire, nommé en `PascalCase`.
- Le nom du répertoire est identique au segment de namespace : `App\\Domains\\{Domaine}\\`.
- Le nom décrit une responsabilité métier, pas un type technique.
- Pas d'abréviation ni de préfixe/suffixe décoratif (`Domain`, `Module`, `Bounded`, etc.).

## Domaines initiaux

La liste de référence est celle de CHAN-10 :

- `Identity`
- `Clients`
- `Projects`
- `Planning`
- `Budgets`
- `Costing`
- `Workforce`
- `TimeTracking`
- `Workshop`
- `Procurement`
- `Inventory`
- `Equipment`
- `Logistics`
- `Quality`
- `Safety`
- `Documents`
- `Handover`
- `Reporting`

Aucun autre domaine ne doit être ajouté sans décision d'architecture explicite.

## Espaces de responsabilité métier

Chaque répertoire représente un espace de responsabilité métier : il regroupe le code dont ce domaine est propriétaire, et il est la seule autorité sur ses règles, ses états et ses données.

Ces répertoires ne définissent pas encore de frontières de dépendance détaillées ni de contrats d'échange. Ces sujets sont traités séparément et ne doivent pas être anticipés ici.

## État actuel

L'arborescence est volontairement vide de toute implémentation métier. Elle ne contient que :

- ce `README.md` ;
- un fichier `.gitkeep` par domaine, uniquement destiné à versionner le répertoire.

Aucune classe PHP, aucun modèle Eloquent, aucun service, aucune action, aucun DTO, aucun événement, aucune policy, aucune migration, aucun provider et aucun fichier de configuration spécifique à un domaine n'est présent à ce stade. Les fichiers `.gitkeep` ne contiennent aucune logique.

## Structuration progressive

Chaque domaine sera structuré **progressivement**, en fonction de ses besoins réels et de son code effectif. Aucune organisation interne (couches, sous-répertoires, conventions de classes) n'est imposée par ce ticket : ces conventions relèvent de CHAN-27.

Il est donc attendu qu'un domaine reste vide tant qu'aucun besoin concret ne justifie du code, et que sa structure interne apparaisse au fur et à mesure de son implémentation.

### Évolution des périmètres cibles

La liste des 18 domaines et leur cartographie actuelle constituent un **cadre initial de responsabilités**, pas une spécification figée de leur contenu fonctionnel ou technique. Les périmètres détaillés, les objets effectivement détenus, les composants internes et les frontières précises seront décidés et affinés au fur et à mesure de la programmation, à partir des besoins métier rencontrés et des règles de gestion mises au jour.

Au cours de cette évolution, un domaine pourra être précisé, étendu, scindé ou réorganisé si l'implémentation le justifie. Toute évolution devra toutefois préserver la propriété explicite des données et invariants, l'isolation des domaines et les règles de communication publique définies dans CHAN-27 et CHAN-28. Une interaction cible documentée ne vaut donc pas engagement à créer immédiatement un contrat ou un composant : sa nécessité et sa forme seront confirmées au moment où le cas d'usage sera développé.

## Références

- [`AGENTS.md`](../../AGENTS.md) — règles générales du dépôt.
- [`app/Core/README.md`](../Core/README.md) — périmètre du noyau technique.
- [`docs/development/git-workflow.md`](../../docs/development/git-workflow.md) — workflow Git et Pull Requests.
