# -*- coding: utf-8 -*-
"""Cherche dans le dictionnaire « An ka taa » les mots bambara qui correspondent à une
liste de CONCEPTS (anglais ou français), pour pré-remplir la feuille de relecture avec
des propositions SOURCÉES plutôt que des cases vides.

    python -I tool/eval/lang/chercher_concepts.py <sortie.json>

Chaque réponse garde le début de ce que dit le dictionnaire, avec le lien de la requête :
c'est une aide à la relecture, pas une validation. Les définitions appartiennent au
dictionnaire (voir verifier_dictionnaire.py).
"""
import io
import json
import sys
import time

sys.path.insert(0, __file__.rsplit('tool', 1)[0] + 'tool/eval/lang')
from verifier_dictionnaire import interroger, principaux  # noqa: E402

# (langue de la requête, requête)
CONCEPTS = [
    ('english', 'machine'), ('english', 'engine'), ('english', 'program'),
    ('english', 'emergency'), ('english', 'danger'), ('english', 'help'),
    ('english', 'wait'), ('english', 'rest'), ('english', 'continue'),
    ('english', 'resume'), ('english', 'again'), ('english', 'finish'),
    ('english', 'show'), ('english', 'condition'), ('english', 'position'),
    ('english', 'return'), ('english', 'beginning'), ('english', 'zero'),
    ('english', 'speed'), ('english', 'slow'), ('english', 'up'),
    ('english', 'down'), ('english', 'left'), ('english', 'right'),
    ('english', 'forward'), ('english', 'backward'), ('english', 'yes'),
    ('english', 'no'), ('english', 'switch on'), ('english', 'turn off'),
    ('english', 'light a fire'), ('english', 'extinguish'), ('english', 'electricity'),
    ('english', 'button'), ('english', 'tool'), ('english', 'blacksmith'),
    ('english', 'thirty'), ('english', 'forty'), ('english', 'put'),
    ('english', 'say'), ('english', 'explain'), ('english', 'tell'),
    ('english', 'ten'), ('english', 'hundred'), ('english', 'thousand'),
    ('french', 'machine'), ('french', 'urgence'), ('french', 'au secours'),
    ('french', 'attendre'), ('french', 'continuer'), ('french', 'reprendre'),
    ('french', 'vitesse'), ('french', 'millimetre'), ('french', 'allumer'),
    ('french', 'eteindre'), ('french', 'danger'),
]


def main(argv):
    sortie = argv[1]
    res = {}
    for i, (langue, mot) in enumerate(CONCEPTS):
        url, texte = interroger(mot, langue)
        trouve = bool(texte) and 'No results found' not in texte
        res['%s:%s' % (langue, mot)] = {'url': url, 'trouvé': trouve,
                                         'extrait': principaux(texte, 900) if trouve else ''}
        sys.stderr.write('%2d/%d %-8s %-18s %s\n' % (i + 1, len(CONCEPTS), langue, mot, 'oui' if trouve else 'non'))
        time.sleep(1.0)
    with io.open(sortie, 'w', encoding='utf-8') as f:
        json.dump(res, f, ensure_ascii=False, indent=1)
    print('%d requêtes → %s' % (len(res), sortie))


if __name__ == '__main__':
    sys.stdout = io.open(1, 'w', encoding='utf-8', closefd=False)
    main(sys.argv)
