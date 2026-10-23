# Plan d'adaptation — arriver à Addis avec un dossier, pas des promesses

*Proposition au 22 octobre 2026, à valider (décisions en §11). Lire d'abord `01-analyse-programme.md` et `02-ecart-forgeron.md`.*

Tailles : **S** ≤ ½ jour · **M** 1 à 2 jours · **L** 3 jours et plus (travail effectif, assistant de code inclus).
Qui : **Lamine** (fondateur) · **Aboubacar** (technicien) · **Claude** (assistant de code, dans le dépôt).

---

## 1. La thèse, en une phrase et trois preuves

> **Forgeron est un opérateur IA hors-ligne, borné par la sécurité, qui parle la langue de l'atelier.**
> L'IA propose, le code déterministe calcule, l'opérateur confirme, le matériel arrête.

Trois preuves à avoir en main le 9 novembre :

1. **Une pièce réelle** — le dôme R20 usiné en 3 h 35, « né d'une phrase » (déjà acquis ; il manque une vidéo propre).
2. **Un chiffre mesuré, rejouable** — Forgeron-Bench : réussite de l'appel d'outil **hors-ligne**, par langue, avec latence et coût. Le chiffre vedette sera de la forme *« X % → Y % de réussite du premier coup, hors-ligne, en moins de Z s, sur un portable à 8 Go de VRAM »*. Les valeurs seront mesurées, pas supposées.
3. **Une sécurité démontrée, pas proclamée** — arrêt d'urgence matériel essayé et documenté, registre de risques, red-team exécuté.

Ce récit est aligné avec les objectifs 3 et 4 du programme (hors-ligne et langues ; IA responsable) et avec le point fort déjà documenté dans `ARCHITECTURE.md`.

## 2. Contraintes

- **17 jours** avant l'arrivée (dimanche 8 novembre). Code figé le **5 novembre**.
- Chevauchement avec MIT (à terminer), Wadhwani (mardi et jeudi), le programme de l'EAII (26 oct.–23 nov. d'après le plan de travail précédent **[à confirmer]**), et le PFE.
- À Addis : journées de 08:30 à 17:00, deux veillées, sprints de 1 h 30 → **pas de grosse construction sur place**.
- Un seul représentant à Addis **[à confirmer]** ; 3 h de décalage avec Bamako.
- Deux versions du plan : **noyau dur** (≤ 1 h par jour pour vous ; l'assistant porte le reste) et **plein**.

**Noyau dur** (à ne pas sacrifier) : P0.1 (**prérequis du départ : la machine voyage**) · P0.4 · P1.1 + P1.2 (réalisés surtout par Claude) · P1.7 (3 entretiens) · P2.4 (répétitions de la démo). Tout le reste est rattrapable à Addis ou après.

## 3. Ce qu'on gèle jusqu'au 21 novembre

- **Capteurs, vision, contrôle adaptatif** (phases 1 à 4 du `PLAN-IA.md`) : hors critères de la résidence. Seule la collecte minimale reste (P3.3).
- **Nouveaux outils pour l'agent** : les 38 suffisent ; chacun coûte du contexte.
- **Pipeline STEP → G-code prismatique** : ne pas le montrer ni le présenter tant que la qualité (pièce `Carre35x35`) n'est pas réglée. La démo s'appuie sur la **pièce de révolution** (dôme R20), validée.
- **Refonte d'interface, fenêtres détachées, nouvelles grilles de panneaux.**
- **5 axes continu / RTCP.**

*Si l'une de ces lignes vous paraît trop radicale, c'est la décision n° 5 du §11.*

---

## 4. Backlog priorisé

### P0 — Sécurité et fiabilité (à boucler d'ici le 31 octobre)

| ID | Chantier | Critère d'acceptation | Qui | Taille | Alimente |
|---|---|---|---|---|---|
| P0.1 | **Arrêt d'urgence matériel** : contact NF du coup-de-poing en série avec l'alimentation de la broche ; résistance de rappel de 10 kΩ sur la commande du relais (`hardware/README.md`) | Essai documenté : ESP32 débranché ou planté → broche coupée. Photo, date, procès-verbal | Aboubacar + Lamine | S | J5, J10, vrai prérequis de toute démo |
| P0.2 | **Préférences** : écriture atomique, copie `.bak`, restauration au démarrage | Tests : fichier nul, JSON tronqué, fichier absent → restauration ou valeurs par défaut, sans plantage ; coupure simulée | Claude | S–M | J3 (MLOps) |
| P0.3 | **Plantage du build Release** (`CoreMessaging` / WebView) | Reproduit ou écarté ; 2 h d'usage continu et 20 répétitions de la démo sans plantage | Claude + Lamine | M | J10 |
| P0.4 | **Audit des affirmations** (`02`, §6) : deck, one-pager, page web, README, `ARCHITECTURE.md`, `PLAN-IA.md` | Plus aucune formule non vérifiable ; chiffres à jour (38 outils, 196 fichiers, 342 tests) | Lamine + Claude | S | J1, J5, J8 |
| P0.5 | **Aligner le prompt système** sur « l'agent ne produit aucune coordonnée » | Le Bench échoue si le modèle écrit un programme ; `run_gcode_program` limité aux fichiers existants ou à une confirmation renforcée | Claude (décision : Lamine) | S | J5 |
| P0.6 | **LICENSE + NOTICE** des composants tiers ; dépôt présentable (`node_modules/` retiré du suivi, fichiers de thèse rangés) | Choix de licence écrit ; `NOTICE` généré ; dépôt lisible en 2 minutes | Lamine (décision) + Claude | S–M | J8 |

### P1 — Preuves de la semaine 1

| ID | Chantier | Critère d'acceptation | Qui | Taille | Alimente |
|---|---|---|---|---|---|
| P1.1 | **Forgeron-Bench v0** : ≥ 40 scénarios figés (français, anglais, puis amharique et swahili relus), lanceur en une commande, rapport Markdown + JSON | Rejouable par un tiers ; rapport daté avec version du modèle, du prompt, des outils | Claude | M | J3, J4 |
| P1.2 | **Référence** : `forgeron-qwen`, Gemini (si clé disponible), deux modèles plus petits | Tableau : réussite par catégorie et par langue, latence p50/p95, tokens par tour | Claude + Lamine | S | J3 |
| P1.3 | **Expérience 1 : routage d'outils** (n'exposer que les outils utiles au tour) | Tokens fixes ≥ −50 % ; réussite ≥ référence ; **aucune** régression de sécurité au red-team | Claude | M–L | J4 |
| P1.4 | **Red-team ≥ 40 cas** + **registre des risques** (anglais) | Chaque risque : scénario, contrôle, test, risque résiduel, plan | Claude + Lamine | M | J5 |
| P1.5 | **Architecture** courante et cible (diagrammes), **registre des défaillances**, **liste de contrôle MLOps** (anglais, 3 pages) | Relus par Aboubacar ; projetables | Claude + Lamine | M | J3 |
| P1.6 | **Localisation** : audit des libellés critiques (arrêt d'urgence, alarmes, broche) par des locuteurs natifs ; choix du sprint du jour 4 | Liste relue et signée ; choix A / B / C arrêté | Lamine (+ pairs à Addis) | S | J4 |
| P1.7 | **Kit d'entretiens clients** : guide FR/EN, hypothèses classées (annexe B), 5 entretiens planifiés dont 3 faits avant le 8 nov. | 3 comptes rendus structurés avant le jour 1 | Lamine | M | J1, J2 |

### P2 — Semaine 2

| ID | Chantier | Critère d'acceptation | Qui | Taille | Alimente |
|---|---|---|---|---|---|
| P2.1 | **Modèle d'économie unitaire** (tableur) avec **vrais coûts** | Nomenclature mécanique + électronique chiffrée ; 3 offres (achat, location-vente, paiement à la pièce) ; marge, point mort, trésorerie | Lamine (données) + Claude (modèle) | M | J6 |
| P2.2 | **Comptes cibles** (Mali, Éthiopie, Japon) + les 3 « demandes » (annexe C) | ≥ 30 comptes qualifiés par segment ; demandes rédigées | Lamine | M | J7, J10 |
| P2.3 | **Dossier d'investissement en anglais** : deck v3, one-pager v2, liste data room, demande chiffrée | Cohérent avec P0.4 ; chiffres issus du Bench | Lamine + Claude | M | J8, J9 |
| P2.4 | **Démo** : script de 3 minutes, 4 niveaux de secours, 10 répétitions, kit hors-ligne | Démo complète en **mode avion** ; vidéo de secours | Lamine + Claude | M | J10 |
| P2.5 | **Plan à 90 jours** (squelette) | Jalons, responsables, dates, indicateurs, dépendances | Lamine | S | J10 |
| P2.7 | **Logistique de la machine** : emballage (caisse de transport), déclaration et douane, assurance, alimentation électrique sur place, accord du laboratoire, liste des pièces de rechange (`04`, annexe C) | Dossier de transport complet ; accord écrit du laboratoire ; essais de l'arrêt d'urgence refaits sur place | Lamine + Aboubacar | M | J10 (démo L1) |
| P2.8 | **Plan de travail chiffré à jour** (échéance du 25 oct.) : calendrier réel de la résidence, objectifs techniques de `04`, budget révisé (voyage, transport de la machine) | Document remis avant l'échéance ; chiffres **fournis par vous**, jamais devinés | Lamine (chiffres) + Claude (rédaction) | M | avant le 25 oct. |
| P2.6 | **Mode « sans IA »** : analyseur déterministe de commandes à vocabulaire fermé (français, anglais) | Couverture mesurée au Bench ; aucun mouvement sans confirmation | Claude | M | J4 (option) — **prototype mesuré le 23/10** (`lib/core/utils/command_lexicon.dart`, 130 tests, [étude 05](05-etude-comparative-langues-locales.md)) ; reste le branchement dans l'application avec confirmation à l'écran |

### P3 — Seulement si tout le reste est bouclé

| ID | Chantier | Critère d'acceptation | Qui | Taille |
|---|---|---|---|---|
| P3.1 | **Ajustement fin (QLoRA)** sur le calcul UniPod, week-end du 14–15 nov. | Modèle v2 contre v1 sur le Bench ; **retour arrière démontré** (objectif MLOps) | Claude + Lamine | L |
| P3.2 | **Jeu de commandes bambara** (vocabulaire fermé) avec des locuteurs natifs | ≥ 100 énoncés validés | Lamine + Aboubacar | M–L — **feuille de relecture prête** : [`langues-locales/feuille-bambara.md`](langues-locales/feuille-bambara.md) ; le moteur et le banc attendent les locuteurs, pas du code |
| P3.3 | **Collecte minimale « fiche d'usinage »** (phase 0 du `PLAN-IA.md`) | ≥ 10 fiches avec verdict de l'opérateur | Lamine | M |

---

## 5. Calendrier de préparation (22 octobre → 8 novembre)

| Période | Mot d'ordre | Contenu |
|---|---|---|
| **22–23 oct.** | Décider | Décisions du §11 ; statut du plan de travail du 25 oct. ; planifier les entretiens ; confirmer l'état de l'arrêt d'urgence |
| **24–28 oct.** — semaine A | **Sécuriser et mesurer** | P0.1 · P0.2 · P0.4 · P0.5 · P1.1 v0 · P1.2 · premier entretien (Kouratechnique) |
| **29 oct. → 4 nov.** — semaine B | **Prouver** | P0.3 · P0.6 · P1.3 · P1.4 · P1.5 · P1.6 · entretiens 2 et 3 · P2.1 v0 |
| **5 nov.** | **Gel du code** | Plus que des corrections de bogues ; builds finaux archivés (Windows Release, APK) avec sommes de contrôle |
| **5–8 nov.** — semaine C | **Emballer** | P2.2 · P2.3 · P2.4 (10 répétitions, mode avion, vidéo de secours) · P2.5 · kit hors-ligne · valise · logistique |

Points de contrôle : **29 oct.** — P0 bouclé · **4 nov.** — Bench avec référence et une expérience mesurée · **7 nov.** — répétition générale complète, chronométrée.

---

## 6. À Addis, jour par jour

| Jour | Entrées prêtes | Sur place | Remise du soir | Point d'attention |
|---|---|---|---|---|
| **J1** lun. 9 | Brouillon d'énoncé du défi (annexe A) · base Abaca retrouvée · preuves MIT et Wadhwani · **pitch d'introduction de 3 minutes** (problème, produit, traction, goulot, résultat voulu) · fiche d'état de Forgeron (`02`, §1) | Fiche structurée ; pont MIT/Wadhwani ; mentors : demander un profil **fabrication** et un profil **évaluation de modèles** ; constituer un conseil de pairs **complémentaire** | Énoncé du défi · fiche de base | Dire « prototype » ; ne pas sur-vendre |
| **J2** mar. 10 | Guide d'entretien · 5 hypothèses prioritaires · **3 entretiens déjà faits à Bamako** · 2 créneaux à distance (10:30–12:00 à Bamako) · pistes à Addis (annexe B) | Séance des 5 hypothèses ; segmentation (utilisateur, acheteur, décideur) ; entretiens 13:30–15:00 ; synthèse | Carte problème–preuves · proposition de valeur révisée | Questions neutres ; ne pas vendre pendant l'entretien ; noter les citations |
| **J3** mer. 11 | Schémas courant et cible · registre des défaillances v0 · liste MLOps · **Bench avec référence** | Revue d'architecture ; atelier MLOps ; permanences techniques ; **choisir UNE expérience** pour le jour 4 | Architecture cible · backlog · carte d'action technique | Un seul changement mesurable |
| **J4** jeu. 12 | Expérience préparée (scripts), protocole d'évaluation prêt | Sprint 13:30–15:00 ; revue par les pairs ; relecture des libellés par des locuteurs natifs | Amélioration produit + résultats du Bench | Noter configuration et versions (exigé par la note) |
| **J5** ven. 13 | Red-team v0 · registre v0 | **Red-team en direct** : laisser les pairs attaquer Forgeron ; priorisation des mesures ; tables rondes sectorielles ; veillée | Registre des risques · dossier de preuves S1 | Accueillir les failles : un risque trouvé en salle vaut mieux que sur scène |
| **14–15 nov.** | Scripts de calcul testés en petit | Calcul UniPod si P3.1 est prêt ; sinon relancer le Bench sur des modèles plus gros ; **se reposer** ; chiffrer le jour 6 | — | Ne pas démarrer de nouveau chantier |
| **J6** lun. 16 | Modèle d'économie unitaire v0 avec vrais coûts · prix issus des entretiens | Modèles économiques ; test de résistance ; prix ; coûts de l'IA ; cliniques de financement (prototype / MVP) | Modèle unitaire + trésorerie · canevas + plan d'expérience | Choisir **une** expérience de prix |
| **J7** mar. 17 | Liste de comptes · pipeline v0 · 3 demandes | Choix du canal ; vente aux institutions (formation technique, bailleurs) ; simulation d'acheteur ; tables rondes | Plan GTM · pipeline | Distinguer utilisateur, acheteur, financeur |
| **J8** mer. 18 | Demande chiffrée v0 · liste data room | Paysage du financement ; due diligence (licence, équipe, données) ; récit d'investissement ; permanences ; veillée | Stratégie de financement · supports à jour | Licence et propriété intellectuelle : sujet certain |
| **J9** jeu. 19 | Deck v3 · script de démo · vidéo de secours | Sprint intégré ; cliniques (droit, finance, marché, impact) ; pitchs entre pairs ; répétition générale | Dossier de venture complet | Chronométrer à 3 minutes |
| **J10** ven. 20 | Tout | 08:30 tests de démo → pitch + démo → tables rondes → **rencontres 1:1** → clinique d'action → évaluation finale | Pipeline qualifié · plan à 90 jours | Décider du niveau de démo 30 minutes avant (§7) |

---

## 7. La démo de trois minutes

Durée visée : **3 minutes** (déduit du programme du jour 10 ; à confirmer avec les organisateurs).

| Temps | Contenu |
|---|---|
| 0:00–0:20 | Le problème : un atelier tourne des pièces de précision et les importe |
| 0:20–1:10 | **D'une phrase à une pièce**, en mode avion : la phrase → l'agent enchaîne les outils → générateur déterministe → aperçu et parcours du dôme R20. La ligne de temps montre ce que l'IA a fait : **elle ne calcule aucune coordonnée** |
| 1:10–1:50 | **Sécurité** : demande dangereuse (hors course, broche sans origine) → refus ou confirmation ; arrêt d'urgence |
| 1:50–2:20 | **Hors-ligne et langue** : badge « LOCAL · modèle » ; commande dans une autre langue (selon le sprint du jour 4), avec sa mesure |
| 2:20–2:45 | **La preuve** : une diapositive — référence → amélioré (réussite, latence, tokens), coût par heure |
| 2:45–3:00 | **La demande** : les 3 « demandes » (annexe C) |

**Échelle de secours** — décider du niveau 30 minutes avant, aux tests de 08:30 :

| Niveau | Quoi | Condition |
|---|---|---|
| L1 | **Machine réelle sur place — plan principal (décision du 22 oct. : la machine voyage)** | Arrêt d'urgence matériel vérifié et refait sur place ; transport, douane, assurance et accord du laboratoire réglés |
| L2 | **Mode simulation + agent local hors-ligne** — secours immédiat si la machine ne peut pas être mise sous tension | Aucun réseau requis |
| L3 | Vidéo de la machine réelle (dôme R20) + capture du Bench | Toujours prête |
| L4 | Diapositives | Dernier recours |

**Kit hors-ligne** : build Windows Release et APK (sommes de contrôle) · installateur et modèles du serveur local sur disque externe · fichiers de démo (STEP, G-code du dôme) · vidéo · deck et PDF du registre · second ordinateur · routeur de voyage préconfiguré · câbles, alimentations, batterie externe.

**À ne pas faire en public** : lancer un G-code non validé sur la machine ; démarrer la broche tant que l'arrêt d'urgence matériel n'est pas vérifié ; montrer le pipeline prismatique.

---

## 8. Annexe A — brouillon de l'énoncé du défi (jour 1, en anglais)

*Les crochets seront remplis par des mesures.*

**Technical.** By Day 5, raise the first-attempt correct tool-call rate of Forgeron's offline AI operator assistant from [baseline X %] to at least [target Y %] on Forgeron-Bench ([N] scenarios, French / English / [Amharic or Bambara]), with p95 latency under [Z] s on an 8 GB-VRAM laptop and a [≥ 50 %] cut in fixed prompt size — while the red-team suite shows zero unsafe actions.

**Market.** By Day 2, learn from at least 5 workshop owners, technical-school leaders or buyers which precision parts small workshops turn away today, what they would pay for a machine plus AI operator assistant (price and financing form), and who decides — then revise the value proposition accordingly.

**Capital.** By Day 8, define a 12-month funding ask ([amount], [use], [milestones]) and the best-fit instrument (grant, pilot pre-payment, equity), with at least 3 qualified funder conversations by Day 10.

## 9. Annexe B — hypothèses à tester, classées (jour 2)

| # | Hypothèse | Question qui la teste |
|---|---|---|
| H1 | Les ateliers perdent régulièrement des commandes de précision faute de machine ou d'opérateur | « Quelle est la dernière pièce refusée ? Quand ? Quelle valeur ? Qu'avez-vous fait ? » (compter par mois) |
| H2 | Une machine à ≈ 10 M FCFA (ou financée) est atteignable ; **5 axes** répond à un vrai besoin (et pas 3 axes) | Pièces typiques ; prix de référence ; alternatives (sous-traiter, importer) |
| H3 | L'assistant IA réduit le besoin d'un opérateur CNC expert ; 25 000 FCFA/mois est acceptable | Coût mensuel d'un opérateur ; réaction à une démonstration |
| H4 | Connectivité et langue sont de vraies contraintes | Coupures, données mobiles, langue de travail |
| H5 | Le décideur et le financement sont identifiables | « Dernier achat de machine : qui, comment, combien de temps ? » |
| H6 | L'après-vente est tenable par une petite équipe | Tolérance aux pannes ; qui répare ; pièces |
| H7 | Un opérateur fait confiance à une IA qui commande une machine, sous conditions | « Qu'est-ce qui vous rassurerait ? » (confirmation, arrêt, historique) |
| H8 | Les établissements techniques achètent pour former (client public ou financé par des bailleurs) | Budgets, procédures, bailleurs |

Pistes de terrain à Addis **[à vérifier avant d'y compter]** : l'Institut de développement de l'industrie des métaux (MIDI, fondé en 1973 avec l'appui du PNUD ; formation pratique et conseil) · le pôle ManuTech (espace de fabrication, en partenariat avec le ministère de l'Industrie, d'après une offre d'emploi de 2025) · la coopération japonaise (JICA — Kaizen, centre TICAD) pour l'angle partenaires japonais. Aucune de ces pistes n'est confirmée comme interlocuteur disponible.

## 10. Annexe C — trois « demandes » pour les rencontres 1:1 (jour 10)

1. **Un site pilote** (atelier ou établissement technique, Éthiopie ou Mali) pendant 3 mois, avec un indicateur de réussite — par exemple « une pièce refusée aujourd'hui produite localement ».
2. **Une introduction à un partenaire japonais** (outillage, machines-outils, coopération technique) pour co-développer ou parrainer un pilote.
3. **Un financeur** pour un plan à 12 mois (pilotes, sécurité vérifiable, premier recrutement commercial) — montant fixé au jour 8.

(Option : un mentor en évaluation de modèles pour 90 jours.)

---

## 11. Décisions

**Prises le 22 octobre 2026** : n° 1 = machine complète + abonnement · n° 2 = **la machine voyage** · n° 3 = **plan de travail à mettre à jour** · lancement par P0 et Forgeron-Bench. Restent ouvertes : n° 4 à 7.

| # | Décision | Pourquoi elle compte | Ma recommandation |
|---|---|---|---|
| 1 | **Récit commercial** : machine complète + abonnement (10 M FCFA + 25 000 FCFA/mois) — **retenu (22 oct.)** · logiciel et kit contrôleur · établissements techniques d'abord | Détermine l'économie unitaire (J6), le GTM (J7) et la démo | Garder l'offre « machine complète + abonnement » et **valider les établissements techniques comme premier client** |
| 2 | **La machine voyage-t-elle ?** — **OUI (22 oct.)** | Niveau de démo L1 ; **arrêt d'urgence matériel obligatoire avant le départ** ; douane, emballage, assurance, accord du labo | Ma recommandation était « non » ; décision prise autrement. Conséquence : P0.1 devient un **prérequis du départ**, et P2.7 est ajouté |
| 3 | **Plan de travail du 25 oct.** : pas encore remis — **à mettre à jour (22 oct.)** | Il suppose une sélection fin novembre ; la résidence est du 9 au 20 | Le mettre à jour avec le nouveau calendrier (entretiens avancés au 10 nov.) |
| 4 | **Licence** du dépôt | Question certaine de la due diligence | Choisir avant le 31 oct. ; l'option dépend du modèle de revenus |
| 5 | **Gel** (§3) et **politique « l'IA n'écrit pas de G-code »** | Cohérence avec le red-team | Approuver les deux |
| 6 | **Sprint du jour 4** : A bambara/français en vocabulaire fermé · B amharique relu par les pairs · C essai vocal hors-ligne sur téléphone | Un seul sera mené | **A** si des locuteurs natifs sont disponibles d'ici là ; sinon **B** |
| 7 | **Rôle commercial** : associé, conseiller ou rien avant le jour 1 | Domaine « équipe » de la fiche VIRAL | Trouver un conseiller avant le jour 1, même à temps partiel |

## 12. Suivi

- [ ] Décisions du §11
- [ ] P0.1 arrêt d'urgence · [ ] P0.2 préférences · [ ] P0.3 plantage Release · [ ] P0.4 affirmations · [ ] P0.5 prompt · [ ] P0.6 licence
- [ ] P1.1 Bench · [ ] P1.2 référence · [ ] P1.3 routage · [ ] P1.4 red-team + registre · [ ] P1.5 architecture · [ ] P1.6 libellés · [ ] P1.7 entretiens (3 faits)
- [ ] P2.1 économie unitaire · [ ] P2.2 comptes · [ ] P2.3 dossier EN · [ ] P2.4 démo · [ ] P2.5 plan 90 jours · [ ] P2.6 mode sans IA · [ ] P2.7 logistique machine · [ ] P2.8 plan de travail chiffré
- [ ] Logistique : visa, vaccination, assurance, billets, matériel, kit hors-ligne
- [ ] Questions aux organisateurs envoyées (`01`, §9)
