#!/bin/bash
# =============================================================================
#  report.sh — Gera relatório comparativo e gráficos a partir do JSON
#  Uso: ./report.sh [arquivo.json]
#  Se não passar arquivo, usa o JSON mais recente em Results/summary/
# =============================================================================

export LC_ALL=C

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m';  BOLD='\033[1m';   NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[AVISO]${NC} $*"; }
fail() { echo -e "${RED}[ERRO]${NC} $*"; }
info() { echo -e "${CYAN}[INFO]${NC} $*"; }

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

# =============================================================================
# SELECIONA JSON
# =============================================================================

if [[ -n "${1:-}" ]]; then
    JSON_FILE="$1"
else
    JSON_FILE=$(ls -t "$BASE_DIR/Results/summary/"*.json 2>/dev/null | head -1)
    if [[ -z "$JSON_FILE" ]]; then
        fail "Nenhum JSON encontrado em Results/summary/"
        echo "    Execute primeiro: ./run_benchmarks.sh"
        exit 1
    fi
    info "Usando resultado mais recente: $(basename "$JSON_FILE")"
fi

[[ ! -f "$JSON_FILE" ]] && { fail "Arquivo não encontrado: $JSON_FILE"; exit 1; }

# =============================================================================
# LÊ IMPLEMENTAÇÕES E BENCHMARKS DISPONÍVEIS NO JSON (sem hardcode)
# =============================================================================

read_json_values() {
    # Lê valores únicos de um campo do JSON via python3
    local field=$1
    python3 -c "
import json, sys
data = json.load(open('$JSON_FILE'))
vals = sorted(set(str(e['$field']).lower() for e in data if e.get('$field')))
print(' '.join(vals))
"
}

mapfile -t JSON_IMPLS  < <(python3 -c "
import json
data = json.load(open('$JSON_FILE'))
print('\n'.join(sorted(set(e['implementation'] for e in data))))
")
mapfile -t JSON_BENCHES < <(python3 -c "
import json
data = json.load(open('$JSON_FILE'))
print('\n'.join(sorted(set(e['benchmark'] for e in data))))
")

# =============================================================================
# MENU DINÂMICO
# =============================================================================

print_menu() {
    local -n _arr=$1
    local i=1
    for item in "${_arr[@]}"; do printf "  %d - %s\n" "$i" "${item^^}"; ((i++)); done
    printf "  %d - TODOS\n" "$i"
}

select_menu() {
    local -n _items=$1
    local total=${#_items[@]}
    print_menu "$1"
    read -rp "${2} [padrão: TODOS]: " inp
    inp="${inp:-TODOS}"
    local selected=()

    # Aceita "TODOS", "todos", número do item TODOS, ou lista de números
    if [[ "${inp^^}" == "TODOS" ]] || [[ "$inp" == "$((total+1))" ]]; then
        selected=("${_items[@]}")
    elif [[ "$inp" =~ ^[0-9\ ]+$ ]]; then
        for n in $inp; do
            if (( n >= 1 && n <= total )); then
                selected+=("${_items[$((n-1))]}")
            fi
        done
    fi

    # Fallback: se nada foi selecionado, seleciona tudo
    [[ ${#selected[@]} -eq 0 ]] && selected=("${_items[@]}")
    [[ ${#selected[@]} -eq 0 ]] && selected=("${_items[@]}")
    echo "${selected[@]}"
}

echo ""
echo -e "${BOLD}===================================="
echo " NPB Benchmarks — Relatório"
echo -e "====================================${NC}"
echo ""
echo "Implementações no JSON: ${JSON_IMPLS[*]}"
echo "Benchmarks no JSON:     ${JSON_BENCHES[*]}"
echo ""

echo "Selecione as implementações:"
read -ra SEL_IMPLS  <<< "$(select_menu JSON_IMPLS  "Opção (ex: 1 3 ou TODOS)")"

echo ""
echo "Selecione os benchmarks:"
read -ra SEL_BENCHES <<< "$(select_menu JSON_BENCHES "Opção (ex: 1 2 ou TODOS)")"

echo ""
echo "Tipo de gráfico:"
echo "  1 - Tempo médio (barras)"
echo "  2 - Mop/s (barras)"
echo "  3 - Speedup relativo ao SERIAL"
echo "  4 - Todos"
read -rp "Opção [padrão: 4]: " chart_inp
chart_inp="${chart_inp:-4}"

# =============================================================================
# SAÍDA
# =============================================================================

REPORT_DIR="$(dirname "$JSON_FILE")"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_TXT="$REPORT_DIR/report_${TIMESTAMP}.txt"
REPORT_PNG="$REPORT_DIR/report_${TIMESTAMP}_chart.png"

IMPLS_ARG="${SEL_IMPLS[*]}"
BENCHES_ARG="${SEL_BENCHES[*]}"

# =============================================================================
# PYTHON INLINE (sem criar arquivo .py em disco)
# =============================================================================

python3 - "$JSON_FILE" "$REPORT_TXT" "$REPORT_PNG" \
          "$IMPLS_ARG" "$BENCHES_ARG" "$chart_inp" << 'PYEOF'
import json, sys, statistics, os
from datetime import datetime
from collections import defaultdict

json_file   = sys.argv[1]
report_txt  = sys.argv[2]
report_png  = sys.argv[3]
sel_impls   = sys.argv[4].split()
sel_benches = sys.argv[5].split()
chart_type  = sys.argv[6]

with open(json_file) as f:
    data = json.load(f)

# Filtra
data = [e for e in data
        if e["implementation"] in sel_impls
        and e["benchmark"] in sel_benches]

# Agrupa por (impl, bench, class, threads)
groups_time = defaultdict(list)
groups_mops = defaultdict(list)

for e in data:
    key = (e["implementation"], e["benchmark"], e["class"], e["threads"])
    try:
        t = e.get("time_seconds")
        if t is not None and float(t) > 0:
            groups_time[key].append(float(t))
    except (ValueError, TypeError):
        pass
    try:
        m = e.get("mops")
        if m is not None:
            groups_mops[key].append(float(m))
    except (ValueError, TypeError):
        pass

def summarize(groups):
    results = []
    for (impl, bench, cls, threads), vals in sorted(groups.items()):
        mean  = statistics.mean(vals)
        stdev = statistics.stdev(vals) if len(vals) > 1 else 0.0
        results.append({
            "impl": impl, "bench": bench, "class": cls,
            "threads": threads, "runs": len(vals),
            "mean": mean, "stdev": stdev, "vals": vals
        })
    return results

res_time = summarize(groups_time)
res_mops = summarize(groups_mops)

# ── Relatório texto ──────────────────────────────────────────────────────────
lines = []
lines.append("=" * 72)
lines.append("  NPB Benchmarks — Relatório Comparativo")
lines.append(f"  Gerado em:      {datetime.now().strftime('%d/%m/%Y %H:%M:%S')}")
lines.append(f"  Fonte:          {os.path.basename(json_file)}")
lines.append(f"  Implementações: {' '.join(sel_impls)}")
lines.append(f"  Benchmarks:     {' '.join(b.upper() for b in sel_benches)}")
lines.append("=" * 72)

benchmarks = sorted(set(r["bench"] for r in res_time))

for bench in benchmarks:
    lines.append(f"\n  ── {bench.upper()} " + "─" * 50)
    br = [r for r in res_time if r["bench"] == bench]
    if br:
        lines.append(f"  {'Implementação':<22} {'Threads':>7} {'Runs':>5} "
                     f"{'Média (s)':>11} {'Desvio (s)':>11} {'Min':>9} {'Max':>9}")
        lines.append("  " + "-" * 76)
        for r in br:
            lines.append(
                f"  {r['impl']:<22} {r['threads']:>7} {r['runs']:>5} "
                f"{r['mean']:>11.4f} {r['stdev']:>11.4f} "
                f"{min(r['vals']):>9.4f} {max(r['vals']):>9.4f}"
            )
        serial = next((r for r in br if r["impl"] == "SERIAL"), None)
        if serial and serial["mean"] > 0:
            lines.append(f"\n  Speedup vs SERIAL:")
            for r in br:
                sp = serial["mean"] / r["mean"]
                lines.append(f"    {r['impl']:<22} {sp:.2f}x")

    bm = [r for r in res_mops if r["bench"] == bench]
    if bm:
        lines.append(f"\n  Mop/s:")
        for r in bm:
            lines.append(f"    {r['impl']:<22} {r['mean']:>10.2f}  ±{r['stdev']:.2f}")

lines.append("")
report_str = "\n".join(lines)
print(report_str)
with open(report_txt, "w") as f:
    f.write(report_str)

# ── Gráficos ─────────────────────────────────────────────────────────────────
try:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    COLORS = {
        "SERIAL":        "#5c85d6",
        "OMP":           "#e07b39",
        "MPI":           "#4caf7d",
        "DO_CONCURRENT": "#b45cbf"
    }

    # Decide quais subplots gerar
    plot_time    = chart_type in ("1", "4")
    plot_mops    = chart_type in ("2", "4")
    plot_speedup = chart_type in ("3", "4")

    subplot_count = sum([plot_time, plot_mops, plot_speedup])
    n_bench = len(benchmarks)

    fig, axes = plt.subplots(
        subplot_count, n_bench,
        figsize=(5 * n_bench, 4 * subplot_count),
        squeeze=False
    )

    row = 0

    def bar_plot(ax, names, vals, errs, title, ylabel):
        colors = [COLORS.get(n, "#aaaaaa") for n in names]
        bars = ax.bar(names, vals, yerr=errs, capsize=5,
                      color=colors, edgecolor="black", linewidth=0.7)
        for bar, v in zip(bars, vals):
            ax.text(bar.get_x() + bar.get_width() / 2,
                    bar.get_height() + max(vals) * 0.02,
                    f"{v:.3f}", ha="center", va="bottom", fontsize=8)
        ax.set_title(title, fontsize=11, fontweight="bold")
        ax.set_ylabel(ylabel)
        ax.tick_params(axis="x", rotation=15)
        ax.grid(axis="y", linestyle="--", alpha=0.4)

    for col, bench in enumerate(benchmarks):
        # Tempo
        if plot_time:
            br = [r for r in res_time if r["bench"] == bench]
            bar_plot(axes[row][col],
                     [r["impl"] for r in br],
                     [r["mean"]  for r in br],
                     [r["stdev"] for r in br],
                     f"{bench.upper()} — Tempo",
                     "Tempo médio (s)")

        # Mop/s
        if plot_mops:
            r2 = row + (1 if plot_time else 0)
            bm = [r for r in res_mops if r["bench"] == bench]
            bar_plot(axes[r2][col],
                     [r["impl"] for r in bm],
                     [r["mean"]  for r in bm],
                     [r["stdev"] for r in bm],
                     f"{bench.upper()} — Mop/s",
                     "Mop/s")

        # Speedup
        if plot_speedup:
            r3 = row + sum([plot_time, plot_mops])
            br = [r for r in res_time if r["bench"] == bench]
            serial = next((r for r in br if r["impl"] == "SERIAL"), None)
            if serial and serial["mean"] > 0:
                names = [r["impl"] for r in br]
                speedups = [serial["mean"] / r["mean"] for r in br]
                bar_plot(axes[r3][col],
                         names, speedups, [0]*len(speedups),
                         f"{bench.upper()} — Speedup",
                         "Speedup vs SERIAL")
                axes[r3][col].axhline(1.0, color="red",
                                      linestyle="--", linewidth=1, alpha=0.6)

    fig.suptitle("NPB Benchmarks — Comparação de Implementações",
                 fontsize=13, fontweight="bold")
    plt.tight_layout()
    plt.savefig(report_png, dpi=150, bbox_inches="tight")
    print(f"\nGráfico salvo em: {report_png}")

except ImportError:
    print("\n[AVISO] matplotlib não instalado: pip install matplotlib")
PYEOF

echo ""
ok "Relatório: $REPORT_TXT"
[[ -f "$REPORT_PNG" ]] && ok "Gráfico:   $REPORT_PNG"
echo ""
echo "  Para limpar resultados: ./clean_results.sh"