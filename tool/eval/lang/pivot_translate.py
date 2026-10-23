# -*- coding: utf-8 -*-
"""Traduit en français les énoncés des scénarios « langues » avec MADLAD-400
(CTranslate2, int8, sur le CPU) — route B de l'étude : un pivot de traduction
devant le modèle d'outils.

    python -I tool/eval/lang/pivot_translate.py <dossier_modèle> <dossier_scénarios> <sortie.json>
                [--cible fr] [--avec-chiffres-protégés]

Le dossier du modèle contient `model.bin`, `shared_vocabulary.json`, `config.json`
et `spiece.model` (MADLAD-400-3B-MT converti en CTranslate2 int8, Apache-2.0).
Ce sont des DONNÉES : le script ne les exécute pas.

Sortie : { id_du_scénario: { "langue", "source", "traduction", "ms" } }, relue par
le banc avec `BENCH_PIVOT=<sortie.json>`. Seuls les énoncés hors français/anglais
sont traduits.

`--avec-chiffres-protégés` : les nombres écrits en chiffres sont remplacés par un
repère avant la traduction puis remis tels quels — pour mesurer ce que ça change
(un chiffre mal traduit est un déplacement faux).
"""
import io
import json
import os
import re
import sys
import time


def charger_scenarios(dossier):
    sc = []
    for nom in sorted(os.listdir(dossier)):
        if nom.endswith('.json'):
            with io.open(os.path.join(dossier, nom), encoding='utf-8') as f:
                sc.extend(json.load(f))
    return sc


def main(argv):
    if len(argv) < 4:
        print(__doc__)
        return 2
    modele, dossier, sortie = argv[1], argv[2], argv[3]
    cible = 'fr'
    protege = '--avec-chiffres-protégés' in argv
    if '--cible' in argv:
        cible = argv[argv.index('--cible') + 1]

    import ctranslate2
    import sentencepiece as spm

    sp = spm.SentencePieceProcessor()
    sp.load(os.path.join(modele, 'spiece.model'))
    tr = ctranslate2.Translator(modele, device='cpu', compute_type='int8',
                                inter_threads=1, intra_threads=max(2, (os.cpu_count() or 4) // 2))

    out = {}
    for s in charger_scenarios(dossier):
        if s.get('language') in ('fr', 'en') or not s.get('user'):
            continue
        source = s['user']
        texte = source
        chiffres = []
        if protege:
            def garder(m):
                chiffres.append(m.group(0))
                return 'N%d' % (len(chiffres) - 1)
            texte = re.sub(r'\d+(?:[.,]\d+)?', garder, texte)
        jetons = sp.encode('<2%s> %s' % (cible, texte), out_type=str)
        t0 = time.time()
        res = tr.translate_batch([jetons], beam_size=4, max_decoding_length=96)
        ms = int((time.time() - t0) * 1000)
        trad = sp.decode(res[0].hypotheses[0])
        if protege:
            for i, c in enumerate(chiffres):
                trad = re.sub(r'\bN%d\b' % i, c, trad)
        out[s['id']] = {'langue': s['language'], 'source': source,
                        'traduction': trad, 'ms': ms}
        print('%-18s %-9s %5d ms  %s  →  %s' % (s['id'], s['language'], ms, source, trad))

    with io.open(sortie, 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    print('\n%d énoncés traduits → %s' % (len(out), sortie))
    return 0


if __name__ == '__main__':
    out = io.open(1, 'w', encoding='utf-8', closefd=False, newline='\n')
    sys.stdout = out
    sys.exit(main(sys.argv))
