#!/usr/bin/env python3
"""
Script para comparar um benchmark específico entre DO CONCURRENT, MPI e OMP
Gera gráfico de barras com tempo de execução em cada implementação.

Usage:
    python3 compare_benchmark.py --benchmark CG [--class C] [--format png/jpeg]
"""

import os
import glob
import json
import matplotlib.pyplot as plt
import numpy as np
from datetime import datetime
import argparse

BASE_DIR = "/mnt/f/NAS Parallel Benchmarks"
RESULTS_DIR = os.path.join(BASE_DIR, "Results")
GRAPH_DIR = os.path.join(BASE_DIR, "Graphics")
os.makedirs(GRAPH_DIR, exist_ok=True)

# Cores para cada implementação
COLORS = {
    "OpenMP": "#FF6B6B",
    "MPI": "#4ECDC4",
    "DO CONCURRENT": "#45B7D1",
    "OMP": "#FF6B6B",
    "DC": "#45B7D1"
}

IMPLEMENTATION_NAMES = {
    "OpenMP": "OpenMP",
    "OMP": "OpenMP",
    "MPI": "MPI",
    "DO CONCURRENT": "DO CONCURRENT",
    "DC": "DO CONCURRENT"
}

def find_latest_json():
    """Encontra o arquivo all_implementations mais recente"""
    pattern = os.path.join(RESULTS_DIR, "all_implementations_*.json")
    files = glob.glob(pattern)
    if not files:
        print(f"❌ Nenhum arquivo encontrado em {RESULTS_DIR}")
        return None
    return max(files, key=os.path.getmtime)

def load_data(json_file):
    with open(json_file, 'r') as f:
        data = json.load(f)
    return data

def extract_benchmark_data(data, benchmark, class_filter=None):
    """Extrai tempos do benchmark específico para as três implementações"""
    benchmark = benchmark.upper()
    impls = ["DO CONCURRENT", "MPI", "OpenMP"]
    times = []

    filtered_data = []
    for impl in impls:
        for item in data:
            impl_name = IMPLEMENTATION_NAMES.get(item["implementation"], item["implementation"])
            bench_name = item["benchmark"].upper()
            bench_class = item.get("class", "N/A").upper()
            if bench_name == benchmark and impl_name == impl:
                if class_filter and bench_class != class_filter.upper():
                    continue
                times.append(float(item.get("execution_time_seconds", 0)))
                filtered_data.append(item)
                break
        else:
            times.append(0)  # caso não tenha encontrado

    return impls, times, filtered_data

def plot_comparison(benchmark, impls, times, class_name, output_file):
    x = np.arange(len(impls))
    width = 0.6

    # Gráfico mais compacto
    plt.figure(figsize=(6, 4))

    # Fonte global maior
    plt.rcParams.update({'font.size': 13})

    bars = plt.bar(
        x, times, width,
        color=[COLORS.get(impl) for impl in impls],
        edgecolor='black'
    )

    # Adiciona valores sobre as barras
    for i, v in enumerate(times):
        plt.text(
            x[i], v + max(times)*0.02,
            f"{v:.2f}s",
            ha='center', va='bottom',
            fontsize=12, fontweight="bold"
        )

    plt.xticks(x, impls, fontsize=12)
    plt.ylabel("Tempo de Execução (s)", fontsize=14)
    plt.xlabel("Implementação", fontsize=14)
    plt.title(f"{benchmark} - Classe {class_name}",
                fontsize=16, fontweight='bold')

    plt.grid(axis='y', linestyle='--', alpha=0.6)
    plt.tight_layout()
    plt.savefig(output_file, dpi=300)
    print(f"📊 Gráfico salvo em: {output_file}")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--benchmark", required=True, help="Benchmark a comparar (CG, MG, FT)")
    parser.add_argument("--class", dest="class_name", default=None, help="Classe a utilizar (opcional)")
    parser.add_argument("--format", choices=["png", "jpeg"], default="png", help="Formato do gráfico")
    args = parser.parse_args()

    json_file = find_latest_json()
    if not json_file:
        return

    data = load_data(json_file)
    impls, times, filtered_data = extract_benchmark_data(data, args.benchmark, args.class_name)

    if not any(times):
        print(f"❌ Nenhum dado válido encontrado para {args.benchmark}")
        return

    class_used = args.class_name if args.class_name else filtered_data[0].get("class", "N/A") if filtered_data else "N/A"
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    output_file = os.path.join(GRAPH_DIR, f"{args.benchmark}_comparison_{timestamp}.{args.format}")

    plot_comparison(args.benchmark, impls, times, class_used, output_file)

if __name__ == "__main__":
    main()