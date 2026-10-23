# -*- coding: utf-8 -*-
"""Genere lib/core/i18n/translations/<code>.dart depuis tool/translations/.

Les cles sont les chaines francaises **evaluees** (apostrophe reelle, saut de
ligne reel) : c'est ce que tr() recoit a l'execution. L'echappement Dart est
produit ici, jamais a la main.

Usage :
    python tool/i18n_gen.py            # genere tous les .dart
    python tool/i18n_gen.py --normalize  # deschappe tool/i18n_keys.json
"""
import io
import json
import os
import sys

OUT_DIR = 'lib/core/i18n/translations'
SRC_DIR = 'tool/translations'

ESCAPES = [('\\\\', '\\'), ("\\'", "'"), ('\\"', '"'), ('\\n', '\n'),
           ('\\t', '\t'), ('\\$', '$')]


def unescape_dart(text):
    out = []
    i = 0
    while i < len(text):
        if text[i] == '\\' and i + 1 < len(text):
            nxt = text[i + 1]
            mapping = {'n': '\n', 't': '\t', "'": "'", '"': '"',
                       '\\': '\\', '$': '$'}
            if nxt in mapping:
                out.append(mapping[nxt])
                i += 2
                continue
        out.append(text[i])
        i += 1
    return ''.join(out)


def dart_literal(text):
    """Litteral Dart simple quote, echappe."""
    body = (text.replace('\\', '\\\\')
                .replace("'", "\\'")
                .replace('$', '\\$')
                .replace('\n', '\\n')
                .replace('\t', '\\t'))
    return "'" + body + "'"


def normalize():
    path = 'tool/i18n_keys.json'
    keys = json.load(io.open(path, encoding='utf-8'))
    keys = sorted({unescape_dart(k) for k in keys})
    io.open(path, 'w', encoding='utf-8').write(
        json.dumps(keys, ensure_ascii=False, indent=1))
    print('cles normalisees :', len(keys))


def write_index(codes):
    """Reecrit translations.dart depuis les langues reellement generees.

    Sans ca, un dictionnaire pouvait etre produit sans jamais etre enregistre
    dans kAppTranslations : la langue s'affichait alors entierement en
    francais, sans erreur ni avertissement nulle part.
    """
    lines = ["import '%s.dart';" % c for c in codes]
    lines += [
        '',
        "/// Dictionnaires de l'interface, par code de langue ISO 639-1.",
        '///',
        '/// Genere par tool/i18n_gen.py : la liste suit les fichiers presents',
        '/// dans tool/translations/. Le francais ne figure pas ici, c'
        "'est la",
        '/// langue source, celle des cles. Une langue absente de cette table,',
        "/// ou une cle absente d'un dictionnaire, affiche le francais.",
        'const Map<String, Map<String, String>> kAppTranslations =',
        '    <String, Map<String, String>>{',
    ]
    for c in codes:
        lines.append("  '%s': k%s," % (c, c.capitalize()))
    lines.append('};')
    lines.append('')
    io.open(os.path.join(OUT_DIR, 'translations.dart'), 'w',
            encoding='utf-8', newline='').write('\n'.join(lines))
    print('index   : %d langues enregistrees' % len(codes))


def generate():
    keys = set(json.load(io.open('tool/i18n_keys.json', encoding='utf-8')))
    total = 0
    codes = []
    for name in sorted(os.listdir(SRC_DIR)):
        if not name.endswith('.json'):
            continue
        code = name[:-5]
        entries = json.load(io.open(os.path.join(SRC_DIR, name),
                                    encoding='utf-8'))
        unknown = [k for k in entries if k not in keys]
        kept = {k: v for k, v in entries.items() if k in keys and v and v != k}

        var = 'k' + code.capitalize()
        lines = [
            "// Traductions de l'interface Forgeron — %s." % code.upper(),
            '//',
            '// Genere par tool/i18n_gen.py depuis tool/translations/%s.' % name,
            '// Cle = chaine francaise du code. Une cle absente affiche le',
            '// francais : ne jamais laisser une valeur vide ici.',
            'const Map<String, String> %s = <String, String>{' % var,
        ]
        for k in sorted(kept):
            lines.append('  %s: %s,' % (dart_literal(k), dart_literal(kept[k])))
        lines.append('};')
        lines.append('')

        io.open(os.path.join(OUT_DIR, code + '.dart'), 'w',
                encoding='utf-8', newline='').write('\n'.join(lines))

        flag = ''
        if unknown:
            flag = '  (%d cle(s) inconnue(s) ignoree(s))' % len(unknown)
        print('  %-4s %4d / %d entrees%s' % (code, len(kept), len(keys), flag))
        total += len(kept)
        codes.append(code)
    write_index(codes)
    print('total :', total, 'traductions')


if __name__ == '__main__':
    if '--normalize' in sys.argv:
        normalize()
    else:
        generate()
