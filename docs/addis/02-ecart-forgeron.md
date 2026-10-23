# Forgeron face au programme — écarts, preuves, affirmations à corriger

*État au 22 octobre 2026. Chaque fait renvoie à un fichier, une commande ou une mesure du dépôt. Ce qui n'a pas pu être vérifié est marqué **[À vérifier]**. Les jugements sont des jugements.*

Lire d'abord `01-analyse-programme.md`.

---

## 1. Forgeron aujourd'hui — faits vérifiés

| Élément | Valeur | Où le vérifier |
|---|---|---|
| Application | **196 fichiers Dart, 52 627 lignes** | `find lib -name '*.dart'` |
| Pipeline CAO (Python) | 3 508 lignes | `pipeline/*.py` |
| Tests | **30 fichiers, 342 tests**, suite complète verte au 21 oct. (dont 10 tests « live » contre un vrai modèle local) | `flutter test` |
| Historique | 116 commits depuis le 4 mai 2026 | `git log` |
| Agent IA | **38 outils**, deux fournisseurs interchangeables (Gemini en ligne, modèle local Ollama) | `lib/application/services/ai_agent_tools.dart`, `local_ai_agent_service.dart` |
| Hors-ligne | Seul appel externe de l'application : le fournisseur IA distant, optionnel. Visualiseur 3D embarqué. Mode simulation sans matériel. | `ARCHITECTURE.md` §1 · `lib/data/mock/` |
| Langues d'interface | **16** : français, anglais, arabe, swahili, afrikaans, amharique, haoussa, yoruba, igbo, zoulou, somali, kinyarwanda, shona, lingala, wolof, malgache. **Pas de bambara.** | `lib/core/i18n/app_language.dart` |
| Voix | Dictée et lecture, avec appariement de langue selon ce que l'appareil sait faire | `lib/core/utils/voice_locale.dart` |
| Machine | Trunnion X/Y/Z/A/C, courses X 80 · Y 150 · Z 110 mm ; dôme R20 usiné en 3 h 35 ; trois pannes profondes diagnostiquées | `ARCHITECTURE.md` §5 |
| Mesures de l'agent local | Réussite de l'appel d'outil : 28/30 (4 000 car. d'historique), 29/30 (12 000), 18/30 (22 000) ; ~50 % sur une discussion extrême ; contexte Ollama par défaut 4 096 ; 6 800 tokens fixes dont ~4 800 pour les 38 outils | `ARCHITECTURE.md` §1 |
| Matériel | Dossier de conception de la carte d'interface Rev 2.0 (nomenclature sans prix) | `hardware/` |
| Documents antérieurs | Pitch deck FR 12 diapos, one-pager, page web, fiche d'entretien, dossier de candidature, export Wadhwani, plan de travail chiffré | branche distante `claude/meti-unipods-ai-programme-g1qdgq` (dossier `scratch/`) |

**Ce qui n'existe pas** : fichier `LICENSE` ou `NOTICE` ; intégration continue (`.github/`) ; télémétrie ou rapport de plantage ; sauvegarde des préférences ; dossier `docs/` (créé avec ce travail) ; collecte de données d'usinage (« fiche d'usinage », phase 0 du `PLAN-IA.md`) ; les briques d'optimisation du `PLAN-OPTIMISATION.md` (`MachineLimits`, `EnvelopeGuard`, `FeedTruth`, `TimeModel`). Build Android récent : **[À vérifier]** (aucune sortie APK dans cet espace de travail).

---

## 2. Objectifs techniques — écarts

### 2.1 Grade production et MLOps

| | |
|---|---|
| **Existe** | Architecture en couches (`domain / data / application / presentation`) · 342 tests · agent indépendant du fournisseur (`AiBackend`) · garde-fous documentés avec la panne qui les a motivés (`ARCHITECTURE.md` §3) · builds Windows (Debug et Release) |
| **Écart** | Aucune intégration continue · aucun rapport de plantage (le plantage du build Release du 21 oct. n'a été vu que par hasard dans l'observateur d'événements) · préférences dans **un seul JSON non atomique** (perte totale le 21 oct.) · prompt et schémas d'outils non versionnés ni évalués séparément du code · le « modèle » est un nom (`forgeron-qwen`) sans numéro de version · le retour arrière (Gemini ↔ local) est manuel et non documenté · aucune surveillance de qualité sur le terrain |
| **Action** | CI minimale (analyse + tests sans modèle) · « fiche de version » du triplet (modèle, prompt, outils) · export de diagnostic · préférences atomiques avec copie de secours · schémas courant et cible · registre des défaillances · liste de contrôle MLOps |
| **Priorité** | P0 (préférences, plantage) · P1 (schémas, registre, liste) |

### 2.2 Amélioration mesurable

| | |
|---|---|
| **Existe** | Une vraie culture de la mesure : comptages et rejeux consignés dans `ARCHITECTURE.md` |
| **Écart** | Mesures ponctuelles, **non rejouables par un tiers** · aucun jeu de scénarios figé · aucune comparaison de modèles · latence et coût non mesurés de façon systématique · aucune expérience d'amélioration menée à son terme |
| **Action** | **Forgeron-Bench** : scénarios figés, lanceur en une commande, rapport Markdown + JSON · référence (baseline) avant le 8 nov. · expérience 1 : routage d'outils (n'exposer que les outils utiles au tour) · expérience 2 : taille de modèle · expérience 3 (calcul UniPod) : ajustement fin · un chiffre avant / après |
| **Priorité** | P1 |

### 2.3 Conditions africaines : langues, hors-ligne, léger, données

| | |
|---|---|
| **Existe** | Hors-ligne par construction · modèle local · 16 langues d'interface dont l'amharique · dictée et lecture · mode simulation |
| **Écart** | **Bambara absent** : c'est la langue d'atelier du marché d'origine · **qualité des traductions non attestée** (tables produites par scripts, `tool/i18n_*.py`, sans relecture par locuteur natif consignée) — risque de sécurité sur les libellés critiques (arrêt d'urgence, alarmes, broche) · **compétence de l'agent par langue jamais mesurée** (un 7B local est faible hors français et anglais) · **voix hors-ligne non garantie** : les paquets de langue Android ne s'installent pas par programme ; l'amharique hors-ligne n'est pas confirmé ; la reconnaissance du bambara reste immature (taux d'erreur de mots de l'ordre de 30 à 47 % dans les travaux récents, d'après la littérature de 2026) · le modèle local suppose un PC à GPU (coût, énergie, coupures de courant) · aucune donnée d'usinage collectée |
| **Action** | Audit des libellés critiques avec des locuteurs natifs · mesure **par langue** dans le Bench · choix du sprint du jour 4 (A : commandes bambara/français en vocabulaire fermé ; B : amharique relu par des pairs ; C : essai vocal hors-ligne sur le téléphone) · essai d'un modèle léger sans GPU · collecte minimale (fiche d'usinage) |
| **Priorité** | P1 (audit, mesure) · P3 (bambara, collecte) |

### 2.4 IA responsable

| | |
|---|---|
| **Existe** | Règle « l'agent ne produit aucune coordonnée » (`ARCHITECTURE.md` §2) · actions gardées avec confirmation de l'opérateur · arrêt d'urgence exécuté sans confirmation · validation de trajectoire, ForceGuard, chien de garde du streaming · principe « jamais de données inventées » · pannes réelles documentées · garde-fous contre trois défaillances **mesurées** du modèle local (état périmé, appel écrit en texte, dérive en chinois) |
| **Écart** | **Arrêt d'urgence matériel non réalisé** : un ESP32 planté laisse la broche tourner (`hardware/README.md`) · **le prompt système autorise encore le modèle à écrire du G-code** et à l'exécuter, ce qui contredit la règle ci-dessus (observé : un cycle `G81` aux paramètres incohérents) · la validation « lookahead » ne couvre que deux choses (voir §6) · aucun registre de risques ni suite de red-teaming · surface d'injection (contenu des fichiers G-code, commentaires, images) non testée · données : en mode Gemini, prompts et images partent chez Google (consentement ?) ; **mot de passe du point d'accès en clair dans les préférences** (`esp_ap_pwd`, `connection_settings_screen.dart`) ; WebSocket FluidNC sans authentification propre (protection = mot de passe Wi-Fi) ; serveur de modèle exposé au réseau s'il écoute sur `0.0.0.0` |
| **Action** | P0 sécurité · suite de red-team (≥ 40 cas) · registre des risques en anglais · liste de gouvernance des données · mesures de confiance visibles (historique des outils, badge « LOCAL », confirmation) |
| **Priorité** | **P0** (arrêt d'urgence, prompt) · P1 (registre, red-team) |

### 2.5 Coût de calcul

| | |
|---|---|
| **Existe** | Suivi d'usage Gemini (requêtes, tokens, par modèle, limites gratuites) · coût marginal nul en local · mesure du surcoût fixe de prompt |
| **Écart** | Pas de coût par heure d'opérateur ni par atelier · pas d'énergie ni de matériel · pas d'objectif chiffré |
| **Action** | Tableau de coûts (cloud gratuit, cloud payant, local) · cibles (tokens par tour, latence) · exigences matérielles par palier : GPU 8 Go, CPU seul, téléphone |
| **Priorité** | P1 (cible chiffrée) · P2 (tableau) |

---

## 3. Objectifs de venture — écarts

### 3.1 Modèle économique, prix, économie unitaire

| | |
|---|---|
| **Existe** | Offre : **machine complète à 10 M FCFA** (contre ≈ 25 M FCFA à l'import) + abonnement agent IA **25 000 FCFA/mois** · segments : ateliers (principal), établissements techniques (secondaire) · persona en brouillon · piste de pilote chez Kouratechnique (300 000 FCFA « en discussion ») — d'après l'export Wadhwani |
| **Écart** | **Aucune disposition à payer validée** · **coût de revient inconnu dans le dépôt** (nomenclature électronique sans prix ; pas de nomenclature mécanique) · TAM / SAM / SOM = estimations non sourcées (« 4 000 ateliers × 10 M ») · financement de l'acheteur non traité (10 M FCFA ≈ 16 000 USD au taux de 615) · service après-vente et pièces non chiffrés · **deux récits concurrents** (« contrôleur à 8 $ » et « machine complète à 10 M ») |
| **Action** | Modèle d'économie unitaire avec **vraies entrées** · trois variantes d'offre (achat, location-vente, paiement à la pièce) · au moins 5 entretiens, dont 3 **avant** le 8 nov. · hypothèses classées par importance et incertitude |
| **Priorité** | P1 (entretiens) · P2 (modèle) |

### 3.2 Mise sur le marché, partenariats, investissement

| | |
|---|---|
| **Existe** | Pitch deck FR (12 diapos), one-pager, page web, fiche d'entretien, dossier de candidature, export Wadhwani · vidéo de démonstration · dépôt public |
| **Écart** | Documents **antérieurs** aux 38 outils, au modèle local et aux mesures ; en français ; chiffres périmés · pas de liste de comptes cibles · pas de stratégie de financement ni de demande chiffrée · aucune approche « partenaire japonais » · **dépôt public sans licence** (question de propriété intellectuelle à la due diligence du jour 8) · dépôt encombré : `node_modules/` suivi par git (500 fichiers sur 1 026), fichiers de thèse et scripts ponctuels à la racine |
| **Action** | Refonte en anglais appuyée sur le Bench · liste de comptes · demande structurée (montant, usage, jalons) · trois « demandes » pour les rencontres 1:1 · `LICENSE` + `NOTICE` · nettoyage du dépôt |
| **Priorité** | P0 (licence, cohérence) · P2 (reste) |

### 3.3 Mentorat et pairs

| | |
|---|---|
| **Existe** | Aucun mentor industriel identifié dans le dépôt |
| **Écart** | **Rôle commercial vacant** (point faible reconnu dans l'export Wadhwani) |
| **Action** | Choisir les profils à demander (fabrication / machines-outils ; évaluation de modèles ; finance du matériel) · décider d'un associé ou conseiller commercial avant le jour 1 |
| **Priorité** | P1 |

---

## 4. Les dix livrables — état et brouillon possible avant le 8 novembre

| Livrable | État aujourd'hui | Brouillon avant le 8 nov. | À produire à Addis |
|---|---|---|---|
| 1. Énoncé du défi | Non rédigé | **Oui** — brouillon dans `03-plan-adaptation.md` §8 | Affinage avec le mentor, J1 |
| 2. Note de validation du marché | Persona en brouillon, **0 entretien documenté** | Guide d'entretien, hypothèses, **3 entretiens à Bamako** | Entretiens J2 et J7, carte problème–preuves |
| 3. Architecture et sprint | Texte (`ARCHITECTURE.md`), pas de diagramme | Diagrammes courant / cible, registre des défaillances, liste MLOps | Revue mentor J3 / J9, backlog |
| 4. Localisation / faibles ressources | 16 langues, hors-ligne | Mesure par langue, décision du sprint | Sprint J4 |
| 5. Dossier IA responsable | Pannes documentées, **pas de registre** | Registre amorcé + red-team exécuté | Red-team en direct J5 |
| 6. Modèle économique | Prix posés, **coûts absents** | Gabarit avec entrées réelles | Atelier J6 |
| 7. GTM et pipeline | Segments définis, **aucun compte** | Liste longue de comptes | J7 / J10 |
| 8. Dossier d'investissement | Deck FR v2, one-pager | Refonte EN, liste data room, demande | J8 / J9 |
| 9. Démo produit | Vidéo ; démo possible en simulation ; **fiabilité à garantir** | Script de 3 minutes, niveaux de secours | J10 |
| 10. Plan à 90 jours | Plan chiffré du 26 oct. au 17 déc., **calendrier désormais périmé** | Squelette | J10 |

---

## 5. Lecture VIRAL — hypothèse de travail (à confronter à votre fiche de base)

*Je ne connais pas vos niveaux Abaca. Ceci est ma lecture des preuves du dépôt, pour savoir où chercher des gains.*

| Domaine | Lecture | Levier en douze jours |
|---|---|---|
| Équipe | Un fondateur ingénieur, un technicien ; rôle commercial vacant | Associé ou conseiller commercial ; cartographie des mentors |
| Problème et vision | Récit solide ; **peu de preuves terrain** | 5 entretiens documentés ou plus |
| Proposition de valeur | Deux formulations concurrentes | En choisir une et la tester |
| Produit | Machine réelle, application, IA hors-ligne — **fiabilité du démonstrateur à garantir** | P0 + Bench |
| Marché | Estimations non sourcées | Comptage ascendant + entretiens |
| Modèle économique | Prix posés, coûts absents | Modèle unitaire réel |
| Passage à l'échelle | Production artisanale ; service après-vente | Plan de production pilote |
| Sortie | Sans objet à ce stade | — |

---

## 6. Affirmations à corriger ou à prouver

La plus grave d'abord.

| # | Affirmation (où) | Problème | Formulation défendable |
|---|---|---|---|
| 1 | « L'IA ne peut pas provoquer de collision » / « physically cannot cause a collision » (dossier de candidature, fiche d'entretien, pitch) | **Faux tel quel.** `trajectory_validator.dart` vérifie **deux choses** : le plancher Z (la course) et la plage de l'axe A. Il ne vérifie ni X/Y/C, ni la pièce, ni les brides, ni la longueur d'outil. Les limites logicielles et matérielles de FluidNC s'y ajoutent, mais pas de modèle de collision. Un red-team le montrera en cinq minutes. | « Les mouvements hors course sont refusés avant exécution ; toute action à risque exige la confirmation de l'opérateur ; l'arrêt d'urgence est toujours prioritaire. » |
| 2 | « 12 outils » (dossier, fiche, export Wadhwani) | Périmé | **38 outils** |
| 3 | « 134 fichiers Dart », « 253 tests » (dossier ; `ARCHITECTURE.md` §3 ; `PLAN-IA.md` §6) | Périmé | **196 fichiers, 342 tests** |
| 4 | « Appels IA routés sur la 4G » comme architecture | Plus la seule voie | L'agent peut tourner **entièrement hors-ligne** (modèle local) ; la 4G est une option |
| 5 | « Un contrôleur à 8 $ » face à « machine à 10 M FCFA » | Deux récits | Un seul : « le 8 $ est le coût du contrôleur, pas le prix de l'offre » |
| 6 | « Code open-source » (export Wadhwani) | **Aucun fichier de licence** dans le dépôt | Trancher (ouvert, ouvert-noyau, propriétaire), puis l'écrire |
| 7 | « TAM 40 Mds FCFA » | Estimation non sourcée | Comptage ascendant, ou étiquette « hypothèse » |
| 8 | « Android + Windows » | Build Android récent non confirmé | Vérifier, puis dater |
| 9 | « L'IA abaisse la barrière de compétence » | Aucune étude d'utilisabilité avec un opérateur novice | À prouver au pilote ; sinon « vise à » |
| 10 | « Validé sur matériel réel » | Trop général | Préciser : 3 axes et 3+2 validés à vide ; dôme R20 usiné ; 5 axes continu non validé (FluidNC sans RTCP) |
| 11 | Message d'erreur « Collision détectée avec le plateau » | Nom trompeur pour une vérification de course Z | « Course Z dépassée » |

---

## 7. Dette et risques relevés — par ordre de gravité

1. **Arrêt d'urgence matériel non câblé** — sécurité physique ; bloquant avant toute démo publique ou tout transport de la machine. *Critique.*
2. **Perte de données utilisateur** — préférences non atomiques, survenue le 21 oct. *Élevé.*
3. **Plantage du build Release** — `CoreMessaging.dll` appelé depuis le composant WebView (écriture sur un pointeur nul), après 8 minutes d'usage ; cause non établie ; dump conservé. *Élevé pour la démo.*
4. **Le prompt autorise le G-code écrit par le modèle** — contredit la règle d'architecture. *Élevé* (crédibilité et sécurité).
5. **Fiabilité du modèle local** — quatre modes d'échec mesurés, trois couverts par des garde-fous. *Moyen.*
6. **Qualité du G-code du pipeline prismatique** (pièce `Carre35x35` : poche trop petite, perçages non détectés, deux passes en Z au lieu d'une descente de 0,2 mm) — **à ne pas montrer** tant que ce n'est pas réglé. *Moyen.*
7. **Pas de licence ni d'avis tiers** (FluidNC est sous GPL ; FreeCAD LGPL ; modèles et API aux conditions propres). *Moyen* — certain d'être demandé le jour 8.
8. **Pas de CI ni de télémétrie.** *Moyen.*
9. **Mot de passe Wi-Fi en clair dans les préférences.** *Moyen.*
10. **Dépôt encombré** — `node_modules/` suivi par git, fichiers de thèse à la racine. *Faible, mais visible* par un mentor ou un investisseur qui ouvre la data room.
