# -*- coding: utf-8 -*-
"""Fabrique le Modelfile « sans réflexion » d'un modèle Qwen3 d'Ollama.

    python -I tool/ollama/make_nothink_modelfile.py <modèle_de_base> <sortie> [num_ctx]
    ollama create forgeron-qwen3-8b-nothink -f <sortie>

Pourquoi : Qwen3 « réfléchit » avant de répondre (≈ 1 000 tokens, 12 à 15 s par
requête sur une RTX 3070 Laptop, mesuré). Sur l'API /v1 d'Ollama 0.34.2, ni
`/no_think` (message ou prompt système), ni `think:false`, ni
`reasoning_effort:none` n'y changent quoi que ce soit (mesuré).

Ce que ça fait : lit le gabarit RÉEL du modèle (`ollama show --modelfile`) et ne
change qu'une chose — l'invite de génération contient d'emblée un bloc de
réflexion VIDE, comme le fait `enable_thinking=False` chez Qwen. Le reste du
gabarit (outils, rôles) est celui d'origine.

Marche pour qwen3:8b (modèle hybride). Échoue pour la build « réflexion » de
qwen3:4b, qui raisonne alors en clair dans sa réponse (voir
`Modelfile.etude-langues-qwen3-4b-nothink`).
"""
import io
import re
import subprocess
import sys

NL = chr(10)


def main(base, out, num_ctx='16384'):
    show = subprocess.run(['ollama', 'show', base, '--modelfile'],
                          capture_output=True, text=True, encoding='utf-8').stdout
    m = re.search(r'TEMPLATE """(.*?)"""', show, re.S)
    if not m:
        sys.exit('pas de gabarit dans ' + base)
    tpl = m.group(1)

    empty = '<think>' + NL + NL + '</think>' + NL + NL
    head = '<|im_start|>assistant' + NL
    # Modèle hybride : bloc de réflexion vide seulement si l'API a demandé think:false.
    cond = (head + '{{ if and $.IsThinkSet (not $.Think) -}}' + NL + empty
            + '{{ end -}}' + NL)
    # Build « réflexion » : la réflexion est ouverte d'avance.
    opened = head + '<think>' + NL + '{{ end }}'
    if cond in tpl:
        tpl = tpl.replace(cond, head + empty)
    elif opened in tpl:
        tpl = tpl.replace(opened, head + empty + '{{ end }}')
    else:
        sys.exit('fin de gabarit inattendue : ce script ne sait pas la modifier')

    text = (
        '# Généré par tool/ollama/make_nothink_modelfile.py à partir de ' + base + NL
        + '# Seule différence avec le gabarit d\'origine : la réflexion est refermée d\'avance.' + NL
        + 'FROM ' + base + NL
        + 'TEMPLATE """' + tpl + '"""' + NL
        + 'PARAMETER stop <|im_start|>' + NL
        + 'PARAMETER stop <|im_end|>' + NL
        + 'PARAMETER top_k 20' + NL
        + 'PARAMETER top_p 0.95' + NL
        + 'PARAMETER repeat_penalty 1' + NL
        + 'PARAMETER num_ctx ' + str(num_ctx) + NL
        + 'PARAMETER temperature 0.2' + NL)
    with io.open(out, 'w', encoding='utf-8', newline=NL) as f:
        f.write(text)
    print('écrit', out, len(text), 'octets')


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(2)
    main(sys.argv[1], sys.argv[2], *(sys.argv[3:4]))
