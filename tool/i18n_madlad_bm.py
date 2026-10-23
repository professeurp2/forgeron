# -*- coding: utf-8 -*-
"""Traduit l'interface en bambara avec MADLAD-400 (CTranslate2 int8, CPU).

    python -I tool/i18n_madlad_bm.py <dossier_modele> [sortie.json]

Pourquoi MADLAD et pas le modele de l'assistant : c'est le seul traducteur de
texte hors ligne deja verifie par l'etude (Apache-2.0, SHA-256 controle,
docs/addis/05-etude-comparative-langues-locales.md §4.4). Le resultat est
reproductible et attribuable, pas invente au fil de l'eau.

CE QUI N'EST PAS TRADUIT, ET POURQUOI :

  - les cles de `tool/i18n_safety_keys.json` (alarmes, arret d'urgence, fins de
    course, consignes de degagement). L'etude a mesure MADLAD fabriquant des
    contresens sur les mots de securite (« arrete » -> « deplace » en swahili).
    Un message d'alarme faux en bambara est un danger : ces chaines restent en
    francais jusqu'a relecture par un locuteur (feuille-bambara.md).
  - les cles absentes de `tool/translations/en.json` : etiquettes machine
    identiques dans toutes les langues (E-STOP, JOG, RTCP G43.4, FLUIDNC...).

Les reperes `{}` sont remplaces par un jeton avant traduction puis remis. Une
traduction qui en perd un est rejetee (le francais est conserve) : un repere
manquant ferait disparaitre un code d'alarme ou un numero de ligne.
"""
import io
import json
import os
import re
import sys
import time

MARQUEUR = re.compile(r'\bN(\d+)\b')


def protege(texte):
    """Remplace chaque {} par N0, N1... et retourne (texte, nombre)."""
    n = [0]

    def sub(_):
        i = n[0]
        n[0] += 1
        return 'N%d' % i

    return re.sub(r'\{\}', sub, texte), n[0]


def restitue(trad, combien):
    """Remet les {} ; retourne None si un repere a disparu."""
    for i in range(combien):
        if not re.search(r'\bN%d\b' % i, trad):
            return None
        trad = re.sub(r'\bN%d\b' % i, '{}', trad, count=1)
    # Un repere en trop (le modele a duplique) : on refuse aussi.
    if MARQUEUR.search(trad):
        return None
    return trad


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    modele = argv[1]
    sortie = argv[2] if len(argv) > 2 else 'tool/translations/bm.json'

    cles = json.load(io.open('tool/i18n_keys.json', encoding='utf-8'))
    sensibles = set(json.load(io.open('tool/i18n_safety_keys.json', encoding='utf-8')))
    # Les etiquettes machine : absentes du dictionnaire anglais = identiques
    # a la source dans toutes les langues.
    anglais = set(json.load(io.open('tool/translations/en.json', encoding='utf-8')))

    a_traduire = [k for k in cles if k not in sensibles and k in anglais]
    print('cles totales        : %d' % len(cles))
    print('  sensibles ecartees: %d (restent en francais)' % len(sensibles))
    print('  etiquettes machine: %d (identiques partout)' % len([k for k in cles if k not in anglais]))
    print('  a traduire        : %d' % len(a_traduire))
    print()

    import ctranslate2
    import sentencepiece as spm

    sp = spm.SentencePieceProcessor()
    sp.load(os.path.join(modele, 'spiece.model'))
    tr = ctranslate2.Translator(modele, device='cpu', compute_type='int8',
                                inter_threads=1,
                                intra_threads=max(2, (os.cpu_count() or 4) // 2))

    out = {}
    refus = []
    t_debut = time.time()
    for idx, cle in enumerate(a_traduire, 1):
        # Chaque ligne est traduite separement : le saut de ligne est porteur
        # de mise en page et le test i18n verifie qu'il survit.
        lignes_src = cle.split('\n')
        lignes_out = []
        ok = True
        for ligne in lignes_src:
            if not ligne.strip():
                lignes_out.append(ligne)
                continue
            texte, combien = protege(ligne)
            jetons = sp.encode('<2bm> %s' % texte, out_type=str)
            res = tr.translate_batch([jetons], beam_size=4,
                                     max_decoding_length=256)
            trad = sp.decode(res[0].hypotheses[0])
            trad = restitue(trad, combien)
            if trad is None or not trad.strip():
                ok = False
                break
            lignes_out.append(trad)
        if not ok:
            refus.append(cle)
            continue
        valeur = '\n'.join(lignes_out)
        # Une traduction identique a la source n'apporte rien : le moteur
        # retombe deja sur le francais.
        if valeur.strip() != cle.strip():
            out[cle] = valeur
        if idx % 25 == 0 or idx == len(a_traduire):
            ecoule = time.time() - t_debut
            print('  %4d/%d  %5.1f s  (%.2f s/cle)' % (
                idx, len(a_traduire), ecoule, ecoule / idx))
            sys.stdout.flush()
            # Sauvegarde incrementale : une demi-heure de calcul ne doit pas
            # dependre d'une fin de processus propre.
            with io.open(sortie, 'w', encoding='utf-8') as f:
                json.dump(out, f, ensure_ascii=False, indent=2, sort_keys=True)

    with io.open(sortie, 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, indent=2, sort_keys=True)

    print()
    print('traduites  : %d' % len(out))
    print('refusees   : %d (repere {} perdu ou sortie vide)' % len(refus))
    for k in refus[:10]:
        print('   - %s' % k[:80])
    print('ecrit      : %s' % sortie)
    return 0


if __name__ == '__main__':
    sys.stdout = io.open(1, 'w', encoding='utf-8', closefd=False, newline='\n')
    sys.exit(main(sys.argv))
