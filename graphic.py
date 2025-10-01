#!/usr/bin/env python3
"""
Script para gerar gráfico comparativo dos NAS Parallel Benchmarks
Mostra benchmarks no eixo X e tempo de execução no eixo Y por implementação.

Usage: python3 graphics.py [--json arquivo.json] [--output grafico.png]
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

def organize_data(data):
    """Retorna benchmarks, implementações e matriz de tempos"""
    benchmarks = sorted({item["benchmark"].upper() for item in data})
    impls = sorted({IMPLEMENTATION_NAMES.get(item["implementation"], item["implementation"]) for item in data})
    
    times = np.zeros((len(benchmarks), len(impls)))
    
    for item in data:
        bench = item["benchmark"].upper()
        impl = IMPLEMENTATION_NAMES.get(item["implementation"], item["implementation"])
        exec_time = float(item.get("execution_time_seconds", 0))
        i = benchmarks.index(bench)
        j = impls.index(impl)
        times[i, j] = exec_time
    
    return benchmarks, impls, times

def plot_graph(benchmarks, impls, times, output_file):
    x = np.arange(len(benchmarks))
    width = 0.8 / len(impls)
    
    plt.figure(figsize=(8, 5))
    
    plt.rcParams.update({'font.size': 12})
    
    for i, impl in enumerate(impls):
        offset = (i - len(impls)/2 + 0.5) * width
        plt.bar(x + offset, times[:, i], width, label=impl, color=COLORS.get(impl, f"C{i}"))
        for j, t in enumerate(times[:, i]):
            if t > 0:
                plt.text(
                    x[j] + offset, t + max(times.flatten())*0.01,
                    f"{t:.2f}", ha='center', va='bottom', fontsize=10
                )
    
    plt.xticks(x, benchmarks, fontsize=13)
    plt.xlabel("Benchmarks", fontsize=15)
    plt.ylabel("Tempo de Execução (s)", fontsize=15)
    plt.title("Comparação de Performance NAS Parallel Benchmarks", fontsize=16, weight="bold")
    plt.legend(fontsize=12)
    plt.grid(axis='y', linestyle='--', alpha=0.5)
    plt.tight_layout()
    
    plt.savefig(output_file, dpi=300)
    print(f"📊 Gráfico salvo em: {output_file}")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--json", help="Arquivo JSON (opcional)")
    parser.add_argument("--output", help="Arquivo PNG/JPEG de saída (opcional)")
    parser.add_argument("--format", choices=["png", "jpeg"], default="png",
                        help="Formato do gráfico de saída (default: png)")
    args = parser.parse_args()
    
    json_file = args.json if args.json else find_latest_json()
    if not json_file:
        return
    
    data = load_data(json_file)
    benchmarks, impls, times = organize_data(data)
    
    # Definir arquivo de saída
    if args.output:
        output_file = args.output
    else:
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        output_file = os.path.join(GRAPH_DIR, f"comparison_{timestamp}.{args.format}")
    
    plot_graph(benchmarks, impls, times, output_file)

if __name__ == "__main__":
    main()