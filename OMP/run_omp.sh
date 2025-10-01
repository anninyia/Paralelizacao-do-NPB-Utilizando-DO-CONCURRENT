#!/bin/bash
# Script para executar benchmarks OpenMP com controle de threads

THREADS=${1:-4}
CLASS=${2:-C}
BASE_BENCHMARK_DIR="/mnt/f/NAS Parallel Benchmarks"
RESULTS_DIR="$BASE_BENCHMARK_DIR/Results"
mkdir -p "$RESULTS_DIR"

echo "=== OpenMP Benchmark Runner ==="
echo "Threads: $THREADS"
echo "Class: $CLASS"
echo "================================"

export OMP_NUM_THREADS=$THREADS

extract_class() {
    local filename=$1
    echo "$filename" | grep -o '\.[SWABCDEF]\.' | tr -d '.'
}

run_omp_benchmark() {
    local benchmark=$1
    local executable_pattern="$(pwd)/bin/${benchmark}.${CLASS}.x"

    if [ ! -f "$executable_pattern" ]; then
        echo "Executable $executable_pattern not found! Skipping..."
        return 1
    fi

    local actual_class=$(extract_class "$executable_pattern")
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local output_file="$RESULTS_DIR/omp_${benchmark}_${actual_class}_t${THREADS}_${timestamp}.txt"
    local json_file="$RESULTS_DIR/omp_${benchmark}_${actual_class}_t${THREADS}_${timestamp}.json"

    echo "=== Executando $benchmark (OpenMP) ===" | tee -a "$output_file"
    echo "Threads: $THREADS" | tee -a "$output_file"
    echo "Class: $actual_class" | tee -a "$output_file"
    echo "Timestamp: $(date)" | tee -a "$output_file"
    echo "" | tee -a "$output_file"

    local start_time=$(date +%s.%N)
    "$executable_pattern" >> "$output_file" 2>&1
    local end_time=$(date +%s.%N)
    local wall_time=$(echo "$end_time - $start_time" | bc)

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
  "implementation": "OpenMP",
  "class": "$actual_class",
  "threads": $THREADS,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "execution_time_seconds": ${exec_time:-$wall_time},
  "wall_time_seconds": $wall_time,
  "performance_mops": ${mops:-0},
  "verification": "${verification:-"Unknown"}",
  "problem_size": "${problem_size:-"Unknown"}",
  "executable": "$executable_pattern",
  "output_file": "$output_file"
}
EOF

    echo "OpenMP $benchmark (Class $actual_class, $THREADS threads): ${exec_time:-$wall_time}s"
    echo "Resultados salvos em: $output_file e $json_file"
    echo ""
}

benchmarks=("cg" "ft" "mg" "sp" "bt" "lu" "ep" "is")
executed_count=0

for benchmark in "${benchmarks[@]}"; do
    if run_omp_benchmark "$benchmark"; then
        ((executed_count++))
    fi
done

consolidated_file="$RESULTS_DIR/omp_results_t${THREADS}_$(date +"%Y%m%d_%H%M%S").json"
echo "[" > "$consolidated_file"
first=true

for json_file in "$RESULTS_DIR"/omp_*_t${THREADS}_*.json; do
    if [ -f "$json_file" ] && [[ "$json_file" != *"omp_results_"* ]]; then
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
echo "Threads utilizadas: $THREADS"
echo "Classe utilizada: $CLASS"
echo "Arquivo consolidado: $consolidated_file"
echo "=========================="