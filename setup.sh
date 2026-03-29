#!/bin/bash

# =============================================================================
#  setup.sh — Verifica e instala dependências para os NPB Benchmarks
# =============================================================================

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
fail() { echo -e "${RED}[ERRO]${NC} $1"; }

echo "===================================="
echo " NPB Benchmarks — Setup e Verificação"
echo "===================================="
echo ""

ERRORS=0

# =============================================================================
# 1. VERIFICAR COMPILADORES
# =============================================================================

echo "--- Verificando compiladores ---"

# nvfortran
if command -v nvfortran &> /dev/null; then
    VERSION=$(nvfortran --version 2>&1 | head -1)
    ok "nvfortran encontrado: $VERSION"
else
    fail "nvfortran não encontrado."
    echo "    Instale o NVIDIA HPC SDK: https://developer.nvidia.com/hpc-sdk"
    ERRORS=$((ERRORS+1))
fi

# gcc
if command -v gcc &> /dev/null; then
    VERSION=$(gcc --version | head -1)
    ok "gcc encontrado: $VERSION"
else
    fail "gcc não encontrado."
    echo "    Ubuntu/Debian: sudo apt install gcc"
    ERRORS=$((ERRORS+1))
fi

# gfortran (opcional, para referência)
if command -v gfortran &> /dev/null; then
    VERSION=$(gfortran --version | head -1)
    ok "gfortran encontrado: $VERSION"
else
    warn "gfortran não encontrado (opcional, não obrigatório para DO_CONCURRENT)."
fi

# MPI
if command -v mpirun &> /dev/null; then
    VERSION=$(mpirun --version 2>&1 | head -1)
    ok "mpirun encontrado: $VERSION"
else
    warn "mpirun não encontrado. Necessário apenas para implementação MPI."
    echo "    Ubuntu/Debian: sudo apt install openmpi-bin libopenmpi-dev"
fi

if command -v mpif90 &> /dev/null; then
    ok "mpif90 encontrado"
else
    warn "mpif90 não encontrado. Necessário apenas para implementação MPI."
fi

echo ""

# =============================================================================
# 2. VERIFICAR FERRAMENTAS DE BUILD
# =============================================================================

echo "--- Verificando ferramentas de build ---"

if command -v make &> /dev/null; then
    ok "make encontrado: $(make --version | head -1)"
else
    fail "make não encontrado."
    echo "    Ubuntu/Debian: sudo apt install make"
    ERRORS=$((ERRORS+1))
fi

if command -v bc &> /dev/null; then
    ok "bc encontrado (necessário para cálculo de tempo)"
else
    fail "bc não encontrado."
    echo "    Ubuntu/Debian: sudo apt install bc"
    ERRORS=$((ERRORS+1))
fi

if command -v python3 &> /dev/null; then
    ok "python3 encontrado: $(python3 --version)"
    # Verificar bibliotecas para geração de relatório
    python3 -c "import json, statistics" 2>/dev/null && ok "  python3: json, statistics OK" || warn "  python3: módulos básicos ausentes"
    python3 -c "import matplotlib" 2>/dev/null && ok "  python3: matplotlib OK" || warn "  python3: matplotlib ausente (necessário para gráficos). Instale com: pip3 install matplotlib"
    python3 -c "import pandas" 2>/dev/null   && ok "  python3: pandas OK"      || warn "  python3: pandas ausente (necessário para relatório). Instale com: pip3 install pandas"
else
    warn "python3 não encontrado. Necessário para gerar relatório com gráficos."
    echo "    Ubuntu/Debian: sudo apt install python3 python3-pip"
fi

echo ""

# =============================================================================
# 3. VERIFICAR ESTRUTURA DO PROJETO
# =============================================================================

echo "--- Verificando estrutura do projeto ---"

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
IMPLEMENTATIONS=("SERIAL" "OMP" "DO_CONCURRENT" "MPI")
BENCHMARKS=("CG" "FT" "MG" "IS")

for impl in "${IMPLEMENTATIONS[@]}"; do
    if [ -d "$BASE_DIR/$impl" ]; then
        ok "Diretório $impl/ encontrado"
        for bench in "${BENCHMARKS[@]}"; do
            if [ -d "$BASE_DIR/$impl/${bench}" ]; then
                ok "  $impl/${bench}/"
            else
                warn "  $impl/${bench}/ não encontrado (benchmark pode não estar disponível)"
            fi
        done
    else
        warn "Diretório $impl/ não encontrado"
    fi
done

echo ""

# =============================================================================
# 4. RESULTADO FINAL
# =============================================================================

echo "--- Resultado ---"

if [ $ERRORS -eq 0 ]; then
    ok "Ambiente verificado com sucesso! Você pode rodar: ./run_benchmarks.sh"
else
    fail "$ERRORS dependência(s) crítica(s) ausente(s). Corrija antes de continuar."
    exit 1
fi