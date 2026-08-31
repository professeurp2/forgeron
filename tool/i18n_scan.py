# -*- coding: utf-8 -*-
"""Inventaire des chaines litterales en position UI.

Ne modifie rien : sert a chiffrer et a reperer les cas qui devront etre
traites a la main (interpolation, chaines hors presentation).
"""
import io
import os
import re
import json

ROOTS = ['lib/presentation', 'lib/core/widgets']

STR = r"(?P<q>'|\")(?P<s>(?:\\.|(?!(?P=q))[^\\])*)(?P=q)"

PATTERNS = [
    ('text', re.compile(r"(?<![\w.])Text\(\s*" + STR)),
    ('title', re.compile(r"\btitle:\s*" + STR)),
    ('tooltip', re.compile(r"\btooltip:\s*" + STR)),
    ('label', re.compile(
        r"\b(?:labelText|hintText|helperText|errorText|semanticLabel|label):\s*"
        + STR)),
]

INTERP = re.compile(r"\$\{?\w")


def looks_translatable(s):
    if len(s.strip()) < 2:
        return False
    if not re.search(r"[A-Za-zÀ-ÿ]", s):
        return False
    return True


def main():
    rows = []
    for root in ROOTS:
        for dirpath, _, files in os.walk(root):
            for f in files:
                if not f.endswith('.dart'):
                    continue
                p = os.path.join(dirpath, f).replace(os.sep, '/')
                src = io.open(p, encoding='utf-8').read()
                for kind, rx in PATTERNS:
                    for m in rx.finditer(src):
                        s = m.group('s')
                        if not looks_translatable(s):
                            continue
                        line = src.count('\n', 0, m.start()) + 1
                        rows.append({
                            'file': p, 'line': line, 'kind': kind, 'text': s,
                            'interp': bool(INTERP.search(s)),
                        })

    io.open('tool/i18n_scan.json', 'w', encoding='utf-8').write(
        json.dumps(rows, ensure_ascii=False, indent=1))

    total = len(rows)
    interp = sum(1 for r in rows if r['interp'])
    uniq = len({r['text'] for r in rows if not r['interp']})
    print('occurrences        :', total)
    print('  dont interpolees :', interp, '(a traiter a la main)')
    print('chaines uniques    :', uniq)
    print()
    print('par type :')
    for k in ['text', 'title', 'tooltip', 'label']:
        print('  %-8s %d' % (k, sum(1 for r in rows if r['kind'] == k)))
    print()
    print('top fichiers :')
    per = {}
    for r in rows:
        per[r['file']] = per.get(r['file'], 0) + 1
    for f, n in sorted(per.items(), key=lambda kv: -kv[1])[:14]:
        print('  %4d  %s' % (n, f))


main()
