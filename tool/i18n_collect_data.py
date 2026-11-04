# -*- coding: utf-8 -*-
"""Ajoute au catalogue les textes des tables `const` de donnees.

    python -I tool/i18n_collect_data.py

Ces tables ne peuvent pas contenir `tr()` (ce ne serait plus une expression
constante, et retirer le `const` casse en cascade). Leurs textes sont donc
traduits au POINT D'AFFICHAGE — mais encore faut-il qu'ils figurent au
catalogue, sinon aucune langue ne les connait et `tr()` rend le francais.

Chaque source est declaree avec le point d'affichage qui la traduit, pour
qu'on puisse verifier le couple d'un coup d'oeil.
"""
import io
import json
import re

STR = r"'(?:\\.|[^'\\\n])*'"
RUN = r"%s(?:\s*%s)*" % (STR, STR)
LITTERAL = re.compile(STR)

# (fichier, motif de capture, ou la traduction a lieu)
SOURCES = [
    ('lib/presentation/tutorial/tutorial_data.dart',
     r"\b(?:title|description|action):\s*(%s)" % RUN,
     'tutorial_tooltip_card.dart : tr(step.title/description/action)'),
    ('lib/presentation/screens/desktop/ai_console_timeline.dart',
     r"^\s*'[a-z_]+':\s*(%s),\s*$" % RUN,
     'ai_console_timeline.dart : friendlyToolLabel -> tr(...)'),
    ('lib/presentation/screens/main_scaffold.dart',
     r"_NavDef\([^,]+,\s*(%s)\)" % RUN,
     'main_scaffold.dart : Text(tr(widget.label))'),
    ('lib/presentation/screens/mobile_dashboard_screen.dart',
     r"MobileTab\([^,]+,\s*(%s)\)" % RUN,
     'mobile_tab_bar.dart : Text(tr(t.label))'),
    ('lib/presentation/widgets/special_chars_row.dart',
     r"\blabel:\s*(%s)" % RUN,
     'special_chars_row.dart : Text(tr(set.label))'),
]

# Ce qui part dans ces tables sans etre du texte affichable.
REJET = re.compile(r'^(GPIO|gpio\.|[A-Z]\d|\d)|^[a-z_]+$|^.{0,2}$')


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
    chemin = 'tool/i18n_keys.json'
    cles = set(json.load(io.open(chemin, encoding='utf-8')))
    depart = len(cles)

    for fichier, motif, ou in SOURCES:
        src = io.open(fichier, encoding='utf-8').read()
        trouves = set()
        for m in re.finditer(motif, src, re.M):
            corps = ''.join(unescape(l.group(0)[1:-1])
                            for l in LITTERAL.finditer(m.group(1)))
            if len(corps.strip()) < 3 or REJET.search(corps):
                continue
            trouves.add(corps)
        nouvelles = trouves - cles
        cles |= trouves
        print('  %-44s %3d textes, %3d nouvelles'
              % (fichier.split('/')[-1], len(trouves), len(nouvelles)))
        print('      traduits par : %s' % ou)

    io.open(chemin, 'w', encoding='utf-8').write(
        json.dumps(sorted(cles), ensure_ascii=False, indent=1))
    print()
    print('catalogue : %d -> %d' % (depart, len(cles)))


main()
