#!/usr/bin/env python3
"""
Forgeron CNC — Évaluation vocale & phonétique sur le corpus Google WAXAL
Dataset : https://huggingface.co/datasets/google/WaxalNLP (Licence CC-BY-4.0)
Bambara : https://huggingface.co/datasets/RobotsMali/bam-asr-early

Usage :
  pip install datasets soundfile
  python tool/eval/lang/waxal_eval.py --lang swa --samples 5
  python tool/eval/lang/waxal_eval.py --all
"""

import argparse
import sys
from dataclasses import dataclass
from typing import Dict, List

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")


@dataclass(frozen=True)
class WaxalConfig:
    forgeron_id: str
    iso639_3: str
    name: str
    hf_dataset: str
    has_asr: bool
    has_tts: bool
    phonetic_fallback: str


WAXAL_CATALOG: Dict[str, WaxalConfig] = {
    "sw": WaxalConfig("sw", "swa", "Kiswahili", "google/WaxalNLP", True, True, "en-US"),
    "ha": WaxalConfig("ha", "hau", "Hausa", "google/WaxalNLP", True, True, "en-US"),
    "yo": WaxalConfig("yo", "yor", "Yorùbá", "google/WaxalNLP", True, True, "en-US"),
    "ig": WaxalConfig("ig", "ibo", "Igbo", "google/WaxalNLP", True, True, "en-US"),
    "ln": WaxalConfig("ln", "lin", "Lingála", "google/WaxalNLP", True, False, "fr-FR"),
    "sn": WaxalConfig("sn", "sna", "ChiShona", "google/WaxalNLP", True, False, "en-US"),
    "mg": WaxalConfig("mg", "mlg", "Malagasy", "google/WaxalNLP", True, False, "fr-FR"),
    "ff": WaxalConfig("ff", "ful", "Fulfulde / Peul", "google/WaxalNLP", True, True, "fr-FR"),
    "ak": WaxalConfig("ak", "aka", "Akan / Twi", "google/WaxalNLP", True, True, "en-US"),
    "ee": WaxalConfig("ee", "ewe", "Eʋegbe (Éwé)", "google/WaxalNLP", True, True, "fr-FR"),
    "lg": WaxalConfig("lg", "lug", "Luganda", "google/WaxalNLP", True, True, "en-US"),
    # Partenaire Mali (RobotsMali / MALIBA-AI) en complément de WAXAL :
    "bm": WaxalConfig("bm", "bam", "Bamanankan (Bambara)", "RobotsMali/bam-asr-early", True, True, "fr-FR"),
}


def resolve_config(code: str) -> WaxalConfig:
    code = code.strip().lower()
    if code in WAXAL_CATALOG:
        return WAXAL_CATALOG[code]
    for cfg in WAXAL_CATALOG.values():
        if cfg.iso639_3 == code:
            return cfg
    raise ValueError(f"Langue '{code}' absente du catalogue WAXAL Forgeron.")


def stream_samples(cfg: WaxalConfig, count: int = 5) -> None:
    try:
        from datasets import load_dataset
    except ImportError:
        print("[!] Installez 'datasets' : pip install datasets soundfile")
        return

    print(
        f"\n=== {cfg.name} ({cfg.forgeron_id} / {cfg.iso639_3}) — "
        f"Source: {cfg.hf_dataset} (ASR={cfg.has_asr}, TTS={cfg.has_tts}) ==="
    )
    if cfg.hf_dataset == "google/WaxalNLP":
        ds = load_dataset("google/WaxalNLP", cfg.iso639_3, split="test", streaming=True)
    else:
        ds = load_dataset(cfg.hf_dataset, split="test", streaming=True)

    for idx, sample in enumerate(ds):
        if idx >= count:
            break
        text = (
            sample.get("transcription")
            or sample.get("text")
            or sample.get("sentence")
            or "<sans transcription>"
        )
        speaker = sample.get("speaker_id", "n/a")
        print(f"  [{idx + 1}] (speaker={speaker}) {text}")


def print_catalog_table() -> None:
    print(f"{'App ID':<8} {'ISO-3':<7} {'Langue':<24} {'Dataset Hugging Face':<26} {'ASR':<5} {'TTS':<5} {'Repli TTS'}")
    print("-" * 92)
    for cfg in WAXAL_CATALOG.values():
        print(
            f"{cfg.forgeron_id:<8} {cfg.iso639_3:<7} {cfg.name:<24} "
            f"{cfg.hf_dataset:<26} {'OUI' if cfg.has_asr else 'NON':<5} "
            f"{'OUI' if cfg.has_tts else 'NON':<5} {cfg.phonetic_fallback}"
        )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Inspection et évaluation du corpus Google WAXAL (google/WaxalNLP) pour Forgeron."
    )
    parser.add_argument("--lang", default="swa", help="Code ISO-1 (sw, ha, yo, bm...) ou ISO-3 (swa, hau, yor...)")
    parser.add_argument("--samples", type=int, default=5, help="Nombre d'échantillons à lire en streaming")
    parser.add_argument("--all", action="store_true", help="Afficher tout le catalogue WAXAL supporté")
    args = parser.parse_args()

    print_catalog_table()
    if not args.all:
        cfg = resolve_config(args.lang)
        stream_samples(cfg, count=args.samples)


if __name__ == "__main__":
    main()
