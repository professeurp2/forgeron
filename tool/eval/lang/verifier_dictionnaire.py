# -*- coding: utf-8 -*-
"""Interroge le dictionnaire en ligne « An ka taa » (bambara/dioula-anglais-français,
avec tons) pour chaque mot du lexique d'étude, et dit s'il est ATTESTÉ.

    python -I tool/eval/lang/verifier_dictionnaire.py <lexique.json> <sortie.json> [langue=bm]

Pourquoi : le lexique bambara a été écrit par un non-locuteur. Avant qu'un locuteur
le relise, on vérifie au moins que chaque mot existe dans un dictionnaire reconnu et
on garde SA définition (courte) à côté du mot, pour que le relecteur coche au lieu
d'écrire. Ce n'est PAS une validation : un mot attesté peut être mal choisi.

Le site accepte l'écriture sans lettres africaines (e pour ɛ, o pour ɔ, ny pour ɲ,
ng pour ŋ) — la même règle de pliage que notre moteur (command_lexicon.dart).

Politesse : une requête par seconde, identifiant explicite. Les définitions restent
la propriété du dictionnaire : le rapport n'en garde que le début, avec le lien.
"""
import html
import io
import json
import re
import subprocess
import sys
import time
import unicodedata
import urllib.parse

BASE = 'https://dictionary.ankataa.com/search.php'
UA = 'Mozilla/5.0 (recherche; verification du lexique Forgeron)'


def fold(s):
    """ɛ→e, ɔ→o, ɲ→ny, ŋ→ng, accents retirés : ce que le site attend."""
    m = {'ɛ': 'e', 'ɔ': 'o', 'ɲ': 'ny', 'ŋ': 'ng', 'Ɛ': 'e', 'Ɔ': 'o', 'Ɲ': 'ny', 'Ŋ': 'ng'}
    s = ''.join(m.get(c, c) for c in s)
    s = unicodedata.normalize('NFD', s)
    return ''.join(c for c in s if unicodedata.category(c) != 'Mn').lower()


def interroger(mot, langue='lexicon'):
    url = BASE + '?' + urllib.parse.urlencode({'input': fold(mot), 'search': langue})
    r = subprocess.run(['curl', '-s', '--max-time', '30', '-A', UA, url],
                       capture_output=True)
    page = r.stdout.decode('utf-8', errors='replace')
    page = re.sub(r'<script.*?</script>|<style.*?</style>', '', page, flags=re.S | re.I)
    texte = html.unescape(re.sub(r'\s+', ' ', re.sub(r'<[^>]+>', ' ', page)))
    i = texte.find('Search  ', texte.find('Tip'))
    texte = texte[i + 8:] if i >= 0 else texte
    for fin in ('Results from The An ka taa Forum', 'Question about usage', 'Copyright'):
        j = texte.find(fin)
        if j >= 0:
            texte = texte[:j]
    return url, texte.strip()


def principaux(texte, n=700):
    """Le début de la réponse, avant les « correspondances partielles »."""
    j = texte.find('Partial Matches')
    t = texte[:j] if j >= 0 else texte
    return t[:n].strip()


def mots_du_lexique(chemin, langue):
    d = json.load(io.open(chemin, encoding='utf-8'))['languages'][langue]
    out = {}

    def add(role, valeur, mot):
        out.setdefault(mot, set()).add('%s%s' % (role, ('/' + valeur) if valeur else ''))

    for role in ('light', 'urgent', 'alarm', 'fillers', 'negations', 'conditions',
                 'directions', 'questions', 'feed'):
        for w in d.get(role, []):
            add(role, '', w)
    for grp in ('actions', 'objects', 'units'):
        for k, ws in (d.get(grp) or {}).items():
            for w in ws:
                add(grp, k, w)
    n = d.get('numbers') or {}
    for k in ('units', 'tens'):
        for w in (n.get(k) or {}):
            add('nombre', k, w)
    for k in ('hundred', 'thousand', 'connectors'):
        for w in n.get(k, []):
            add('nombre', k, w)
    if n.get('tens_prefix'):
        add('nombre', 'dizaines', n['tens_prefix'])
    return out


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 2
    chemin, sortie = argv[1], argv[2]
    langue = argv[3] if len(argv) > 3 else 'bm'
    mots = mots_du_lexique(chemin, langue)
    # Les expressions de plusieurs mots sont vérifiées mot à mot.
    unites = {}
    for expr, roles in mots.items():
        for w in re.findall(r'[^\s\']+', expr):
            unites.setdefault(w, set()).update(roles)
    res = {}
    for i, (w, roles) in enumerate(sorted(unites.items())):
        url, texte = interroger(w)
        # « No results found » vient APRÈS l'en-tête de la page : le chercher partout
        # (une première version ne regardait que les 200 premiers caractères et
        # déclarait attestés des mots que le dictionnaire ne connaît pas).
        trouve = bool(texte) and 'No results found' not in texte
        res[w] = {'roles': sorted(roles), 'url': url, 'attesté': trouve,
                  'extrait': principaux(texte) if trouve else ''}
        sys.stderr.write('%3d/%d %-14s %s\n' % (i + 1, len(unites), w, 'oui' if trouve else 'NON'))
        time.sleep(1.0)
    with io.open(sortie, 'w', encoding='utf-8') as f:
        json.dump(res, f, ensure_ascii=False, indent=1)
    print('%d mots interrogés → %s' % (len(res), sortie))
    return 0


if __name__ == '__main__':
    sys.stdout = io.open(1, 'w', encoding='utf-8', closefd=False)
    sys.exit(main(sys.argv))
