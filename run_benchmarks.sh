#!/bin/bash
# =============================================================================
#  run_benchmarks.sh — Compila e executa os NPB Benchmarks
#  Benchmarks e implementações são descobertos automaticamente em disco.
#
#  Uso: ./run_benchmarks.sh [--class S] [--threads 4] [--runs 3]
#       [--impl SERIAL,OMP] [--bench cg,ft] [--force-rebuild] [--no-compile]
# =============================================================================

set -euo pipefail

# Força separador decimal como ponto (evita falha de printf em locales pt_BR)
export LC_NUMERIC=C
export LC_ALL=C
export LANG=C

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULTS_DIR="$BASE_DIR/Results"
LOG_COMPILE="$RESULTS_DIR/logs/compile"
LOG_RUN="$RESULTS_DIR/logs/run"
SUMMARY_DIR="$RESULTS_DIR/summary"

mkdir -p "$LOG_COMPILE" "$LOG_RUN" "$SUMMARY_DIR"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m';  BOLD='\033[1m';   NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[AVISO]${NC} $*"; }
fail() { echo -e "${RED}[ERRO]${NC} $*"; }
info() { echo -e "${CYAN}[INFO]${NC} $*"; }

# =============================================================================
# AUTODISCOVERY
# =============================================================================

SKIP_DIRS="bin|common|config|sys|MPI_dummy|npb_original|Results"

discover_impls() {
    find "$BASE_DIR" -maxdepth 1 -mindepth 1 -type d \
        | while read -r d; do
            name=$(basename "$d")
            [[ "$name" =~ ^($SKIP_DIRS|\..*)$ ]] && continue
            [[ -f "$d/Makefile" ]] && echo "$name"
          done | sort
}

discover_benchmarks() {
    local impl=$1
    find "$BASE_DIR/$impl" -maxdepth 1 -mindepth 1 -type d \
        | while read -r d; do
            name=$(basename "$d")
            [[ "$name" =~ ^($SKIP_DIRS)$ ]] && continue
            [[ -f "$d/Makefile" ]] && echo "${name,,}"
          done | sort
}

discover_all_benchmarks() {
    for impl in $(discover_impls); do
        discover_benchmarks "$impl"
    done | sort -u
}

mapfile -t ALL_IMPLS < <(discover_impls)
mapfile -t ALL_BENCH < <(discover_all_benchmarks)

if [[ ${#ALL_IMPLS[@]} -eq 0 ]]; then
    fail "Nenhuma implementação encontrada em $BASE_DIR"; exit 1
fi
if [[ ${#ALL_BENCH[@]} -eq 0 ]]; then
    fail "Nenhum benchmark encontrado"; exit 1
fi

# =============================================================================
# DEFAULTS
# =============================================================================

CLASS="S"
THREADS=4
RUNS=3
IMPLEMENTATIONS=()
BENCHMARKS=()
FORCE_REBUILD=false
SKIP_COMPILE=false

# =============================================================================
# PARSE CLI
# =============================================================================

use_cli=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --class)         CLASS="${2^^}";                                 shift 2 ;;
        --threads)       THREADS="$2";                                   shift 2 ;;
        --runs)          RUNS="$2";                                      shift 2 ;;
        --impl)          IFS=',' read -ra IMPLEMENTATIONS <<< "${2^^}"; shift 2 ;;
        --bench)         IFS=',' read -ra BENCHMARKS     <<< "${2,,}";  shift 2 ;;
        --force-rebuild) FORCE_REBUILD=true;                             shift   ;;
        --no-compile)    SKIP_COMPILE=true;                              shift   ;;
        -h|--help)
            echo "Uso: $0 [--class S] [--threads 4] [--runs 3]"
            echo "         [--impl IMPL1,IMPL2] [--bench bench1,bench2]"
            echo "         [--force-rebuild] [--no-compile]"
            echo ""
            echo "Implementações disponíveis: ${ALL_IMPLS[*]}"
            echo "Benchmarks disponíveis:     ${ALL_BENCH[*]}"
            exit 0 ;;
        *) fail "Argumento desconhecido: $1"; exit 1 ;;
    esac
    use_cli=true
done

# =============================================================================
# MENU INTERATIVO (gerado dinamicamente)
# =============================================================================

print_menu() {
    local -n _arr=$1
    local i=1
    for item in "${_arr[@]}"; do
        printf "  %d - %s\n" "$i" "${item^^}"
        ((i++))
    done
    printf "  %d - TODOS\n" "$i"
}

select_from_menu() {
    local -n _items=$1
    local prompt=$2
    local total=${#_items[@]}

    print_menu "$1"
    read -rp "$prompt [padrão: TODOS]: " inp
    inp="${inp:-$((total+1))}"

    if [[ "$inp" =~ ^[0-9]+$ ]] && (( inp >= 1 && inp <= total )); then
        echo "${_items[$((inp-1))]}"
    elif (( inp == total+1 )); then
        echo "${_items[*]}"
    else
        fail "Opção inválida: $inp"; exit 1
    fi
}

if ! $use_cli; then
    echo -e "${BOLD}===================================="
    echo " NAS Parallel Benchmarks Runner"
    echo -e "====================================${NC}"
    echo ""
    echo -e "Implementações encontradas: ${CYAN}${ALL_IMPLS[*]}${NC}"
    echo -e "Benchmarks encontrados:     ${CYAN}${ALL_BENCH[*]}${NC}"
    echo ""

    read -rp "Classe (S,W,A,B,C,D,E) [padrão: S]: " inp
    CLASS="${inp:-S}"; CLASS="${CLASS^^}"

    read -rp "Threads/processos [padrão: 4]: " inp
    THREADS="${inp:-4}"

    read -rp "Repetições por benchmark [padrão: 3]: " inp
    RUNS="${inp:-3}"

    echo ""
    echo "Implementação:"
    read -ra IMPLEMENTATIONS <<< "$(select_from_menu ALL_IMPLS "Opção")"

    echo ""
    echo "Benchmark:"
    read -ra BENCHMARKS <<< "$(select_from_menu ALL_BENCH "Opção")"

    echo ""
    read -rp "Forçar recompilação mesmo se binário existir? (y/N): " inp
    [[ "${inp,,}" == "y" ]] && FORCE_REBUILD=true

    read -rp "Pular compilação? (y/N): " inp
    [[ "${inp,,}" == "y" ]] && SKIP_COMPILE=true
fi

[[ ${#IMPLEMENTATIONS[@]} -eq 0 ]] && IMPLEMENTATIONS=("${ALL_IMPLS[@]}")
[[ ${#BENCHMARKS[@]} -eq 0 ]]      && BENCHMARKS=("${ALL_BENCH[@]}")

# =============================================================================
# VALIDAÇÕES
# =============================================================================

if ! [[ "$THREADS" =~ ^[1-9][0-9]*$ ]]; then
    fail "Número de threads inválido: $THREADS"; exit 1
fi
if ! [[ "$RUNS" =~ ^[1-9][0-9]*$ ]]; then
    fail "Número de repetições inválido: $RUNS"; exit 1
fi

for impl in "${IMPLEMENTATIONS[@]}"; do
    if ! printf '%s\n' "${ALL_IMPLS[@]}" | grep -qx "$impl"; then
        fail "Implementação não encontrada em disco: $impl"
        info "Disponíveis: ${ALL_IMPLS[*]}"
        exit 1
    fi
done

# =============================================================================
# RESUMO + MATRIZ DE DISPONIBILIDADE
# =============================================================================

echo ""
echo -e "${BOLD}===================================="
echo " Configuração selecionada"
echo -e "====================================${NC}"
echo "  Classe:      $CLASS"
echo "  Repetições:  $RUNS"
echo ""
echo "  Matriz de disponibilidade:"
printf "  %-18s" ""
for bench in "${BENCHMARKS[@]}"; do printf "%-8s" "${bench^^}"; done
echo ""
for impl in "${IMPLEMENTATIONS[@]}"; do
    mapfile -t avail < <(discover_benchmarks "$impl")
    eff=$(  [[ "$impl" == "SERIAL" ]] && echo "1 thread" || echo "$THREADS threads" )
    printf "  %-18s" "$impl ($eff)"
    for bench in "${BENCHMARKS[@]}"; do
        if printf '%s\n' "${avail[@]}" | grep -qx "$bench"; then
            printf "${GREEN}%-8s${NC}" "OK"
        else
            printf "${RED}%-8s${NC}" "N/A"
        fi
    done
    echo ""
done
echo ""
$FORCE_REBUILD && info "Modo: FORCE REBUILD"
$SKIP_COMPILE  && info "Modo: SEM COMPILAÇÃO"
echo ""

read -rp "Continuar? (y/N): " CONFIRM
[[ "${CONFIRM,,}" != "y" ]] && exit 0

# =============================================================================
# EXTRAÇÃO DE MÉTRICAS
# O NPB usa nomes diferentes por benchmark:
#   CG/FT/MG/EP → "Mop/s total"
#   IS          → "Mop/s total" com unidade "Mkeys/s"  (mesmo campo, valor válido)
#   BT/SP/LU    → "Mflops"
# Estratégia: tenta cada padrão em ordem, pega o primeiro número encontrado.
# =============================================================================

extract_time() {
    # "Time in seconds  =   0.0095" ou "Time in seconds =  0.14"
    grep -i "Time in seconds" "$1" 2>/dev/null \
        | grep -oP '\d+\.\d+' | tail -1
}

extract_mops() {
    local f=$1
    local val

    # Padrão 1: "Mop/s total" (CG, FT, MG, IS, EP)
    val=$(grep -i "Mop/s total" "$f" 2>/dev/null \
        | grep -oP '\d+\.\d+' | tail -1)
    [[ -n "$val" ]] && echo "$val" && return

    # Padrão 2: "Mflops" (BT, SP, LU)
    val=$(grep -iE "^\s*Mflops\s*=" "$f" 2>/dev/null \
        | grep -oP '\d+\.\d+' | tail -1)
    [[ -n "$val" ]] && echo "$val" && return

    # Padrão 3: "Mop/s" sem "total" (algumas versões antigas)
    val=$(grep -iE "Mop/s\s*$" "$f" 2>/dev/null \
        | grep -oP '\d+\.\d+' | tail -1)
    [[ -n "$val" ]] && echo "$val" && return

    echo ""   # não encontrou
}

extract_verified() {
    grep -i "Verification" "$1" 2>/dev/null \
        | grep -oE "SUCCESSFUL|FAILED|SKIPPED" | head -1
}

# =============================================================================
# FUNÇÕES PRINCIPAIS
# =============================================================================

effective_threads() {
    [[ "$1" == "SERIAL" ]] && echo 1 || echo "$THREADS"
}

compile_benchmark() {
    local impl=$1 bench=$2
    local LOGFILE="$LOG_COMPILE/${impl}_${bench}_compile.log"
    local BIN="$BASE_DIR/$impl/bin/${bench}.${CLASS}.x"

    # Benchmark não existe para esta implementação?
    mapfile -t avail < <(discover_benchmarks "$impl")
    if ! printf '%s\n' "${avail[@]}" | grep -qx "$bench"; then
        warn "$impl não possui $bench — pulando"
        return 2
    fi

    if $SKIP_COMPILE; then
        if [[ ! -f "$BIN" ]]; then
            fail "Executável não encontrado (--no-compile ativo): $BIN"
            return 1
        fi
        info "Compilação pulada: $impl → $bench (binário existe)"
        return 0
    fi

    if [[ -f "$BIN" ]] && ! $FORCE_REBUILD; then
        info "Binário já existe, pulando compilação: $impl → $bench"
        return 0
    fi

    info "Compilando $impl → $bench ..."
    cd "$BASE_DIR/$impl"
    make clean              >> "$LOGFILE" 2>&1
    make "$bench" CLASS="$CLASS" >> "$LOGFILE" 2>&1 || {
        fail "Erro de compilação: $impl $bench  →  verifique $LOGFILE"
        return 1
    }
    ok "Compilado: $impl $bench"
}

run_once() {
    local impl=$1 bench=$2 run_num=$3
    local eff_threads; eff_threads=$(effective_threads "$impl")
    local BIN="$BASE_DIR/$impl/bin/${bench}.${CLASS}.x"
    local OUTDIR="$RESULTS_DIR/$impl/${bench^^}"
    local TIMESTAMP; TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    local OUTFILE="$OUTDIR/${impl,,}_${bench}_${CLASS}_t${eff_threads}_run${run_num}_$TIMESTAMP.txt"
    local RUNLOG="$LOG_RUN/${impl}_${bench}_run.log"

    mkdir -p "$OUTDIR"
    [[ ! -f "$BIN" ]] && { fail "Executável não encontrado: $BIN"; return 1; }

    case "$impl" in
        SERIAL)
            "$BIN" > "$OUTFILE" 2>> "$RUNLOG" ;;
        OMP|DO_CONCURRENT)
            OMP_NUM_THREADS=$eff_threads OMP_STACKSIZE=512M \
                "$BIN" > "$OUTFILE" 2>> "$RUNLOG" ;;
        MPI)
            mpirun -np "$eff_threads" "$BIN" > "$OUTFILE" 2>> "$RUNLOG" ;;
        *)
            fail "Implementação desconhecida: $impl"; return 1 ;;
    esac

    [[ $? -ne 0 ]] && {
        fail "Execução falhou: $impl $bench run $run_num"; return 1
    }

    # ── extração ──────────────────────────────────────────────────────────────
    local bench_time mops mops_json verified

    bench_time=$(extract_time "$OUTFILE")
    if [[ -z "$bench_time" ]]; then
        bench_time="null"
        warn "  Tempo não encontrado em $impl $bench run $run_num"
    else
        bench_time=$(printf "%.6f" "$bench_time")
    fi

    mops=$(extract_mops "$OUTFILE")
    if [[ -z "$mops" ]]; then
        mops_json="null"
    elif [[ "$mops" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        mops_json="$mops"
    else
        mops_json="null"
        warn "  Mop/s com formato inesperado: '$mops' em $impl $bench run $run_num"
    fi

    verified=$(extract_verified "$OUTFILE")
    [[ -z "$verified" ]] && verified="UNKNOWN"

    info "  Run $run_num — tempo: ${bench_time}s | Mop/s: ${mops:-N/A} | $verified"

    JSON_ENTRIES+=("{
        \"implementation\": \"$impl\",
        \"benchmark\": \"$bench\",
        \"class\": \"$CLASS\",
        \"threads\": $eff_threads,
        \"run\": $run_num,
        \"time_seconds\": $bench_time,
        \"mops\": $mops_json,
        \"verified\": \"$verified\",
        \"output_file\": \"${OUTFILE#"$BASE_DIR"/}\"
    }")
}

run_benchmark() {
    local impl=$1 bench=$2
    echo ""
    info "Executando $impl $bench (Classe $CLASS, $RUNS repetições) ..."
    for ((r=1; r<=RUNS; r++)); do
        run_once "$impl" "$bench" "$r" || true
    done
}

# =============================================================================
# GERAÇÃO E VALIDAÇÃO DO JSON
# Montado em memória → escrito uma vez → validado → auto-reparo se necessário.
# Elimina a necessidade do rebuild_json.sh.
# =============================================================================

write_and_validate_json() {
    local json_file=$1

    # Escreve
    {
        echo "["
        for i in "${!JSON_ENTRIES[@]}"; do
            echo "${JSON_ENTRIES[$i]}"
            [[ $i -lt $(( ${#JSON_ENTRIES[@]} - 1 )) ]] && echo ","
        done
        echo "]"
    } > "$json_file"

    # Valida
    if ! command -v python3 &>/dev/null; then
        warn "python3 não encontrado — JSON não validado"
        return
    fi

    if python3 -c "import json,sys; json.load(open('$json_file'))" 2>/dev/null; then
        ok "JSON válido: $json_file"
        return
    fi

    # Auto-reparo (substitui o rebuild_json.sh)
    warn "JSON inválido detectado — tentando auto-reparo ..."
    python3 - "$json_file" << 'PYEOF'
import sys, re, json

path = sys.argv[1]
with open(path) as f:
    raw = f.read()

# Remove vírgulas pendentes antes de } ou ]
fixed = re.sub(r',\s*([}\]])', r'\1', raw)

# Garante que é um array
fixed = fixed.strip()
if not fixed.startswith('['):
    # Tenta encontrar objetos individuais e montar array
    objects = re.findall(r'\{[^{}]+\}', fixed, re.DOTALL)
    fixed = '[\n' + ',\n'.join(objects) + '\n]'

try:
    parsed = json.loads(fixed)
    with open(path, 'w') as f:
        json.dump(parsed, f, indent=4)
    print(f"[AUTO-REPARO] JSON corrigido com {len(parsed)} entradas: {path}")
except Exception as e:
    print(f"[ERRO] Não foi possível reparar o JSON: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF

    if python3 -c "import json; json.load(open('$json_file'))" 2>/dev/null; then
        ok "JSON reparado com sucesso: $json_file"
    else
        fail "JSON ainda inválido após reparo — verifique manualmente: $json_file"
    fi
}

# =============================================================================
# EXECUÇÃO PRINCIPAL
# =============================================================================

TIMESTAMP_GLOBAL=$(date +"%Y%m%d_%H%M%S")
JSON_FILE="$SUMMARY_DIR/results_$TIMESTAMP_GLOBAL.json"
JSON_ENTRIES=()

for impl in "${IMPLEMENTATIONS[@]}"; do
    echo ""
    echo -e "${BOLD}====================================${NC}"
    echo -e "${BOLD} Implementação: $impl${NC}"
    echo -e "${BOLD}====================================${NC}"

    for bench in "${BENCHMARKS[@]}"; do
        compile_benchmark "$impl" "$bench" || true
        rc=$?
        if   [[ $rc -eq 0 ]]; then run_benchmark "$impl" "$bench"
        elif [[ $rc -eq 2 ]]; then : # não disponível, já avisou
        else warn "Pulando execução de $impl $bench (falha de compilação)."
        fi
    done
done

write_and_validate_json "$JSON_FILE"

echo ""
echo -e "${BOLD}====================================${NC}"
echo -e "${BOLD} Execução finalizada!${NC}"
echo -e "${BOLD}====================================${NC}"
echo "  JSON:     $JSON_FILE"
echo "  Para gerar relatório: ./report.sh $JSON_FILE"
echo -e "${BOLD}====================================${NC}"