#!/bin/bash

# =============================================================================
#  report.sh — Gera relatório comparativo a partir do JSON de resultados
# =============================================================================

if [ -z "$1" ]; then
    BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
    JSON_FILE=$(ls -t "$BASE_DIR/Results/summary/"*.json 2>/dev/null | head -1)
    if [ -z "$JSON_FILE" ]; then
        echo "Uso: ./report.sh <arquivo_results.json>"
        echo "Nenhum JSON encontrado em Results/summary/"
        exit 1
    fi
    echo "Usando resultado mais recente: $JSON_FILE"
else
    JSON_FILE="$1"
fi

if [ ! -f "$JSON_FILE" ]; then
    echo "Arquivo não encontrado: $JSON_FILE"
    exit 1
fi

# =============================================================================
# FILTROS INTERATIVOS
# =============================================================================

echo ""
echo "===================================="
echo " Filtros do relatório"
echo "===================================="

echo ""
echo "Benchmarks disponíveis:"
echo "  1 - CG"
echo "  2 - FT"
echo "  3 - MG"
echo "  4 - IS"
echo "  5 - TODOS"
read -p "Selecione os benchmarks (ex: 1 2 ou 5 para todos): " bench_input

FILTER_BENCHES=""
for b in $bench_input; do
    case $b in
        1) FILTER_BENCHES="$FILTER_BENCHES cg" ;;
        2) FILTER_BENCHES="$FILTER_BENCHES ft" ;;
        3) FILTER_BENCHES="$FILTER_BENCHES mg" ;;
        4) FILTER_BENCHES="$FILTER_BENCHES is" ;;
        5) FILTER_BENCHES="cg ft mg is"; break ;;
    esac
done
FILTER_BENCHES=$(echo $FILTER_BENCHES | tr ' ' '\n' | sort -u | tr '\n' ' ')

echo ""
echo "Implementações disponíveis:"
echo "  1 - SERIAL"
echo "  2 - OMP"
echo "  3 - MPI"
echo "  4 - DO_CONCURRENT"
echo "  5 - TODAS"
read -p "Selecione as implementações (ex: 2 4 ou 5 para todas): " impl_input

FILTER_IMPLS=""
for i in $impl_input; do
    case $i in
        1) FILTER_IMPLS="$FILTER_IMPLS SERIAL" ;;
        2) FILTER_IMPLS="$FILTER_IMPLS OMP" ;;
        3) FILTER_IMPLS="$FILTER_IMPLS MPI" ;;
        4) FILTER_IMPLS="$FILTER_IMPLS DO_CONCURRENT" ;;
        5) FILTER_IMPLS="SERIAL OMP MPI DO_CONCURRENT"; break ;;
    esac
done
FILTER_IMPLS=$(echo $FILTER_IMPLS | tr ' ' '\n' | sort -u | tr '\n' ' ')

echo ""
echo "  Benchmarks selecionados:      $FILTER_BENCHES"
echo "  Implementações selecionadas:  $FILTER_IMPLS"
echo ""

# =============================================================================
# NOME DO ARQUIVO DE SAÍDA
# =============================================================================

REPORT_DIR="$(dirname "$JSON_FILE")"
SUFFIX=$(echo "${FILTER_BENCHES// /_}_${FILTER_IMPLS// /_}" | tr '[:upper:]' '[:lower:]' | sed 's/__/_/g' | sed 's/_$//')
REPORT_NAME="report_$(basename "$JSON_FILE" .json)_${SUFFIX}"
REPORT_PY="$REPORT_DIR/${REPORT_NAME}.py"
REPORT_OUT="$REPORT_DIR/${REPORT_NAME}.txt"
REPORT_PNG="$REPORT_DIR/${REPORT_NAME}_chart.png"

# =============================================================================
# GERAR SCRIPT PYTHON
# =============================================================================

cat > "$REPORT_PY" << PYEOF
import json, sys, statistics, os
from datetime import datetime
from collections import defaultdict

json_file    = sys.argv[1]
report_out   = sys.argv[2]
report_png   = sys.argv[3]
filter_benches = sys.argv[4].split()
filter_impls   = sys.argv[5].split()

with open(json_file) as f:
    data = json.load(f)

data = [e for e in data
        if e["benchmark"] in filter_benches
        and e["implementation"] in filter_impls]

groups = defaultdict(list)
for entry in data:
    key = (entry["implementation"], entry["benchmark"], entry["class"], entry["threads"])
    try:
        if entry["time_seconds"] is not None and entry["time_seconds"] != 0.0:
            groups[key].append(float(entry["time_seconds"]))
    except (ValueError, KeyError):
        pass

results = []
for (impl, bench, cls, threads), times in sorted(groups.items()):
    mean  = statistics.mean(times)
    stdev = statistics.stdev(times) if len(times) > 1 else 0.0
    results.append({
        "impl": impl, "bench": bench, "class": cls,
        "threads": threads, "runs": len(times),
        "mean": mean, "stdev": stdev, "times": times
    })

# Relatório texto
lines = []
lines.append("=" * 72)
lines.append(" NPB Benchmarks — Relatório Comparativo")
lines.append(f" Gerado em: {datetime.now().strftime('%d/%m/%Y %H:%M:%S')}")
lines.append(f" Fonte: {os.path.basename(json_file)}")
lines.append(f" Benchmarks: {' '.join(b.upper() for b in filter_benches)}")
lines.append(f" Implementações: {' '.join(filter_impls)}")
lines.append("=" * 72)
lines.append("")

benchmarks = sorted(set(r["bench"] for r in results))

for bench in benchmarks:
    lines.append(f"  Benchmark: {bench.upper()}")
    lines.append(f"  {'Implementação':<20} {'Threads':>8} {'Runs':>6} {'Média (s)':>12} {'Desvio (s)':>12} {'Min (s)':>10} {'Max (s)':>10}")
    lines.append("  " + "-" * 80)
    bench_results = [r for r in results if r["bench"] == bench]
    for r in bench_results:
        lines.append(
            f"  {r['impl']:<20} {r['threads']:>8} {r['runs']:>6} "
            f"{r['mean']:>12.4f} {r['stdev']:>12.4f} "
            f"{min(r['times']):>10.4f} {max(r['times']):>10.4f}"
        )
    lines.append("")
    serial = next((r for r in bench_results if r["impl"] == "SERIAL"), None)
    if serial and serial["mean"] > 0:
        lines.append(f"  Speedup relativo ao SERIAL:")
        for r in bench_results:
            lines.append(f"    {r['impl']:<20} {serial['mean']/r['mean']:.2f}x")
        lines.append("")
    lines.append("")

with open(report_out, "w") as f:
    f.write("\n".join(lines))
print("\n".join(lines))

# Gráfico
try:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    colors = {
        "SERIAL":        "#5c85d6",
        "OMP":           "#e07b39",
        "MPI":           "#4caf7d",
        "DO_CONCURRENT": "#b45cbf"
    }

    n = len(benchmarks)
    fig, axes = plt.subplots(1, n, figsize=(5 * n, 6))
    if n == 1:
        axes = [axes]

    for ax, bench in zip(axes, benchmarks):
        bench_results = [r for r in results if r["bench"] == bench]
        impl_names  = [r["impl"]  for r in bench_results]
        means       = [r["mean"]  for r in bench_results]
        stdevs      = [r["stdev"] for r in bench_results]
        bar_colors  = [colors.get(i, "#aaaaaa") for i in impl_names]

        bars = ax.bar(impl_names, means, yerr=stdevs, capsize=5,
                      color=bar_colors, edgecolor="black", linewidth=0.7)

        for bar, mean in zip(bars, means):
            ax.text(bar.get_x() + bar.get_width() / 2,
                    bar.get_height() + max(means) * 0.01,
                    f"{mean:.3f}s", ha="center", va="bottom", fontsize=9)

        ax.set_title(f"Benchmark: {bench.upper()}", fontsize=12, fontweight="bold")
        ax.set_ylabel("Tempo médio (segundos)")
        ax.set_xlabel("Implementação")
        ax.tick_params(axis='x', rotation=15)
        ax.grid(axis="y", linestyle="--", alpha=0.5)

    fig.suptitle("NPB Benchmarks — Comparação de Implementações",
                 fontsize=14, fontweight="bold")
    plt.tight_layout()
    plt.savefig(report_png, dpi=150, bbox_inches="tight")
    print(f"\nGráfico salvo em: {report_png}")

except ImportError:
    print("\n[AVISO] matplotlib não instalado. Instale com: pip install matplotlib")

PYEOF

# =============================================================================
# RODAR
# =============================================================================

echo "===================================="
echo " Gerando relatório..."
echo "===================================="

python3 "$REPORT_PY" "$JSON_FILE" "$REPORT_OUT" "$REPORT_PNG" "$FILTER_BENCHES" "$FILTER_IMPLS"

echo ""
echo "===================================="
echo " Relatório salvo em:"
echo "   Texto:   $REPORT_OUT"
if [ -f "$REPORT_PNG" ]; then
echo "   Gráfico: $REPORT_PNG"
fi
echo "===================================="