"""Coût de l'agent IA pour 1 000 requêtes d'opérateur — objectif 5 du programme.

Lit un rapport de Forgeron-Bench (.json) et calcule, pour 1 000 requêtes :

- la voie EN LIGNE : tokens × tarif (les tarifs sont À FOURNIR : ils changent,
  et ce script n'en connaît aucun) ;
- la voie LOCALE : énergie mesurée pendant le banc (BENCH_POWER=1) × prix du
  kWh, plus l'amortissement du PC.

Aucun prix n'est inscrit ici. Un prix manquant s'affiche « à renseigner » :
mieux vaut un trou visible qu'un chiffre inventé.

    python tool/eval/cost_model.py eval_reports/<rapport>.json \
        --kwh-price 0.15 --pc-price 900 --pc-years 4 --requests-per-day 200 \
        --cloud-in-per-m 0.10 --cloud-out-per-m 0.40

Toutes les valeurs monétaires sont dans UNE même devise, la vôtre.
"""

import argparse
import json
import sys


def fmt(value, unit=""):
    return "à renseigner" if value is None else f"{value:,.3f}{unit}".replace(",", " ")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("report", help="rapport Forgeron-Bench (.json)")
    ap.add_argument("--kwh-price", type=float, help="prix du kWh")
    ap.add_argument("--pc-price", type=float, help="prix du PC (avec GPU) qui héberge le modèle")
    ap.add_argument("--pc-years", type=float, default=4.0, help="durée d'amortissement en années (défaut 4)")
    ap.add_argument("--requests-per-day", type=float, help="requêtes d'opérateur par jour et par atelier")
    ap.add_argument("--cloud-in-per-m", type=float, help="tarif en ligne : prix d'un million de tokens EN ENTRÉE")
    ap.add_argument("--cloud-out-per-m", type=float, help="tarif en ligne : prix d'un million de tokens EN SORTIE")
    ap.add_argument("--input-share", type=float, default=0.97,
                    help="part des tokens qui sont en entrée (défaut 0,97 : le prompt domine)")
    args = ap.parse_args()

    with open(args.report, encoding="utf-8") as f:
        rep = json.load(f)

    meta, head = rep["meta"], rep["headline"]
    runs = head["runs"]
    tokens = head["mean_tokens"]
    p50 = head["latency_p50_ms"]
    power = meta.get("power")

    print(f"# Coût pour 1 000 requêtes — {meta['model']} ({meta['date'][:10]})\n")
    print(f"- Tokens par requête (moyenne) : **{tokens:,.0f}**".replace(",", " "))
    print(f"- Latence médiane : **{(p50 or 0) / 1000:.2f} s**")
    print(f"- Outils déclarés : {meta.get('tool_count')} ; options : {meta.get('options', {})}\n")

    # Voie en ligne
    cloud = None
    if args.cloud_in_per_m is not None and args.cloud_out_per_m is not None:
        tin = tokens * args.input_share
        tout = tokens * (1 - args.input_share)
        per_request = (tin * args.cloud_in_per_m + tout * args.cloud_out_per_m) / 1_000_000
        cloud = per_request * 1000

    # Voie locale
    energy_wh = None
    if power:
        wh_per_request = power["energy_wh"] / runs if runs else None
        energy_wh = wh_per_request * 1000 if wh_per_request is not None else None
    energy_cost = (energy_wh / 1000 * args.kwh_price) if (energy_wh is not None and args.kwh_price is not None) else None

    amort = None
    if args.pc_price is not None and args.requests_per_day:
        total_requests = args.requests_per_day * 365 * args.pc_years
        amort = args.pc_price / total_requests * 1000

    local_total = None
    if energy_cost is not None and amort is not None:
        local_total = energy_cost + amort

    print("| Voie | Coût / 1 000 requêtes | Comment |")
    print("|---|---:|---|")
    print(f"| En ligne (tarif fourni) | {fmt(cloud)} | tokens × tarif ; palier gratuit : 0 jusqu'à la limite quotidienne |")
    print(f"| Local — énergie | {fmt(energy_cost)} | {fmt(energy_wh, ' Wh')} pour 1 000 requêtes (GPU, mesuré) |")
    print(f"| Local — amortissement du PC | {fmt(amort)} | prix ÷ (requêtes/jour × 365 × années) |")
    print(f"| **Local — total** | **{fmt(local_total)}** | |")
    if power is None:
        print("\n*Pas de mesure d'énergie dans ce rapport : relancer le banc avec BENCH_POWER=1.*")
    return 0


if __name__ == "__main__":
    sys.exit(main())
