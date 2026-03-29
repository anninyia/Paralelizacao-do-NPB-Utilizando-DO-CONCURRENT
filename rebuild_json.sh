#!/bin/bash

RESULTS_DIR="Results"
JSON_OUT="Results/summary/rebuilt_results.json"

mkdir -p "$(dirname $JSON_OUT)"
echo "[" > $JSON_OUT

first=1

for file in $RESULTS_DIR/*/*/*.txt; do
    [ -f "$file" ] || continue

    impl=$(echo $file | cut -d'/' -f2)
    bench=$(echo $file | cut -d'/' -f3 | tr '[:upper:]' '[:lower:]')
    class=$(basename $file | grep -oP '_[A-Z]_t' | tr -d '_t')
    threads=$(basename $file | grep -oP 't\d+_run' | grep -oP '\d+' | head -1)
    run=$(basename $file | grep -oP 'run\d+' | grep -oP '\d+')

    # Pega apenas a PRIMEIRA ocorrência de "Time in seconds"
    # (evita concatenação do MPI com múltiplos processos)
    time=$(grep "Time in seconds" "$file" | head -1 | awk '{
    if ($NF ~ /^[0-9]/) print $NF
    else print $(NF-1)
}')

    # Se time vazio ou zero, tenta formato alternativo
    if [ -z "$time" ] || [ "$time" = "0.000000" ] || [ "$time" = "0" ]; then
        # Formato OMP IS original: "  Time:   0.167  seconds"
        time=$(grep -E "^\s*Time:\s" "$file" | head -1 | awk '{print $2}')
    fi

    if [ -z "$time" ] || [ "$time" = "0.000000" ] || [ "$time" = "0" ]; then
        # Tenta "Elapsed time" ou "Wall clock"
        time=$(grep -i "elapsed\|wall" "$file" | head -1 | awk '{print $NF}')
    fi

    # Garante zero antes do ponto decimal
    if [ -n "$time" ]; then
        time=$(echo "$time" | awk '{printf "%.6f", $1}')
    else
        time="null"
    fi

    # mops: primeira ocorrência
    mops=$(grep "Mop/s total" "$file" | head -1 | awk '{print $NF}')
    if echo "$mops" | grep -qE '^[0-9]+(\.[0-9]+)?$'; then
        mops_json=$mops
    else
        mops_json="null"
    fi

    verified=$(grep "Verification" "$file" | grep -o "SUCCESSFUL\|FAILED\|UNSUCCESSFUL" | head -1)
    [ -z "$verified" ] && verified="UNKNOWN"
    [ "$verified" = "UNSUCCESSFUL" ] && verified="FAILED"

    # Valida que temos os campos essenciais
    [ -z "$impl" ] || [ -z "$bench" ] || [ -z "$class" ] || \
    [ -z "$threads" ] || [ -z "$run" ] && continue

    if [ $first -eq 0 ]; then
        echo "," >> $JSON_OUT
    fi
    first=0

    cat >> $JSON_OUT << ENTRY
{
    "implementation": "$impl",
    "benchmark": "$bench",
    "class": "$class",
    "threads": $threads,
    "run": $run,
    "time_seconds": $time,
    "mops": $mops_json,
    "verified": "$verified",
    "output_file": "$file"
}
ENTRY

done

echo "]" >> $JSON_OUT

# Valida o JSON
python3 -c "
import json
try:
    with open('$JSON_OUT') as f:
        data = json.load(f)
    print(f'JSON válido! {len(data)} entradas.')
except Exception as e:
    print(f'Erro: {e}')
"