# -*- coding: utf-8 -*-
"""Enveloppe les derniers libelles bruts et les ajoute au catalogue.

    python -I tool/i18n_wrap_rest.py [--essai]

Troisieme et derniere passe. Les deux premieres ne reconnaissaient que des
positions nommees (`Text(`, `subtitle:`...) ou des chaines deja au
catalogue. Celle-ci prend tout litteral qui RESSEMBLE a du texte affiche et
qui n'est pas dans un contexte interdit.

Refus, dans l'ordre : contexte interdit (police, G-code envoye, comparaison,
journal, clef de map), declaration `const`, et tout ce qui n'a pas la forme
d'une phrase ou d'un libellé francais.
"""
import io
import json
import os
import re
import sys

RACINES = ['lib/presentation', 'lib/core/widgets']
# Tables `const` : leurs textes sont collectes par i18n_collect_data.py et
# traduits au point d'affichage.
EXCLURE = {
    'lib/presentation/tutorial/tutorial_data.dart',
    'lib/presentation/screens/desktop/ai_console_timeline.dart',
}

STR = r"'(?:\\.|[^'\\\n])*'"
LITTERAL = re.compile(STR)
DEJA = re.compile(r"\btr\(\s*(?:%s\s*)+" % STR)

AVANT_INTERDIT = re.compile(
    r"(fontFamily|fontFamilyFallback|family|key|id|name|route|path|asset|"
    r"package|value|group|tag)\s*:\s*$"
    r"|(sendRaw|sendCommand|sendGcode|write|writeln|debugPrint|print|log|"
    r"logRaw|startsWith|endsWith|contains|replaceAll|replaceFirst|split|"
    r"RegExp|jsonDecode|jsonEncode|setLanguage|localeId|getString|setString|"
    r"getBool|setBool|remove|containsKey|indexOf|Uri\.parse|DateFormat)\s*\($"
    r"|(==|!=|\?\?)\s*$"
    r"|case\s+$"
    # Valeur par defaut d'un parametre : doit etre une constante,
    # `[String label = tr('...')]` ne compile pas.
    r"|[\[{,]\s*[\w<>?]+\s+\w+\s*=\s*$")

POLICE = re.compile(r'^(JetBrains Mono|Roboto|Courier|monospace|sans-serif)$')
GCODE = re.compile(r'^\s*[\$GMT]\d|^\s*G\d{1,3}(\.\d)?\s|^\$[A-Z]*$'
                   r'|^[XYZABC][-\d]|\bG\d+ L\d+')
# Reperes materiels : une broche de microcontroleur n'est pas du francais.
MATERIEL = re.compile(r'^(GPIO|ADC|DAC|PWM|SPI|I2C|UART|PIN)\s*[\d.]*$'
                      r'|^[A-Z]{1,4}\d+$')

LETTRES = re.compile(r'[A-Za-zÀ-ÿ]')
ACCENT = re.compile(r'[À-ÿ]')
CHEMIN = re.compile(r'^(assets/|package:|dart:|lib/|http|www\.)|://'
                    r'|\.(dart|json|png|svg|nc|yaml|ttf)$')


def affichable(s):
    t = s.strip()
    if len(t) < 4 or not LETTRES.search(t):
        return False
    if CHEMIN.search(t) or POLICE.search(t) or GCODE.search(t):
        return False
    if MATERIEL.search(t):
        return False
    if len(LETTRES.findall(t)) < 4:
        return False
    if re.match(r'^[a-z][a-z0-9_]*$', t):      # identifiant
        return False
    return bool(ACCENT.search(t)) or ' ' in t


def litteraux(src):
    """Spans (debut, fin) des chaines de PREMIER niveau du fichier.

    Ecrit a la main plutot qu'en expression reguliere, parce qu'une regex
    perd le fil dans `'... ${cond ? 'a' : 'b'} ...'` : elle voit la
    quote interieure comme une fin de chaine et renvoie ensuite des
    fragments (« origine obligatoire avant tout usinage.")} »). Envelopper
    un fragment casse le fichier en silence.

    Les chaines imbriquees dans une interpolation ne sont PAS retournees :
    elles appartiennent a une expression, pas a un libelle.
    """
    spans = []
    i, n = 0, len(src)
    while i < n:
        deux = src[i:i + 2]
        if deux == '//':
            i = src.find('\n', i)
            if i < 0:
                break
            continue
        if deux == '/*':
            fin = src.find('*/', i + 2)
            i = n if fin < 0 else fin + 2
            continue
        if src[i] in ("'", '"'):
            brut = i > 0 and src[i - 1] == 'r'
            triple = src[i:i + 3] in ("'''", '"""')
            debut = i
            fin = _fin_chaine(src, i, triple, brut)
            if not triple:
                spans.append((debut, fin))
            i = fin
            continue
        i += 1
    return spans


def fusionne_runs(src, spans):
    """Fond les litteraux separes seulement par des blancs."""
    out = []
    for debut, fin in spans:
        if out and src[out[-1][1]:debut].strip() == '':
            out[-1] = (out[-1][0], fin)
        else:
            out.append((debut, fin))
    return out


def texte_du_run(src, debut, fin):
    """Contenu concatene d'un run, echappements resolus."""
    morceaux = []
    for d, f in litteraux(src[debut:fin]):
        morceaux.append(unescape(src[debut + d + 1:debut + f - 1]))
    return ''.join(morceaux)


def _fin_chaine(src, i, triple, brut):
    """Index juste apres la chaine qui commence a [i]."""
    n = len(src)
    marque = src[i:i + 3] if triple else src[i]
    i += len(marque)
    while i < n:
        if not brut and src[i] == '\\':
            i += 2
            continue
        if not brut and src[i:i + 2] == '${':
            i = _fin_interpolation(src, i + 2)
            continue
        if src.startswith(marque, i):
            return i + len(marque)
        i += 1
    return n


def _fin_interpolation(src, i):
    """Index juste apres le `}` qui ferme l'interpolation ouverte."""
    n, profondeur = len(src), 1
    while i < n and profondeur:
        if src[i] in ("'", '"'):
            i = _fin_chaine(src, i, src[i:i + 3] in ("'''", '"""'),
                            i > 0 and src[i - 1] == 'r')
            continue
        if src[i] == '{':
            profondeur += 1
        elif src[i] == '}':
            profondeur -= 1
        i += 1
    return i


def dans_const(propre, pos):
    """`const` englobant, sous toutes ses formes (`static const`,
    `: const [`, `const <T>{`). `tr()` y est impossible."""
    borne = max(propre.rfind(';', 0, pos), propre.rfind('{', 0, pos),
                propre.rfind('}', 0, pos))
    for m in re.finditer(r'\bconst\b', propre[:pos]):
        if m.start() > borne:
            return True
    return False


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
    depart = len(cles)
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
                # Dart concatene les litteraux adjacents : 'a' 'b' est UNE
                # chaine. Les envelopper separement donnerait
                # `tr('a') tr('b')`, qui ne compile pas — et couperait la
                # phrase en deux cles que personne ne saurait traduire.
                spans = fusionne_runs(brut, litteraux(brut))

                remplacements, vus = [], []
                for debut, fin in spans:
                    corps = brut[debut:fin]
                    # Deja enveloppee ?
                    amont_proche = brut[max(0, debut - 4):debut]
                    if amont_proche.rstrip().endswith('tr('):
                        continue
                    # Une chaine interpolee n'a pas de cle stable : elle
                    # releve de la premiere passe, qui sait transformer
                    # $x en {}. Ici on passe.
                    if re.search(r'(?<!\\)\$', corps):
                        continue
                    texte = texte_du_run(brut, debut, fin)
                    if not affichable(texte):
                        continue
                    amont = brut[max(0, debut - 48):debut].rstrip()
                    if AVANT_INTERDIT.search(amont):
                        continue
                    if dans_const(brut, debut):
                        continue
                    remplacements.append((debut, fin))
                    vus.append(texte)

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
                    cles |= set(vus)
                print('  %-50s %3d' % (nom, len(remplacements)))
                if '--montre' in argv:
                    for t in vus:
                        print('        %s' % t.replace('\n', ' / ')[:92])
                total += len(remplacements)
                fichiers += 1

    if not essai:
        io.open('tool/i18n_keys.json', 'w', encoding='utf-8').write(
            json.dumps(sorted(cles), ensure_ascii=False, indent=1))

    print()
    print('enveloppees : %d dans %d fichiers' % (total, fichiers))
    print('catalogue   : %d -> %d%s'
          % (depart, len(cles), '  (ESSAI, rien ecrit)' if essai else ''))
    return 0


if __name__ == '__main__':
    sys.stdout = io.open(1, 'w', encoding='utf-8', closefd=False, newline='\n')
    sys.exit(main(sys.argv))
