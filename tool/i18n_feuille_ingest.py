# -*- coding: utf-8 -*-
"""Reprend une feuille de relecture remplie et en fait un dictionnaire.

    python -I tool/i18n_feuille_ingest.py docs/addis/langues-locales/feuille-bambara-interface.md \
        --langue bm --relecteur "Nom Prenom" --date 2026-10-24

Ne lit QUE la colonne « Votre version ». La colonne « Brouillon » est celle de
l'assistant de code : elle n'entre jamais dans l'application, meme si elle a
l'air juste. Une case vide laisse la chaine en francais — c'est le
comportement voulu, pas un trou a combler.

Ecrit tool/translations/<langue>.json et tool/translations/<langue>.source.json
(qui a relu, quand, depuis quelle feuille). Lancer ensuite :
    python -I tool/i18n_gen.py
"""
import io
import json
import os
import re
import sys

LIGNE = re.compile(r'^\|\s*(\d+)\s*\|(.*)\|(.*)\|(.*)\|\s*$')


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    feuille = argv[1]

    def opt(nom, defaut=None):
        return argv[argv.index(nom) + 1] if nom in argv else defaut

    langue = opt('--langue', 'bm')
    relecteur = opt('--relecteur')
    date = opt('--date')
    if not relecteur or not date:
        print('Il faut --relecteur et --date : une traduction sans nom ni '
              'date reste un brouillon, et le dire est tout l\'interet de '
              'cette feuille.')
        return 2

    cles = set(json.load(io.open('tool/i18n_keys.json', encoding='utf-8')))
    out, inconnues, vides = {}, [], 0

    for brute in io.open(feuille, encoding='utf-8'):
        m = LIGNE.match(brute.rstrip('\n'))
        if not m:
            continue
        source = m.group(2).strip().replace(r'\|', '|')
        version = m.group(3 + 1).strip().replace(r'\|', '|')
        if not version or version == '—':
            vides += 1
            continue
        if source not in cles:
            inconnues.append(source)
            continue
        # Un repere perdu ferait disparaitre un code ou un numero de ligne.
        if source.count('{}') != version.count('{}'):
            print('  ! reperes {} differents, ignore : %s' % source[:60])
            continue
        out[source] = version

    cible = os.path.join('tool/translations', langue + '.json')
    io.open(cible, 'w', encoding='utf-8').write(
        json.dumps(out, ensure_ascii=False, indent=2, sort_keys=True))

    provenance = {
        'langue': langue,
        'statut': 'relu',
        'relu_par': relecteur,
        'relu_le': date,
        'feuille': feuille.replace('\\', '/'),
        'libelles_relus': len(out),
        'note': "Les chaines absentes de ce fichier s'affichent en francais. "
                "Les messages d'alarme et d'arret d'urgence ne sont pas dans "
                "cette feuille : ils suivent leur propre relecture.",
    }
    io.open(os.path.join('tool/translations', langue + '.source.json'),
            'w', encoding='utf-8').write(
        json.dumps(provenance, ensure_ascii=False, indent=2))

    print('relus      : %d' % len(out))
    print('laisses vides (restent en francais) : %d' % vides)
    if inconnues:
        print('hors catalogue, ignorees : %d' % len(inconnues))
        for s in inconnues[:5]:
            print('   - %s' % s[:70])
    print('ecrit      : %s' % cible)
    print('Lancer maintenant : python -I tool/i18n_gen.py')
    return 0


if __name__ == '__main__':
    sys.stdout = io.open(1, 'w', encoding='utf-8', closefd=False, newline='\n')
    sys.exit(main(sys.argv))
