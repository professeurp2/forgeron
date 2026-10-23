# -*- coding: utf-8 -*-
"""Complete tool/i18n_keys.json avec les chaines francaises hors ecrans.

Ces textes vivent dans des donnees (catalogue d'alarmes, parcours guide) ou
des enums : ils restent en francais dans le code, qui sert de cle, et sont
traduits au point d'affichage.
"""
import io
import json
import os
import re

SINGLE = r"'(?:\\.|[^'\\\n])*'"
DOUBLE = r'"(?:\\.|[^"\\\n])*"'
ONE = '(?:%s|%s)' % (SINGLE, DOUBLE)
RUN = '%s(?:\\s*%s)*' % (ONE, ONE)
LITERAL = re.compile(ONE)
LETTERS = re.compile(r"[A-Za-zÀ-ÿ]")
INTERP = re.compile(r"\$\{?\w")

# fichier -> noms d'arguments dont la valeur est du texte affiche
SOURCES = [
    ('lib/core/utils/grbl_alarm_catalog.dart', ['title', 'cause', 'action']),
    ('lib/presentation/tutorial/tutorial_data.dart',
     ['title', 'description', 'action']),
]

# fichier -> getters dont chaque `return`/`=>` produit un libelle affiche
RETURNS = [
    ('lib/application/providers/ai_agent_settings_provider.dart', 'label'),
    ('lib/domain/models/machining_mode.dart', 'label'),
]

# Ajoutees a la main : composees au point d'affichage (safety_banner).
EXTRA = [
    '{} — le programme est interrompu.',
    ' Fin(s) de course active(s) : {}.',
    'MACHINE EN ALARME',
    'ALARME {} — {}',
    'La machine est verrouillée.{} '
    'Lance la récupération guidée pour reprendre en sécurité.',
    "⚠️ Position machine perdue : prise d'origine obligatoire avant tout usinage.",
    'RÉCUPÉRER',
]


def body_of(run):
    parts = []
    for m in LITERAL.finditer(run):
        raw = m.group(0)
        inner = raw[1:-1]
        if raw[0] == '"':
            inner = inner.replace('\\"', '"').replace("'", "\\'")
        parts.append(inner)
    return ''.join(parts)


def usable(text):
    if INTERP.search(text):
        return False
    return len(LETTERS.findall(text)) >= 3


def main():
    keys = set(json.load(io.open('tool/i18n_keys.json', encoding='utf-8')))
    before = len(keys)
    added = {}

    for path, names in SOURCES:
        if not os.path.exists(path):
            print('  absent :', path)
            continue
        src = io.open(path, encoding='utf-8').read()
        rx = re.compile(r"\b(?:%s):\s*(?P<run>%s)" % ('|'.join(names), RUN))
        found = 0
        for m in rx.finditer(src):
            text = body_of(m.group('run'))
            if usable(text):
                keys.add(text)
                found += 1
        added[path.split('/')[-1]] = found

    for path, getter in RETURNS:
        src = io.open(path, encoding='utf-8').read()
        # Le corps du getter, jusqu'a la prochaine declaration de meme niveau.
        start = src.find('get %s' % getter)
        if start < 0:
            print('  getter absent :', path, getter)
            continue
        chunk = src[start:start + 900]
        found = 0
        for m in re.finditer(RUN, chunk):
            text = body_of(m.group(0))
            if usable(text):
                keys.add(text)
                found += 1
        added[path.split('/')[-1]] = found

    for text in EXTRA:
        keys.add(text)

    io.open('tool/i18n_keys.json', 'w', encoding='utf-8').write(
        json.dumps(sorted(keys), ensure_ascii=False, indent=1))

    for name, n in added.items():
        print('  %-42s %d chaines' % (name, n))
    print('cles : %d -> %d' % (before, len(keys)))


main()
