#!/bin/bash
# Script para executar benchmarks MPI com controle de processos

PROCESSES=${1:-4}
CLASS=${2:-C}
BASE_BENCHMARK_DIR="/mnt/f/NAS Parallel Benchmarks"
RESULTS_DIR="$BASE_BENCHMARK_DIR/Results"
mkdir -p "$RESULTS_DIR"

AVAILABLE_CORES=$(nproc)
IS_WSL=$(grep -qi microsoft /proc/version && echo "true" || echo "false")

MPI_OPTIONS=""
if [ "$IS_WSL" = "true" ]; then
    MPI_OPTIONS="--oversubscribe --allow-run-as-root"
    export OMPI_ALLOW_RUN_AS_ROOT=1
    export OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1
elif [ $PROCESSES -gt $AVAILABLE_CORES ]; then
    MPI_OPTIONS="--oversubscribe"
fi

extract_class() {
    local filename=$1
    echo "$filename" | grep -o '\.[SWABCDEF]\.' | tr -d '.'
}

run_mpi_benchmark() {
    local benchmark=$1
    local executable_pattern="$(pwd)/bin/${benchmark}.${CLASS}.x"

    if [ ! -f "$executable_pattern" ]; then
        echo "Executable $executable_pattern not found! Skipping..."
        return 1
    fi

    local actual_class=$(extract_class "$executable_pattern")
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local output_file="$RESULTS_DIR/mpi_${benchmark}_${actual_class}_p${PROCESSES}_${timestamp}.txt"
    local json_file="$RESULTS_DIR/mpi_${benchmark}_${actual_class}_p${PROCESSES}_${timestamp}.json"

    echo "=== Executando $benchmark (MPI) ===" | tee -a "$output_file"
    echo "Processes: $PROCESSES" | tee -a "$output_file"
    echo "Class: $actual_class" | tee -a "$output_file"
    echo "Timestamp: $(date)" | tee -a "$output_file"
    echo "" | tee -a "$output_file"

    local start_time=$(date +%s.%N)
    mpirun $MPI_OPTIONS -np $PROCESSES "$executable_pattern" >> "$output_file" 2>&1
    local mpi_exit_code=$?
    local end_time=$(date +%s.%N)
    local wall_time=$(echo "$end_time - $start_time" | bc)

    if [ $mpi_exit_code -ne 0 ]; then
        echo "MPI execution failed with exit code $mpi_exit_code" | tee -a "$output_file"
    fi

    local exec_time=$(grep -E "Time in seconds|Total time|time =|Time =" "$output_file" | tail -1 | grep -o '[0-9]*\.[0-9]*' | head -1)
    local mops=$(grep -iE "mop/s|mflops|gflops" "$output_file" | grep -o '[0-9]*\.[0-9]*' | head -1)
    local verification=$(grep -i "verification\|successful\|passed\|failed" "$output_file" | head -1)
    local problem_size=$(grep -E "Size:|Problem size|Grid points" "$output_file" | head -1)

    if [ -z "$exec_time" ]; then
        exec_time=$wall_time
    fi

    cat > "$json_file" << EOF
{
  "benchmark": "$benchmark",
  "implementation": "MPI",
  "class": "$actual_class",
  "processes": $PROCESSES,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "execution_time_seconds": ${exec_time:-$wall_time},
  "wall_time_seconds": $wall_time,
  "performance_mops": ${mops:-0},
  "verification": "${verification:-"Unknown"}",
  "mpi_exit_code": $mpi_exit_code,
  "problem_size": "${problem_size:-"Unknown"}",
  "executable": "$executable_pattern",
  "output_file": "$output_file"
}
EOF

    echo "MPI $benchmark (Class $actual_class, $PROCESSES processes): ${exec_time:-$wall_time}s"
    if [ $mpi_exit_code -ne 0 ]; then
        echo "Warning: MPI execution had errors (exit code: $mpi_exit_code)"
    fi
    echo "Resultados salvos em: $output_file e $json_file"
    echo ""
}

benchmarks=("cg" "ft" "mg" "sp" "bt" "lu" "ep" "is")
executed_count=0

for benchmark in "${benchmarks[@]}"; do
    if run_mpi_benchmark "$benchmark"; then
        ((executed_count++))
    fi
done

consolidated_file="$RESULTS_DIR/mpi_results_p${PROCESSES}_$(date +"%Y%m%d_%H%M%S").json"
echo "[" > "$consolidated_file"
first=true

for json_file in "$RESULTS_DIR"/mpi_*_p${PROCESSES}_*.json; do
    if [ -f "$json_file" ] && [[ "$json_file" != *"mpi_results_"* ]]; then
        if [ "$first" = false ]; then
            echo "," >> "$consolidated_file"
        fi
        cat "$json_file" >> "$consolidated_file"
        first=false
    fi
done

echo "]" >> "$consolidated_file"

echo "=== Resumo da Execução ==="
echo "Benchmarks executados: $executed_count"
echo "Processos utilizados: $PROCESSES"
echo "Classe utilizada: $CLASS"
echo "Arquivo consolidado: $consolidated_file"
echo "=========================="