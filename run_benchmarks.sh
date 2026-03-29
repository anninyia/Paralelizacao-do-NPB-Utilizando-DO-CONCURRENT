#!/bin/bash

# =============================================================================
#  run_benchmarks.sh — Compila e executa os NPB Benchmarks
# =============================================================================

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULTS_DIR="$BASE_DIR/Results"

LOG_COMPILE="$RESULTS_DIR/logs/compile"
LOG_RUN="$RESULTS_DIR/logs/run"
SUMMARY_DIR="$RESULTS_DIR/summary"

mkdir -p "$LOG_COMPILE" "$LOG_RUN" "$SUMMARY_DIR"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
fail() { echo -e "${RED}[ERRO]${NC} $1"; }
info() { echo -e "${CYAN}[INFO]${NC} $1"; }

TIMESTAMP_GLOBAL=$(date +"%Y%m%d_%H%M%S")
JSON_FILE="$SUMMARY_DIR/results_$TIMESTAMP_GLOBAL.json"

# =============================================================================
# USER INPUT
# =============================================================================

echo "===================================="
echo " NAS Parallel Benchmarks Runner"
echo "===================================="
echo ""

read -p "Classe (S,W,A,B,C,D,E) [padrão: S]: " CLASS
CLASS=${CLASS:-S}

read -p "Threads/processos [padrão: 4]: " THREADS
THREADS=${THREADS:-4}

read -p "Repetições por benchmark (para média) [padrão: 3]: " RUNS
RUNS=${RUNS:-3}

echo ""
echo "Implementação:"
echo "  1 - SERIAL"
echo "  2 - OMP"
echo "  3 - MPI"
echo "  4 - DO_CONCURRENT"
echo "  5 - TODAS"
read -p "Opção [padrão: 5]: " IMPL_OPTION
IMPL_OPTION=${IMPL_OPTION:-5}

echo ""
echo "Benchmarks:"
echo "  1 - CG"
echo "  2 - FT"
echo "  3 - MG"
echo "  4 - IS"
echo "  5 - TODOS"
read -p "Opção [padrão: 5]: " BENCH_OPTION
BENCH_OPTION=${BENCH_OPTION:-5}

# =============================================================================
# RESOLVE SELEÇÕES
# =============================================================================

case $IMPL_OPTION in
    1) IMPLEMENTATIONS=("SERIAL") ;;
    2) IMPLEMENTATIONS=("OMP") ;;
    3) IMPLEMENTATIONS=("MPI") ;;
    4) IMPLEMENTATIONS=("DO_CONCURRENT") ;;
    5) IMPLEMENTATIONS=("SERIAL" "OMP" "MPI" "DO_CONCURRENT") ;;
    *) fail "Opção inválida"; exit 1 ;;
esac

case $BENCH_OPTION in
    1) BENCHMARKS=("cg") ;;
    2) BENCHMARKS=("ft") ;;
    3) BENCHMARKS=("mg") ;;
    4) BENCHMARKS=("is") ;;
    5) BENCHMARKS=("cg" "ft" "mg" "is") ;;
    *) fail "Opção inválida"; exit 1 ;;
esac

echo ""
echo "===================================="
echo " Configuração selecionada"
echo "===================================="
echo "  Classe:          $CLASS"
echo "  Threads:         $THREADS"
echo "  Repetições:      $RUNS"
echo "  Implementações:  ${IMPLEMENTATIONS[*]}"
echo "  Benchmarks:      ${BENCHMARKS[*]}"
echo ""

read -p "Continuar? (y/n): " CONFIRM
[ "$CONFIRM" != "y" ] && exit 0

# =============================================================================
# FUNÇÕES
# =============================================================================

compile_benchmark() {
    local impl=$1
    local bench=$2
    local LOGFILE="$LOG_COMPILE/${impl}_${bench}_compile.log"

    info "Compilando $impl → $bench ..."

    cd "$BASE_DIR/$impl" || { fail "Diretório $impl não encontrado"; return 1; }

    make clean >> "$LOGFILE" 2>&1
    make $bench CLASS=$CLASS >> "$LOGFILE" 2>&1

    if [ $? -ne 0 ]; then
        fail "Erro de compilação: $impl $bench"
        echo "    Verifique: $LOGFILE"
        return 1
    fi

    ok "Compilado: $impl $bench"
    return 0
}

run_once() {
    local impl=$1
    local bench=$2
    local run_num=$3

    local BIN="$BASE_DIR/$impl/bin/${bench}.${CLASS}.x"
    local OUTDIR="$RESULTS_DIR/$impl/${bench^^}"
    local TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    local OUTFILE="$OUTDIR/${impl,,}_${bench}_${CLASS}_t${THREADS}_run${run_num}_$TIMESTAMP.txt"
    local RUNLOG="$LOG_RUN/${impl}_${bench}_run.log"

    mkdir -p "$OUTDIR"

    if [ ! -f "$BIN" ]; then
        fail "Executável não encontrado: $BIN"
        echo ""
        return
    fi

    local start end runtime

    start=$(date +%s.%N)

    case $impl in
        SERIAL)
            "$BIN" > "$OUTFILE" 2>> "$RUNLOG"
            ;;
        OMP)
            OMP_NUM_THREADS=$THREADS OMP_STACKSIZE=512M "$BIN" > "$OUTFILE" 2>> "$RUNLOG"
            ;;
        MPI)
            mpirun -np $THREADS "$BIN" > "$OUTFILE" 2>> "$RUNLOG"
            ;;
        DO_CONCURRENT)
            OMP_NUM_THREADS=$THREADS OMP_STACKSIZE=512M "$BIN" > "$OUTFILE" 2>> "$RUNLOG"
            ;;
    esac

    local exit_code=$?
    end=$(date +%s.%N)
    runtime=$(echo "$end - $start" | bc)

    if [ $exit_code -ne 0 ]; then
        fail "Execução falhou (exit $exit_code): $impl $bench run $run_num"
        echo ""
        return
    fi

    # Extrair tempo reportado pelo próprio benchmark (mais preciso que o bash)
    local bench_time
    bench_time=$(grep "Time in seconds" "$OUTFILE" 2>/dev/null | head -1 | awk '{
    if ($NF ~ /^[0-9]/) print $NF
    else print $(NF-1)
}')
    [ -z "$bench_time" ] && bench_time=$runtime
    # Garantir 0 antes do ponto decimal (JSON não aceita .123, precisa ser 0.123)
    bench_time=$(echo "$bench_time" | awk '{printf "%.6f", $1}')

    # Extrair Mop/s (como número ou null para JSON válido)
    local mops mops_json
    mops=$(grep "Mop/s total" "$OUTFILE" 2>/dev/null | awk '{print $NF}')
    if [ -z "$mops" ]; then
        mops_json="null"
        mops="N/A"
    else
        mops_json=$mops
    fi

    # Extrair verificação
    local verified
    verified=$(grep "Verification" "$OUTFILE" 2>/dev/null | grep -o "SUCCESSFUL\|FAILED\|SKIPPED" | head -1)
    [ -z "$verified" ] && verified="UNKNOWN"

    info "  Run $run_num — tempo: ${bench_time}s | Mop/s: $mops | Verificação: $verified"

    # Salvar no JSON
    echo "{
        \"implementation\": \"$impl\",
        \"benchmark\": \"$bench\",
        \"class\": \"$CLASS\",
        \"threads\": $THREADS,
        \"run\": $run_num,
        \"time_seconds\": $bench_time,
        \"mops\": $mops_json,
        \"verified\": \"$verified\",
        \"output_file\": \"$OUTFILE\"
    }," >> "$JSON_FILE"
}

run_benchmark() {
    local impl=$1
    local bench=$2

    echo ""
    info "Executando $impl $bench (Classe $CLASS, $RUNS execuções) ..."

    for ((r=1; r<=RUNS; r++)); do
        run_once "$impl" "$bench" "$r"
    done
}

# =============================================================================
# EXECUÇÃO PRINCIPAL
# =============================================================================

echo "[" > "$JSON_FILE"

for impl in "${IMPLEMENTATIONS[@]}"; do
    echo ""
    echo "===================================="
    echo " Implementação: $impl"
    echo "===================================="

    for bench in "${BENCHMARKS[@]}"; do
        compile_benchmark "$impl" "$bench"

        if [ $? -eq 0 ]; then
            run_benchmark "$impl" "$bench"
        else
            warn "Pulando execução de $impl $bench devido a erro de compilação."
        fi
    done
done

# Fechar JSON corretamente (remover última vírgula)
sed -i '$ s/,$//' "$JSON_FILE"
echo "]" >> "$JSON_FILE"

echo ""
echo "===================================="
echo " Execução finalizada!"
echo "===================================="
echo "  Resultados em: $RESULTS_DIR"
echo "  JSON:          $JSON_FILE"
echo ""
echo "  Para gerar relatório com gráficos, execute:"
echo "  ./report.sh $JSON_FILE"
echo "===================================="