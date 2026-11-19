# -*- coding: utf-8 -*-
"""Relecture du corpus de distillation par des locuteurs.

    python tool/distill/relecture.py exporter    # → distill_data/relecture/<langue>.csv
    python tool/distill/relecture.py importer    # → distill_data/corpus_relu.jsonl

exporter : une feuille par langue (CSV « ; », UTF-8, s'ouvre dans Excel ou
Google Sheets). Une ligne par réponse écrite du professeur : la question en
français, la même dans la langue, la réponse. Le relecteur remplit
`verdict` :

    ok         la réponse est juste et bien écrite
    corrige    juste sur le fond, écriture corrigée dans `correction`
    faux       sens faux, mal écrit ou incompréhensible : à écarter
    invente    promet une capacité ou une donnée que la machine n'a pas

et peut laisser un commentaire. Une ligne sans verdict n'est pas relue.

importer : relit les feuilles et écrit distill_data/corpus_relu.jsonl avec
les seuls exemples « ok » et « corrige » (la correction remplace la
réponse), marqués `relu: true`. Les appels d'outils sans texte qui
précèdent une réponse gardée sont repris avec elle ; ceux d'une réponse
écartée sont écartés aussi (l'élève ne doit pas apprendre la moitié d'une
mauvaise conversation). entrainer_qlora.py --corpus distill_data/corpus_relu.jsonl
"""
import csv
import glob
import json
import os
import sys

DOSSIER = os.path.join('distill_data', 'relecture')
CHAMPS = ['id', 'categorie', 'question_fr', 'question', 'reponse',
          'verdict', 'correction', 'commentaire']
VERDICTS_GARDES = {'ok', 'corrige'}


def charger(motif):
    out = []
    for f in sorted(glob.glob(motif)):
        with open(f, encoding='utf-8') as fh:
            out += [json.loads(l) for l in fh if l.strip()]
    return out


def texte(ex):
    return (ex['messages'][-1].get('content') or '').strip()


def conversation(ex):
    """Id de la conversation : « langue-graine-n » sans le n."""
    return ex['id'].rsplit('-', 1)[0]


def exporter(motif):
    exemples = [e for e in charger(motif) if texte(e)]
    if not exemples:
        sys.exit(f'Aucun exemple avec texte dans {motif}')
    os.makedirs(DOSSIER, exist_ok=True)
    par_langue = {}
    for e in exemples:
        par_langue.setdefault(e['langue'], []).append(e)
    for langue, lot in sorted(par_langue.items()):
        chemin = os.path.join(DOSSIER, f'{langue}.csv')
        if os.path.exists(chemin):
            print(f'{chemin} existe déjà (relecture en cours ?) : non écrasé')
            continue
        # utf-8-sig : Excel reconnaît l'UTF-8 (ɛ, ɔ, tons du yoruba…).
        with open(chemin, 'w', encoding='utf-8-sig', newline='') as fh:
            w = csv.DictWriter(fh, CHAMPS, delimiter=';')
            w.writeheader()
            for e in lot:
                w.writerow({'id': e['id'], 'categorie': e.get('categorie', ''),
                            'question_fr': e.get('graine_fr', ''),
                            'question': e.get('graine_traduite', ''),
                            'reponse': texte(e)})
        print(f'{chemin} : {len(lot)} réponses')


def importer(motif):
    verdicts = {}
    for f in sorted(glob.glob(os.path.join(DOSSIER, '*.csv'))):
        with open(f, encoding='utf-8-sig', newline='') as fh:
            for ligne in csv.DictReader(fh, delimiter=';'):
                v = (ligne.get('verdict') or '').strip().lower()
                if v:
                    verdicts[ligne['id']] = (v, (ligne.get('correction')
                                                 or '').strip())
    exemples = charger(motif)
    # Une conversation est gardée si toutes ses réponses écrites relues sont
    # gardées et qu'au moins une l'est.
    statut = {}
    for e in exemples:
        if not texte(e):
            continue
        v = verdicts.get(e['id'], (None, ''))[0]
        conv = conversation(e)
        if v is None:
            statut.setdefault(conv, None)
        elif v in VERDICTS_GARDES:
            if statut.get(conv) is not False:
                statut[conv] = True
        else:
            statut[conv] = False
    gardes, compte = [], {}
    for e in exemples:
        if statut.get(conversation(e)) is not True:
            continue
        e = dict(e, relu=True)
        v, corr = verdicts.get(e['id'], (None, ''))
        if v == 'corrige' and corr:
            msgs = [dict(m) for m in e['messages']]
            msgs[-1]['content'] = corr
            e['messages'] = msgs
        gardes.append(e)
        compte[e['langue']] = compte.get(e['langue'], 0) + 1
    sortie = os.path.join('distill_data', 'corpus_relu.jsonl')
    with open(sortie, 'w', encoding='utf-8') as fh:
        for e in gardes:
            fh.write(json.dumps(e, ensure_ascii=False) + '\n')
    nb = {}
    for v, _ in verdicts.values():
        nb[v] = nb.get(v, 0) + 1
    print(f'Verdicts lus : {nb}')
    print(f'{sortie} : {len(gardes)} exemples gardés {compte}')


if __name__ == '__main__':
    if len(sys.argv) < 2 or sys.argv[1] not in ('exporter', 'importer'):
        sys.exit(__doc__)
    motif = sys.argv[2] if len(sys.argv) > 2 else 'distill_data/corpus_2*.jsonl'
    (exporter if sys.argv[1] == 'exporter' else importer)(motif)
