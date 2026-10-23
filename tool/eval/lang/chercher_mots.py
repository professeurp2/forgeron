# -*- coding: utf-8 -*-
"""Interroge le dictionnaire « An ka taa » pour une LISTE de requêtes précises et garde,
pour chacune, le début de la réponse avec le lien.

    python -I tool/eval/lang/chercher_mots.py <requetes.txt> <sortie.json>

`requetes.txt` : une requête par ligne, « langue<TAB>mot » (langue = lexicon | english |
french). Les lignes vides ou commençant par # sont ignorées.

Même politesse que verifier_dictionnaire.py : une requête par seconde, identifiant
explicite. Aide à la relecture, pas une validation.
"""
import io
import json
import sys
import time

sys.path.insert(0, __file__.rsplit('tool', 1)[0] + 'tool/eval/lang')
from verifier_dictionnaire import interroger, principaux  # noqa: E402


def main(argv):
    lignes = [l.rstrip('\n') for l in io.open(argv[1], encoding='utf-8')]
    reqs = []
    for l in lignes:
        l = l.strip()
        if not l or l.startswith('#'):
            continue
        langue, mot = l.split('\t', 1)
        reqs.append((langue.strip(), mot.strip()))
    res = {}
    for i, (langue, mot) in enumerate(reqs):
        url, texte = interroger(mot, langue)
        trouve = bool(texte) and 'No results found' not in texte
        res['%s:%s' % (langue, mot)] = {'url': url, 'trouvé': trouve,
                                         'extrait': principaux(texte, 1100) if trouve else ''}
        sys.stderr.write('%2d/%d %-8s %-18s %s\n' % (i + 1, len(reqs), langue, mot, 'oui' if trouve else 'non'))
        time.sleep(1.0)
    with io.open(argv[2], 'w', encoding='utf-8') as f:
        json.dump(res, f, ensure_ascii=False, indent=1)
    print('%d requêtes → %s' % (len(res), argv[2]))


if __name__ == '__main__':
    sys.stdout = io.open(1, 'w', encoding='utf-8', closefd=False)
    main(sys.argv)
