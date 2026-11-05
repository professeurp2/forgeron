# -*- coding: utf-8 -*-
"""Clés tr() du code absentes du catalogue (tool/i18n_keys.json).

    python -I tool/i18n_tr_keys.py            # résumé par fichier
    python -I tool/i18n_tr_keys.py --liste    # chaque clé manquante
    python -I tool/i18n_tr_keys.py --ajoute   # les ajoute au catalogue

Un texte passé à tr() mais absent du catalogue n'est traduit dans AUCUNE
langue, sans que rien ne le signale : tr() retombe en silence sur le
français. Le banc de conversation du 5 nov. 2026 en a trouvé 344, dont
toutes les réponses fixes de l'assistant (« Broche allumée. »…).

Lit le PREMIER argument de chaque tr( : littéraux adjacents concaténés,
branches d'une ternaire (`cond ? 'a' : 'b'`). Ignore une clé interpolée
(`$x`) : ce serait un bogue à corriger dans le code, pas une clé.
"""
import glob
import io
import json
import re
import sys

sys.path.insert(0, 'tool')
from i18n_gen import unescape_dart  # noqa: E402

LIT = re.compile(r"""r?'(?:\\.|[^'\\\n])*'|r?"(?:\\.|[^"\\\n])*\"""")
TR = re.compile(r'(?<![\w.])tr\(')
INTERP = re.compile(r'(?<!\\)\$\{?\w')


def first_arg_keys(src, start):
    """Clés du premier argument de tr( commençant à src[start]."""
    keys, run, depth, i = [], [], 0, start
    while i < len(src):
        c = src[i]
        if c in '\'"' or (c == 'r' and i + 1 < len(src) and src[i + 1] in '\'"'):
            m = LIT.match(src, i)
            if not m:
                break
            run.append(m.group(0))
            i = m.end()
            continue
        if c in '([{':
            depth += 1
        elif c in ')]}':
            if depth == 0:
                break
            depth -= 1
        elif c == ',' and depth == 0:
            break
        elif c in '?:' and depth == 0 and run:
            keys.append(run)
            run = []
        elif not c.isspace() and c not in '?:' and run:
            # Autre chose qu'un littéral après un littéral (opérateur,
            # appel) : clé calculée, on ne la devine pas.
            return []
        i += 1
    if run:
        keys.append(run)
    out = []
    for parts in keys:
        texte = ''
        for p in parts:
            raw = p.startswith('r')
            body = p[2:-1] if raw else p[1:-1]
            if not raw and INTERP.search(body):
                return []
            texte += body if raw else unescape_dart(body)
        out.append(texte)
    return out


# Passés à tr() mais pas du texte : un gabarit de clé API (exemple de saisie,
# à ne jamais faire circuler dans des fichiers de traduction).
EXCLUES = {'AIzaSy...'}


def collect():
    found = {}
    for f in sorted(glob.glob('lib/**/*.dart', recursive=True)):
        if f.replace('\\', '/').startswith('lib/core/i18n/translations/'):
            continue
        src = io.open(f, encoding='utf-8').read()
        for m in TR.finditer(src):
            debut = src.rfind('\n', 0, m.start()) + 1
            if src[debut:m.start()].lstrip().startswith('//'):
                continue  # exemple dans un commentaire
            for k in first_arg_keys(src, m.end()):
                if k.strip() and k not in EXCLUES:
                    found.setdefault(k, set()).add(f.replace('\\', '/'))
    return found


def main(argv):
    path = 'tool/i18n_keys.json'
    catalogue = json.load(io.open(path, encoding='utf-8'))
    connus = set(catalogue)
    found = collect()
    manquantes = {k: v for k, v in found.items() if k not in connus}
    if '--liste' in argv:
        for k in sorted(manquantes):
            print(json.dumps(k, ensure_ascii=False), '<-',
                  ', '.join(sorted(manquantes[k])))
    else:
        par_fichier = {}
        for k, fs in manquantes.items():
            for f in fs:
                par_fichier[f] = par_fichier.get(f, 0) + 1
        for f, n in sorted(par_fichier.items(), key=lambda x: -x[1]):
            print('%4d  %s' % (n, f))
    print('%d clés tr() dans le code, %d absentes du catalogue (%d clés).'
          % (len(found), len(manquantes), len(connus)))
    if '--ajoute' in argv and manquantes:
        catalogue.extend(sorted(manquantes))
        io.open(path, 'w', encoding='utf-8', newline='\n').write(
            json.dumps(catalogue, ensure_ascii=False, indent=2) + '\n')
        print('ajoutées au catalogue :', len(manquantes))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
