# -*- coding: utf-8 -*-
"""Ajoute au catalogue les textes du parcours guide.

    python -I tool/i18n_collect_tutorial.py

`tutorial_data.dart` est une liste de DONNEES : on n'y met pas `tr()` (elle
est construite une fois, la traduction y serait figee). Les points
d'affichage sont deja branches (`tr(step.title)` dans
tutorial_tooltip_card.dart) — il manquait seulement les textes au
catalogue, donc aucune des quinze langues ne les traduisait.
"""
import io
import json
import re

SRC = 'lib/presentation/tutorial/tutorial_data.dart'
CHAMPS = ('title', 'description', 'action')

STR = r"'(?:\\.|[^'\\\n])*'"
RUN = r"%s(?:\s*%s)*" % (STR, STR)
LITTERAL = re.compile(STR)


def unescape(body):
    out, i = [], 0
    table = {'n': '\n', 't': '\t', "'": "'", '"': '"', '\\': '\\', '$': '$'}
    while i < len(body):
        if body[i] == '\\' and i + 1 < len(body) and body[i + 1] in table:
            out.append(table[body[i + 1]])
            i += 2
            continue
        out.append(body[i])
        i += 1
    return ''.join(out)


def main():
    src = io.open(SRC, encoding='utf-8').read()
    trouves = set()
    for champ in CHAMPS:
        rx = re.compile(r"\b%s:\s*(%s)" % (champ, RUN))
        for m in rx.finditer(src):
            corps = ''.join(unescape(l.group(0)[1:-1])
                            for l in LITTERAL.finditer(m.group(1)))
            if len(corps.strip()) >= 3:
                trouves.add(corps)

    chemin = 'tool/i18n_keys.json'
    cles = set(json.load(io.open(chemin, encoding='utf-8')))
    nouvelles = trouves - cles
    io.open(chemin, 'w', encoding='utf-8').write(
        json.dumps(sorted(cles | trouves), ensure_ascii=False, indent=1))

    print('textes du tutoriel : %d' % len(trouves))
    print('nouvelles cles     : %d' % len(nouvelles))
    print('catalogue total    : %d' % len(cles | trouves))


main()
