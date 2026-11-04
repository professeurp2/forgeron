# Forgeron — Dossier de candidature · METI-funded UniPods AI Programme

> **À postuler ce soir** · Deadline : **21 août 2026** (affiche) / 23 août (texte) → vise le **21**.
> Lien : https://forms.gle/NMzAg6iwbWi6GtgQ6
>
> Ce dossier contient : (1) un **one-pager** de pitch, (2) des **réponses prêtes à coller**
> dans le formulaire (EN + FR), (3) un **script de démo**, (4) la **thèse business**.
> Les `⟦...⟧` sont des champs à compléter par toi (nom, équipe, contacts, chiffres réels).

---

## 0. Ce qu'il te reste à remplir toi-même (5 min)

- ⟦Ton nom complet + rôle⟧ et l'équipe (même si tu es seul, dis-le : « solo founder, PFE ENI »).
- ⟦Pays / ville⟧ pour l'éligibilité régionale.
- ⟦Contact : email, téléphone, LinkedIn/GitHub du repo forgeron⟧.
- ⟦Toute traction réelle⟧ : as-tu montré la démo à un atelier, un fablab, un prof, un client
  potentiel ? Même « démontré à 2 ateliers d'usinage » compte. Sinon, on reste sur
  « prototype validé sur hardware réel ».
- ⟦Une vidéo de démo⟧ (30-90 s) — voir le script en section 3. Un jury retient une démo.

---

## 1. One-pager (pitch)

**Forgeron — Le premier contrôleur CNC 5-axes piloté par IA, pensé pour l'industrie africaine.**

**Le problème.** Les contrôleurs de machines-outils CNC 5-axes industriels (Fanuc, Heidenhain,
Siemens) coûtent 5 000 – 50 000 $, tournent sur du matériel propriétaire fermé, et exigent des
opérateurs hautement formés. Résultat : les ateliers, fablabs et PME manufacturières africaines
sont exclus de la fabrication de précision — pièces aéronautiques, moules, prothèses,
outillage — qui reste importée.

**La solution.** Forgeron transforme un ESP32 à 8 $ (firmware open-source FluidNC) + 5 drivers
pas-à-pas bon marché en un contrôleur CNC 5-axes de grade industriel, piloté depuis un
smartphone ou un PC. Application Flutter fonctionnelle : DRO temps réel, jog 5 axes, streaming
G-code, visualiseur 3D Trunnion, palpage, systèmes de coordonnées, sécurité matérielle.

**L'IA — le cœur du « next leap ».** Un **agent IA agentique** (LLM en *function calling*)
permet de piloter la machine en **langage naturel** : *« palpe le centre de la pièce puis lance
le programme à 80 % d'avance »*. L'agent dispose de 12 outils sûrs (jog, homing, override,
WCS, arrêt d'urgence…) encadrés par un **système de permissions** et une **validation de
trajectoire *lookahead*** qui simule tout le parcours contre les limites mécaniques réelles de
la machine *avant* d'usiner — pour qu'un LLM ne puisse jamais provoquer une collision.
L'IA abaisse la barrière de compétence : un opérateur peu formé pilote une 5-axes en parlant.

**L'innovation IA défendable** (ce n'est pas « un wrapper d'API ») :
1. **Contrôle industriel agentique sûr** : couche outils + permissions + validation *lookahead*
   qui rend un LLM sûr pour piloter une machine physique. C'est ça, l'IP.
2. **Résilience connectivité** : le téléphone reste sur le WiFi de la machine (sans Internet)
   pendant que les appels IA sont routés via la 4G/5G par un pont réseau natif — conçu pour
   les conditions de connectivité africaines.
3. **Repli multi-modèles & quota** : bascule automatique entre modèles pour tenir sur des
   paliers gratuits — l'IA reste accessible sans coût d'infrastructure.

**Marché.** Ateliers d'usinage, fablabs/makerspaces, écoles techniques et PME
manufacturières en Afrique ; à terme, fabricants de kits CNC. Modèle : app freemium +
licence Pro (fonctions IA, multi-machines) + bundles hardware certifiés.

**Stade.** Prototype fonctionnel validé sur hardware réel (ESP32 + FluidNC + TB6600),
134 fichiers Dart, suite de tests (parsers, streaming, validation trajectoire). Issu d'un
Projet de Fin d'Études (ENI). Prêt à passer de prototype à venture.

**La demande.** Le programme UniPods AI nous apporte exactement ce qui manque : skilling
technique IA (Ethiopian AI Institute) pour durcir l'agent, et le parcours Wadhwani
(customer discovery → investment readiness) pour construire la venture autour d'un produit
déjà crédible.

---

## 2. Réponses prêtes à coller dans le formulaire

> Le formulaire timbuktoo/UNDP est probablement en **anglais**. Chaque réponse est donnée en
> **EN (à coller)** puis **FR (pour toi)**. Adapte la longueur au champ.

### Q — Nom du projet / startup
**EN:** Forgeron
**FR:** Forgeron

### Q — One-line description / pitch
**EN:** Forgeron is the first AI-piloted 5-axis CNC controller for Africa's workshops — turning
an $8 microcontroller into an industrial-grade machine controller you operate in plain language.
**FR:** Le premier contrôleur CNC 5-axes piloté par IA pour les ateliers africains — un
microcontrôleur à 8 $ transformé en contrôleur industriel qu'on pilote en langage naturel.

### Q — What problem are you solving?
**EN:** Precision 5-axis CNC machining is locked behind proprietary controllers costing
$5,000–$50,000 that require highly trained operators. This excludes African workshops, fablabs
and manufacturing SMEs from making aerospace parts, molds, prosthetics and tooling — which stay
imported. The hardware to build capable CNC machines is now cheap (open-source FluidNC on an
ESP32); the missing piece is an affordable, accessible, safe *controller* — especially the
operator-skill barrier.
**FR:** L'usinage CNC 5-axes de précision est verrouillé derrière des contrôleurs propriétaires
à 5 000–50 000 $ exigeant des opérateurs très formés. Les ateliers/fablabs/PME africains en sont
exclus. Le hardware est devenu bon marché (FluidNC/ESP32) ; ce qui manque, c'est un contrôleur
abordable, accessible et sûr — surtout côté compétence opérateur.

### Q — Your solution
**EN:** Forgeron is a working Flutter application that turns an ESP32 (open-source FluidNC
firmware) plus low-cost stepper drivers into an industrial-grade 5-axis CNC controller running
on a phone or PC: real-time DRO, 5-axis jog, G-code streaming for million-line files, 3D
Trunnion visualizer, probing, work-coordinate systems, and hardware-safety features
(emergency stop, watchdog, exponential-backoff reconnection). An embedded AI agent lets a
low-skill operator control the machine in natural language, made safe by a permissions layer
and pre-machining trajectory validation.
**FR:** (voir one-pager §1 — même contenu.)

### Q — How does your product use AI? (le champ décisif du programme)
**EN:** Forgeron embeds an **agentic AI assistant** built on an LLM with **function calling**.
The model is exposed to 12 safe machine-control tools (get machine state, jog axis, home,
feed/spindle override, select/set work-coordinate systems, send G-code, pause/resume/reset,
emergency stop). An operator types or speaks an intent — "probe the part center, then run the
program at 80% feed" — and the agent plans and executes the tool sequence. Three engineering
layers make this genuinely novel rather than a thin API wrapper:
(1) a **permissions system** gating each tool, with emergency-stop always allowed;
(2) a **lookahead trajectory validator** that simulates the full toolpath against the machine's
real mechanical limits before any motion, so the AI cannot cause a collision;
(3) a **cellular-routing network layer** that keeps the phone on the machine's offline WiFi AP
while routing AI calls over mobile data — built for African connectivity, plus automatic
multi-model fallback to stay on free tiers. The AI lowers the operator-skill barrier that keeps
CNC out of reach.
**FR:** Agent IA agentique (LLM + function calling) exposant 12 outils sûrs de contrôle machine.
Nouveauté défendable = 3 couches d'ingénierie : permissions par outil, validation trajectoire
*lookahead* (anti-collision avant tout mouvement), et routage réseau cellulaire + repli
multi-modèles pour la connectivité/coût. L'IA fait tomber la barrière de compétence opérateur.

### Q — What stage is your prototype at? (demonstrable prototype)
**EN:** Functional prototype, validated on real hardware (ESP32 DevKit V1 + FluidNC v3.7 +
5× TB6600 drivers, X/Y/Z linear + A/C rotary Trunnion). Codebase: 134 Dart files, clean
architecture (domain/data/application/presentation), automated tests covering G-code and GRBL
parsers, streaming, and trajectory validation. Runs on Windows desktop and Android; simulation
mode for demos without hardware. Originated as an engineering final-year project (ENI).
**FR:** Prototype fonctionnel validé sur hardware réel. 134 fichiers Dart, archi propre, tests
automatisés (parsers, streaming, validation trajectoire), Windows + Android + mode simulation.

### Q — Who are your customers / target market?
**EN:** Primary: machine shops, fablabs/makerspaces, technical schools and manufacturing SMEs
across Africa that cannot afford proprietary 5-axis controllers. Secondary: CNC-kit and
desktop-CNC builders who need a controller layer. Beachhead: ⟦ton pays/ville⟧ makerspaces and
technical institutes, where FluidNC-based machines are already appearing.
**FR:** Cible primaire : ateliers, fablabs, écoles techniques, PME manuf. africaines.
Secondaire : fabricants de kits CNC. Tête de pont : ⟦ton pays⟧.

### Q — Business model
**EN:** Freemium app (core control free to drive adoption) + Pro subscription (AI assistant,
multi-machine management, advanced probing/analytics) + certified hardware bundles (ESP32 +
drivers pre-flashed and calibrated) as a hardware-attach revenue line. Later: marketplace of
verified machine configs and macros.
**FR:** Freemium + abonnement Pro (IA, multi-machines, analytics) + bundles hardware certifiés
+ (plus tard) marketplace de configs/macros.

### Q — Traction / validation to date
**EN:** ⟦À personnaliser⟧ Working end-to-end prototype demonstrated on physical 5-axis hardware;
⟦e.g. "shown to N workshops / fablabs", "N test users", any letters of interest⟧. Technical
validation: reliable real-time control, million-line G-code streaming, collision-preventing
trajectory validation.
**FR:** Personnalise honnêtement. Si pas d'utilisateurs externes : « validation technique sur
hardware réel » + toute démo faite à quelqu'un (prof, atelier).

### Q — Team
**EN:** ⟦Ton nom⟧ — founder & engineer (embedded, real-time systems, Flutter, applied AI),
⟦ENI, année⟧. ⟦Ajoute co-fondateurs / mentors si présents⟧. Built Forgeron end-to-end:
firmware config, real-time protocol, app architecture, and the AI agent layer.
**FR:** Mets-toi en avant : tu as tout construit (firmware, protocole temps réel, archi app,
agent IA). Si tu es seul, assume-le — les programmes financent aussi des solo founders solides.

### Q — Why this programme / what do you need?
**EN:** We have a strong, demonstrable prototype but need to become an investable venture. The
Ethiopian AI Institute skilling would help us harden the agentic control layer (safety,
on-device/edge models, evaluation). The 14-week Wadhwani track is exactly the gap: customer
discovery to validate the beachhead, business modelling around the freemium+hardware mix,
go-to-market for African workshops, and investment readiness. The in-person Addis bootcamp and
the timbuktoo network would connect us to manufacturing and investor ecosystems we can't reach
alone.
**FR:** On a le prototype ; il manque la venture. Skilling IA (durcir l'agent, edge, éval) +
Wadhwani (customer discovery, business model, GTM, investment readiness) + réseau timbuktoo.

### Q — Vision / impact (Africa)
**EN:** Democratize precision manufacturing in Africa: make advanced 5-axis CNC affordable and
operable by less-specialized workers, so local workshops can produce tooling, spare parts,
prosthetics and components currently imported — building local industrial capacity and jobs.
**FR:** Démocratiser la fabrication de précision en Afrique ; produire localement ce qui est
aujourd'hui importé ; créer de la capacité industrielle et des emplois.

---

## 3. Script de démo (vidéo 60-90 s ou live bootcamp)

1. **(0-10s) Le hook.** « Ce contrôleur CNC 5-axes coûte moins de 20 $ de matériel. Voici
   comment on le pilote — en lui parlant. »
2. **(10-25s) Le prototype réel.** Montrer l'app (DRO temps réel qui bouge, jog 5 axes),
   la machine/ESP32 si dispo, sinon le **mode simulation** + le visualiseur 3D Trunnion.
3. **(25-55s) L'IA — le moment fort.** Taper à l'agent : *« Fais l'origine de tous les axes,
   sélectionne G54, puis déplace Z de +10 mm à 500 mm/min. »* Montrer l'agent qui enchaîne
   `home` → `select_wcs` → `jog_axis`, avec la **demande de permission** qui apparaît.
4. **(55-70s) La sécurité.** Demander un mouvement hors limites → montrer la **validation
   *lookahead*** qui **refuse** avant tout mouvement. « L'IA ne peut pas casser la machine. »
5. **(70-90s) L'ambition.** « Un opérateur peu formé pilote une 5-axes en parlant. On veut
   mettre ça dans chaque atelier africain. »

> Enregistre en mode simulation si le hardware n'est pas branché — c'est fait pour ça.

---

## 4. Thèse business (2 min de lecture)

- **Pourquoi maintenant :** FluidNC + ESP32 ont rendu le *hardware* CNC quasi gratuit ; les LLM
  à function calling rendent enfin le pilotage en langage naturel fiable. La fenêtre s'ouvre.
- **Wedge (produit d'entrée) :** l'app de contrôle gratuite → adoption virale dans les fablabs.
- **Douve (moat) :** couche de sécurité (validation lookahead + permissions) + configs machines
  certifiées + données d'usinage réelles pour améliorer l'agent = avance difficile à copier.
- **Revenu :** freemium → Pro (IA/multi-machines) → bundles hardware → marketplace.
- **Ce qu'un investisseur voudra voir (à construire pendant Wadhwani) :** 3-5 interviews
  clients, 1 atelier pilote qui l'utilise, un prix testé, un coût d'acquisition estimé.
- **Risques & réponses :**
  - *« C'est juste un wrapper Gemini »* → non : l'IP est la couche de contrôle sûr + connectivité.
  - *« Marché de niche »* → tête de pont niche, mais le contrôle machine en langage naturel
    s'étend à toute la CNC/robotique/automatisation abordable.
  - *« Dépendance API »* → repli multi-modèles aujourd'hui, edge/on-device visé (d'où le
    skilling AI Institute).

---

## 5. Checklist avant d'envoyer ce soir

- [ ] Remplir tous les ⟦...⟧ (nom, pays, équipe, contacts, GitHub).
- [ ] Enregistrer la vidéo démo (script §3), l'héberger (YouTube non-listé / Drive), coller le lien.
- [ ] Coller les réponses EN de la section 2 dans le formulaire, ajuster la longueur.
- [ ] Relire le champ « How does your product use AI? » — c'est LE champ qui te qualifie.
- [ ] Vérifier la deadline exacte sur le formulaire (21 vs 23 août) et soumettre avant.
- [ ] Garder une copie de tes réponses (ce fichier).
