#!/bin/bash
# Master script para executar todos os NAS Parallel Benchmarks
# Usage: ./run_benchmarks.sh [threads/processes] [class] [implementations]
# Example: ./run_benchmarks.sh 4 C "omp,mpi,dc"
# Example: ./run_benchmarks.sh 8 B "omp,mpi"

THREADS_PROCESSES=${1:-4}  # Default 4 threads/processes
CLASS=${2:-C}              # Default class C  
IMPLEMENTATIONS=${3:-"omp,mpi,dc"}  # Default all implementations
BASE_DIR="/mnt/f/NAS Parallel Benchmarks"
RESULTS_DIR="$BASE_DIR/Results"
mkdir -p "$RESULTS_DIR"

# Enable nullglob to avoid literal patterns when no files found
shopt -s nullglob

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║        NAS Parallel Benchmarks Master      ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo -e "${BLUE}Threads/Processes: ${YELLOW}$THREADS_PROCESSES${NC}"
echo -e "${BLUE}Class: ${YELLOW}$CLASS${NC}"  
echo -e "${BLUE}Implementations: ${YELLOW}$IMPLEMENTATIONS${NC}"
echo -e "${BLUE}Results Directory: ${YELLOW}$RESULTS_DIR${NC}"
echo ""

# Parse implementations
IFS=',' read -ra IMPL_ARRAY <<< "$IMPLEMENTATIONS"

# Função para executar implementação específica
run_implementation() {
    local impl=$1
    local impl_upper
    
    case "$impl" in
        "omp") impl_upper="OMP" ;;
        "mpi") impl_upper="MPI" ;;
        "dc")  impl_upper="DO_CONCURRENT" ;;
        *) impl_upper=$(echo "$impl" | tr '[:lower:]' '[:upper:]') ;;
    esac
    
    local impl_dir="$BASE_DIR/$impl_upper"
    local script_name="run_${impl}.sh"
    
    echo -e "${CYAN}=== Executando $impl_upper Benchmarks ===${NC}"
    
    if [ ! -d "$impl_dir" ]; then
        echo -e "${RED}❌ Diretório $impl_dir não encontrado${NC}"
        return 1
    fi
    
    if [ ! -f "$impl_dir/$script_name" ]; then
        echo -e "${RED}❌ Script $impl_dir/$script_name não encontrado${NC}"
        return 1
    fi
    
    cd "$impl_dir" || return 1
    
    echo -e "${BLUE}Executando: ./$script_name $THREADS_PROCESSES $CLASS${NC}"
    ./"$script_name" "$THREADS_PROCESSES" "$CLASS"
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✅ $impl_upper concluído com sucesso${NC}"
    else
        echo -e "${RED}❌ $impl_upper falhou (exit code: $exit_code)${NC}"
    fi
    
    echo ""
    cd "$BASE_DIR" || return 1
    return $exit_code
}

# Função para consolidar resultados
consolidate_results() {
    echo -e "${CYAN}=== Consolidando Resultados ===${NC}"
    
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local consolidated_file="$RESULTS_DIR/all_implementations_${CLASS}_t${THREADS_PROCESSES}_${timestamp}.json"
    
    echo "[" > "$consolidated_file"
    local first=true
    
    # Procurar todos os JSONs gerados na pasta centralizada
    for impl in "${IMPL_ARRAY[@]}"; do
        for json_file in "$RESULTS_DIR"/${impl}_*_"$CLASS"_*.json; do
            if [ -f "$json_file" ] && [[ "$json_file" != *"all_implementations_"* ]]; then
                if [ "$first" = false ]; then
                    echo "," >> "$consolidated_file"
                fi
                cat "$json_file" >> "$consolidated_file"
                first=false
            fi
        done
    done
    
    echo "]" >> "$consolidated_file"
    echo -e "${GREEN}📊 Resultados consolidados em: $consolidated_file${NC}"
    echo "$consolidated_file"  # Return do arquivo
}

# Função para gerar relatório de comparação
generate_comparison_report() {
    local json_file=$1
    local report_file="${json_file%.*}_report.txt"
    
    echo -e "${CYAN}=== Gerando Relatório de Comparação ===${NC}"
    
    cat > "$report_file" << EOF
NAS Parallel Benchmarks - Relatório de Comparação
================================================
Data: $(date)
Classe: $CLASS
Threads/Processes: $THREADS_PROCESSES
Implementações: $IMPLEMENTATIONS

EOF

    if command -v python3 &> /dev/null; then
        python3 << EOF >> "$report_file"
import json
try:
    with open('$json_file', 'r') as f:
        data = json.load(f)
    results = {}
    for item in data:
        benchmark = item.get('benchmark', 'unknown')
        impl = item.get('implementation', 'unknown')
        exec_time = float(item.get('execution_time_seconds', 0))
        if benchmark not in results:
            results[benchmark] = {}
        results[benchmark][impl] = exec_time

    print("COMPARAÇÃO DE PERFORMANCE:")
    print("=" * 40)
    for benchmark, impls in results.items():
        print(f"\n🔥 {benchmark.upper()}:")
        sorted_impls = sorted(impls.items(), key=lambda x: x[1])
        for i, (impl, time) in enumerate(sorted_impls):
            if i == 0:
                print(f"   🥇 {impl}: {time:.3f}s (FASTEST)")
            else:
                speedup = time / sorted_impls[0][1]
                print(f"   🏃 {impl}: {time:.3f}s ({speedup:.2f}x slower)")
except Exception as e:
    print(f"Erro na análise: {e}")
EOF
    else
        echo "Python3 não disponível - relatório básico gerado" >> "$report_file"
    fi
    
    echo -e "${GREEN}📈 Relatório de comparação: $report_file${NC}"
}

# Execução principal
echo -e "${BLUE}Iniciando execução dos benchmarks...${NC}"
start_time=$(date +%s)

successful_runs=0
total_runs=0

for impl in "${IMPL_ARRAY[@]}"; do
    ((total_runs++))
    if run_implementation "$impl"; then
        ((successful_runs++))
    fi
done

# Consolidar resultados se houver execuções bem-sucedidas
if [ $successful_runs -gt 0 ]; then
    consolidated_file=$(consolidate_results)
    if [ -f "$consolidated_file" ]; then
        generate_comparison_report "$consolidated_file"
    fi
fi

# Relatório final
end_time=$(date +%s)
total_time=$((end_time - start_time))

echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║              RELATÓRIO FINAL               ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo -e "${BLUE}Execuções bem-sucedidas: ${GREEN}$successful_runs${NC}/${BLUE}$total_runs${NC}"
echo -e "${BLUE}Tempo total: ${YELLOW}${total_time}s${NC}"
echo -e "${BLUE}Classe executada: ${YELLOW}$CLASS${NC}"
echo -e "${BLUE}Threads/Processes: ${YELLOW}$THREADS_PROCESSES${NC}"

if [ $successful_runs -gt 0 ]; then
    echo -e "${GREEN}✅ Benchmarks executados com sucesso!${NC}"
    echo -e "${BLUE}📁 Resultados em: ${YELLOW}$RESULTS_DIR${NC}"
else
    echo -e "${RED}❌ Nenhum benchmark executado com sucesso${NC}"
    exit 1
fi

# Restore nullglob
shopt -u nullglob