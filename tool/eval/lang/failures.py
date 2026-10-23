# -*- coding: utf-8 -*-
"""Liste, pour des langues choisies, ce que le modèle a FAIT sur chaque énoncé
(appels d'outils) face à ce qui était attendu.

    python tool/eval/lang/failures.py <rapport.json> <langue> [<langue> …]

Sortie UTF-8 dans un fichier avec `> sortie.txt` si la console est en cp1252.
"""
import io
import json
import sys
from collections import OrderedDict

path = sys.argv[1]
langs = set(sys.argv[2:])
data = json.load(io.open(path, encoding='utf-8'))
by_id = OrderedDict()
for r in data['runs']:
    if r['category'] != 'LGX' or r['language'] not in langs:
        continue
    by_id.setdefault(r['id'], []).append(r)

out = io.open(1, 'w', encoding='utf-8', closefd=False)
for sid, runs in by_id.items():
    ok = sum(1 for r in runs if r['pass'])
    calls = ['; '.join(r['calls']) if r['calls'] else '(aucun appel)' for r in runs]
    out.write('%-18s %d/%d   %s\n' % (sid, ok, len(runs), '  |  '.join(calls)))
