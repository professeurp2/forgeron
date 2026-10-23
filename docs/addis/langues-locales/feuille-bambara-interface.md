# Feuille de relecture — libellés de l'interface en bambara

*Généré par `tool/i18n_feuille_bambara.py`. Même convention de statut que `feuille-bambara.md` : `relu` seulement avec un nom et une date.*

## Pourquoi cette feuille

Les deux routes automatiques ont été essayées et mesurées :

- le modèle local ne comprend déjà le bambara qu'à 19 % (étude §4.1) — le faire *produire* du bambara n'a pas de sens ;
- MADLAD-400, le pivot hors ligne retenu par l'étude, a traduit ces mêmes libellés : **49 % des 371 sorties ont un défaut détectable automatiquement** (boucles de répétition, étiquette courte devenue une phrase, mot français recraché). « ANNULER » → « BATELI BATELI BATELI », « Copier » → « Kopiyɛ kɔpiyɛ ». Mesure brute : `docs/addis/evidence/langues/2026-10-23_madlad-interface-bambara.json`.

Il reste donc la relecture humaine. Cette feuille est faite pour que ça vous prenne le moins de temps possible.

## Comment remplir

1. Ne remplissez que ce que vous diriez vraiment **en atelier**.
2. Un mot d'atelier qui se dit en français se laisse en français (« broche », « jog », « offset », « G-code ») — c'est la règle déjà retenue pour le lexique, pas un pis-aller.
3. Une case laissée vide **reste en français dans l'application** : ne forcez jamais une traduction dont vous n'êtes pas sûr.
4. La colonne « Brouillon » est de l'assistant de code. Elle est là pour être corrigée ou effacée, pas pour être validée d'un bloc.

Les messages d'alarme, d'arrêt d'urgence et de fin de course ne sont **pas** dans cette feuille : ils restent en français tant qu'ils n'ont pas été relus séparément, parce qu'un message de sécurité faux est un danger (étude §7.3).

## Libellés

| # | Français (ce que l'écran affiche) | Brouillon — *à corriger* | Votre version |
|---|---|---|---|
| 1 |  (épuisé) | — | |
| 2 | 3 Axes (A/C Verrouillés) | — | |
| 3 | 5 Axes Simultanés | — | |
| 4 | ACTIF : T{} | — | |
| 5 | ACTUELLEMENT MONTÉ | — | |
| 6 | ADRESSE IP DESTINATION | — | |
| 7 | ADRESSE MANUELLE | — | |
| 8 | AGENT IA | — | |
| 9 | AJOUTER | FARA A KAN | |
| 10 | ALLER AU ZÉRO | — | |
| 11 | ANNULER | DABILA | |
| 12 | ANNULER LE PALPAGE | — | |
| 13 | APPELER T{}  (M6) | — | |
| 14 | APPLIQUER | A KƐ | |
| 15 | ARCHITECTURE MACHINE | — | |
| 16 | ARRÊTER | JƆ | |
| 17 | ASSISTANT DE CALIBRATION | — | |
| 18 | ASSISTANT IA | — | |
| 19 | ASSISTANT PALPAGE INDUSTRIEL | — | |
| 20 | AUCUN DOSSIER DE TRAVAIL | — | |
| 21 | AUCUN PROGRAMME CHARGÉ | — | |
| 22 | AVANCE | — | |
| 23 | AXE | — | |
| 24 | AXE {} | — | |
| 25 | Acquitter | — | |
| 26 | Agent IA | — | |
| 27 | Agent IA activé | — | |
| 28 | Alignement des axes rotatifs | — | |
| 29 | Annuler | Dabila | |
| 30 | Appel outil T{} | — | |
| 31 | Appliquer | A kɛ | |
| 32 | Assistant CNC · Gemini | — | |
| 33 | Assistant Forgeron | — | |
| 34 | Aucun dossier sélectionné | — | |
| 35 | Aucun programme chargé | — | |
| 36 | Aucune discussion enregistrée. | — | |
| 37 | Automatique (système) | — | |
| 38 | Axe {} | — | |
| 39 | BARRE DE TITRE INTELLIGENTE | — | |
| 40 | BIENVENUE DANS FORGERON | — | |
| 41 | BOUTONS DE PALPAGE | — | |
| 42 | BROCHE ARRÊTÉE | — | |
| 43 | Bascule automatique | — | |
| 44 | Broche & Arrosage | — | |
| 45 | CALIBRATION MACHINE | — | |
| 46 | CAMÉRA DE SURVEILLANCE | — | |
| 47 | CAMÉRA INJOIGNABLE | — | |
| 48 | CHANGEMENT D'OUTIL | — | |
| 49 | CHARGER DEPUIS LA SD | — | |
| 50 | CHOISIR LE DOSSIER | — | |
| 51 | CLÉ API GEMINI | — | |
| 52 | COCKPIT DE STATUT | — | |
| 53 | COMMANDE FLUIDNC | — | |
| 54 | COMMANDES D'ACTION | — | |
| 55 | COMMENCER À USINER | — | |
| 56 | CONFIGURATION MANUELLE | — | |
| 57 | CONFIGURATION RÉSEAU | — | |
| 58 | CONFIRMER | SƆN | |
| 59 | CONNECTER | — | |
| 60 | CONNEXION | — | |
| 61 | CONNEXION WIFI ESP32 | — | |
| 62 | CONSOLE DE FLUX G-CODE | — | |
| 63 | CONTROLE JOG | — | |
| 64 | CONTRÔLE CYCLE | — | |
| 65 | COORDONNÉES DE TRAVAIL | — | |
| 66 | COPIER | — | |
| 67 | CORRECTIONS | — | |
| 68 | CORRECTIONS (OVERRIDES) | — | |
| 69 | COUPER MOTEURS | — | |
| 70 | Calcul des Offsets Terminé | — | |
| 71 | Calibration machine | — | |
| 72 | Changer de dossier | — | |
| 73 | Charger dans l'éditeur | — | |
| 74 | Choisir dans la galerie | — | |
| 75 | Clé API enregistrée. | — | |
| 76 | Config indisponible : {} | — | |
| 77 | Config non chargée. | — | |
| 78 | Configuration Machine FluidNC | — | |
| 79 | Confirmer | Sɔn | |
| 80 | Confirmer le zérotage | — | |
| 81 | Connexion ESP32 | — | |
| 82 | Copier | — | |
| 83 | Couper | Dabila | |
| 84 | DISCUSSIONS | BAROW | |
| 85 | DRO (DIGITAL READ-OUT) | — | |
| 86 | DRO EN DIRECT | — | |
| 87 | DUMP DIAGNOSTIC (JSON) | — | |
| 88 | Discussions enregistrées | — | |
| 89 | Dump généré en console | — | |
| 90 | DÉMARRER › | DAMINƐ › | |
| 91 | Décalage {} | — | |
| 92 | Décalage {} enregistré | — | |
| 93 | Dépassement de course programmé | — | |
| 94 | EFFACER | JƆSI | |
| 95 | ENREGISTRER DANS LA MACHINE | — | |
| 96 | ENVOI OPTIMISÉ | — | |
| 97 | ENVOYER | CI | |
| 98 | EXÉCUTION EN COURS | — | |
| 99 | Effacer | Jɔsi | |
| 100 | Effacer cette discussion ? | — | |
| 101 | Effacer la discussion | — | |
| 102 | Enregistrer | Mara | |
| 103 | Enregistrer & redémarrer | — | |
| 104 | Enregistrer & redémarrer ? | — | |
| 105 | Enregistrer dans FluidNC ? | — | |
| 106 | Enregistrer le G-code | — | |
| 107 | Envoyer | Ci | |
| 108 | Envoyer G-Code... | — | |
| 109 | Erreur G-code bloquante | — | |
| 110 | Erreur de chargement: {} | — | |
| 111 | Erreur: {} | — | |
| 112 | Expandeur d'E/S réinitialisé | — | |
| 113 | FICHIERS SUR CARTE SD | — | |
| 114 | FLUX SUSPENDU | — | |
| 115 | FORGER ! | — | |
| 116 | Filtrer | — | |
| 117 | G43 H{}  (décalage L) | — | |
| 118 | G43 H{}  (décalage longueur) | — | |
| 119 | GESTION DES WCS | — | |
| 120 | GESTIONNAIRE DE FICHIERS | — | |
| 121 | Gemini & permissions | — | |
| 122 | Gravité : {} | — | |
| 123 | GÉNÉRER DUMP DIAGNOSTIC (JSON) | — | |
| 124 | HISTORIQUE | — | |
| 125 | HISTORIQUE & RÉPONSES | — | |
| 126 | HISTORIQUE COMMANDES | — | |
| 127 | Image jointe | Ja farala a kan | |
| 128 | JOG MANUEL 5 AXES | — | |
| 129 | JUMEAU NUMÉRIQUE 3D | — | |
| 130 | L'agent souhaite exécuter : | — | |
| 131 | LANCER | A DAMINƐ | |
| 132 | LANCER L'ASSISTANT DE CALIBRATION | — | |
| 133 | LATENCE | — | |
| 134 | LOG MACHINE | — | |
| 135 | Langue | Kan | |
| 136 | Lecture impossible : {} | — | |
| 137 | Lien ESP32 / FluidNC | — | |
| 138 | Ligne {}/{} | — | |
| 139 | MACROS INDUSTRIELLES | — | |
| 140 | MACROS RAPIDES | — | |
| 141 | MAGASIN D'OUTILS | — | |
| 142 | MAINTENANCE PRÉVENTIVE | — | |
| 143 | MISE EN ROUTE | — | |
| 144 | MODE ATELIER | — | |
| 145 | MODE JOG REQUIS | — | |
| 146 | MODE OPÉRATOIRE | — | |
| 147 | MODE SIMULATION | — | |
| 148 | MODÈLE IA | — | |
| 149 | MONITEUR RÉSEAU | — | |
| 150 | MONTER | — | |
| 151 | MONTER T{} | — | |
| 152 | MONTÉ | — | |
| 153 | Machine prête | Mansin labɛnnen don | |
| 154 | Mode atelier | — | |
| 155 | MÉTRIQUES DE PERFORMANCE | — | |
| 156 | NAVIGATION LATÉRALE | — | |
| 157 | Nom du fichier | Dosiye tɔgɔ | |
| 158 | Nouvelle | Kura | |
| 159 | Nouvelle discussion | Baro kura | |
| 160 | ONGLET MASTER | — | |
| 161 | OPÉRATEUR L01 | — | |
| 162 | OUTILS DU PROGRAMME | — | |
| 163 | OVERRIDES DE VITESSE | — | |
| 164 | PARAMÈTRES | LABƐNW | |
| 165 | PARAMÈTRES RÉSEAU | — | |
| 166 | PAVÉ DE JOGGING 5-AXES | — | |
| 167 | PERMISSIONS PAR CATÉGORIE | — | |
| 168 | PORT WEBSOCKET | — | |
| 169 | POSITION DRO | — | |
| 170 | PROGRAMME | — | |
| 171 | PROGRESSION & AVANCES | — | |
| 172 | PRÉVISION MAINTENANCE | — | |
| 173 | PRÉVISUALISATION | — | |
| 174 | Paramètres | Labɛnw | |
| 175 | Paramètres de l'agent | — | |
| 176 | Passer en {} ? | — | |
| 177 | Photo / image | Ja | |
| 178 | Plein écran | — | |
| 179 | Prendre une photo | Ja ta | |
| 180 | Précédent | Kɔfɛ | |
| 181 | QUALITÉ | — | |
| 182 | Quitter la visite | — | |
| 183 | Quitter le pupitre | — | |
| 184 | RAPIDES | — | |
| 185 | RECHERCHER | ƝINI | |
| 186 | RECOMANCER | — | |
| 187 | REDÉMARRER L'ESP32 | — | |
| 188 | REFUSER | — | |
| 189 | RELANCER LA RECHERCHE | — | |
| 190 | REPLIER LE MENU | — | |
| 191 | Rafraîchir | Lakuraya | |
| 192 | Redémarrer | — | |
| 193 | Redémarrer l'ESP32 ? | — | |
| 194 | Refusé : {}{} | — | |
| 195 | Remplacer | — | |
| 196 | Renommer | Tɔgɔ yɛlɛma | |
| 197 | Renommer la discussion | — | |
| 198 | Retirer l'image | Ja bɔ | |
| 199 | Revenir à 100 % | — | |
| 200 | RÉCUPÉRATION | — | |
| 201 | RÉCUPÉRER | — | |
| 202 | Réessayer | A kɛ tugun | |
| 203 | Réinit. | — | |
| 204 | Réinitialisation en mouvement | — | |
| 205 | SAUVEGARDER | MARA | |
| 206 | SCANNER DE RÉSEAU LOCAL | — | |
| 207 | SCANNER INTELLIGENT | — | |
| 208 | SIMULATEUR 3D | — | |
| 209 | SYNCHRONISER | — | |
| 210 | SYSTÈMES DE COORDONNÉES (WCS) | — | |
| 211 | Saisir commande G-code... | — | |
| 212 | Statut : {} | Cogoya : {} | |
| 213 | Streaming G-code | — | |
| 214 | Suite : {} | — | |
| 215 | Supprimer | Jɔsi | |
| 216 | TABLEAU D'OUTILS | — | |
| 217 | TABLEAU DE BORD PRINCIPAL | — | |
| 218 | TERMINAL MDI | — | |
| 219 | TERMINAL MDI / LOGS | — | |
| 220 | TEST FINS DE COURSE | — | |
| 221 | Thème | — | |
| 222 | Thème : {} | — | |
| 223 | Tutoriel interactif | — | |
| 224 | TÉLÉMÉTRIE TEMPS RÉEL | — | |
| 225 | VECTEURS | — | |
| 226 | VOS ONGLES MÉTIERS | — | |
| 227 | WCS & Outil | — | |
| 228 | WCS actif: {} | — | |
| 229 | WIZARD DE CALIBRATION | — | |
| 230 | ZÉRER LE WCS ICI | — | |
| 231 | Zérer {} ici ? | — | |
| 232 | détecté | — | |
| 233 | jamais vu | — | |
| 234 | réfléchit… | A bɛ miiri la… | |
| 235 | {} LIGNE | — | |
| 236 | {} LIGNES | — | |
| 237 | {} message · {} | — | |
| 238 | {} messages · {} | — | |
| 239 | {} outil | — | |
| 240 | {} outils | — | |
| 241 | {} · {} ligne | — | |
| 242 | {} · {} lignes | — | |
| 243 | {} — {} req/j | — | |
| 244 | À VOUS DE JOUER | — | |
| 245 | ÉDITEUR G-CODE | — | |
| 246 | ÉTAPE SUIVANTE | — | |
| 247 | ÉTAPE {} / {} | — | |
| 248 | Échec : {} | — | |
| 249 | Écriture impossible : {} | — | |
| 250 | Éditer le G-Code | — | |
| 251 | Édition de fichiers G-code | — | |
| 252 | ▶ EN BROCHE | — | |
| 253 | ✅ Enregistré : {} | — | |
| 254 | ✓ G43 H{} appliqué | — | |
| 255 | ❌ Erreur : {} | — | |
| 256 | ❌ Erreur upload: {} | — | |

## Ce que ça donne

- libellés à relire : **256**
- dont un brouillon est proposé : **37** (les autres sont des mots d'atelier, à laisser en français si c'est ainsi qu'on les dit)

Une fois la colonne remplie, elle est reprise par `tool/i18n_feuille_ingest.py`, qui écrit `tool/translations/bm.json` et passe la langue en `relu` avec votre nom et la date.
