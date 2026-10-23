# -*- coding: utf-8 -*-
"""Produit la feuille de relecture des LIBELLES d'interface en bambara.

    python -I tool/i18n_feuille_bambara.py

Pourquoi une feuille et pas un dictionnaire livre : les deux routes
automatiques ont ete mesurees et echouent sur des etiquettes courtes.
MADLAD-400 produit 49 % d'entrees defectueuses (boucles de repetition,
etiquettes devenues des phrases) — voir
docs/addis/evidence/langues/2026-10-23_madlad-interface-bambara.json.
Le brouillon ci-dessous est de l'assistant de code : il sert de point de
depart au relecteur, il ne part JAMAIS dans l'application tel quel.

Regle de contenu, reprise de la note du lexique : un mot d'atelier sans
equivalent bambara reste en francais (« broche », « jog », « offset »,
« G-code »). On ne traduit que le vocabulaire courant.

Sortie : docs/addis/langues-locales/feuille-bambara-interface.md
Une fois la colonne « Votre version » remplie :
    python -I tool/i18n_feuille_ingest.py <feuille.md>
"""
import io
import json

SORTIE = 'docs/addis/langues-locales/feuille-bambara-interface.md'

# Brouillon de l'assistant. « None » = aucune proposition : le mot n'a pas
# d'equivalent courant, ou la proposition serait une invention.
# Les mots marques (lex) viennent du lexique deja source sur An ka taa
# (assets/lexicon/lexique.json) : ceux-la sont verifiables.
BROUILLON = {
    # — actions courantes —
    'ANNULER': 'DABILA',                 # (lex) dabila = laisser, cesser
    'Annuler': 'Dabila',                 # (lex)
    'ARRÊTER': 'JƆ',                     # (lex) jɔ = s'arrêter
    'Couper': 'Dabila',                  # (lex)
    'LANCER': 'A DAMINƐ',                # (lex) daminɛ = commencer
    'DÉMARRER ›': 'DAMINƐ ›',            # (lex)
    'CONFIRMER': 'SƆN',                  # sɔn = accepter
    'Confirmer': 'Sɔn',
    'APPLIQUER': 'A KƐ',                 # (lex) kɛ = faire
    'Appliquer': 'A kɛ',                 # (lex)
    'Enregistrer': 'Mara',               # mara = garder
    'SAUVEGARDER': 'MARA',
    'EFFACER': 'JƆSI',                   # jɔsi = effacer
    'Effacer': 'Jɔsi',
    'Supprimer': 'Jɔsi',
    'ENVOYER': 'CI',                     # ci = envoyer
    'Envoyer': 'Ci',
    'AJOUTER': 'FARA A KAN',             # fara … kan = ajouter
    'RECHERCHER': 'ƝINI',                # ɲini = chercher
    'Rafraîchir': 'Lakuraya',            # lakuraya = renouveler
    'Réessayer': 'A kɛ tugun',           # tugun = encore
    'Précédent': 'Kɔfɛ',                 # (lex) kɔfɛ = derrière
    'Renommer': 'Tɔgɔ yɛlɛma',           # tɔgɔ = nom, yɛlɛma = changer
    # — objets courants —
    'Langue': 'Kan',                     # kan = langue
    'PARAMÈTRES': 'LABƐNW',              # labɛn = régler
    'Paramètres': 'Labɛnw',
    'Nom du fichier': 'Dosiye tɔgɔ',
    'Photo / image': 'Ja',               # ja = image
    'Prendre une photo': 'Ja ta',
    'Retirer l\'image': 'Ja bɔ',
    'Image jointe': 'Ja farala a kan',
    'Nouvelle': 'Kura',                  # kura = nouveau
    'Nouvelle discussion': 'Baro kura',  # baro = conversation
    'DISCUSSIONS': 'BAROW',
    'Machine prête': 'Mansin labɛnnen don',   # (lex) mansin = machine
    'Statut : {}': 'Cogoya : {}',        # (lex) cogoya = état
    'réfléchit…': 'A bɛ miiri la…',
    # — mots d'atelier : volontairement sans proposition —
    'AVANCE': None, 'AXE': None, 'CONTROLE JOG': None, 'MODE ATELIER': None,
    'MAGASIN D\'OUTILS': None, 'COORDONNÉES DE TRAVAIL': None,
    'GESTION DES WCS': None, 'DRO EN DIRECT': None, 'JUMEAU NUMÉRIQUE 3D': None,
    'MÉTRIQUES DE PERFORMANCE': None, 'COCKPIT DE STATUT': None,
    'CALIBRATION MACHINE': None, 'MODE SIMULATION': None, 'LATENCE': None,
    'Broche & Arrosage': None, 'CHANGEMENT D\'OUTIL': None,
    'CONSOLE DE FLUX G-CODE': None, 'MACROS RAPIDES': None,
    'MONITEUR RÉSEAU': None, 'CONFIGURATION RÉSEAU': None,
}


def main():
    keys = json.load(io.open('tool/i18n_keys.json', encoding='utf-8'))
    safety = set(json.load(io.open('tool/i18n_safety_keys.json',
                                   encoding='utf-8')))
    anglais = set(json.load(io.open('tool/translations/en.json',
                                    encoding='utf-8')))
    courtes = sorted(k for k in keys
                     if k not in safety and k in anglais
                     and '\n' not in k and len(k) <= 34
                     and len(k.split()) <= 4)

    lignes = [
        '# Feuille de relecture — libellés de l\'interface en bambara',
        '',
        "*Généré par `tool/i18n_feuille_bambara.py`. Même convention de statut "
        "que `feuille-bambara.md` : `relu` seulement avec un nom et une date.*",
        '',
        '## Pourquoi cette feuille',
        '',
        "Les deux routes automatiques ont été essayées et mesurées :",
        '',
        "- le modèle local ne comprend déjà le bambara qu'à 19 % "
        "(étude §4.1) — le faire *produire* du bambara n'a pas de sens ;",
        "- MADLAD-400, le pivot hors ligne retenu par l'étude, a traduit ces "
        "mêmes libellés : **49 % des 371 sorties ont un défaut détectable "
        "automatiquement** (boucles de répétition, étiquette courte devenue "
        "une phrase, mot français recraché). « ANNULER » → « BATELI BATELI "
        "BATELI », « Copier » → « Kopiyɛ kɔpiyɛ ». Mesure brute : "
        "`docs/addis/evidence/langues/2026-10-23_madlad-interface-bambara.json`.",
        '',
        "Il reste donc la relecture humaine. Cette feuille est faite pour que "
        "ça vous prenne le moins de temps possible.",
        '',
        '## Comment remplir',
        '',
        "1. Ne remplissez que ce que vous diriez vraiment **en atelier**.",
        "2. Un mot d'atelier qui se dit en français se laisse en français "
        "(« broche », « jog », « offset », « G-code ») — c'est la règle déjà "
        "retenue pour le lexique, pas un pis-aller.",
        "3. Une case laissée vide **reste en français dans l'application** : "
        "ne forcez jamais une traduction dont vous n'êtes pas sûr.",
        "4. La colonne « Brouillon » est de l'assistant de code. Elle est là "
        "pour être corrigée ou effacée, pas pour être validée d'un bloc.",
        '',
        "Les messages d'alarme, d'arrêt d'urgence et de fin de course ne sont "
        "**pas** dans cette feuille : ils restent en français tant qu'ils "
        "n'ont pas été relus séparément, parce qu'un message de sécurité faux "
        "est un danger (étude §7.3).",
        '',
        '## Libellés',
        '',
        '| # | Français (ce que l\'écran affiche) | Brouillon — *à corriger* | Votre version |',
        '|---|---|---|---|',
    ]

    for i, k in enumerate(courtes, 1):
        brouillon = BROUILLON.get(k, None)
        affiche = k.replace('|', r'\|')
        prop = (brouillon or '—').replace('|', r'\|')
        lignes.append('| %d | %s | %s | |' % (i, affiche, prop))

    propose = sum(1 for k in courtes if BROUILLON.get(k))
    lignes += [
        '',
        '## Ce que ça donne',
        '',
        '- libellés à relire : **%d**' % len(courtes),
        '- dont un brouillon est proposé : **%d** (les autres sont des mots '
        "d'atelier, à laisser en français si c'est ainsi qu'on les dit)"
        % propose,
        '',
        "Une fois la colonne remplie, elle est reprise par "
        "`tool/i18n_feuille_ingest.py`, qui écrit `tool/translations/bm.json` "
        "et passe la langue en `relu` avec votre nom et la date.",
        '',
    ]

    io.open(SORTIE, 'w', encoding='utf-8', newline='\n').write(
        '\n'.join(lignes))
    print('libellés  : %d' % len(courtes))
    print('brouillons: %d' % propose)
    print('écrit     : %s' % SORTIE)


if __name__ == '__main__':
    main()
