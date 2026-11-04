# -*- coding: utf-8 -*-
"""Liste les chaines visibles a l'ecran qui ne passent PAS par tr().

    python -I tool/i18n_audit.py            # resume
    python -I tool/i18n_audit.py --liste    # chaque chaine, avec son fichier

Le codemod initial ne connaissait que `Text(`, `title:`, `tooltip:`,
`labelText:`... Tout ce qui arrive a l'ecran par un autre chemin
(`subtitle:`, un argument positionnel d'une fonction maison, une ternaire
dans `Text(...)`) est reste en francais dans TOUTES les langues, sans que
rien ne le signale.
"""
import io
import json
import os
import re
import sys

RACINES = ['lib/presentation', 'lib/core/widgets']

STR = r"'(?:\\.|[^'\\\n])*'"
LITTERAL = re.compile(STR)
# Une chaine deja couverte : tr('...'  (eventuellement sur plusieurs
# fragments adjacents).
COUVERTE = re.compile(r"\btr\(\s*(?:%s\s*)+" % STR)

LETTRES = re.compile(r'[A-Za-zÀ-ÿ]')
ACCENT = re.compile(r'[À-ÿ]')
# Ce qui n'est pas du texte d'interface.
REJET = re.compile(
    r'^(assets/|package:|dart:|lib/|http|www\.|[a-z0-9_]+\.(dart|json|png|svg|nc|yaml))'
    r'|^\$|^[a-z][a-z0-9_]*$|^[A-Z][A-Z0-9_]*$|://')


def interessante(s):
    if len(s) < 4 or not LETTRES.search(s):
        return False
    if REJET.search(s):
        return False
    if len(LETTRES.findall(s)) < 4:
        return False
    # Du francais visible : soit un accent, soit plusieurs mots.
    return bool(ACCENT.search(s)) or ' ' in s.strip()


def sans_commentaires(src):
    """Neutralise commentaires et chaines a triple quote, longueur gardee.

    Indispensable : une apostrophe francaise dans un commentaire
    (« l'app », « jusqu'ici ») se lit sinon comme un debut de chaine, et
    tout le fichier part de travers derriere.
    """
    out = list(src)
    i, n = 0, len(src)
    while i < n:
        deux = src[i:i + 2]
        trois = src[i:i + 3]
        if trois in ("'''", '"""'):
            fin = src.find(trois, i + 3)
            fin = n if fin < 0 else fin + 3
            for j in range(i, fin):
                if src[j] != '\n':
                    out[j] = ' '
            i = fin
            continue
        if deux == '//':
            while i < n and src[i] != '\n':
                out[i] = ' '
                i += 1
            continue
        if deux == '/*':
            fin = src.find('*/', i + 2)
            fin = n if fin < 0 else fin + 2
            for j in range(i, fin):
                if src[j] != '\n':
                    out[j] = ' '
            i = fin
            continue
        if src[i] in ("'", '"'):
            quote = src[i]
            i += 1
            while i < n and src[i] != quote:
                i += 2 if src[i] == '\\' else 1
            i += 1
            continue
        i += 1
    return ''.join(out)


POLICE = re.compile(r'^(JetBrains Mono|Roboto|Courier|monospace|sans-serif)')
GCODE = re.compile(r'^\s*[\$GMT]\d|^\s*G\d{1,3}(\.\d)?\s|^\$[A-Z]*$'
                   r'|^[XYZABC][-\d]|\bG\d+ L\d+')


def classe(s, cles):
    """Pourquoi cette chaine est hors tr() — et si c'est un probleme."""
    if POLICE.search(s):
        return 'police'
    if GCODE.search(s):
        return 'gcode'
    if s in cles:
        # Deja au catalogue : traduite ailleurs ou au point d'affichage.
        return 'deja-cle'
    return 'MANQUANTE'


def main(argv):
    detail = '--liste' in argv
    cles = set(json.load(io.open('tool/i18n_keys.json', encoding='utf-8')))
    comptes = {'police': 0, 'gcode': 0, 'deja-cle': 0, 'MANQUANTE': 0}
    total = 0
    par_fichier = {}
    for racine in RACINES:
        for dossier, _, fichiers in os.walk(racine):
            for f in sorted(fichiers):
                if not f.endswith('.dart'):
                    continue
                p = os.path.join(dossier, f).replace(os.sep, '/')
                brut = io.open(p, encoding='utf-8').read()
                src = sans_commentaires(brut)

                couvert = set()
                for m in COUVERTE.finditer(src):
                    for lit in LITTERAL.finditer(m.group(0)):
                        couvert.add(m.start() + lit.start())

                restantes = []
                for m in LITTERAL.finditer(src):
                    if m.start() in couvert:
                        continue
                    corps = m.group(0)[1:-1]
                    if interessante(corps):
                        ligne = src.count('\n', 0, m.start()) + 1
                        cat = classe(corps, cles)
                        comptes[cat] += 1
                        if cat == 'MANQUANTE':
                            restantes.append((ligne, corps))
                if restantes:
                    par_fichier[p] = restantes
                    total += len(restantes)

    print('chaines hors tr(), par nature :')
    print('  police / technique  : %4d  (ne DOIT pas etre traduit)'
          % comptes['police'])
    print('  G-code / commande   : %4d  (ne DOIT pas etre traduit)'
          % comptes['gcode'])
    print('  deja au catalogue   : %4d  (traduite ailleurs, ou a l affichage)'
          % comptes['deja-cle'])
    print('  ------')
    print('  VRAIMENT MANQUANTES : %4d  dans %d fichiers'
          % (total, len(par_fichier)))
    print()
    for p, r in sorted(par_fichier.items(), key=lambda kv: -len(kv[1]))[:15]:
        print('  %4d  %s' % (len(r), p))
    if detail:
        print()
        for p, r in sorted(par_fichier.items()):
            print('--- %s' % p)
            for ligne, s in r:
                print('  %5d  %s' % (ligne, s[:100]))
    return 0


if __name__ == '__main__':
    sys.stdout = io.open(1, 'w', encoding='utf-8', closefd=False, newline='\n')
    sys.exit(main(sys.argv))
