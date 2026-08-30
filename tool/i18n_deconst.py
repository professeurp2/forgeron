# -*- coding: utf-8 -*-
"""Retire les `const` devenus impossibles apres l'enveloppe tr().

`const Text('x')` etait constant ; `Text(tr('x'))` ne l'est plus, et le
`const` peut se trouver plusieurs niveaux au-dessus (const SnackBar(content:
Text(...))). On remonte donc les parentheses/crochets englobants jusqu'a
trouver le mot-cle fautif.

Entree : la sortie de `flutter analyze` sur stdin.
"""
import io
import re
import sys

ERR = re.compile(
    r"^\s*error - .*? - (?P<file>[^ ]+\.dart):(?P<line>\d+):(?P<col>\d+) - "
    r"(?P<code>const_eval_method_invocation|invalid_constant|"
    r"const_with_non_constant_argument|non_constant_list_element|"
    r"non_constant_map_value|const_constructor_with_field_initialized_by_"
    r"non_const)\s*$")

OPEN = {'(': ')', '[': ']'}
CLOSE = {')': '(', ']': '['}


def blank_strings(src):
    """Copie de meme longueur ou le contenu des chaines est neutralise."""
    out = list(src)
    i = 0
    n = len(src)
    while i < n:
        ch = src[i]
        if ch in ("'", '"'):
            quote = ch
            i += 1
            while i < n and src[i] != quote:
                if src[i] == '\\':
                    out[i] = '_'
                    i += 1
                    if i < n:
                        out[i] = '_'
                        i += 1
                    continue
                out[i] = '_'
                i += 1
            i += 1
            continue
        if ch == '/' and i + 1 < n and src[i + 1] == '/':
            while i < n and src[i] != '\n':
                out[i] = ' '
                i += 1
            continue
        i += 1
    return ''.join(out)


def offset_of(src, line, col):
    lines = src.split('\n')
    return sum(len(x) + 1 for x in lines[:line - 1]) + col - 1


def enclosing_const(scan, pos):
    """Index du `const` qui rend [pos] constant, ou None."""
    depth = 0
    i = pos
    while i > 0:
        ch = scan[i]
        if ch in CLOSE:
            depth += 1
        elif ch in OPEN:
            if depth == 0:
                j = i - 1
                while j >= 0 and (scan[j].isalnum() or scan[j] in '_.<>'):
                    j -= 1
                k = j
                while k >= 0 and scan[k] in ' \n\t\r':
                    k -= 1
                if k >= 4 and scan[k - 4:k + 1] == 'const':
                    return k - 4
                i = j + 1
                depth = 0
            else:
                depth -= 1
        i -= 1
    return None


def main():
    targets = {}
    for raw in sys.stdin:
        m = ERR.match(raw.rstrip('\n'))
        if m:
            path = m.group('file').replace('\\', '/')
            targets.setdefault(path, []).append(
                (int(m.group('line')), int(m.group('col'))))

    if not targets:
        print('aucune erreur de const a corriger')
        return

    total = 0
    for path, spots in sorted(targets.items()):
        src = io.open(path, encoding='utf-8').read()
        scan = blank_strings(src)
        cuts = set()
        for line, col in spots:
            idx = enclosing_const(scan, offset_of(src, line, col))
            if idx is None:
                print('  ? const introuvable :', path, line, col)
                continue
            cuts.add(idx)
        for idx in sorted(cuts, reverse=True):
            end = idx + 5
            while end < len(src) and src[end] in ' \n\t\r':
                end += 1
            src = src[:idx] + src[end:]
            total += 1
        io.open(path, 'w', encoding='utf-8', newline='').write(src)
        print('  %-58s %d const retire(s)' % (path.split('/')[-1], len(cuts)))
    print('total :', total)


main()
