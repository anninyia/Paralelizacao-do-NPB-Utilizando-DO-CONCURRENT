#!/bin/bash
# Script para limpar arquivos .json e .txt da pasta Results/
# Uso: ./clean_results.sh [--force]

FORCE_MODE=false
if [ "$1" = "--force" ] || [ "$1" = "-f" ]; then
    FORCE_MODE=true
fi

BASE_DIR="$(pwd)"  # Considera que o script está em NAS Parallel Benchmarks
RESULTS_DIR="$BASE_DIR/Results"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Results Cleaner Script ===${NC}"
echo "Este script irá limpar todos os arquivos .json e .txt da pasta 'Results'"
echo ""

# Verifica se a pasta Results existe
if [ ! -d "$RESULTS_DIR" ]; then
    echo -e "${GREEN}✅ Pasta $RESULTS_DIR não existe, nada para limpar${NC}"
    exit 0
fi

# Contagem detalhada
json_count=$(find "$RESULTS_DIR" -maxdepth 1 -type f -name "*.json" | wc -l)
txt_count=$(find "$RESULTS_DIR" -maxdepth 1 -type f -name "*.txt" | wc -l)
total_count=$((json_count + txt_count))

if [ $total_count -eq 0 ]; then
    echo -e "${GREEN}✅ Nenhum arquivo .json ou .txt encontrado na pasta Results${NC}"
    exit 0
fi

echo -e "${YELLOW}Arquivos encontrados na pasta Results:${NC}"
echo -e "   JSON: ${BLUE}$json_count${NC}"
echo -e "   TXT:  ${BLUE}$txt_count${NC}"
echo -e "   TOTAL: ${RED}$total_count${NC}"
echo ""

# Confirmação
if [ "$FORCE_MODE" = false ]; then
    echo -e "${YELLOW}Deseja realmente remover todos estes arquivos? (y/N):${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Yy]([Ee][Ss])?$ ]]; then
        echo -e "${BLUE}Operação cancelada pelo usuário.${NC}"
        exit 0
    fi
fi

# Limpeza segura
echo -e "${BLUE}Iniciando limpeza...${NC}"
removed_count=0
errors=0

while IFS= read -r -d '' file; do
    if rm -f "$file"; then
        ((removed_count++))
    else
        echo -e "${RED}❌ Erro ao remover $file${NC}"
        ((errors++))
    fi
done < <(find "$RESULTS_DIR" -maxdepth 1 -type f \( -name "*.json" -o -name "*.txt" \) -print0)

# Relatório final
echo -e "${BLUE}=== Relatório Final ===${NC}"
echo -e "Arquivos removidos: ${GREEN}$removed_count${NC}"
if [ $errors -gt 0 ]; then
    echo -e "Erros encontrados: ${RED}$errors${NC}"
else
    echo -e "Erros encontrados: ${GREEN}0${NC}"
fi

echo -e "${GREEN}🎉 Limpeza concluída!${NC}"