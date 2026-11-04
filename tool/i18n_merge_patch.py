# -*- coding: utf-8 -*-
"""Fusionne un lot de traductions dans un dictionnaire de langue.

    python -I tool/i18n_merge_patch.py <lot.json> <code_langue>

Le lot ne contient que les NOUVELLES cles : on n'ecrase jamais une entree
existante sans le dire. Refuse toute cle absente du catalogue (une faute de
frappe donnerait une entree morte que personne ne verrait jamais) et toute
traduction qui ne porte pas le meme nombre de reperes {} que sa cle.
"""
import io
import json
import sys


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 2
    lot_path, code = argv[1], argv[2]

    cles = set(json.load(io.open('tool/i18n_keys.json', encoding='utf-8')))
    lot = json.load(io.open(lot_path, encoding='utf-8'))
    cible = 'tool/translations/%s.json' % code
    actuel = json.load(io.open(cible, encoding='utf-8'))

    ajoutes, remplaces, refuses = 0, [], []
    for k, v in lot.items():
        if k not in cles:
            refuses.append(('hors catalogue', k))
            continue
        if k.count('{}') != v.count('{}'):
            refuses.append(('reperes {} differents', k))
            continue
        if not v.strip():
            refuses.append(('vide', k))
            continue
        if k in actuel and actuel[k] != v:
            remplaces.append(k)
        actuel[k] = v
        ajoutes += 1

    io.open(cible, 'w', encoding='utf-8').write(
        json.dumps(actuel, ensure_ascii=False, indent=2, sort_keys=True))

    print('%s : %d entrees ecrites, total %d / %d'
          % (code, ajoutes, len(actuel), len(cles)))
    if remplaces:
        print('  remplacements d\'entrees existantes : %d' % len(remplaces))
        for k in remplaces[:5]:
            print('     - %s' % k[:70])
    for quoi, k in refuses:
        print('  REFUSE (%s) : %s' % (quoi, k[:70]))
    return 0


if __name__ == '__main__':
    sys.stdout = io.open(1, 'w', encoding='utf-8', closefd=False, newline='\n')
    sys.exit(main(sys.argv))
