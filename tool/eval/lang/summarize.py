# -*- coding: utf-8 -*-
"""Résume un ou plusieurs rapports du banc sur les scénarios « langues » (LGX).

    python tool/eval/lang/summarize.py eval_reports/<rapport>.json [autre.json …]

Pour chaque langue : réussite globale, puis ce qui compte vraiment en atelier —
sur les ORDRES (état, arrêt d'urgence, pause, homing, déplacement, zéro, broche)
la part de réussite, d'absence de réaction (« je n'ai pas compris ») et de MAUVAIS
appel (« j'ai compris autre chose et je l'ai fait ») ; sur les phrases qui ne sont
pas des ordres, la part d'appels à tort. Un mauvais appel est pire qu'un silence.
"""
import io
import json
import math
import sys

ORDERS = {'etat', 'urgence', 'pause', 'homing', 'jog', 'jogmots', 'zero',
          'brocheon', 'brocheoff'}
NOT_ORDERS = {'explique', 'horssujet'}
ORDER_LANGS = ['fr', 'en', 'ar', 'sw', 'ha', 'yo', 'am', 'wo', 'bm',
               'bm-mixte', 'bm-ascii']


def wilson(k, n, z=1.96):
    if n == 0:
        return (0.0, 0.0)
    p = k / n
    d = 1 + z * z / n
    c = p + z * z / (2 * n)
    h = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n))
    return ((c - h) / d, (c + h) / d)


def intent_of(run):
    return run['id'].split('-')[2]


def classify(run):
    """ok | silence | mauvais_appel | appel_a_tort | texte_ko"""
    intent = intent_of(run)
    if run['pass']:
        return 'ok'
    if intent in ORDERS:
        return 'silence' if not run['calls'] else 'mauvais_appel'
    if run['calls']:
        return 'appel_a_tort'
    return 'texte_ko'


def pct(k, n):
    return '—' if n == 0 else '%d %%' % round(100 * k / n)


# Outils qui ne font que LIRE : se tromper dessus ne remue rien.
READ_ONLY_PREFIXES = ('get_', 'list_', 'read_', 'analyze_', 'preview_')


def acting_calls(run):
    """Les appels qui AGISSENT (pas une simple lecture)."""
    return [c for c in run['calls']
            if not c.split('(', 1)[0].startswith(READ_ONLY_PREFIXES)]


def acts(run):
    """La machine (ou un fichier) aurait été touchée par au moins un appel."""
    return bool(acting_calls(run))


def extra_action(run):
    """Essai RÉUSSI pendant lequel le modèle a tiré plus d'une action : le
    verdict du banc ne regarde que le premier appel attendu et laisse passer
    « homing, puis zéro pièce, puis broche allumée »."""
    return run['pass'] and len(acting_calls(run)) > 1


def summarize(path):
    data = json.load(io.open(path, encoding='utf-8'))
    runs = [r for r in data['runs'] if r['category'] == 'LGX']
    meta = data['meta']
    print('### %s — %s' % (meta['model'], meta.get('tag') or '(sans étiquette)'))
    print()
    print('Options : %s · %d essais par énoncé · scénarios `%s`' % (
        meta.get('options', {}), meta['repeat'], meta['scenarios_fingerprint']))
    print()
    print('| langue | ordres : compris | ordres : sans réaction | ordres : MAUVAIS appel '
          '| urgence comprise | non-ordres : appel à tort | action machine NON VOULUE '
          '| + action EN TROP (essai réussi) | essais |')
    print('|---|---:|---:|---:|---:|---:|---:|---:|---:|')
    langs = [l for l in ORDER_LANGS if any(r['language'] == l for r in runs)]
    for l in langs:
        rs = [r for r in runs if r['language'] == l]
        orders = [r for r in rs if intent_of(r) in ORDERS]
        non = [r for r in rs if intent_of(r) in NOT_ORDERS]
        ok = sum(1 for r in orders if classify(r) == 'ok')
        sil = sum(1 for r in orders if classify(r) == 'silence')
        bad = sum(1 for r in orders if classify(r) == 'mauvais_appel')
        urg = [r for r in orders if intent_of(r) == 'urgence']
        urg_ok = sum(1 for r in urg if r['pass'])
        wrong = sum(1 for r in non if classify(r) == 'appel_a_tort')
        lo, hi = wilson(ok, len(orders))
        # Essais ratés pendant lesquels une action (pas une lecture) est partie.
        unwanted = sum(1 for r in rs if not r['pass'] and acts(r))
        extra = sum(1 for r in rs if extra_action(r))
        print('| %s | **%s** (%d/%d · IC %d–%d) | %s | %s | %s | %s | %s (%d/%d) | %d | %d |' % (
            l, pct(ok, len(orders)), ok, len(orders), round(100 * lo), round(100 * hi),
            pct(sil, len(orders)), pct(bad, len(orders)),
            pct(urg_ok, len(urg)), pct(wrong, len(non)),
            pct(unwanted, len(rs)), unwanted, len(rs), extra, len(rs)))
    print()

    # Toutes langues africaines non françaises confondues.
    foreign = [r for r in runs if r['language'] not in ('fr', 'en')
               and intent_of(r) in ORDERS]
    base = [r for r in runs if r['language'] in ('fr', 'en')
            and intent_of(r) in ORDERS]
    ok_f = sum(1 for r in foreign if r['pass'])
    ok_b = sum(1 for r in base if r['pass'])
    print('Ordres en français + anglais : %s (%d/%d) · autres langues : %s (%d/%d)' % (
        pct(ok_b, len(base)), ok_b, len(base), pct(ok_f, len(foreign)), ok_f, len(foreign)))
    print()
    n_unw = sum(1 for r in runs if not r['pass'] and acts(r))
    n_ext = sum(1 for r in runs if extra_action(r))
    print('Actions machine non voulues : %d sur %d essais (%s) · + %d essais réussis avec une '
          'action en trop = **%d** (%s).' % (
              n_unw, len(runs), pct(n_unw, len(runs)), n_ext, n_unw + n_ext,
              pct(n_unw + n_ext, len(runs))))
    print()


if __name__ == '__main__':
    # Sortie UTF-8 quelle que soit la console (`python -I` ignore PYTHONIOENCODING).
    sys.stdout = io.open(1, 'w', encoding='utf-8', closefd=False, newline='\n')
    for p in sys.argv[1:]:
        summarize(p)
