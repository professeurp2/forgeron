# -*- coding: utf-8 -*-
"""Enveloppe les chaines litterales d'interface dans tr().

Transforme :
    Text('Demarrer')                    -> Text(tr('Demarrer'))
    const Text('Ligne 1 ' 'ligne 2')    -> Text(tr('Ligne 1 ligne 2'))
    Text('Fichier $nom introuvable')    -> Text(tr('Fichier {} introuvable', [nom]))

Ecrit tool/i18n_keys.json : la liste des cles francaises produites.

Les fichiers de donnees pures (const, sans widget) sont exclus : leurs chaines
sont traduites au point d'affichage, la cle etant le texte francais.
"""
import io
import json
import os
import re

ROOTS = ['lib/presentation', 'lib/core/widgets']

EXCLUDE = {
    # Donnees const : traduites la ou elles sont affichees.
    'lib/presentation/tutorial/tutorial_data.dart',
}

SINGLE = r"'(?:\\.|[^'\\\n])*'"
DOUBLE = r'"(?:\\.|[^"\\\n])*"'
ONE = '(?:%s|%s)' % (SINGLE, DOUBLE)
RUN = '%s(?:\\s*%s)*' % (ONE, ONE)

HEADS = [
    r"(?P<pre>(?<![\w.$])(?:const\s+)?Text\(\s*)",
    r"(?P<pre>\b(?:title|tooltip|labelText|hintText|helperText|semanticLabel|label):\s*)",
]
MATCHERS = [re.compile(h + '(?P<run>' + RUN + ')') for h in HEADS]

LITERAL = re.compile(ONE)
INTERP = re.compile(r"\$(?:\{(?P<expr>[^{}]*)\}|(?P<name>[A-Za-z_]\w*(?:\.\w+)*))")
LETTERS = re.compile(r"[A-Za-zÀ-ÿ]")
SKIP_SHAPES = re.compile(r"assets/|://|^[A-Z]:|\.(png|jpg|svg|nc|json|dart)$")


def fragments(run):
    """Contenu concatene des litteraux adjacents, echappements conserves."""
    parts = []
    for m in LITERAL.finditer(run):
        raw = m.group(0)
        body = raw[1:-1]
        if raw[0] == '"':
            body = body.replace('\\"', '"').replace("'", "\\'")
        parts.append(body)
    return ''.join(parts)


def template(body):
    """Remplace les interpolations par {} ; retourne (modele, expressions)."""
    args = []
    out = []
    pos = 0
    for m in INTERP.finditer(body):
        if m.start() > 0 and body[m.start() - 1] == '\\':
            continue
        out.append(body[pos:m.start()])
        out.append('{}')
        args.append(m.group('expr') or m.group('name'))
        pos = m.end()
    out.append(body[pos:])
    return ''.join(out), args


def leftover_dollar(model):
    """Un $ non echappe restant = interpolation non convertie."""
    for i, ch in enumerate(model):
        if ch == '$' and (i == 0 or model[i - 1] != '\\'):
            return True
    return False


def translatable(model):
    """Assez de texte pour meriter une traduction.

    Le seuil de trois lettres ecarte les unites et les codes machine ('mm',
    'G54', '{} mm') : les traduire n'aurait pas de sens et polluerait les
    dictionnaires.
    """
    if SKIP_SHAPES.search(model):
        return False
    return len(LETTERS.findall(model)) >= 3


def process(path, keys, report):
    src = io.open(path, encoding='utf-8').read()
    original = src

    for matcher in MATCHERS:
        out = []
        last = 0
        for m in matcher.finditer(src):
            if m.start() < last:
                continue
            pre = m.group('pre')
            body = fragments(m.group('run'))
            model, args = template(body)
            if not translatable(model):
                continue
            if leftover_dollar(model):
                report.append((path, 'interpolation complexe', body))
                continue
            if any(("'" in a or '"' in a) for a in args):
                report.append((path, 'expression avec quotes', body))
                continue
            head = pre
            if head.lstrip().startswith('const '):
                head = head.replace('const ', '', 1)
            call = "tr('" + model + "'"
            if args:
                call += ', [' + ', '.join(args) + ']'
            call += ')'
            out.append(src[last:m.start()])
            out.append(head + call)
            last = m.end()
            keys.add(model)
        out.append(src[last:])
        src = ''.join(out)

    if src == original:
        return False

    if 'core/i18n/app_localizations.dart' not in src:
        rel = '../' * (path.count('/') - 1) + 'core/i18n/app_localizations.dart'
        lines = src.split('\n')
        idx = max(i for i, line in enumerate(lines) if line.startswith('import '))
        lines.insert(idx + 1, "import '%s';" % rel)
        src = '\n'.join(lines)

    io.open(path, 'w', encoding='utf-8', newline='').write(src)
    return True


def main():
    keys = set()
    report = []
    touched = 0
    for root in ROOTS:
        for dirpath, _, files in os.walk(root):
            for f in sorted(files):
                if not f.endswith('.dart'):
                    continue
                p = os.path.join(dirpath, f).replace(os.sep, '/')
                if p in EXCLUDE:
                    continue
                if process(p, keys, report):
                    touched += 1

    io.open('tool/i18n_keys.json', 'w', encoding='utf-8').write(
        json.dumps(sorted(keys), ensure_ascii=False, indent=1))
    print('fichiers modifies :', touched)
    print('cles produites    :', len(keys))
    if report:
        print()
        print('a traiter a la main (%d) :' % len(report))
        for path, why, body in report:
            print('  %-50s %-22s %s' % (path.split('/')[-1], why, body[:56]))


main()
