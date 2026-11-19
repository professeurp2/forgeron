# -*- coding: utf-8 -*-
"""Compare le modèle de base et le même modèle + adaptateur LoRA, sur des
questions qui ne sont PAS des graines du corpus (celles du banc de
conversation, tool/eval/conversation_langues_test.dart).

    python tool/distill/comparer_adaptateur.py distill_data/adaptateur_essai_ep1

Même mise en forme qu'à l'entraînement : prompt système d'un exemple du
corpus dans la langue visée, réduit comme dans entrainer_qlora.py, sans
outils (réponse écrite seulement). Génération gloutonne, 220 tokens.
Écrit distill_data/comparaison_<adaptateur>.md : les deux réponses côte à
côte et une étiquette de langue grossière (mêmes marqueurs que le banc).
L'étiquette trie ; la lecture par un locuteur fait foi.

Pas de réseau ni d'Ollama : PyTorch seul, sur la carte graphique.
"""
import glob
import json
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from entrainer_qlora import BASE, charger, compacter  # noqa: E402

# Questions du banc de conversation (pas des graines du corpus).
QUESTIONS = [
    ('bm', 'I ni ce. I bɛ se ka mun kɛ n ye?'),
    ('bm', 'Mansin cogoya ka di sisan?'),
    ('sw', 'Habari, unaweza kunisaidia nini?'),
    ('sw', 'Hali ya mashine ikoje sasa hivi?'),
    ('wo', 'Salaam aleekum, lan nga mënn a def ngir man?'),
    ('wo', 'Naka la masin bi mel léegi?'),
    ('ha', 'Sannu, me za ka iya yi mini?'),
    ('ha', 'Yaya yanayin injin yanzu?'),
    ('ar', 'مرحبا، ماذا يمكنك أن تفعل لي؟'),
    ('fr', "Bonjour, qu'est-ce que tu peux faire pour moi ?"),
    ('en', 'Hi, what can you help me with?'),
]

# Mêmes marqueurs que tool/eval/conversation_langues_test.dart.
MARQUEURS = {
    'fr': r"\b(je|tu|vous|le|la|les|une|des|est|pour|avec|dans|machine|broche|bonjour|peux|voici|votre|sont|pas)\b",
    'en': r"\b(the|is|are|you|your|can|with|this|that|machine|spindle|hello|please|here|have)\b",
    'bm': r"\b(i|ni|ce|bɛ|ka|ye|ko|n|a|don|kɛ|mansin|sisan|ani|tɛ|be|ba|walima|fɛ|la)\b|[ɛɔɲŋ]",
    'sw': r"\b(habari|na|ya|wa|kwa|ni|hali|mashine|kuna|unaweza|tafadhali|sasa|hii|katika|kama|ninaweza)\b",
    'wo': r"\b(nga|naka|dafa|ngir|ak|ci|bi|mën|def|jërëjëf|masin|léegi|waaw|deedeet|man)\b",
    'ha': r"\b(da|ka|na|ne|ce|zan|iya|yanzu|injin|sannu|me|wannan|don|ina|kuma|yana)\b",
}


def langue(t):
    s = t.lower()
    if not s.strip():
        return '∅'
    if re.search(r'[一-鿿]', s):
        return 'zh!'
    if len(re.findall(r'[؀-ۿ]', s)) > len(s) * 0.3:
        return 'ar'
    scores = {k: len(re.findall(v, s)) for k, v in MARQUEURS.items()}
    best = max(scores, key=scores.get)
    return best if scores[best] else '?'


def prompt_systeme(exemples, lg):
    """Prompt système réduit du premier exemple à un seul tour de la langue."""
    for e in exemples:
        if e['langue'] != lg:
            continue
        users = [m for m in e['messages'] if m['role'] == 'user']
        if len(users) == 1 and not e['messages'][-1].get('tool_calls'):
            msgs, _ = compacter(e['messages'], e.get('tools') or [])
            return msgs[0]['content']
    return None


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    adaptateur = sys.argv[1].rstrip('/\\')
    corpus = sys.argv[2] if len(sys.argv) > 2 else 'distill_data/corpus_2*.jsonl'
    exemples = charger(corpus)

    import torch
    from peft import PeftModel
    from transformers import (AutoModelForCausalLM, AutoTokenizer,
                              BitsAndBytesConfig)
    tok = AutoTokenizer.from_pretrained(BASE)
    base = AutoModelForCausalLM.from_pretrained(
        BASE,
        quantization_config=BitsAndBytesConfig(
            load_in_4bit=True, bnb_4bit_quant_type='nf4',
            bnb_4bit_use_double_quant=True,
            bnb_4bit_compute_dtype=torch.bfloat16),
        dtype=torch.bfloat16, device_map={'': 0})
    model = PeftModel.from_pretrained(base, adaptateur)
    model.eval()

    def generer(system, question):
        msgs = [{'role': 'system', 'content': system},
                {'role': 'user', 'content': question}]
        # transformers 5 : renvoie un dictionnaire (input_ids, attention_mask).
        enc = tok.apply_chat_template(msgs, add_generation_prompt=True,
                                      return_tensors='pt', return_dict=True)
        ids = enc['input_ids'].to(0)
        with torch.no_grad():
            out = model.generate(ids, max_new_tokens=220, do_sample=False,
                                 repetition_penalty=1.05,
                                 pad_token_id=tok.eos_token_id)
        return tok.decode(out[0, ids.shape[1]:], skip_special_tokens=True).strip()

    lignes, bilan = [], {'base': 0, 'adapte': 0}
    for lg, q in QUESTIONS:
        system = prompt_systeme(exemples, lg)
        if system is None:
            print(f'{lg} : aucun prompt système dans le corpus, sauté')
            continue
        t = time.time()
        with model.disable_adapter():
            r_base = generer(system, q)
        r_adapte = generer(system, q)
        lb, la = langue(r_base), langue(r_adapte)
        bilan['base'] += lb == lg
        bilan['adapte'] += la == lg
        print(f'{lg} {time.time() - t:5.1f} s  base={lb:3} adapté={la:3}  {q}')
        lignes.append((lg, q, r_base, lb, r_adapte, la))

    nom = os.path.basename(adaptateur)
    sortie = os.path.join('distill_data', f'comparaison_{nom}.md')
    with open(sortie, 'w', encoding='utf-8') as fh:
        fh.write(f'# Base contre base + adaptateur `{nom}`\n\n')
        fh.write(f'Modèle de base : `{BASE}` (4 bits). Questions du banc de '
                 'conversation, pas des graines du corpus. Génération '
                 'gloutonne, 220 tokens au plus.\n\n')
        fh.write(f'Langue attendue (étiquette grossière) : base '
                 f'{bilan["base"]}/{len(lignes)}, adapté '
                 f'{bilan["adapte"]}/{len(lignes)}. **La lecture par un '
                 'locuteur fait foi.**\n\n')
        for lg, q, rb, lb, ra, la in lignes:
            fh.write(f'## {lg} — {q}\n\n')
            fh.write(f'**Base** (étiquette : {lb})\n\n> '
                     + rb.replace('\n', '\n> ') + '\n\n')
            fh.write(f'**Adapté** (étiquette : {la})\n\n> '
                     + ra.replace('\n', '\n> ') + '\n\n')
    print(f'Base {bilan["base"]}/{len(lignes)}, adapté '
          f'{bilan["adapte"]}/{len(lignes)} → {sortie}')


if __name__ == '__main__':
    main()
