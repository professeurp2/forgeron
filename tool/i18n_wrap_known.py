# -*- coding: utf-8 -*-
"""Enveloppe les chaines brutes dont le texte EST deja une cle connue.

    python -I tool/i18n_wrap_known.py [--essai]

Le premier codemod ne reconnaissait que `Text(`, `title:`, `subtitle:`...
Resultat : « ALLER AU ZERO » est traduit sur un ecran et reste en francais
sur un autre, parce qu'a cet endroit la chaine est passee en argument
positionnel d'un widget maison. Ces sites-la ne demandent aucune traduction
nouvelle — seulement d'etre branches.

Ne touche qu'aux chaines dont le texte correspond EXACTEMENT a une cle de
tool/i18n_keys.json, et refuse tout contexte ou la chaine n'est pas du
texte affiche (police, G-code envoye a la machine, comparaison, clef de
map, journal).
"""
import io
import json
import os
import re
import sys

RACINES = ['lib/presentation', 'lib/core/widgets']
EXCLURE = {'lib/presentation/tutorial/tutorial_data.dart'}

STR = r"'(?:\\.|[^'\\\n])*'"
LITTERAL = re.compile(STR)
DEJA = re.compile(r"\btr\(\s*(?:%s\s*)+" % STR)

# Contextes ou une chaine n'est PAS du texte affiche. Regardes juste avant
# le litteral.
AVANT_INTERDIT = re.compile(
    r"(fontFamily|fontFamilyFallback|family|key|id|name|route|path|asset|"
    r"semanticsLabel\s*:\s*null|package)\s*:\s*$"
    r"|(sendRaw|sendCommand|sendGcode|write|debugPrint|print|log|logRaw|"
    r"startsWith|endsWith|contains|replaceAll|split|RegExp|jsonDecode|"
    r"setLanguage|localeId|getString|setString|remove)\s*\($"
    r"|(==|!=)\s*$"
    r"|case\s+$")

# Une cle qui ressemble a une commande machine ne doit jamais etre
# enveloppee, meme si elle figure au catalogue.
GCODE = re.compile(r"^\s*[\$GMT]\d|^\s*G\d{1,3}(\.\d)?\s|^\$[A-Z]*$")


def sans_commentaires(src):
    out = list(src)
    i, n = 0, len(src)
    while i < n:
        deux, trois = src[i:i + 2], src[i:i + 3]
        if trois in ("'''", '"""'):
            fin = src.find(trois, i + 3)
            fin = n if fin < 0 else fin + 3
            for j in range(i, fin):
                if src[j] != '\n':
                    out[j] = ' '
            i = fin
            continue
        if deux in ('//', '/*'):
            fin = (src.find('\n', i) if deux == '//'
                   else (src.find('*/', i + 2) + 2 or n))
            fin = n if fin <= 0 else fin
            for j in range(i, min(fin, n)):
                if src[j] != '\n':
                    out[j] = ' '
            i = fin
            continue
        if src[i] in ("'", '"'):
            q = src[i]
            i += 1
            while i < n and src[i] != q:
                i += 2 if src[i] == '\\' else 1
            i += 1
            continue
        i += 1
    return ''.join(out)


def dans_const(propre, pos):
    """Vrai si [pos] tombe dans une declaration `const` de haut niveau.

    `tr()` y est interdit (ce n'est pas une expression constante) et le
    deconst ne peut pas aider : retirer le `const` d'un `const kX = ...`
    casse en cascade tous les `const` qui s'y referent. Ces chaines-la se
    traduisent au point d'affichage, pas a la declaration.
    """
    point_virgule = propre.rfind(';', 0, pos)
    accolade = max(propre.rfind('{', 0, pos), propre.rfind('}', 0, pos))
    depart = max(point_virgule, accolade)
    debut_const = propre.rfind('\nconst ', 0, pos)
    return debut_const > depart


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


def main(argv):
    essai = '--essai' in argv
    cles = set(json.load(io.open('tool/i18n_keys.json', encoding='utf-8')))
    total, fichiers = 0, 0

    for racine in RACINES:
        for dossier, _, noms in os.walk(racine):
            for nom in sorted(noms):
                if not nom.endswith('.dart'):
                    continue
                p = os.path.join(dossier, nom).replace(os.sep, '/')
                if p in EXCLURE:
                    continue
                brut = io.open(p, encoding='utf-8').read()
                propre = sans_commentaires(brut)

                couvert = set()
                for m in DEJA.finditer(propre):
                    for lit in LITTERAL.finditer(m.group(0)):
                        couvert.add(m.start() + lit.start())

                remplacements = []
                for m in LITTERAL.finditer(propre):
                    if m.start() in couvert:
                        continue
                    texte = unescape(m.group(0)[1:-1])
                    if texte not in cles or GCODE.search(texte):
                        continue
                    amont = propre[max(0, m.start() - 40):m.start()]
                    if AVANT_INTERDIT.search(amont.rstrip()):
                        continue
                    if dans_const(propre, m.start()):
                        continue
                    remplacements.append((m.start(), m.end()))

                if not remplacements:
                    continue
                sortie, dernier = [], 0
                for debut, fin in remplacements:
                    sortie.append(brut[dernier:debut])
                    sortie.append('tr(' + brut[debut:fin] + ')')
                    dernier = fin
                sortie.append(brut[dernier:])
                nouveau = ''.join(sortie)

                if 'core/i18n/app_localizations.dart' not in nouveau:
                    rel = '../' * (p.count('/') - 1) + \
                        'core/i18n/app_localizations.dart'
                    lignes = nouveau.split('\n')
                    idx = max(i for i, l in enumerate(lignes)
                              if l.startswith('import '))
                    lignes.insert(idx + 1, "import '%s';" % rel)
                    nouveau = '\n'.join(lignes)

                if not essai:
                    io.open(p, 'w', encoding='utf-8',
                            newline='').write(nouveau)
                print('  %-56s %3d' % (p.split('/')[-1], len(remplacements)))
                total += len(remplacements)
                fichiers += 1

    print()
    print('sites branches : %d dans %d fichiers%s'
          % (total, fichiers, '  (ESSAI, rien ecrit)' if essai else ''))
    return 0


if __name__ == '__main__':
    sys.stdout = io.open(1, 'w', encoding='utf-8', closefd=False, newline='\n')
    sys.exit(main(sys.argv))
