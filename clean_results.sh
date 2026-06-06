#!/bin/bash
# =============================================================================
#  clean_results.sh — Limpa resultados dos benchmarks NPB
#  Uso: ./clean_results.sh [--force] [--keep-json] [--keep-png]
# =============================================================================

export LC_ALL=C

FORCE=false
KEEP_JSON=false
KEEP_PNG=false

for arg in "$@"; do
    case "$arg" in
        --force|-f)     FORCE=true ;;
        --keep-json)    KEEP_JSON=true ;;
        --keep-png)     KEEP_PNG=true ;;
        -h|--help)
            echo "Uso: $0 [--force] [--keep-json] [--keep-png]"
            echo "  --force      Remove sem confirmar"
            echo "  --keep-json  Preserva os JSONs de resultados"
            echo "  --keep-png   Preserva os gráficos PNG"
            exit 0 ;;
        *) echo "Argumento desconhecido: $arg"; exit 1 ;;
    esac
done

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m';  BOLD='\033[1m';   NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/Results"

echo -e "${BOLD}===================================="
echo " NPB Results Cleaner"
echo -e "====================================${NC}"
echo "  Diretório: $RESULTS_DIR"
echo ""

if [[ ! -d "$RESULTS_DIR" ]]; then
    echo -e "${GREEN}Nenhum diretório Results encontrado.${NC}"
    exit 0
fi

# Conta arquivos por tipo
count_files() { find "$RESULTS_DIR" -type f -name "$1" | wc -l; }

txt_count=$(count_files "*.txt")
log_count=$(count_files "*.log")
py_count=$(count_files  "*.py")
json_count=$(count_files "*.json")
png_count=$(count_files  "*.png")

# Aplica filtros --keep-*
will_remove_json=$( $KEEP_JSON && echo 0 || echo "$json_count" )
will_remove_png=$(  $KEEP_PNG  && echo 0 || echo "$png_count"  )
total=$(( txt_count + log_count + py_count + will_remove_json + will_remove_png ))

if [[ $total -eq 0 ]]; then
    echo -e "${GREEN}Nada para limpar.${NC}"
    exit 0
fi

echo -e "${YELLOW}Arquivos a remover:${NC}"
echo "  TXT:  $txt_count"
echo "  LOG:  $log_count"
echo "  PY:   $py_count  (scripts temporários do report)"
$KEEP_JSON \
    && echo -e "  JSON: ${GREEN}preservados (--keep-json)${NC}" \
    || echo "  JSON: $json_count"
$KEEP_PNG \
    && echo -e "  PNG:  ${GREEN}preservados (--keep-png)${NC}" \
    || echo "  PNG:  $png_count"
echo "  ────────────────"
echo "  Total: $total arquivo(s)"
echo ""

if ! $FORCE; then
    read -rp "Remover? (y/N): " resp
    [[ ! "$resp" =~ ^[Yy]$ ]] && echo "Cancelado." && exit 0
fi

echo -e "${CYAN}Removendo...${NC}"

find "$RESULTS_DIR" -type f -name "*.txt" -delete
find "$RESULTS_DIR" -type f -name "*.log" -delete
find "$RESULTS_DIR" -type f -name "*.py"  -delete
$KEEP_JSON || find "$RESULTS_DIR" -type f -name "*.json" -delete
$KEEP_PNG  || find "$RESULTS_DIR" -type f -name "*.png"  -delete

# Remove diretórios vazios (exceto Results/ em si)
find "$RESULTS_DIR" -mindepth 1 -type d -empty -delete 2>/dev/null || true

echo -e "${GREEN}Limpeza concluída. $total arquivo(s) removido(s).${NC}"