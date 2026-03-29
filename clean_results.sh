#!/bin/bash
# Limpa resultados de benchmarks NPB
# Uso:
#   ./clean_results.sh
#   ./clean_results.sh --force

FORCE=false
[[ "$1" == "--force" || "$1" == "-f" ]] && FORCE=true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/Results"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== NPB Results Cleaner ===${NC}"
echo "Diretório: $RESULTS_DIR"
echo ""

if [[ ! -d "$RESULTS_DIR" ]]; then
    echo -e "${GREEN}Nenhum diretório Results encontrado.${NC}"
    exit 0
fi

txt_count=$(find "$RESULTS_DIR" -type f -name "*.txt" | wc -l)
json_count=$(find "$RESULTS_DIR" -type f -name "*.json" | wc -l)
png_count=$(find "$RESULTS_DIR" -type f -name "*.png" | wc -l)
log_count=$(find "$RESULTS_DIR" -type f -name "*.log" | wc -l)
py_count=$(find "$RESULTS_DIR"  -type f -name "*.py"  | wc -l)

total=$((txt_count + json_count + png_count + log_count + py_count))

if [[ $total -eq 0 ]]; then
    echo -e "${GREEN}Nada para limpar.${NC}"
    exit 0
fi

echo -e "${YELLOW}Arquivos encontrados:${NC}"
echo "  TXT:  $txt_count"
echo "  JSON: $json_count"
echo "  PNG:  $png_count"
echo "  LOG:  $log_count"
echo "  PY:   $py_count"
echo "  Total: $total"
echo ""

if [[ "$FORCE" = false ]]; then
    read -p "Remover todos? (y/N): " resp
    [[ ! "$resp" =~ ^[Yy]$ ]] && echo "Cancelado." && exit 0
fi

echo -e "${BLUE}Removendo arquivos...${NC}"

find "$RESULTS_DIR" -type f -name "*.txt"  -delete
find "$RESULTS_DIR" -type f -name "*.json" -delete
find "$RESULTS_DIR" -type f -name "*.png"  -delete
find "$RESULTS_DIR" -type f -name "*.log"  -delete
find "$RESULTS_DIR" -type f -name "*.py"   -delete

# Remover diretórios vazios que sobraram (exceto o próprio Results/)
find "$RESULTS_DIR" -mindepth 1 -type d -empty -delete

echo -e "${GREEN}Limpeza concluida. $total arquivo(s) removido(s).${NC}"