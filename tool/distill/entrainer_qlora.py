# -*- coding: utf-8 -*-
"""Entraîne un adaptateur LoRA (QLoRA 4 bits) de Qwen 2.5 sur le corpus de
distillation (tool/distill/generer_corpus_test.dart → distill_data/).

Environnement : %USERPROFILE%\\.forgeron\\venv-ft (PyTorch CUDA, transformers,
peft, trl, bitsandbytes), hors du dépôt.

    python tool/distill/entrainer_qlora.py --stats            # sans GPU
    python tool/distill/entrainer_qlora.py --steps 5          # essai court
    python tool/distill/entrainer_qlora.py                    # entraînement

Contexte réduit (--contexte compact, défaut) : un exemple réel pèse 6 000
à 12 000 tokens (mesuré le 6 nov. 2026 ; 1 500 à 2 800 en contexte réduit) (prompt système ~13-16 k caractères + jusqu'à 49 outils,
~25 k caractères). Un 7B en QLoRA sur une RTX 3070 Laptop (8 Go) ne tient pas
à cette longueur. Ce que l'élève doit apprendre tient dans la RÉPONSE :
écrire la langue de l'opérateur. On garde donc, du prompt système, le rôle,
le glossaire et les consignes de langue ; des outils, ceux que la
conversation appelle. Compromis assumé : l'élève s'entraîne sur un contexte
plus court que celui de l'application ; le banc de conversation dit, après
coup, si la compétence se transporte.

Seule la réponse finale (le message assistant du professeur) porte la perte ;
le prompt est masqué. Un exemple trop long est écarté, jamais tronqué.
"""
import argparse
import glob
import json
import os
import sys

BASE = 'Qwen/Qwen2.5-7B-Instruct'


def sections(system):
    """Découpe le prompt système en blocs « === TITRE === »."""
    parts, cur, title = [], [], ''
    for line in system.split('\n'):
        if line.startswith('=== ') and line.rstrip().endswith('==='):
            parts.append((title, '\n'.join(cur)))
            title, cur = line.strip(), [line]
        else:
            cur.append(line)
    parts.append((title, '\n'.join(cur)))
    return parts


# Blocs gardés : ce qui fonde la réponse (état, fiches, spécificités) et ce
# qui fixe sa langue (glossaire, consignes de langue).
GARDES = ('VOCABULAIRE', 'MOTS ', 'LANGUE', 'CONSIGNE FINALE', 'ÉTAT ACTUEL',
          'FICHES', 'SPÉCIFICITÉS')


def compacter(messages, tools):
    """Contexte réduit : rôle + blocs de langue/état ; outils appelés seuls."""
    msgs = [dict(m) for m in messages]
    if msgs and msgs[0]['role'] == 'system':
        blocs = sections(msgs[0]['content'] or '')
        role = blocs[0][1].split('\n\n')[0][:800]
        gardes = [txt for titre, txt in blocs[1:]
                  if any(g in titre.upper() for g in GARDES)]
        msgs[0]['content'] = '\n\n'.join([role] + gardes)
    appeles = {c['function']['name'] for m in msgs
               for c in (m.get('tool_calls') or [])}
    outils = [t for t in tools if t.get('function', {}).get('name') in appeles]
    return msgs, outils


def charger(motif):
    out = []
    for f in sorted(glob.glob(motif)):
        with open(f, encoding='utf-8') as fh:
            for line in fh:
                if line.strip():
                    out.append(json.loads(line))
    return out


def encoder(tok, ex, max_len, compact):
    msgs, tools = ex['messages'], ex.get('tools') or []
    if compact:
        msgs, tools = compacter(msgs, tools)
    for m in msgs:  # le gabarit Qwen attend des arguments en objet
        for c in m.get('tool_calls') or []:
            a = c['function'].get('arguments')
            if isinstance(a, str):
                try:
                    c['function']['arguments'] = json.loads(a)
                except ValueError:
                    pass
    prompt = tok.apply_chat_template(msgs[:-1], tools=tools or None,
                                     add_generation_prompt=True, tokenize=False)
    full = tok.apply_chat_template(msgs, tools=tools or None, tokenize=False)
    if not full.startswith(prompt):
        return None, 'gabarit'
    p_ids = tok(prompt, add_special_tokens=False)['input_ids']
    f_ids = tok(full, add_special_tokens=False)['input_ids']
    if len(f_ids) > max_len:
        return None, 'trop_long'
    labels = [-100] * len(p_ids) + f_ids[len(p_ids):]
    return {'input_ids': f_ids, 'attention_mask': [1] * len(f_ids),
            'labels': labels}, None


def main():
    ap = argparse.ArgumentParser()
    # Par défaut le corpus relu (tool/distill/relecture.py importer) ; les
    # corpus bruts restent utilisables pour un essai : --corpus
    # 'distill_data/corpus_2*.jsonl'.
    ap.add_argument('--corpus', default='distill_data/corpus_relu.jsonl')
    ap.add_argument('--base', default=BASE)
    ap.add_argument('--sortie', default='distill_data/adaptateur')
    ap.add_argument('--max-len', type=int, default=3072)
    ap.add_argument('--contexte', choices=['compact', 'complet'],
                    default='compact')
    ap.add_argument('--epoques', type=float, default=2)
    ap.add_argument('--lr', type=float, default=2e-4)
    ap.add_argument('--rang', type=int, default=16)
    ap.add_argument('--steps', type=int, default=-1,
                    help='nombre de pas (essai) ; -1 = époques complètes')
    ap.add_argument('--stats', action='store_true',
                    help='longueurs seulement, sans charger le modèle')
    a = ap.parse_args()

    from transformers import AutoTokenizer
    tok = AutoTokenizer.from_pretrained(a.base)
    exemples = charger(a.corpus)
    if not exemples:
        sys.exit(f'Aucun exemple dans {a.corpus}')
    if any(not e.get('relu') for e in exemples):
        print('ATTENTION : corpus NON relu par des locuteurs '
              '(docs/addis/distillation-langues.md, étape 2).')

    data, ecarts, longueurs = [], {}, []
    for e in exemples:
        enc, motif = encoder(tok, e, a.max_len, a.contexte == 'compact')
        if enc is None:
            ecarts[motif] = ecarts.get(motif, 0) + 1
            continue
        data.append(enc)
        longueurs.append(len(enc['input_ids']))
    longueurs.sort()
    print(f'{len(exemples)} exemples, {len(data)} gardés, écartés : {ecarts}')
    if longueurs:
        print(f'tokens : min {longueurs[0]}, médiane '
              f'{longueurs[len(longueurs) // 2]}, max {longueurs[-1]}')
    if a.stats or not data:
        return

    import torch
    from datasets import Dataset
    from peft import LoraConfig, get_peft_model
    from transformers import (AutoModelForCausalLM, BitsAndBytesConfig,
                              DataCollatorForSeq2Seq, Trainer,
                              TrainingArguments)

    # Attention : sans masque (lot de 1), transformers passe enable_gqa=True
    # à SDPA ; sous Windows (pas de noyau flash) le noyau « efficace » ne
    # gère pas le GQA et SDPA retombe sur le noyau mathématique, qui
    # matérialise la matrice 2 800² : ~2 Go par couche au lieu de ~150 Mo
    # (mesuré le 6 nov. 2026). On répète donc les têtes K/V avant SDPA.
    import transformers.integrations.sdpa_attention as sdpa
    sdpa.use_gqa_in_sdpa = lambda *args, **kwargs: False

    model = AutoModelForCausalLM.from_pretrained(
        a.base,
        quantization_config=BitsAndBytesConfig(
            load_in_4bit=True, bnb_4bit_quant_type='nf4',
            bnb_4bit_use_double_quant=True,
            bnb_4bit_compute_dtype=torch.bfloat16),
        dtype=torch.bfloat16, device_map={'': 0})
    # Pas de prepare_model_for_kbit_training : il passe en float32 les
    # embeddings et lm_head (2 × 1,1 Go de plus) — mesuré le 6 nov. 2026,
    # 12,6 Go demandés sur une carte de 8 Go.
    model.gradient_checkpointing_enable(
        gradient_checkpointing_kwargs={'use_reentrant': False})
    model.enable_input_require_grads()
    model = get_peft_model(model, LoraConfig(
        r=a.rang, lora_alpha=2 * a.rang, lora_dropout=0.05,
        target_modules=['q_proj', 'k_proj', 'v_proj', 'o_proj', 'gate_proj',
                        'up_proj', 'down_proj'],
        task_type='CAUSAL_LM'))
    model.print_trainable_parameters()

    # transformers 5 n'a plus warmup_ratio : 5 % des pas, calculé ici.
    pas = a.steps if a.steps > 0 else max(
        1, int(len(data) / 8 * a.epoques + 0.999))
    class TrainerReponse(Trainer):
        """Logits calculés sur les seuls tokens de la réponse (lot de 1) :
        sur toute la séquence, 152 k mots × 2 800 tokens en float32 font
        1,6 Go pour des positions masquées de toute façon."""

        def compute_loss(self, model, inputs, return_outputs=False,
                         num_items_in_batch=None):
            labels = inputs['labels']
            garde = (labels[0, 1:] != -100).nonzero().squeeze(-1)
            out = model(input_ids=inputs['input_ids'],
                        attention_mask=inputs['attention_mask'],
                        logits_to_keep=garde)
            # Somme / tokens de réponse du lot accumulé : le Trainer ne
            # redivise pas par l'accumulation quand num_items_in_batch est
            # fourni (transformers 5).
            loss = torch.nn.functional.cross_entropy(
                out.logits[0].float(), labels[0, garde + 1],
                reduction='sum')
            loss = loss / (num_items_in_batch if num_items_in_batch
                           is not None else max(1, garde.numel()))
            return (loss, out) if return_outputs else loss

    trainer = TrainerReponse(
        model=model,
        args=TrainingArguments(
            output_dir=a.sortie, per_device_train_batch_size=1,
            gradient_accumulation_steps=8, num_train_epochs=a.epoques,
            max_steps=a.steps, learning_rate=a.lr, lr_scheduler_type='cosine',
            warmup_steps=max(1, pas // 20), logging_steps=1, save_strategy='epoch',
            bf16=True, optim='paged_adamw_8bit', report_to=[],
            gradient_checkpointing=True,
            gradient_checkpointing_kwargs={'use_reentrant': False}),
        train_dataset=Dataset.from_list(data),
        data_collator=DataCollatorForSeq2Seq(tok, padding=True,
                                             label_pad_token_id=-100))
    torch.cuda.reset_peak_memory_stats()
    trainer.train()
    model.save_pretrained(a.sortie)
    tok.save_pretrained(a.sortie)
    print(f'VRAM max : {torch.cuda.max_memory_allocated() / 2**30:.2f} Go')
    print(f'Adaptateur : {os.path.abspath(a.sortie)}')


if __name__ == '__main__':
    main()
