# Analyse du programme — METI-UniPods, Cohort One Bootcamp

*Addis-Abeba, Ethiopian AI UniPod · 9–20 novembre 2026*
*Source : « METI Addis Residency Concept Note (4).pdf » (20 pages). État au 22 octobre 2026 — arrivée le dimanche 8 novembre, soit J-17.*

Légende : **[Note]** = dit par le Concept Note · **[Inférence]** = déduit par nous, à confirmer · **[À vérifier]** = non établi.

---

## 0. L'essentiel

1. **Ce n'est pas une formation, c'est un atelier de preuves.** Deux semaines, dix jours ouvrés, un livrable obligatoire et un critère de qualité par jour, un dossier « vérifié » en sortie, un Demo Day devant investisseurs, acheteurs et partenaires japonais. [Note]
2. **Semaine 1 : rendre le produit fiable et adapté au terrain** (validation client, architecture et MLOps, localisation et hors-ligne, IA responsable). **Semaine 2 : en faire une entreprise** (modèle économique, vente institutionnelle, financement, sprint intégré, démo). [Note]
3. **Le progrès est mesuré** : un diagnostic Abaca VIRAL le jour 1, un diagnostic final le jour 10. [Note] Abaca est la version en ligne du cadre VIRAL (Village Capital), une auto-évaluation sur huit domaines. [Web, à vérifier dans Abaca]
4. **Le temps est compté.** Journées de 08:30 à 17:00, deux veillées, et des « sprints techniques » qui tiennent dans des plages de 1 h 30. [Note] **Conséquence [Inférence] : l'ingénierie lourde se fait AVANT le 8 novembre.** À Addis, on valide, on mesure, on rédige, on négocie.
5. **Chaque affirmation sera testée** : jour 2 (terrain), jour 5 (red-teaming), jour 8 (due diligence), jour 10 (démo). [Note] Toute formule non prouvée dans notre propre dossier est un risque, pas un atout.
6. **Forgeron a un atout rare** — un produit physique, une IA qui fonctionne hors-ligne, des mesures consignées dans le dépôt — **et trois faiblesses visibles** : l'équipe (un fondateur, un rôle commercial vacant), les preuves de marché (hypothèses, pas de données), la fiabilité et la sécurité du démonstrateur. Détail dans `02-ecart-forgeron.md`.

---

## 1. Le programme en chiffres [Note]

| | |
|---|---|
| Candidatures | 670, venues de 24 pays en environ trois semaines |
| Présélection / entretiens | 574 / 461 (un par un, pour vérifier chaque produit) |
| Cohorte One | 244 innovateurs sélectionnés |
| Résidence d'Addis | **50 équipes**, soit ≈ 7 % des candidats |
| Stade des produits | 41,4 % MVP · 35,7 % prototype · 23,0 % early-stage |
| Femmes | 20,9 % |
| Thèmes dominants | santé, éducation, inclusion financière |
| Parcours en parallèle | MIT Emerging Talent (300 licences, 270 000 USD) · Wadhwani, 14 semaines · programme d'IA appliquée de l'EAII ; UniPods résidents en appui local |

**Lecture [Inférence].** Forgeron se situe entre *prototype* et *MVP* (machine construite, application et agent fonctionnels, aucun utilisateur payant documenté). Le thème « fabrication / automatisation industrielle » n'est pas dans le trio dominant : c'est un **point de différenciation** (un produit physique parmi des logiciels) et un **risque** (les mentors et investisseurs raisonnent surtout en IA logicielle ; il faudra expliquer pourquoi le matériel n'est pas un frein).

---

## 2. La logique du programme [Note]

- **Constat de départ** : après le bootcamp de Guinée, les innovateurs sortaient avec de meilleures compétences mais « sans modèle économique validé, sans client payant, sans partenaire d'adoption, sans infrastructure pour continuer ». Le goulot n'est plus d'apprendre l'IA, c'est de construire avec elle.
- **Ce que la résidence cible** : la validation du modèle économique pour les marchés africains et l'accès aux investisseurs (premières priorités du recensement des besoins), puis partenariats, vente institutionnelle, prix.
- **Ce qu'elle ne refait pas** : les bases d'IA du MIT, le tronc commun de Wadhwani. Le jour 1 contient d'ailleurs une session « pont » où chacun relie ce qu'il a déjà appris aux lacunes à combler.
- **Ce qui ne se fait qu'en présentiel** : terrain client, revues d'architecture au tableau, red-teaming, simulations d'acheteurs, rencontres investisseurs pré-appariées, accès aux laboratoires de calcul et de robotique.
- **Le produit final** : un dossier vérifié — preuves de validation, architecture cible, registre des risques d'IA responsable, économie unitaire, plan de mise sur le marché, dossier d'investissement, plan à 90 jours.
- **Pourquoi Addis** : centre d'excellence IA du réseau (calcul, laboratoire de robotique, faculté de l'EAII sur place), siège de l'Union africaine, auberges cédées par le gouvernement éthiopien.

---

## 3. Les objectifs, et ce qu'ils demandent concrètement

### Techniques (piste IA)

| # | Objectif [Note] | Lecture pour Forgeron [Inférence] |
|---|---|---|
| 1 | Passer du prototype au grade production : architecture cible, chaîne de déploiement, MLOps proportionné (versions, tests, surveillance, ré-entraînement, retour arrière) | On attend des **diagrammes, une liste de contrôle MLOps, un backlog** — pas une migration vers le cloud. |
| 2 | Amélioration **mesurable** (précision, latence, fiabilité ou coût d'inférence) via un sprint supervisé sur le calcul et le labo de robotique | Il faut **un chiffre avant / après**, reproductible, avec la configuration documentée (« les fondateurs documentent les configurations, résultats de tests et décisions de déploiement »). |
| 3 | Adapter aux conditions africaines : interfaces vocales et langues locales, faible connectivité et **hors-ligne d'abord**, modèles légers et embarqués, préparation des données | C'est le **cœur de Forgeron** — mais il faut des *preuves par langue*, pas seulement une liste de langues. |
| 4 | IA responsable dès la conception : évaluation des risques, red-teaming, tests de biais et de sécurité, gouvernance des données, vie privée, confiance des utilisateurs | Registre de risques, tests, mesures de confiance ; **red-team en direct le jour 5**. Pour un agent qui commande une machine, les dommages sont physiques : l'exigence est plus haute qu'ailleurs. |
| 5 | Optimiser l'infrastructure et le coût de calcul pour rester abordable à l'échelle | Coût par heure d'opérateur et par atelier ; exigences matérielles par palier. |

### Venture et marché

| # | Objectif [Note] | Lecture pour Forgeron [Inférence] |
|---|---|---|
| 1 | Valider modèle économique, prix et économie unitaire face aux réalités clients et distribution | Prix et coûts réels, pas des estimations : disposition à payer, forme de financement, qui décide. |
| 2 | Construire chemins de mise sur le marché, de partenariat et d'investissement, dont co-développement et pilotes avec des entreprises japonaises | Un pilote concret (lieu, durée, indicateur) vaut plus qu'un intérêt général. |
| 3 | Mentorat durable et responsabilité entre pairs | Choisir à l'avance **quel mentor** demander (voir §9). |

---

## 4. Calendrier — heures d'Addis (UTC+3) ; Bamako = UTC+0, soit 3 h de moins

| Date | Jour | Thème [Note] | Livrable [Note] | Revue |
|---|---|---|---|---|
| Dim. 8 nov. | — | Arrivée et enregistrement | — | |
| Lun. 9 nov. | **J1** | Orientation, diagnostics, appariement des mentors | Énoncé du défi de la résidence · fiche de base (scorecard) | Mentor, J1 |
| Mar. 10 nov. | **J2** | Validation du marché, terrain client | Carte problème–preuves · proposition de valeur révisée | J2 et J7 |
| Mer. 11 nov. | **J3** | Architecture de production, intégration logicielle, MLOps | Architecture cible · backlog du sprint technique | J3 et J9 |
| Jeu. 12 nov. | **J4** | Localisation, IA vocale et langues locales, hors-ligne | Amélioration du produit pour les utilisateurs cibles | J4 |
| Ven. 13 nov. | **J5** | IA responsable, gouvernance des données, red-teaming · veillée 17:15–18:15 | Registre des risques · dossier de preuves de la semaine 1 | J5 |
| 14–15 nov. | — | Repos ; accès supervisé au labo et au calcul (facultatif) | | |
| Lun. 16 nov. | **J6** | Modèles économiques, prix, coûts de l'IA, économie unitaire | Modèle d'économie unitaire · prévision de trésorerie | J6 |
| Mar. 17 nov. | **J7** | Mise sur le marché, vente institutionnelle, tables rondes d'acheteurs | Plan GTM · pipeline de partenariats | J7 et J10 |
| Mer. 18 nov. | **J8** | Paysage du financement, due diligence, permanences d'investisseurs · veillée 17:15–18:15 | Stratégie de financement · supports de pitch à jour | J8 et J9 |
| Jeu. 19 nov. | **J9** | Sprint de venture intégré, cliniques de spécialistes, répétition générale | Dossier de venture complet | J9 |
| Ven. 20 nov. | **J10** | **Demo, Deal and Partnership Day** | Pipeline d'opportunités qualifiées · plan à 90 jours | J10 |
| Sam. 21 nov. | — | Départs | | |

*Note de lecture.* L'annexe 1 intitule le jour 6 « Product Architecture… » : c'est un copier-coller du jour 3. Son contenu (modèles économiques, prix, économie unitaire) est bien celui du tableau principal.

**Rythme quotidien** [Note] : 08:30–17:00 — point de diagnostic le matin, masterclass, atelier appliqué ou clinique, laboratoire produit ou terrain l'après-midi, mentorat, puis clôture quotidienne où chacun **remet ses livrables**.

**Fuseaux.** 08:30 à Addis = 05:30 à Bamako ; 17:00 = 14:00. Le terrain du jour 2 (13:30–15:00) correspond à 10:30–12:00 à Bamako : les entretiens *à distance* avec des ateliers maliens sont donc possibles, la note autorisant « en présentiel ou à distance ».

### Le jour 10 en détail [Note]

| Heure | Séance |
|---|---|
| 08:30–09:00 | Tests de démo et vérification technique |
| 09:00–09:30 | Briefing fermé des investisseurs et partenaires |
| 09:30–10:45 | **Bloc de pitchs I** (pitchs thématiques, démos en direct) |
| 11:00–12:15 | **Bloc de pitchs II** |
| 12:15–13:00 | Tables rondes d'acheteurs institutionnels |
| 14:00–15:30 | **Rencontres 1:1 pré-appariées** (demandes documentées, suites notées) |
| 15:45–16:30 | Clinique d'action : transformer les retours en plan à 90 jours |
| 16:30–17:00 | Évaluation finale et engagements des mentors |
| 17:00–17:30 | Clôture |

---

## 5. Les dix livrables et leurs critères de qualité (annexe 2) [Note]

| Livrable | Critère minimal | Revue |
|---|---|---|
| Énoncé du défi de la résidence | Questions précises — technique, marché, capital — avec résultats souhaités mesurables | J1 |
| Note de validation du marché | Preuves issues d'échanges clients ou acheteurs ; hypothèses révisées ; prochain test | J2, J7 |
| Architecture technique et sprint | Architecture actuelle et cible, risques, actions MLOps, backlog avec responsables | J3, J9 |
| Amélioration localisation / faibles ressources | Décision produit ou prototype démontrable, relié aux utilisateurs et au contexte | J4 |
| Dossier IA responsable | Registre des risques, mesures d'atténuation, liste de gouvernance des données, mesures de confiance | J5 |
| Modèle économique et financier | Prix, économie unitaire, moteurs de coût, trésorerie | J6 |
| GTM et pipeline de partenariats | Segments, canaux, comptes cibles, partenaires qualifiés, prochaines actions | J7, J10 |
| Dossier d'investissement | Stratégie de financement, demande cohérente, deck, one-pager, liste data room | J8, J9 |
| Démo produit | Démonstration fiable, reliée à la valeur client et aux preuves | J10 |
| Plan d'exécution à 90 jours | Jalons, responsables, dates, indicateurs, dépendances, soutien requis | J10 |

---

## 6. Comment la résidence sera mesurée [Note]

| Résultat | Indicateur | Preuve |
|---|---|---|
| Amélioration du produit | Équipes ayant terminé une amélioration ou un déploiement **testé** | Démo, vérification par un mentor |
| Validation du marché | Équipes ayant mené des échanges acheteurs et révisé leurs hypothèses | Comptes rendus d'entretiens |
| IA responsable | Équipes avec registre des risques et plan d'atténuation | Dossier IA responsable |
| Maturité commerciale | Équipes avec prix, économie unitaire et plan GTM | Portefeuille de venture |
| Maturité d'investissement | Équipes avec une demande crédible et une liste data room | Revue de maturité investisseur |
| Accès au marché et au financement | **Nombre et qualité** des échanges avec investisseurs, acheteurs, partenaires, dont japonais ; plans à 90 jours approuvés par un mentor | Suivi des rencontres · plan d'action final |
| Soutien durable | Relations mentors et pairs actives après la résidence | Registres de suivi |

**Abaca VIRAL.** Le jour 1 (13:30–14:30), chacun remplit une fiche structurée et « revoit sa base Abaca VIRAL » ; le jour 10, un diagnostic final produit la fiche de sortie. [Note] **[Inférence]** : le gain de niveaux entre les deux sera l'indicateur de succès le plus visible. À ce stade, retrouver la base Abaca remplie lors de la candidature et relire les critères de chaque domaine. D'après les recherches web, VIRAL (Venture Investment Readiness Assessment Levels) couvre huit domaines — équipe, problème et vision, proposition de valeur, produit, marché, modèle économique, passage à l'échelle, sortie. **[À vérifier]** dans Abaca : liste exacte et niveaux.

---

## 7. Infrastructure et mentorat [Note]

- **Calcul et labo de robotique** : accès alloué selon le besoin du sprint technique de chaque équipe ; le personnel du labo encadre l'usage ; les fondateurs documentent configurations, résultats et décisions. Le week-end des 14–15 novembre est prévu pour un accès facultatif et supervisé.
- **Mentorat** : un mentor principal par startup pendant les deux semaines ; des mentors spécialistes (ingénierie IA, MLOps, intégration logicielle, IA responsable, produit, accès au marché, finance, investissement, droit) ; des **conseils de pairs de quatre à six fondateurs, qui continuent après la résidence**.

**Lecture [Inférence].** Le week-end de calcul est la seule fenêtre longue : tout ce qui demande des heures de GPU (évaluations lourdes, ajustement fin) doit être **scripté et testé en petit avant le départ**. Le mentor principal est la ressource la plus rare : savoir à l'avance quel profil demander (§9).

---

## 8. Lectures stratégiques — ce que le texte ne dit pas, mais implique

1. **Le calendrier est un tableau de bord.** Chaque jour a un livrable remis le soir. Qui arrive avec des brouillons déjà structurés selon les critères de l'annexe 2 passe le temps en salle à les confronter, pas à les écrire.
2. **Le sprint technique est un test de discipline.** Une plage de 1 h 30 le jour 4, un sprint intégré le jour 9, un week-end de calcul. Il faut choisir **un seul** changement mesurable, avec son protocole d'évaluation prêt à tourner.
3. **La base et la fiche finale imposent de choisir ses batailles.** En douze jours, les domaines qui bougent le plus sont le marché (entretiens), le modèle économique (calculs) et le produit (preuves). L'équipe bouge par une décision nette (recruter ou s'associer un profil commercial).
4. **Le Demo Day est court [Inférence].** Deux blocs de pitchs de 75 minutes pour une cohorte de cinquante : de l'ordre de trois minutes par équipe, démo comprise. Le vrai lieu de conversion est la plage de rencontres 1:1 : il faut des **demandes précises et documentées**, et un dossier à laisser.
5. **Les chiffres sont une arme à double tranchant.** La note promet aux investisseurs et partenaires japonais des ventures « dont les affirmations ont été testées ». Les mesures honnêtes du dépôt sont un avantage ; une formule trop forte est fatale (voir `02-ecart-forgeron.md`, §6).
6. **Le cadre « architecture / MLOps / IA responsable » est écrit pour de l'IA logicielle.** Un agent qui commande une machine doit traduire : « déploiement » = application + machine + nœud d'inférence local ; « défaillance » inclut le dommage physique. C'est plus exigeant — et c'est précisément ce qui peut distinguer Forgeron.
7. **Le laboratoire de robotique est une opportunité unique si l'on décide AVANT ce qu'on y fait** : banc d'essai de la carte d'interface, essai de la machine, mesure du modèle sur GPU.
8. **Le Japon.** Attente explicite de co-développement et de pilotes avec des entreprises japonaises. Les entreprises présentes ne sont pas nommées **[À vérifier]**. Piste naturelle : la coopération japonaise en Éthiopie dans la formation technique et la productivité (JICA : programme Kaizen depuis 2009 ; centre TICAD de développement des ressources humaines inauguré en 2023) — à confirmer avec les organisateurs.
9. **Les pairs comptent.** Le conseil de quatre à six fondateurs dure au-delà de la résidence : choisir un conseil complémentaire (finance, vente) plutôt que des profils semblables.
10. **Un seul représentant [Mémoire du dossier d'information, à confirmer pour la résidence]**, le reste de l'équipe en soutien à distance, avec 3 h de décalage. Prévoir des plages de disponibilité et un canal fixe.

---

## 9. Questions à poser aux organisateurs avant le départ

1. **Démo (J10)** : durée par équipe, format (démo en direct, vidéo autorisée ?), branchements, Wi-Fi fourni ou non, matériel d'affichage.
2. **Calcul** : types de GPU et VRAM, quotas, durée des sessions, accès à distance ou sur place, environnement (conteneurs ?), heures du week-end.
3. **Laboratoire de robotique** : horaires, équipements (fraiseuse CNC, imprimantes 3D, bancs électroniques ?), consignes de sécurité ; peut-on apporter une carte, un banc, une machine ? formalités douanières ?
4. **Remises quotidiennes** : plateforme, format, langue, confidentialité.
5. **Mentors** : profils ; possibilité de demander un mentor « fabrication / machines-outils » et un mentor « évaluation de modèles ».
6. **Partenaires japonais et investisseurs** : secteurs, tickets, intérêts — pour calibrer les demandes.
7. **Confidentialité et propriété intellectuelle** pour les sessions fermées ; politique de photos et vidéos ; le dépôt de Forgeron étant public.
8. **Terrain du jour 2** : accompagnement pour trouver des ateliers ou instituts techniques à Addis ; entretiens à distance acceptés (la note le dit).
9. **Évaluation** : comment la fiche finale est notée ; quel suivi après la résidence ; accès aux pôles timbuktoo.
10. **Logistique** : hébergement, transports, repas, électricité (coupures ?), connexion, lettre d'invitation, prise en charge du voyage.

## 10. Logistique à vérifier (hors Concept Note) — **[À vérifier]** auprès des organisateurs et des autorités

- **Visa éthiopien** (e-visa ?) et délais ; lettre d'invitation.
- **Certificat de vaccination** (fièvre jaune) exigé ou non selon la provenance ; assurance santé et voyage.
- **Dates de vol** : arrivée le 8 novembre, départ le 21 ; retour possible dès le 20 au soir ? (la clôture est à 17:30).
- **Matériel** : ordinateur de démo **et de secours**, chargeurs, adaptateurs et multiprises, batterie externe, **routeur de voyage**, données mobiles locales ; copie hors-ligne de tout ce qui sert à la démo ; déclaration douanière pour l'électronique.
- **Fuseau** : UTC+3 ; le reste de l'équipe est en UTC+0.

---

## Sources

- *METI Addis Residency Concept Note (4).pdf* — document fourni, 20 pages.
- VIRAL / Abaca — résumé de recherche web citant [Maine Technology Institute](https://mainetechnology.org/?p=11197) (cadre développé à l'origine par Village Capital). Non vérifié sur Abaca lui-même.
- Lancement de l'AI UniPod d'Addis-Abeba (16 février 2026) — [UNDP Éthiopie](https://www.undp.org/ethiopia/press-releases/ethiopia-launches-ai-unipod) et [allAfrica](https://allafrica.com/stories/202602170117.html). Aucune source publique ne confirme les dates de novembre ; seul le Concept Note fait foi.
- Coopération japonaise en Éthiopie — [JICA, TICAD HRD Center (2023)](https://www.jica.go.jp/english/information/press/2023/20231013_31.html) ; programme Kaizen, d'après les résultats de recherche.
