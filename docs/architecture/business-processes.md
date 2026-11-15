# Cartographie des processus métier

Ce document décrit les principaux processus métier de **C2ME Chantier** et la responsabilité des 18 domaines à chaque étape.

- Ticket : CHAN-29 — Documenter les frontières et dépendances autorisées.
- Lot : Lot 1 — Inventaire et cartographie des responsabilités métier.
- Portée : parcours commercial, préparation, planification, approvisionnement, fabrication, logistique, exécution, suivi, qualité/sécurité et réception.
- Hors portée : matrice technique des dépendances (Lot 2), contrats et événements (CHAN-28), spécifications d'implémentation.

> **Statut du document — Lot 1.**
> Les processus décrivent des **responsabilités cibles**, pas un existant applicatif. Aucun de ces processus n'est implémenté à ce jour : `app/Domains/` ne contient que des répertoires et des fichiers `.gitkeep`. Les étapes, règles et exceptions sont des propositions de cadrage métier, sauf mention explicite d'une décision validée.

## 1. Convention de lecture

### 1.1 Identifiants

| Élément | Convention | Exemple |
| --- | --- | --- |
| Processus | `P01` à `P12` | `P05` Approvisionnement et stock |
| Domaine | `D01` à `D18` | `D11` Inventory |
| Objet métier | Préfixe du domaine + numéro | `PRJ-01` Affaire |
| Interaction | `INT-xxx` | `INT-042` |
| Chevauchement | `BD-xx` | `BD-05` |
| Question ouverte | `Q-xx` | `Q-19` |

Les objets, interactions et questions sont détaillés dans les documents liés en fin de document.

### 1.2 Statut des étapes

Chaque étape indique :

- le ou les **domaines responsables** de l'opération ;
- les **domaines ou acteurs contributeurs** ;
- les **informations d'entrée** nécessaires ;
- le **résultat** produit ;
- les **interactions** principales.

Une étape peut mobiliser plusieurs domaines. Lorsque plusieurs domaines sont indiqués comme responsables, l'étape est **conjointe** : chaque domaine est responsable de la partie du résultat qui relève de sa propriété. Les domaines qui fournissent seulement une information ou un moyen restent dans la colonne « Contributeurs ».

### 1.3 Principe de responsabilité

Le domaine responsable d'une étape est celui qui :

- décide de la validité métier du résultat ;
- applique les invariants et les transitions d'état ;
- écrit les données dont il est propriétaire ;
- publie le fait métier correspondant.

Les autres domaines fournissent une information ou consomment le résultat ; ils n'écrivent pas à sa place. Lorsque l'étape est conjointe, chaque domaine applique ces règles sur son propre résultat partiel.

## 2. Vue d'ensemble des 12 processus

| ID | Processus | Déclencheur principal | Domaines pilotes | Résultat principal |
| --- | --- | --- | --- | --- |
| P01 | Prospection, étude, devis et ouverture d'affaire | Prospect qualifié ou demande de prix | Projects | Devis accepté et affaire ouverte |
| P02 | Ouverture directe d'affaire | Commande ou ordre de service reçu | Projects | Affaire ouverte et préparation lancée |
| P03 | Préparation technique, financière et documentaire | Affaire ouverte | Projects | Dossier d'exécution et autorisation de démarrer |
| P04 | Planification des ressources humaines et matérielles | Besoin d'exécution daté | Planning | Planning publié et ressources affectées |
| P05 | Approvisionnement et gestion du stock central | Besoin matière ou seuil de stock | Procurement / Inventory | Commande, réception et stock disponible |
| P06 | Fabrication interne en atelier | Besoin de fabrication validé | Workshop | Composants fabriqués et contrôlés |
| P07 | Fabrication ou opération externe — sous-traitance dans les deux sens | Décision de faire-faire ou commande reçue | Procurement / Projects / Handover | Prestation externe commandée ou exécutée selon le rôle de C2ME |
| P08 | Préparation logistique et transport vers le chantier | Besoin de livraison | Logistics | Matériel livré et réceptionné sur site |
| P09 | Réalisation des travaux sur chantier | Autorisation de démarrer | Projects | Travaux exécutés et suivis |
| P10 | Suivi des temps, de l'avancement et des coûts | Exécution quotidienne et périodes de suivi | TimeTracking / Planning / Costing | Temps, avancement et coûts fiables |
| P11 | Contrôle qualité, sécurité et non-conformités | Point de contrôle, inspection ou incident | Quality / Safety | Conformité et actions traitées |
| P12 | Réception, réserves, DOE et clôture | Achèvement des travaux | Handover / Projects | Réception contractuelle et affaire clôturée |

## 3. P01 — Prospection, étude, devis et ouverture d'affaire

### 3.1 Contexte

Ce processus couvre le parcours commercial complet :

```text
Prospect → Client → Étude → Devis → Acceptation / Commande → Affaire → Chantier
```

Il s'applique aux activités de bureau d'études, charpente métallique, couverture, bardage, fabrication, montage, serrurerie, menuiseries métalliques, maçonnerie et génie civil. La nature de l'étude et le poids relatif de la fabrication varient selon l'activité, mais la logique de responsabilité reste la même.

### 3.2 Déclencheur

- Un prospect est identifié ou qualifié.
- Un client existant demande une étude ou un devis.
- Un appel d'offres ou une consultation est reçu.
- Une opportunité commerciale est jugée suffisamment crédible pour engager une étude.

### 3.3 Acteurs

Direction générale, direction commerciale, chargé d'affaires, bureau d'études, métreur/économiste, contrôleur de gestion, acheteur, planificateur, qualité, sécurité, gestionnaire documentaire, client ou donneur d'ordre.

### 3.4 Informations d'entrée

- identité du prospect ou du client, contacts et rôles ;
- besoin, site, nature des travaux et contraintes ;
- documents techniques, plans, cahier des charges, appel d'offres ;
- exigences de qualité, de sécurité et de délais ;
- conditions commerciales envisagées ;
- disponibilité et capacités internes ;
- prix ou budget cible éventuel.

### 3.5 Étapes

| # | Étape | Domaine(s) responsable(s) | Contributeurs (domaines ou acteurs) | Opérations métier | Résultat / interactions |
| --- | --- | --- | --- | --- | --- |
| 1 | Détecter et qualifier le besoin | Clients | Projects | Créer ou retrouver le prospect, qualifier le besoin, identifier les contacts et rôles, vérifier les doublons | Prospect qualifié, contact et rôle identifiés (`CLI-01`, `CLI-03`, `CLI-04`) |
| 2 | Ouvrir l'étude | Projects / Documents | Clients | Créer l'étude, rattacher le client ou prospect, décrire le périmètre, le site et les contraintes, ouvrir le dossier documentaire | Étude ouverte, périmètre initial et dossier documentaire (`PRJ-04`, `DOC-01`) |
| 3 | Réaliser l'étude technique | Projects | Workshop, Quality, Safety, Documents | Visite de site, relevés, calculs, hypothèses techniques, faisabilité de fabrication, exigences qualité et sécurité | Dossier d'étude, hypothèses, plans et notes (`PRJ-04`) |
| 4 | Chiffrer l'offre | Costing | Projects, Procurement, Workforce, Equipment, Workshop, Logistics | Quantifier, valoriser main-d'œuvre, matière, équipements, sous-traitance, transport et risques ; produire le chiffrage prévisionnel | Chiffrage et marge prévisionnelle (`CST-01`, `CST-05`) |
| 5 | Consulter les fournisseurs et sous-traitants | Procurement | Costing, Workshop, Quality, Safety | Consulter, comparer et retenir les offres nécessaires au chiffrage | Offres et engagements prévisionnels (`PRC-04`) |
| 6 | Vérifier la faisabilité et le planning indicatif | Planning | Projects, Workshop, Procurement, Workforce, Equipment | Vérifier les délais, les capacités, les approvisionnements longs et les contraintes de site | Planning indicatif et alertes (`PLN-01`, `PLN-05`) |
| 7 | Construire le devis | Projects | Costing, Clients, Documents | Définir le prix, les prestations, les hypothèses, les exclusions, les conditions et la validité ; vérifier la marge cible | Devis versionné (`PRJ-05`, `CST-05`) |
| 8 | Valider le devis | Projects | Direction, Costing, Budgets, Identity | Vérifier les droits, la marge, les risques, les remises et les conditions ; tracer la validation | Devis validé (`PRJ-05`) |
| 9 | Envoyer et négocier | Projects / Documents | Clients | Envoyer le devis, suivre les échanges, produire les révisions, conserver l'historique | Devis envoyé ou révisé (`PRJ-05`, `DOC-05`) |
| 10 | Accepter ou commander | Clients / Projects | Direction, Budgets, Costing | Enregistrer l'acceptation, la commande ou l'ordre de service ; convertir le prospect en client si nécessaire | Acceptation ou commande enregistrée (`PRJ-06`, `CLI-02`) |
| 11 | Ouvrir l'affaire et le chantier | Projects | Clients, Budgets, Planning, Costing | Créer l'affaire, rattacher le contrat et les lots, créer le ou les chantiers, nommer les acteurs, notifier les domaines | Affaire et chantier ouverts (`PRJ-01`, `PRJ-02`, `PRJ-03`) |
| 12 | Établir le budget de l'affaire | Budgets | Costing, Projects, Procurement | Reprendre le chiffrage accepté, construire les lignes budgétaires, valider l'enveloppe et la marge cible | Budget validé (`BUD-01`, `BUD-02`) |

### 3.6 Résultats

- prospect qualifié et, si nécessaire, converti en client ;
- étude technique et dossier de référence ;
- chiffrage prévisionnel et marge simulée ;
- devis versionné, validé et diffusé ;
- acceptation, commande ou ordre de service enregistré ;
- affaire et chantier ouverts ;
- budget de l'affaire validé ;
- premiers jalons contractuels et besoins de préparation identifiés.

### 3.7 Exceptions et cas particuliers

| Cas | Traitement proposé |
| --- | --- |
| Prospect non qualifié ou hors cible | Ne pas engager d'étude coûteuse ; documenter le motif de refus ou de mise en attente. |
| Client inconnu ou non encore créé | Créer le prospect ou le client selon Q-04 ; ne pas ouvrir d'affaire sans identité vérifiée. |
| Devis perdu ou expiré | Conserver l'étude et le chiffrage pour analyse ; ne pas ouvrir d'affaire. |
| Acceptation partielle | Créer une version de devis ou un avenant ; ne pas considérer l'affaire comme complète. |
| Commande directe sans devis | Basculer sur P02 et compléter les données manquantes. |
| Étude techniquement incertaine | Identifier les hypothèses, les réserves et les risques ; faire valider par le bureau d'études. |
| Fournisseur ou sous-traitant indisponible | Documenter l'alternative, le délai ou l'exclusion du périmètre. |
| Marge insuffisante | Refuser, réviser le prix ou demander une validation explicite de la direction. |
| Conflit d'intérêts ou client bloqué | Appliquer la règle Clients et l'autorisation appropriée ; tracer la dérogation. |
| Appel d'offres avec variantes | Versionner les hypothèses et les prix ; conserver la trace de la variante retenue. |

### 3.8 Interactions principales

- Clients → Projects : identité, contacts, rôles, conditions commerciales.
- Projects → Costing : périmètre, quantités, hypothèses et exigences.
- Costing → Projects : chiffrage, marge, risques économiques.
- Procurement → Costing : offres fournisseurs et sous-traitants.
- Planning → Projects : faisabilité et délais.
- Projects → Budgets : base du budget après acceptation.
- Documents → tous : versions contrôlées des documents d'étude et de devis.

### 3.9 Points ouverts

Q-01, Q-02, Q-03, Q-04, Q-05, Q-06, Q-08, Q-37, Q-45.

## 4. P02 — Ouverture directe d'affaire à partir d'une commande ou d'un ordre de service

### 4.1 Contexte

Le parcours direct correspond au cas où C2ME reçoit une commande, un ordre de service ou un contrat déjà obtenu, sans phase de devis complète. Il est fréquent en sous-traitance, en travaux urgents, en reconduction de contrat ou lorsque le client est déjà engagé.

```text
Commande ou ordre de service → Création de l'affaire → Préparation → Exécution
```

### 4.2 Déclencheur

- réception d'un bon de commande, d'un ordre de service, d'un contrat cadre ou d'une lettre d'engagement ;
- décision de démarrer une affaire sur la base d'un accord écrit ;
- reconduction ou extension d'une affaire existante.

### 4.3 Acteurs

Direction, chargé d'affaires, assistant commercial, contrôleur de gestion, planificateur, acheteur, responsable atelier, chef de chantier, qualité, sécurité.

### 4.4 Informations d'entrée

- commande, ordre de service ou contrat ;
- identité du donneur d'ordre et du client payeur ;
- périmètre, quantités, prix, délais et conditions ;
- site et contraintes d'accès ;
- documents techniques disponibles ;
- budget ou prix cible éventuel ;
- exigences qualité, sécurité et documentation.

### 4.5 Étapes

| # | Étape | Domaine(s) responsable(s) | Contributeurs (domaines ou acteurs) | Opérations métier | Résultat / interactions |
| --- | --- | --- | --- | --- | --- |
| 1 | Réceptionner et enregistrer la commande | Projects / Documents | Clients | Enregistrer la commande ou l'OS, rattacher le document, identifier la référence et la date | Commande enregistrée (`PRJ-06`, `DOC-01`) |
| 2 | Identifier et qualifier le donneur d'ordre | Clients | Projects | Retrouver ou créer le client/donneur d'ordre, vérifier les rôles et les contacts, détecter les doublons | Client et rôles identifiés (`CLI-02`, `CLI-04`) |
| 3 | Vérifier la cohérence contractuelle | Projects | Costing, Budgets | Vérifier le périmètre, le prix, les délais, les conditions et les écarts avec l'offre ou le tarif | Analyse des écarts et risques contractuels |
| 4 | Ouvrir l'affaire et le chantier | Projects | Clients, Budgets, Planning, Costing | Créer l'affaire, le chantier, les lots, rattacher le contrat et les acteurs | Affaire ouverte (`PRJ-01`, `PRJ-02`, `PRJ-03`) |
| 5 | Établir un budget provisoire | Budgets | Costing, Procurement, Workforce | Construire une enveloppe provisoire ou confirmer le budget existant ; identifier les engagements urgents | Budget provisoire validé (`BUD-01`) |
| 6 | Vérifier la faisabilité et les délais | Planning | Workshop, Procurement, Inventory, Workforce, Equipment | Vérifier la capacité, les approvisionnements longs, les compétences et les accès | Planning initial et alertes (`PLN-01`, `PLN-05`) |
| 7 | Lancer la préparation | Projects | Tous les domaines de préparation | Déclencher P03 avec les informations disponibles et les manques identifiés | Dossier de préparation lancé |
| 8 | Formaliser les informations manquantes | Projects | Clients, Quality, Safety, Documents | Lister les documents, validations, autorisations et données à obtenir ; assigner les responsabilités | Registre des manques et des risques |
| 9 | Autoriser le démarrage conditionnel | Projects | Direction, Quality, Safety, Budgets | Vérifier les conditions minimales et autoriser ou différer le démarrage | Autorisation tracée |

### 4.6 Résultats

- commande ou OS enregistré ;
- donneur d'ordre et client identifiés ;
- affaire, chantier et lots ouverts ;
- budget provisoire ou confirmé ;
- planning initial et besoins critiques identifiés ;
- liste des informations manquantes et des risques ;
- autorisation de préparation ou de démarrage conditionnel.

### 4.7 Exceptions et cas particuliers

| Cas | Traitement proposé |
| --- | --- |
| Commande reçue avant l'identification du client | Ouvrir une fiche prospect/client provisoire ; ne pas engager de dépense non autorisée. |
| Périmètre ambigu | Demander une clarification écrite ; limiter le démarrage aux travaux certains. |
| Prix absent ou incohérent | Ne pas démarrer sans validation commerciale ; documenter l'écart. |
| Délai impossible | Proposer un phasage ou une réserve ; faire valider par le client et la direction. |
| Démarrage urgent avant préparation complète | Autorisation conditionnelle, risques tracés, préparation parallèle. |
| Commande verbale | Exiger une confirmation écrite ; documenter la relance. |
| Sous-traitance reçue | L'affaire est de type sous-traitance ; le donneur d'ordre est le client, pas un fournisseur. |
| Commande de travaux supplémentaires | Créer un avenant ou une nouvelle affaire selon la nature et le contrat. |

### 4.8 Interactions principales

- Clients → Projects : donneur d'ordre, contacts, rôles.
- Projects → Budgets : besoin de budget provisoire.
- Costing → Budgets : estimation rapide et risques.
- Planning → Projects : faisabilité et délais.
- Procurement / Inventory / Workshop → Planning : disponibilité et délais.
- Projects → Quality / Safety : exigences à vérifier avant démarrage.

### 4.9 Points ouverts

Q-01, Q-04, Q-05, Q-07, Q-08, Q-45.

## 5. P03 — Préparation technique, financière et documentaire

### 5.1 Contexte

La préparation transforme un engagement contractuel en dossier d'exécution exploitable. Elle couvre les études, la fabrication, les achats, le budget, le planning, la qualité, la sécurité et la documentation.

### 5.2 Déclencheur

- affaire ouverte à l'issue de P01 ou P02 ;
- avenant modificatif important ;
- suspension puis reprise d'une affaire ;
- changement de périmètre ou de site.

### 5.3 Acteurs

Chargé d'affaires, conducteur de travaux, bureau d'études, responsable atelier, acheteur, planificateur, contrôleur de gestion, qualité, sécurité, gestionnaire documentaire, chef de chantier.

### 5.4 Informations d'entrée

- contrat, commande, devis accepté et avenants ;
- données du client et du site ;
- budget et chiffrage ;
- documents techniques ;
- exigences qualité, sécurité et réglementaires ;
- contraintes de délais, de ressources et d'approvisionnement.

### 5.5 Étapes

| # | Étape | Domaine(s) responsable(s) | Contributeurs (domaines ou acteurs) | Opérations métier | Résultat / interactions |
| --- | --- | --- | --- | --- | --- |
| 1 | Tenir le kick-off de l'affaire | Projects | Tous les domaines concernés | Présenter le contrat, le périmètre, les lots, les risques, les acteurs et les règles du projet | Compte rendu de lancement, acteurs nommés (`PRJ-10`) |
| 2 | Consolider le périmètre contractuel | Projects | Clients, Documents | Vérifier les pièces contractuelles, les limites de prestation, les interfaces et les responsabilités | Périmètre contractuel consolidé (`PRJ-08`) |
| 3 | Réaliser les études techniques | Projects | Workshop, Quality, Safety, Documents | Produire les études d'exécution, notes de calcul, plans, spécifications et hypothèses | Dossier technique validé (`PRJ-04`) |
| 4 | Préparer la fabrication | Workshop | Projects, Quality, Inventory, Procurement | Définir les nomenclatures, gammes, besoins matière, postes et décisions de faire ou faire-faire | Dossiers de fabrication et besoins matière (`WKS-01`, `WKS-02`) |
| 5 | Valider le budget et la structure de coûts | Budgets / Costing | Projects, Procurement, Workforce | Valider l'enveloppe, les lignes, les taux, les axes analytiques et les règles d'imputation | Budget et structure de coûts (`BUD-01`, `CST-04`) |
| 6 | Établir le planning d'exécution | Planning | Projects, Workforce, Equipment, Workshop, Procurement | Décomposer les activités, vérifier les capacités, affecter les ressources et publier le planning | Planning d'exécution (`PLN-01`, `PLN-03`) |
| 7 | Lancer les approvisionnements critiques | Procurement | Inventory, Costing, Budgets | Identifier les articles longs, consulter, commander et suivre les engagements | Commandes et échéanciers (`PRC-05`) |
| 8 | Vérifier la disponibilité du stock | Inventory | Procurement, Workshop, Projects | Vérifier les articles disponibles, réserver pour les affaires et identifier les pénuries | Réservations et alertes (`INV-07`) |
| 9 | Établir le plan qualité | Quality | Projects, Workshop, Procurement | Définir les plans de contrôle, points d'arrêt, essais, certificats et qualifications | Plan qualité et plan de contrôle (`QUA-01`, `QUA-02`) |
| 10 | Établir le plan de prévention | Safety | Projects, Workshop, Procurement, Workforce | Analyser les risques, définir les mesures, les autorisations, les inductions et les EPI | Plan de prévention (`SAF-01`, `SAF-02`) |
| 11 | Établir le plan documentaire | Documents | Projects, Quality, Safety, Handover | Définir les documents attendus, les modèles, les circuits de validation, la diffusion et la conservation | Plan documentaire et dossier (`DOC-03`, `DOC-04`) |
| 12 | Tenir la revue de préparation | Projects | Tous | Vérifier la complétude, les risques, les interfaces et les conditions de démarrage | Décision de démarrer, de différer ou de corriger |

### 5.6 Résultats

- dossier d'exécution technique ;
- dossiers de fabrication et besoins matière ;
- budget et structure analytique validés ;
- planning d'exécution et affectations ;
- commandes critiques et réservations de stock ;
- plan qualité, plan de prévention et plan documentaire ;
- autorisation de démarrer ou liste de conditions à lever.

### 5.7 Exceptions et cas particuliers

| Cas | Traitement proposé |
| --- | --- |
| Informations client manquantes | Bloquer les études concernées, tracer la relance et la responsabilité. |
| Autorisation administrative absente | Ne pas démarrer la partie concernée ; Projects suit l'obtention. |
| Modification technique en préparation | Passer par un avenant ou une révision d'étude ; mesurer l'impact budget/planning. |
| Délai fournisseur incompatible | Replanifier, chercher une alternative ou informer le client. |
| Capacité interne insuffisante | Décider un achat de capacité ou une sous-traitance via Procurement. |
| Ressources non qualifiées | Refuser l'affectation ou planifier une formation ; documenter la dérogation. |
| Documents non conformes | Bloquer la diffusion et demander une correction au domaine propriétaire. |
| Sites multiples | Préparer un plan par chantier ou par lot, avec des jalons distincts. |

### 5.8 Interactions principales

- Projects → Planning : périmètre, lots, jalons, contraintes.
- Projects → Workshop : études et besoins de fabrication.
- Workshop → Inventory / Procurement : besoins matière et sous-traitance.
- Budgets → Costing : enveloppe et lignes.
- Quality / Safety → Projects : plans et exigences.
- Documents → tous : modèles, versions, diffusion.

### 5.9 Points ouverts

Q-01, Q-08, Q-10, Q-16, Q-23, Q-24, Q-30, Q-50.

## 6. P04 — Planification des ressources humaines et matérielles

### 6.1 Contexte

La planification traduit les besoins d'exécution en activités datées et en affectations de ressources. Elle couvre les collaborateurs, les équipements, la capacité d'atelier et, lorsque nécessaire, les sous-traitants.

### 6.2 Déclencheur

- planning d'exécution à établir ou à réviser ;
- nouvelle affaire, avenant ou changement de priorité ;
- absence, panne, retard de livraison ou incident ;
- demande urgente d'intervention.

### 6.3 Acteurs

Planificateur, chargé d'affaires, conducteur de travaux, chef de chantier, responsable atelier, RH, responsable matériel, acheteur, sous-traitants.

### 6.4 Informations d'entrée

- périmètre, lots et jalons contractuels ;
- contraintes de site et dates clients ;
- disponibilité et qualifications des collaborateurs ;
- disponibilité, maintenance et inspections des équipements ;
- capacité et engagements de l'atelier ;
- délais fournisseurs et dates de livraison ;
- règles de sécurité et autorisations.

### 6.5 Étapes

| # | Étape | Domaine(s) responsable(s) | Contributeurs (domaines ou acteurs) | Opérations métier | Résultat / interactions |
| --- | --- | --- | --- | --- | --- |
| 1 | Exprimer les besoins d'exécution | Projects | — | Fournir le périmètre, les lots, les jalons, les priorités et les contraintes de site | Besoins datés (`PRJ-01`, `PRJ-09`) |
| 2 | Décomposer en activités | Planning | Projects, Workshop | Créer les activités, durées, dépendances, zones et contraintes | Activités planifiées (`PLN-02`) |
| 3 | Vérifier les ressources humaines | Workforce | Planning | Identifier les collaborateurs, équipes, qualifications, disponibilités et contraintes contractuelles | Proposition de ressources (`WKF-01`, `WKF-04`, `WKF-07`) |
| 4 | Vérifier les équipements | Equipment | Planning | Vérifier la disponibilité, la maintenance, les inspections et les affectations | Proposition d'équipements (`EQP-01`, `EQP-03`) |
| 5 | Vérifier la capacité d'atelier | Workshop | Planning | Confirmer les créneaux, les OF et les contraintes de production | Capacité et créneaux (`WKS-09`) |
| 6 | Vérifier les sous-traitances et achats | Procurement | Planning, Workshop | Confirmer les délais, les commandes et la disponibilité des prestataires | Engagements et dates (`PRC-05`, `PRC-07`) |
| 7 | Affecter et lisser la charge | Planning | Workforce, Equipment, Workshop | Affecter les ressources, détecter les conflits, lisser la charge, proposer des arbitrages | Affectations et conflits (`PLN-03`, `PLN-05`) |
| 8 | Confirmer les affectations | Workforce / Equipment / Workshop | Planning | Confirmer la disponibilité, les qualifications et les moyens | Affectations confirmées |
| 9 | Publier le planning | Planning | Projects, tous | Publier la version de référence, diffuser les dates et les priorités | Planning publié (`PLN-01`) |
| 10 | Suivre et replanifier | Planning | TimeTracking, Projects, Equipment, Workshop | Comparer prévu/réel, mettre à jour l'avancement, replanifier les écarts | Planning révisé (`PLN-06`) |

### 6.6 Résultats

- activités datées et dépendances ;
- affectations humaines et matérielles confirmées ;
- capacité d'atelier et engagements de sous-traitance intégrés ;
- conflits identifiés et arbitrés ;
- planning publié et diffusé ;
- prévision glissante et alertes.

### 6.7 Exceptions et cas particuliers

| Cas | Traitement proposé |
| --- | --- |
| Absence imprévue | Replanifier, remplacer avec une qualification équivalente, tracer l'impact. |
| Panne d'équipement | Déclarer l'indisponibilité, chercher une location ou un remplacement. |
| Retard de livraison | Replanifier les activités dépendantes, informer Projects et le client si nécessaire. |
| Accès chantier refusé | Reporter la mobilisation, tracer la responsabilité et le coût. |
| Conflit entre affaires | Arbitrage direction selon criticité, pénalités, engagements et marge. |
| Sous-traitant indisponible | Chercher une alternative via Procurement, replanifier ou réduire le périmètre. |
| Qualification manquante | Refuser l'affectation ou organiser une formation ; documenter la dérogation. |
| Heures supplémentaires | Vérifier les règles et l'autorisation avant affectation. |

### 6.8 Interactions principales

- Projects → Planning : besoins, jalons, priorités.
- Workforce → Planning : disponibilité, qualifications, contraintes.
- Equipment → Planning : disponibilité, maintenance, inspections.
- Workshop → Planning : capacité et avancement.
- Procurement → Planning : délais et dates.
- TimeTracking → Planning : temps réels et absences.
- Planning → Projects : planning, dates, conflits.

### 6.9 Points ouverts

Q-13, Q-24, Q-26, Q-27, Q-28.

## 7. P05 — Approvisionnement et gestion du stock central

### 7.1 Contexte

Ce processus couvre l'expression du besoin, l'achat, la réception, la mise en stock, la réservation, la consommation et le réapprovisionnement. Il s'appuie sur un stock central unique, avec des sorties vers l'atelier et les chantiers.

### 7.2 Déclencheur

- besoin matière d'un chantier ou d'un OF ;
- seuil de réapprovisionnement atteint ;
- commande client nécessitant un approvisionnement spécifique ;
- remplacement d'un article défectueux ou manquant.

### 7.3 Acteurs

Acheteur, responsable achats, magasinier, responsable magasin, chargé d'affaires, responsable atelier, qualité, contrôleur de gestion, fournisseur, transporteur.

### 7.4 Informations d'entrée

- besoin, quantité, qualité, date et destination ;
- article, référence, unité et spécifications ;
- budget et lot analytique ;
- fournisseurs et conditions d'achat ;
- délais et contraintes de transport ;
- exigences qualité et sécurité.

### 7.5 Étapes

| # | Étape | Domaine(s) responsable(s) | Contributeurs (domaines ou acteurs) | Opérations métier | Résultat / interactions |
| --- | --- | --- | --- | --- | --- |
| 1 | Recueillir et qualifier la demande d'achat | Procurement | Projects, Workshop, Inventory | Décrire l'article ou la prestation, la quantité, la date, la destination et le lot | Demande d'achat (`PRC-03`) |
| 2 | Vérifier le stock disponible | Inventory | — | Consulter le stock, les réservations et les mouvements prévus | Disponibilité ou pénurie (`INV-01`, `INV-07`) |
| 3 | Valider le disponible budgétaire | Budgets | Costing, Procurement | Vérifier l'enveloppe, le disponible et la nature de coût | Autorisation ou refus (`BUD-01`) |
| 4 | Consulter et sélectionner le fournisseur | Procurement | Quality, Safety | Consulter, comparer, vérifier la qualification et retenir l'offre | Offre retenue (`PRC-04`) |
| 5 | Créer et approuver la commande | Procurement | Budgets, Costing | Créer la commande, les lignes, l'échéancier et l'engagement | Commande approuvée (`PRC-05`) |
| 6 | Préparer la réception | Inventory | Procurement, Logistics | Planifier la réception, l'emplacement et le contrôle éventuel | Réception attendue (`INV-06`) |
| 7 | Réceptionner physiquement | Inventory | Logistics, Quality | Constater la quantité, l'état, le lot et les écarts ; enregistrer le mouvement | Réception et stock (`INV-05`, `INV-06`) |
| 8 | Contrôler la qualité | Quality | Inventory | Effectuer le contrôle d'entrée selon le plan ; accepter, refuser ou mettre en quarantaine | Statut qualité (`QUA-03`) |
| 9 | Mettre à disposition et réserver | Inventory | Workshop, Projects | Ranger, affecter, réserver pour une affaire ou un OF | Stock disponible/réservé (`INV-07`) |
| 10 | Consommer et tracer | Inventory | Workshop, Projects | Sortir la matière, enregistrer la consommation et la traçabilité | Consommation (`INV-08`) |
| 11 | Enregistrer le coût | Costing | Inventory, Procurement | Valoriser la réception, la consommation et les écarts | Coût matière (`CST-02`) |
| 12 | Réapprovisionner | Inventory / Procurement | Budgets | Déclencher une nouvelle demande selon le seuil ou la pénurie | Nouvelle demande (`PRC-03`) |

### 7.6 Résultats

- besoin qualifié et budgétisé ;
- fournisseur sélectionné et commande approuvée ;
- réception enregistrée avec contrôle qualité ;
- stock disponible, réservé et traçable ;
- consommation imputée à l'affaire ou à l'OF ;
- coût matière enregistré ;
- seuils et besoins de réapprovisionnement à jour.

### 7.7 Exceptions et cas particuliers

| Cas | Traitement proposé |
| --- | --- |
| Rupture de stock | Déclencher un achat urgent, informer Planning et Projects, chercher une substitution. |
| Livraison partielle | Réception partielle, échéancier ajusté, information des domaines concernés. |
| Non-conformité à la réception | Refus ou quarantaine, NCR fournisseur, retour ou remplacement. |
| Écart de prix | Bloquer le paiement ou demander une validation ; tracer l'écart. |
| Livraison directe sur chantier | Inventory enregistre la réception, Logistics organise et constate la livraison. |
| Article fourni par le client | Statut, responsabilité et valorisation à définir (Q-43). |
| Retour fournisseur | Mouvement de sortie, documentation et impact coût. |
| Commande sans budget | Refus ou dérogation explicite et tracée. |

### 7.8 Interactions principales

- Inventory → Procurement : besoins, pénuries, écarts de réception.
- Procurement → Inventory : commande, quantités attendues, échéancier.
- Procurement → Costing : engagements.
- Budgets → Procurement : disponible.
- Quality → Inventory : acceptation, refus, quarantaine.
- Inventory → Costing : consommation et valorisation.
- Inventory → Logistics : colis et bon de sortie.

### 7.9 Points ouverts

Q-07, Q-08, Q-09, Q-17, Q-18, Q-19, Q-20, Q-21, Q-43.

## 8. P06 — Fabrication interne en atelier

### 8.1 Contexte

La fabrication interne couvre la charpente métallique, l'assemblage, la serrurerie, les menuiseries métalliques et les préparations nécessaires aux activités de couverture, bardage, montage, maçonnerie et génie civil. Elle s'appuie sur un ordre de fabrication, un dossier technique, des opérations et des moyens d'atelier.

### 8.2 Déclencheur

- décision de fabriquer en interne après étude ;
- besoin d'un chantier ou d'un lot ;
- réapprovisionnement d'un composant standard ;
- reprise ou modification d'un existant.

### 8.3 Acteurs

Responsable atelier, bureau d'études atelier, chef d'atelier, opérateurs, soudeurs, magasinier, qualité, planning, logistique, safety.

### 8.4 Informations d'entrée

- dossier technique et plans d'exécution ;
- affaire, lot et dates ;
- nomenclatures et besoins matière ;
- capacité et disponibilité des postes ;
- qualifications des opérateurs ;
- exigences qualité et sécurité ;
- disponibilité des équipements.

### 8.5 Étapes

| # | Étape | Domaine(s) responsable(s) | Contributeurs (domaines ou acteurs) | Opérations métier | Résultat / interactions |
| --- | --- | --- | --- | --- | --- |
| 1 | Décider faire ou faire-faire | Projects / Workshop | Procurement, Budgets, Quality | Comparer capacité, coût, délai et risque ; décider l'exécution interne ou externe | Décision tracée (`WKS-01`) |
| 2 | Créer l'ordre de fabrication | Workshop | Projects, Planning | Créer l'OF, rattacher l'affaire, le lot, les quantités et les dates | OF lancé (`WKS-01`) |
| 3 | Préparer le dossier de fabrication | Workshop | Projects, Documents | Produire les plans d'atelier, nomenclatures, gammes et instructions | Dossier de fabrication (`WKS-02`, `WKS-03`) |
| 4 | Réserver et sortir la matière | Inventory | Workshop | Vérifier la disponibilité, réserver, sortir et tracer les lots | Matière disponible (`INV-07`, `INV-08`) |
| 5 | Planifier les opérations | Planning / Workshop | — | Intégrer l'OF dans le planning, affecter les postes et les opérateurs | Créneaux et affectations (`PLN-03`) |
| 6 | Exécuter les opérations | Workshop | Workforce, Equipment | Découpe, assemblage, soudage, finition, contrôle dimensionnel | Production réalisée (`WKS-06`) |
| 7 | Réaliser l'autocontrôle | Workshop | Quality | Vérifier les caractéristiques, enregistrer les résultats et signaler les écarts | Autocontrôle atelier (`WKS-06`) |
| 8 | Faire contrôler par Quality | Quality | Workshop | Contrôler selon le plan, prononcer la conformité ou ouvrir une NCR | Conformité ou NCR (`QUA-04`) |
| 9 | Traiter les reprises | Workshop | Quality, Costing | Reprendre, réparer ou rebuter ; enregistrer le temps et la matière | Reprise ou rebut (`WKS-06`) |
| 10 | Emballer et marquer | Workshop | Logistics | Protéger, identifier, peser, mesurer et préparer les colis | Colis prêts (`WKS-07`) |
| 11 | Expédier | Inventory / Logistics | Workshop, Projects | Enregistrer la sortie, planifier le transport et livrer | Expédition (`INV-09`, `LOG-04`) |
| 12 | Clôturer l'OF et valoriser | Workshop / Costing | Inventory, Quality | Vérifier les quantités, clôturer l'OF, valoriser heures et matière | OF clôturé, coût (`WKS-01`, `CST-02`) |

### 8.6 Résultats

- OF exécuté et clôturé ;
- composants fabriqués, contrôlés et emballés ;
- matière consommée et tracée ;
- non-conformités traitées ou reprises ;
- colis prêts pour le transport ;
- heures et coûts atelier fournis à Costing ;
- avancement communiqué à Projects et Planning.

### 8.7 Exceptions et cas particuliers

| Cas | Traitement proposé |
| --- | --- |
| Matière manquante | Bloquer l'opération, alerter Procurement/Inventory, replanifier. |
| Erreur de plan | Arrêter, corriger le dossier, tracer l'impact et la responsabilité. |
| Panne de machine | Déclarer la panne, alerter Equipment/Planning, chercher une alternative. |
| Non-conformité | Ouvrir une NCR, contenir, réparer ou rebuter, vérifier l'efficacité. |
| Priorité changée | Replanifier avec Planning et Projects, tracer l'impact. |
| Capacité insuffisante | Externaliser via Procurement ou décaler. |
| Opération sous-traitée | Utiliser P07, avec dossier technique Workshop et commande Procurement. |
| Chute ou rebut important | Enregistrer la consommation, analyser le coût et la cause. |

### 8.8 Interactions principales

- Workshop → Inventory : demande, réservation, consommation, retour.
- Workshop → Quality : autocontrôle, demande de contrôle, NCR.
- Workshop → Planning : capacité, avancement, retards.
- Workshop → Procurement : besoin de fabrication externe.
- Workshop → Logistics : colis prêts.
- Workshop → Costing : heures, matière, rebuts.

### 8.9 Points ouverts

Q-16, Q-23, Q-24, Q-50.

## 9. P07 — Fabrication ou opération externe — sous-traitance dans les deux sens

### 9.1 Contexte

C2ME peut confier une fabrication, un traitement, un assemblage ou une prestation à un tiers. Le processus couvre les deux configurations de sous-traitance :

- **C2ME donneur d'ordre** : C2ME commande à un sous-traitant.
- **C2ME sous-traitant** : C2ME intervient pour le compte d'un donneur d'ordre.

Les responsabilités diffèrent complètement entre les deux cas.

### 9.2 Déclencheur

- décision de faire-faire une fabrication ou une opération ;
- capacité interne insuffisante ;
- compétence ou équipement externe nécessaire ;
- commande reçue d'un donneur d'ordre dans le cadre d'une sous-traitance.

### 9.3 Acteurs

Acheteur, responsable achats, responsable atelier, bureau d'études, chargé d'affaires, qualité, sécurité, logistique, contrôleur de gestion, sous-traitant, donneur d'ordre.

### 9.4 Informations d'entrée

- besoin technique, plans, nomenclatures et spécifications ;
- affaire, lot, quantités, dates et contraintes de site ;
- budget, prix cible et conditions d'achat ;
- exigences qualité, sécurité et documentation ;
- qualifications et capacités du prestataire ;
- conditions de réception, de garantie et de paiement ;
- dans la sous-traitance reçue : commande ou ordre de service du donneur d'ordre, contrat, périmètre, prix et délais.

### 9.5 Étapes

Les étapes dépendent de la configuration. Les deux variantes ci-dessous ne sont pas deux implémentations simultanées : elles décrivent deux relations contractuelles différentes.

#### Variante A — C2ME donneur d'ordre

| # | Étape | Domaine(s) responsable(s) | Contributeurs (domaines ou acteurs) | Opérations métier | Résultat / interactions |
| --- | --- | --- | --- | --- | --- |
| 1 | Décider de faire-faire | Projects / Workshop | Budgets, Procurement | Comparer coût, délai, capacité et risque ; décider l'externalisation | Décision tracée |
| 2 | Constituer le dossier technique | Workshop | Projects, Documents | Préparer plans, nomenclatures, spécifications, exigences qualité et sécurité | Dossier de fabrication externe (`WKS-08`) |
| 3 | Consulter et qualifier | Procurement | Quality, Safety | Consulter les sous-traitants, vérifier la qualification et la conformité | Offre et sous-traitant retenus (`PRC-04`, `PRC-02`) |
| 4 | Commander | Procurement | Budgets, Costing | Créer la commande de sous-traitance, l'échéancier et l'engagement | Commande notifiée (`PRC-07`) |
| 5 | Suivre l'exécution | Procurement / Workshop | Quality, Planning | Suivre l'avancement, les délais, les points d'arrêt et les risques | Suivi et alertes |
| 6 | Réceptionner et contrôler | Inventory / Quality | Workshop, Logistics | Réceptionner, contrôler la conformité, accepter ou refuser | Réception et statut qualité (`INV-06`, `QUA-03`) |
| 7 | Accepter techniquement | Workshop | Quality, Projects | Vérifier la conformité au dossier technique et prononcer l'acceptation | Acceptation technique |
| 8 | Traiter les écarts | Quality / Procurement | Workshop, Costing | Ouvrir une NCR, demander une reprise, appliquer une retenue ou un refus | NCR et action (`QUA-04`) |
| 9 | Valoriser et clôturer | Costing / Procurement | Budgets | Enregistrer le coût, solder l'engagement et clôturer la commande | Coût et clôture (`CST-02`) |

#### Variante B — C2ME sous-traitant

| # | Étape | Domaine(s) responsable(s) | Contributeurs (domaines ou acteurs) | Opérations métier | Résultat / interactions |
| --- | --- | --- | --- | --- | --- |
| 1 | Réceptionner la commande ou l'OS | Projects | Clients, Documents | Enregistrer le donneur d'ordre, le contrat, le périmètre, le prix et les délais | Commande reçue (`PRJ-06`) |
| 2 | Ouvrir l'affaire de sous-traitance | Projects | Clients, Budgets, Costing | Créer l'affaire, identifier le type de contrat et les obligations de C2ME | Affaire ouverte (`PRJ-01`) |
| 3 | Préparer l'exécution | Projects / Workshop | Planning, Quality, Safety | Adapter les études, la fabrication, le planning et les contrôles aux exigences du donneur d'ordre | Dossier d'exécution |
| 4 | Acheter les besoins propres | Procurement | Inventory, Costing | Acheter les matières, composants et services nécessaires à C2ME | Commandes (`PRC-05`) |
| 5 | Exécuter | Projects / Workshop | Planning, Logistics, Quality, Safety | Réaliser les travaux ou fabrications selon le contrat | Travaux exécutés |
| 6 | Contrôler et documenter | Quality | Projects, Documents | Appliquer les contrôles, produire les preuves et les documents exigés | Dossier de conformité (`QUA-03`, `DOC-01`) |
| 7 | Réceptionner avec le donneur d'ordre | Handover | Projects, Quality | Organiser la réception, les réserves et le DOE | Réception (`HND-01`, `HND-04`) |
| 8 | Clôturer et valoriser | Projects / Costing | Budgets, Handover | Clôturer l'affaire, calculer la marge et solder les engagements | Affaire clôturée (`PRJ-01`, `CST-05`) |

### 9.6 Résultats

**Variante A :** dossier technique externe, commande de sous-traitance, suivi, réception, acceptation technique, NCR éventuelle, coût et clôture.

**Variante B :** affaire de sous-traitance, exécution conforme au contrat, preuves, réception par le donneur d'ordre, clôture et marge.

### 9.7 Exceptions et cas particuliers

| Cas | Traitement proposé |
| --- | --- |
| Sous-traitant défaillant | Appliquer la clause contractuelle, trouver une alternative, tracer l'impact. |
| Retard de livraison externe | Replanifier, informer Projects et le client, évaluer les pénalités. |
| Non-conformité externe | NCR, reprise, refus, retenue ou remplacement. |
| Modification de périmètre | Avenant à la commande de sous-traitance et au contrat client si nécessaire. |
| Sous-traitance en cascade | Vérifier l'acceptation du donneur d'ordre et la conformité documentaire. |
| Donneur d'ordre qui impose un sous-traitant | Vérifier la qualification, le contrat et la responsabilité. |
| Co-activité sur site | Plan de prévention Safety, coordination et autorisations. |
| Défaut de paiement ou litige | Hors périmètre des 18 domaines ; documenter et escalader. |

### 9.8 Interactions principales

- Workshop → Procurement : dossier technique et besoin externe.
- Procurement → Workshop : commande, statut, délais.
- Quality → Procurement / Workshop : qualification, contrôle, NCR.
- Inventory / Logistics → Workshop : réception et livraison.
- Costing ← Procurement : engagement et coût.
- Clients / Projects → Handover : réception du donneur d'ordre dans la variante B.

### 9.9 Points ouverts

Q-22, Q-23, Q-41.

## 10. P08 — Préparation logistique et transport vers le chantier

### 10.1 Contexte

La logistique organise les flux physiques depuis l'atelier, le stock central ou un fournisseur vers le chantier, puis les retours. Elle ne possède ni le stock ni la production, mais elle garantit que le bon colis arrive au bon endroit, dans les bonnes conditions.

### 10.2 Déclencheur

- colis de fabrication prêt ;
- besoin de matériaux ou matériels sur chantier ;
- livraison fournisseur à réceptionner ;
- retour de matériel, d'emballage ou d'équipement ;
- demande urgente du chantier.

### 10.3 Acteurs

Logisticien, magasinier, chef de chantier, conducteur de travaux, transporteur, chauffeur, qualité, sécurité, acheteur.

### 10.4 Informations d'entrée

- colis, poids, dimensions, quantités et valeur ;
- site, adresse, accès, horaires et destinataire ;
- date souhaitée et contraintes de production ;
- moyens de transport et de levage ;
- règles de sécurité et autorisations d'accès ;
- documents de transport et de douane éventuels.

### 10.5 Étapes

| # | Étape | Domaine(s) responsable(s) | Contributeurs (domaines ou acteurs) | Opérations métier | Résultat / interactions |
| --- | --- | --- | --- | --- | --- |
| 1 | Recueillir et qualifier les besoins de livraison | Logistics | Inventory, Workshop, Projects | Identifier les colis, quantités, dates, destinations et priorités | Demande de transport (`LOG-01`) |
| 2 | Vérifier la disponibilité et la préparation | Inventory / Workshop | — | Confirmer que le colis est prêt, contrôlé, emballé et documenté | Colis prêt (`WKS-07`, `INV-09`) |
| 3 | Planifier le transport | Logistics | Procurement, Equipment, Projects | Choisir le mode, le transporteur, la tournée, les moyens et les dates | Plan de transport (`LOG-02`, `LOG-03`) |
| 4 | Vérifier les accès et la sécurité | Logistics | Safety, Projects | Vérifier l'accès, les autorisations, les règles de chargement et de levage | Conditions validées (`LOG-07`) |
| 5 | Préparer le chargement | Inventory / Workshop | Logistics | Sortir le stock, charger, vérifier les quantités et les documents | Bon de sortie (`INV-09`) |
| 6 | Transporter | Logistics | Transporteur | Exécuter la tournée, suivre les incidents, respecter les délais | Livraison en cours (`LOG-04`) |
| 7 | Réceptionner sur site | Projects / Logistics | Quality, Safety | Contrôler la conformité, les quantités et l'état ; signer la réception | Réception chantier (`LOG-05`) |
| 8 | Traiter les écarts | Logistics / Inventory | Quality, Procurement | Déclarer les manques, avaries ou erreurs ; ouvrir une action | Écart tracé |
| 9 | Organiser les retours | Logistics | Inventory, Equipment, Workshop | Récupérer les emballages, matériels, équipements ou chutes | Retour (`LOG-06`) |
| 10 | Enregistrer le coût | Costing | Logistics, Procurement | Imputer le transport et les frais associés à l'affaire et au lot | Coût transport (`CST-02`) |

### 10.6 Résultats

- plan de transport et tournée ;
- colis chargés et documentés ;
- livraison suivie et réceptionnée ;
- écarts et avaries tracés ;
- retours organisés ;
- coût de transport imputé ;
- stock et localisation mis à jour.

### 10.7 Exceptions et cas particuliers

| Cas | Traitement proposé |
| --- | --- |
| Colis non prêt | Reporter, informer Projects et le client, tracer l'impact. |
| Accès chantier impossible | Modifier la tournée, utiliser un point de dépôt, tracer la cause. |
| Avarie ou manque | Constater, photographier, ouvrir un écart, informer Quality/Inventory/Procurement. |
| Retard transporteur | Informer le chantier, replanifier, évaluer l'impact. |
| Livraison partielle | Réception partielle, reliquat planifié, information des domaines. |
| Livraison directe fournisseur | Inventory enregistre, Logistics coordonne, Quality contrôle. |
| Transport exceptionnel | Vérifier les autorisations, les assurances et les moyens de levage. |
| Retour d'équipement | Contrôler l'état, enregistrer l'affectation et la maintenance éventuelle. |

### 10.8 Interactions principales

- Inventory → Logistics : colis, bon de sortie.
- Workshop → Logistics : colis de fabrication.
- Logistics → Projects : statut de livraison, réception site.
- Logistics → Inventory : confirmation, retour, écart.
- Logistics → Costing : coût transport.
- Equipment → Logistics : véhicules et moyens.
- Safety → Logistics : règles d'accès et de chargement.

### 10.9 Points ouverts

Q-19, Q-21, Q-26.

## 11. P09 — Réalisation des travaux sur chantier

### 11.1 Contexte

L'exécution sur chantier couvre les activités de montage, installation, couverture, bardage, maçonnerie, génie civil, serrurerie et menuiseries, ainsi que la coordination des intervenants, des approvisionnements et des contrôles.

### 11.2 Déclencheur

- autorisation de démarrer ;
- mobilisation planifiée ;
- réception des matériaux et matériels ;
- ordre de service du client.

### 11.3 Acteurs

Chargé d'affaires, conducteur de travaux, chef de chantier, équipes, sous-traitants, qualité, sécurité, logisticien, client, maître d'œuvre.

### 11.4 Informations d'entrée

- dossier d'exécution et plans ;
- planning et affectations ;
- matériaux, composants et équipements ;
- plan qualité et plan de prévention ;
- autorisations d'accès et de travail ;
- contraintes du site et du client.

### 11.5 Étapes

| # | Étape | Domaine(s) responsable(s) | Contributeurs (domaines ou acteurs) | Opérations métier | Résultat / interactions |
| --- | --- | --- | --- | --- | --- |
| 1 | Autoriser le démarrage | Projects | Quality, Safety, Budgets | Vérifier les conditions contractuelles, techniques, financières et de sécurité | Autorisation tracée |
| 2 | Mobiliser le chantier | Planning | Workforce, Equipment, Logistics, Safety | Affecter les équipes, installer les moyens, organiser les accès et les zones | Chantier mobilisé (`PLN-03`) |
| 3 | Accueillir et former les intervenants | Safety | Workforce, sous-traitants | Réaliser l'induction, vérifier les habilitations, délivrer les autorisations | Intervenants autorisés (`SAF-08`, `SAF-07`) |
| 4 | Installer les moyens et les stocks de chantier | Projects / Logistics | Inventory, Equipment, Safety | Installer les équipements, zones de stockage, protections et signalisations | Installation prête (`LOG-07`) |
| 5 | Approvisionner le chantier | Inventory / Logistics | Procurement, Workshop | Livrer les matériaux, composants et équipements selon le planning | Matériel disponible (`LOG-04`) |
| 6 | Exécuter les travaux | Projects | Workshop, sous-traitants, Workforce, Equipment | Réaliser les travaux, coordonner les interfaces, respecter les plans et les règles | Travaux exécutés |
| 7 | Contrôler la qualité | Quality | Projects, Workshop, sous-traitants | Réaliser les contrôles, essais et mesures ; ouvrir les NCR | Conformité ou NCR (`QUA-03`, `QUA-04`) |
| 8 | Surveiller la sécurité | Safety | Projects, sous-traitants | Inspecter, corriger, déclarer les incidents, animer la prévention | Sécurité suivie (`SAF-03`, `SAF-04`) |
| 9 | Suivre l'avancement et les temps | Projects / Planning / TimeTracking | Costing | Déclarer l'avancement, pointer les heures, mettre à jour le planning | Avancement et temps (`PLN-06`, `TKT-01`) |
| 10 | Gérer les changements | Projects | Clients, Costing, Budgets, Planning | Identifier les travaux supplémentaires, instruire l'avenant, mesurer l'impact | Avenant ou décision (`PRJ-07`) |
| 11 | Demander la réception | Handover | Projects, Quality | Vérifier l'achèvement et ouvrir la demande de réception | Réception demandée (`HND-01`) |

### 11.6 Résultats

- chantier mobilisé et sécurisé ;
- travaux exécutés selon le périmètre ;
- approvisionnements coordonnés ;
- contrôles qualité et sécurité réalisés ;
- avancement, temps et coûts suivis ;
- changements tracés ;
- achèvement constaté et réception demandée.

### 11.7 Exceptions et cas particuliers

| Cas | Traitement proposé |
| --- | --- |
| Accès chantier refusé ou retardé | Reporter la mobilisation, tracer la responsabilité et l'impact. |
| Conditions météo défavorables | Arrêter ou adapter les travaux, tracer l'impact sur le planning. |
| Matériel manquant | Alerter Inventory/Procurement, replanifier, chercher une substitution. |
| Erreur de plan ou de conception | Arrêter la partie concernée, corriger avec le bureau d'études, tracer l'impact. |
| Sous-traitant défaillant | Appliquer le contrat, remplacer, tracer les coûts et délais. |
| Accident ou incident | Arrêter si nécessaire, sécuriser, déclarer, enquêter. |
| Non-conformité bloquante | Arrêter la partie concernée, ouvrir une NCR, reprendre après validation. |
| Travaux supplémentaires | Ne pas exécuter sans instruction écrite ou avenant, sauf urgence autorisée. |
| Site multi-lots | Suivre l'avancement et les contrôles par lot ou zone. |

### 11.8 Interactions principales

- Projects → Planning : besoin d'exécution, avancement, priorités.
- Planning → Projects : affectations, planning, conflits.
- Safety → Projects : autorisations, incidents, consignes.
- Quality → Projects : conformité, NCR, blocages.
- Inventory / Logistics → Projects : disponibilité et livraison.
- TimeTracking → Projects / Costing : temps et avancement.
- Projects → Handover : demande de réception.

### 11.9 Points ouverts

Q-01, Q-27, Q-28, Q-45, Q-46, Q-47.

## 12. P10 — Suivi des temps, de l'avancement et des coûts

### 12.1 Contexte

Ce processus assure la fiabilité des données de temps, d'avancement et de coût. Il ne se limite pas à la saisie : il couvre la validation, l'imputation, la consolidation, l'analyse des écarts et la replanification.

### 12.2 Déclencheur

- pointage quotidien ou hebdomadaire ;
- fin de période de paie ;
- point d'avancement de chantier ;
- réception d'une commande, d'une facture ou d'un mouvement de stock ;
- clôture mensuelle ou trimestrielle.

### 12.3 Acteurs

Collaborateur, chef d'équipe, chef de chantier, RH, planificateur, chargé d'affaires, contrôleur de gestion, direction, prestataire de paie.

### 12.4 Informations d'entrée

- pointages et feuilles de temps ;
- affectations et activités planifiées ;
- avancement des travaux et des fabrications ;
- commandes, réceptions, consommations et transports ;
- contrats et taux RH ;
- budget et structure analytique ;
- événements de changement.

### 12.5 Étapes

| # | Étape | Domaine(s) responsable(s) | Contributeurs (domaines ou acteurs) | Opérations métier | Résultat / interactions |
| --- | --- | --- | --- | --- | --- |
| 1 | Saisir les temps | TimeTracking | Collaborateurs, chefs d'équipe | Enregistrer les heures, absences, trajets et imputations | Pointages (`TKT-01`) |
| 2 | Valider et verrouiller | TimeTracking | Managers, RH | Vérifier les chevauchements, corriger, valider et verrouiller la période | Temps validé (`TKT-02`, `TKT-04`) |
| 3 | Préparer les variables de paie | Workforce | TimeTracking, prestataire | Consolider les éléments variables, absences et heures supplémentaires | Variables de paie (`WKF-08`) |
| 4 | Mettre à jour l'avancement des activités | Planning | Projects, chefs de chantier | Comparer prévu/réel, mettre à jour les activités et les dates | Avancement planning (`PLN-06`) |
| 5 | Déclarer l'avancement contractuel | Projects | Planning, Quality | Déclarer l'avancement par lot ou phase, valider les jalons | Avancement contractuel (`PRJ-09`) |
| 6 | Enregistrer les coûts | Costing | Procurement, Inventory, Workshop, Equipment, Logistics | Valoriser temps, matière, production, équipements, transport et sous-traitance | Coûts et engagements (`CST-02`, `CST-03`) |
| 7 | Calculer la marge et l'EAC | Costing | Projects, Budgets | Calculer le coût final estimé, la marge et les écarts | Marge et EAC (`CST-05`, `CST-06`) |
| 8 | Analyser le budget | Budgets | Costing, Projects | Comparer budget, engagements, coûts constatés et prévision | Écarts budgétaires (`BUD-04`) |
| 9 | Alerter et décider | Projects | Direction, Costing, Budgets, Planning | Identifier les dérives, décider des actions correctives | Décision et plan d'action |
| 10 | Replanifier | Planning | Projects, Workforce, Equipment, Procurement | Ajuster les activités, les ressources et les délais | Planning révisé (`PLN-01`) |
| 11 | Consolider le reporting | Reporting | Tous | Produire les indicateurs et tableaux de bord | Rapport (`RPT-01`) |

### 12.6 Résultats

- temps validés et verrouillés ;
- variables de paie préparées ;
- avancement planning et contractuel mis à jour ;
- coûts, engagements et marge calculés ;
- écarts budgétaires analysés ;
- alertes et décisions tracées ;
- planning révisé ;
- reporting consolidé.

### 12.7 Exceptions et cas particuliers

| Cas | Traitement proposé |
| --- | --- |
| Pointage manquant | Relancer, bloquer la validation, régulariser avec trace. |
| Imputation erronée | Corriger avant verrouillage ; après verrouillage, réouverture autorisée. |
| Heures supplémentaires | Vérifier les règles, l'autorisation et l'impact paie/coût. |
| Coût non budgété | Alerter, analyser la cause, demander une révision ou une décision. |
| Commande reçue sans engagement | Rapprocher, corriger l'engagement, tracer l'écart. |
| Écart de stock | Analyser, corriger le mouvement, ajuster le coût. |
| Retard d'avancement | Replanifier, informer le client, analyser l'impact contractuel. |
| Période clôturée | Rouvrir avec autorisation et trace, ou passer une régularisation. |

### 12.8 Interactions principales

- TimeTracking → Workforce : temps et absences.
- TimeTracking → Costing : heures validées.
- TimeTracking → Planning : temps réels.
- Costing → Projects / Budgets : coûts, EAC, marges, écarts.
- Budgets → Projects : disponible et alertes.
- Planning → Projects : avancement et dates.
- Reporting ← tous : données consolidées.

### 12.9 Points ouverts

Q-09, Q-10, Q-11, Q-12, Q-13, Q-27, Q-37.

## 13. P11 — Contrôle qualité, sécurité et traitement des non-conformités

### 13.1 Contexte

Ce processus couvre les contrôles techniques et les actions de prévention, ainsi que le traitement des non-conformités et incidents. Quality et Safety sont deux domaines distincts : une non-conformité technique n'est pas un incident de sécurité, et inversement.

### 13.2 Déclencheur

- point de contrôle planifié ;
- début d'une opération critique ;
- inspection sécurité planifiée ;
- incident, accident ou presqu'accident ;
- réclamation client ou réserve ;
- audit interne ou externe.

### 13.3 Acteurs

Responsable qualité, contrôleur qualité, responsable sécurité, préventeur, chef de chantier, responsable atelier, opérateur, sous-traitant, client, organisme de contrôle.

### 13.4 Informations d'entrée

- plan qualité et plan de contrôle ;
- plan de prévention et analyse de risques ;
- spécifications, normes et procédures ;
- résultats d'autocontrôle ;
- qualifications et certificats ;
- constats d'inspection et incidents ;
- réserves ou réclamations.

### 13.5 Étapes

| # | Étape | Domaine(s) responsable(s) | Contributeurs (domaines ou acteurs) | Opérations métier | Résultat / interactions |
| --- | --- | --- | --- | --- | --- |
| 1 | Établir les plans | Quality / Safety | Projects, Workshop | Définir les contrôles, fréquences, critères, risques et mesures de prévention | Plans validés (`QUA-01`, `SAF-02`) |
| 2 | Réaliser les autocontrôles | Workshop / Projects | Quality | Vérifier les caractéristiques avant contrôle formel | Autocontrôles exécutés (traces atelier et chantier) |
| 3 | Réaliser les contrôles qualité | Quality | Workshop, Projects, sous-traitants | Inspecter, mesurer, essayer, enregistrer les résultats | Conformité ou NCR (`QUA-03`, `QUA-04`) |
| 4 | Traiter la non-conformité | Quality | Workshop, Projects, Procurement | Constater, contenir, analyser la cause, décider reprise/refus/dérogation | NCR et action (`QUA-04`, `QUA-05`) |
| 5 | Vérifier l'efficacité | Quality | Workshop, Projects | Contrôler après reprise, clôturer la NCR avec preuve | NCR clôturée |
| 6 | Réaliser les inspections sécurité | Safety | Projects, Workshop, sous-traitants | Inspecter les conditions de travail, les équipements et les comportements | Constat et action (`SAF-03`, `SAF-05`) |
| 7 | Déclarer et investiguer un incident | Safety | Projects, Workforce, témoins | Sécuriser, déclarer, analyser les causes, définir les actions | Incident et actions (`SAF-04`) |
| 8 | Mesurer l'impact | Projects / Planning / Costing | Quality, Safety | Évaluer l'impact sur le délai, le coût, la conformité et la sécurité | Impacts et décisions |
| 9 | Documenter et diffuser | Documents | Quality, Safety, Handover | Archiver les preuves, certificats, rapports et actions | Dossier de preuve (`DOC-01`) |
| 10 | Consolider les indicateurs | Reporting | Quality, Safety | Produire les taux de conformité, NCR, incidents et actions | Tableau de bord (`RPT-03`) |

### 13.6 Résultats

- contrôles qualité réalisés et tracés ;
- non-conformités traitées et clôturées ;
- inspections sécurité réalisées ;
- incidents déclarés, investigués et suivis ;
- actions correctives et préventives suivies ;
- preuves documentaires disponibles ;
- impacts coût/délai évalués ;
- indicateurs consolidés.

### 13.7 Exceptions et cas particuliers

| Cas | Traitement proposé |
| --- | --- |
| Contrôle non conforme | Ouvrir une NCR, contenir, analyser, reprendre ou refuser. |
| NCR répétitive | Analyse de cause racine, action systémique, revue de processus. |
| Accident grave | Arrêt, secours, préservation des lieux, enquête, obligations légales. |
| Presqu'accident | Déclarer et traiter comme un signal précurseur. |
| Sous-traitant non conforme | NCR, action, évaluation fournisseur, mesure contractuelle. |
| Réserve client | Handover porte la réserve ; Quality traite la cause technique. |
| Organisme de contrôle | Coordonner la visite, fournir les preuves, traiter les écarts. |
| Arrêt de chantier | Décision Projects/Direction, impacts planning et coût. |

### 13.8 Interactions principales

- Quality → Workshop / Projects : résultats, NCR, blocages.
- Safety → Projects / Workshop : inspections, incidents, actions.
- Quality / Safety → Documents : preuves et rapports.
- Quality → Handover : conformité et NCR clôturées.
- Quality → Procurement : performance fournisseur.
- Quality / Safety → Costing : coûts de non-qualité et de prévention.
- Safety → Workforce : formations et restrictions.

### 13.9 Points ouverts

Q-15, Q-16, Q-23, Q-25, Q-29, Q-30.

## 14. P12 — Réception, réserves, DOE et clôture

### 14.1 Contexte

La réception contractuelle clôt la relation d'exécution avec le client. Elle ne se confond ni avec le contrôle qualité technique ni avec la clôture administrative de l'affaire. Handover porte la réception, les réserves, le DOE et les garanties ; Projects porte la clôture de l'affaire ; Costing porte la clôture des coûts.

### 14.2 Déclencheur

- achèvement des travaux ou d'une partie ;
- demande du client ;
- réception partielle par lot ou zone ;
- levée des réserves ;
- fin de la période de garantie.

### 14.3 Acteurs

Responsable réception/handover, chargé d'affaires, chef de chantier, qualité, gestionnaire documentaire, contrôleur de gestion, client, maître d'ouvrage, maître d'œuvre.

### 14.4 Informations d'entrée

- périmètre et lots concernés ;
- preuves de conformité et NCR clôturées ;
- plans conformes à l'exécution et documents du DOE ;
- réserves éventuelles ;
- garanties fournisseurs et sous-traitants nécessaires aux garanties clientes ;
- situation des coûts et des engagements.

### 14.5 Étapes

| # | Étape | Domaine(s) responsable(s) | Contributeurs (domaines ou acteurs) | Opérations métier | Résultat / interactions |
| --- | --- | --- | --- | --- | --- |
| 1 | Constater l'achèvement | Projects | Quality, chef de chantier | Vérifier la fin des travaux, les autocontrôles et les prérequis | Achèvement constaté |
| 2 | Réaliser les contrôles finaux | Quality | Projects, Workshop | Contrôler la conformité finale, clôturer les NCR bloquantes | Dossier de conformité (`QUA-03`, `QUA-04`) |
| 3 | Préparer le DOE | Handover | Documents, Projects, Quality | Identifier les pièces attendues, vérifier la complétude et les versions | DOE en préparation (`HND-04`) |
| 4 | Demander la réception | Handover | Projects, Clients | Proposer une date, un périmètre et les représentants | Réception demandée (`HND-01`) |
| 5 | Inspecter avec le client | Handover | Projects, Quality, Client | Visiter, vérifier, constater les écarts et les réserves | Constat de réception |
| 6 | Prononcer la réception | Handover | Client, Projects | Rédiger le PV, lister les réserves, fixer les délais | PV et réserves (`HND-01`, `HND-02`) |
| 7 | Traiter les réserves | Quality / Workshop / Projects | Handover | Corriger, reprendre, documenter, demander la levée | Travaux de levée |
| 8 | Vérifier et lever les réserves | Handover | Client, Quality | Contrôler la preuve, prononcer la levée ou refuser | Levée (`HND-03`) |
| 9 | Remettre le DOE et les garanties | Handover | Documents, Clients | Compiler, diffuser, faire accuser réception, remettre les garanties clientes | DOE et garanties clientes (`HND-04`, `HND-05`) |
| 10 | Clôturer contractuellement | Handover | Projects, Clients | Vérifier les conditions, prononcer la clôture contractuelle | Clôture contractuelle |
| 11 | Clôturer les coûts | Costing / Budgets | Projects, Procurement | Solder les engagements, calculer la marge finale, clôturer la période | Marge finale (`CST-05`) |
| 12 | Clôturer l'affaire | Projects | Handover, Costing, Budgets | Vérifier les conditions, clôturer l'affaire et les lots | Affaire clôturée (`PRJ-01`) |
| 13 | Capitaliser | Reporting | Projects, Quality, Safety | Produire les indicateurs et retours d'expérience | Rapport de clôture (`RPT-01`) |

### 14.6 Résultats

- achèvement constaté ;
- contrôles finaux et NCR clôturées ;
- DOE complet et diffusé ;
- réception prononcée avec ou sans réserves ;
- réserves levées et vérifiées ;
- garanties constituées ;
- clôture contractuelle, clôture des coûts et clôture d'affaire ;
- retour d'expérience.

### 14.7 Exceptions et cas particuliers

| Cas | Traitement proposé |
| --- | --- |
| Réserves non levées | Ne pas clôturer ; suivre les délais et les responsabilités. |
| DOE incomplet | Bloquer la clôture contractuelle ; lister les pièces manquantes. |
| Client indisponible | Reporter la réception, tracer les relances et l'impact. |
| Réception partielle | Prononcer par lot ou zone, avec réserves et dates distinctes. |
| Refus de réception | Documenter les motifs, traiter, reproposer. |
| Défaut latent après réception | Ouvrir une garantie ou une réclamation ; hors périmètre contentieux. |
| Garantie fournisseur expirée | Identifier l'impact, alerter Procurement, documenter. |
| Litige financier | Hors périmètre des 18 domaines ; escalader. |

### 14.8 Interactions principales

- Projects → Handover : demande, périmètre, lots, client.
- Quality → Handover : conformité, NCR clôturées.
- Documents → Handover : pièces et versions du DOE.
- Handover → Projects : réception, réserves, levées, PV.
- Handover → Clients : PV, DOE, garanties.
- Handover → Costing : dates de réception et de garantie.
- Handover → Quality : réserves à traiter.
- Procurement → Handover : garanties fournisseurs.

### 14.9 Points ouverts

Q-53, Q-30, Q-31, Q-44.

## 15. Vues transverses

### 15.1 Les deux parcours commerciaux

| Étape | Parcours complet (P01) | Parcours direct (P02) |
| --- | --- | --- |
| Origine | Prospect ou demande de prix | Commande ou ordre de service |
| Étude | Réalisée avant le devis | Réalisée après réception, ou partiellement disponible |
| Devis | Versionné et validé | Absent, partiel ou remplacé par un tarif/contrat |
| Client | Prospect converti à l'acceptation | Identifié à réception de la commande |
| Budget | Établi après acceptation | Provisoire, puis confirmé |
| Risque principal | Étude insuffisante ou marge faible | Périmètre ou délai mal connus |
| Domaine pilote | Projects | Projects |

### 15.2 Les deux configurations d'atelier

| Configuration | Responsables de l'ordre | Responsables de l'exécution | Responsables de la matière | Responsables du contrôle |
| --- | --- | --- | --- | --- |
| Atelier interne | Workshop | Workshop | Inventory | Quality |
| Fabrication externe | Procurement (commande) / Workshop (dossier technique) | Sous-traitant | Inventory ou sous-traitant selon le contrat | Quality / Workshop |

### 15.3 Les deux configurations de sous-traitance

| Configuration | Relation commerciale | Commande | Exécution | Réception |
| --- | --- | --- | --- | --- |
| C2ME donneur d'ordre | Procurement / sous-traitant | Procurement | Sous-traitant | Inventory / Quality / Workshop |
| C2ME sous-traitant | Clients / donneur d'ordre | Projects (commande reçue) | Projects / Workshop | Handover (réception par le donneur d'ordre) |

### 15.4 Flux physiques et flux financiers

| Flux | Domaines pilotes | Domaines consommateurs |
| --- | --- | --- |
| Besoin matière | Workshop / Projects | Procurement, Inventory, Costing |
| Commande | Procurement | Inventory, Costing, Budgets, Planning |
| Réception | Inventory | Quality, Costing, Procurement |
| Stock et réservation | Inventory | Workshop, Projects, Planning |
| Fabrication | Workshop | Inventory, Quality, Logistics, Costing |
| Transport | Logistics | Inventory, Projects, Workshop, Costing |
| Consommation | Inventory / Workshop | Costing |
| Coût et marge | Costing | Projects, Budgets, Reporting |

## 16. Références

- [`domain-responsibilities.md`](domain-responsibilities.md) — catalogue des 18 domaines.
- [`business-objects.md`](business-objects.md) — catalogue des objets métier.
- [`domain-interactions-register.md`](domain-interactions-register.md) — registre des interactions.
- [`domain-boundary-decisions.md`](domain-boundary-decisions.md) — chevauchements et questions ouvertes.
- [`domain-conventions.md`](domain-conventions.md) — conventions internes CHAN-27.
- [`domain-communication.md`](domain-communication.md) — contrats synchrones CHAN-28.
