#!/bin/bash
# =============================================================================
#  setup.sh — Verifica e instala dependências para os NPB Benchmarks
#  Compilador principal: nvfortran (NVIDIA HPC SDK)
# =============================================================================

set -uo pipefail   # sem -e: avisos não abortam o script
export LC_ALL=C

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m';  BOLD='\033[1m';   NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[AVISO]${NC} $*"; }
fail() { echo -e "${RED}[ERRO]${NC} $*"; }
info() { echo -e "${CYAN}[INFO]${NC} $*"; }

ERRORS=0
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
SKIP_DIRS="bin|common|config|sys|MPI_dummy|npb_original|Results"

echo -e "${BOLD}===================================="
echo " NPB Benchmarks — Setup e Verificação"
echo " Compilador alvo: nvfortran (NVIDIA HPC SDK)"
echo -e "====================================${NC}"
echo ""

# =============================================================================
# 1. COMPILADORES
# =============================================================================

echo -e "${BOLD}--- Compiladores ---${NC}"

# nvfortran — obrigatório para SERIAL, OMP, DO_CONCURRENT
if command -v nvfortran &>/dev/null; then
    ok "nvfortran: $(nvfortran --version 2>&1 | head -1)"
else
    fail "nvfortran NÃO encontrado — necessário para SERIAL, OMP e DO_CONCURRENT"
    echo ""
    echo "    Para instalar o NVIDIA HPC SDK:"
    echo "      1. Verifique versões disponíveis:"
    echo "           apt-cache search nvhpc | head -10"
    echo "      2. Instale:"
    echo "           sudo apt install nvhpc-25-3   # ajuste a versão"
    echo "      3. Adicione ao PATH (~/.bashrc):"
    echo "           export PATH=/opt/nvidia/hpc_sdk/Linux_x86_64/25.3/compilers/bin:\$PATH"
    echo "      4. Recarregue:"
    echo "           source ~/.bashrc"
    echo ""
    ERRORS=$((ERRORS+1))
fi

# mpif90 — obrigatório para MPI (deve estar wrappando nvfortran)
if command -v mpif90 &>/dev/null; then
    ok "mpif90: $(mpif90 --version 2>&1 | head -1)"
    # Verifica se está wrappando nvfortran
    backend=$(mpif90 --showme:compile 2>/dev/null || true)
    [[ -z "$backend" ]] && backend=$(mpif90 -show 2>/dev/null | awk '{print $1}' || true)
    if echo "$backend" | grep -qi "nvfortran" 2>/dev/null; then
        ok "  mpif90 → nvfortran (correto)"
    else
        warn "  mpif90 pode não estar usando nvfortran como backend"
        warn "  Verifique: mpif90 --showme:compile"
        warn "  Para usar nvfortran com MPI, configure OMPI_FC=nvfortran"
    fi
else
    fail "mpif90 não encontrado — necessário para MPI"
    echo "    Ubuntu/Debian: sudo apt install openmpi-bin libopenmpi-dev"
    ERRORS=$((ERRORS+1))
fi

# mpirun
if command -v mpirun &>/dev/null; then
    ok "mpirun: $(mpirun --version 2>&1 | head -1)"
else
    fail "mpirun não encontrado"
    echo "    Ubuntu/Debian: sudo apt install openmpi-bin"
    ERRORS=$((ERRORS+1))
fi

# gfortran (fallback informativo)
if command -v gfortran &>/dev/null; then
    warn "gfortran encontrado mas NÃO será usado (nvfortran tem prioridade)"
fi

echo ""

# =============================================================================
# 2. FERRAMENTAS DE BUILD
# =============================================================================

echo -e "${BOLD}--- Ferramentas de build ---${NC}"

if command -v make &>/dev/null; then
    ok "make: $(make --version | head -1)"
else
    fail "make não encontrado"
    echo "    sudo apt install make"
    ERRORS=$((ERRORS+1))
fi

if command -v python3 &>/dev/null; then
    ok "python3: $(python3 --version)"
    python3 -c "import matplotlib" 2>/dev/null \
        && ok "  matplotlib OK" \
        || warn "  matplotlib ausente — instale: pip install matplotlib"
    python3 -c "import json, statistics" 2>/dev/null \
        && ok "  json, statistics OK"
else
    warn "python3 não encontrado — necessário para relatórios"
    echo "    sudo apt install python3 python3-pip"
fi

echo ""

# =============================================================================
# 3. ESTRUTURA DO PROJETO (autodiscovery)
# =============================================================================

echo -e "${BOLD}--- Estrutura do projeto ---${NC}"

mapfile -t IMPLS < <(
    find "$BASE_DIR" -maxdepth 1 -mindepth 1 -type d | while read -r d; do
        name=$(basename "$d")
        [[ "$name" =~ ^($SKIP_DIRS|Results|\..*)$ ]] && continue
        [[ -f "$d/Makefile" ]] && echo "$name"
    done | sort
)

for impl in "${IMPLS[@]}"; do
    # Verifica make.def
    if [[ -f "$BASE_DIR/$impl/config/make.def" ]]; then
        compiler=$(grep -E "^(F77|FC|MPIFC)\s*=" "$BASE_DIR/$impl/config/make.def" \
            | head -1 | awk -F'=' '{print $2}' | tr -d ' ')
        if [[ "$compiler" == "gfortran" ]]; then
            warn "$impl/config/make.def usa '$compiler' → deveria ser nvfortran"
            warn "  Veja instruções abaixo para corrigir"
        elif [[ "$compiler" == "nvfortran" || "$compiler" == '$(FC)' ]]; then
            ok "$impl/config/make.def → compilador: $compiler"
        elif [[ "$compiler" == "mpif90" ]]; then
            # MPI usa wrapper do OpenMPI — gfortran é aceitável como backend
            mpi_backend=$(mpif90 --showme:compile 2>/dev/null | grep -oE 'nvfortran|gfortran' | head -1 || echo "desconhecido")
            if [[ "$mpi_backend" == "nvfortran" ]]; then
                ok "$impl/config/make.def → compilador: $compiler (backend: nvfortran ✓)"
            else
                ok "$impl/config/make.def → compilador: $compiler (backend: ${mpi_backend})"
                info "  MPI usa gfortran via wrapper — aceitável para benchmarks"
            fi
        else
            warn "$impl/config/make.def → compilador: '${compiler:-não encontrado}' (verifique)"
        fi
    else
        warn "$impl/config/make.def não encontrado"
    fi

    # Lista benchmarks disponíveis
    mapfile -t benches < <(
        find "$BASE_DIR/$impl" -maxdepth 1 -mindepth 1 -type d | while read -r d; do
            name=$(basename "$d")
            [[ "$name" =~ ^($SKIP_DIRS)$ ]] && continue
            [[ -f "$d/Makefile" ]] && echo "${name^^}"
        done | sort
    )
    info "  $impl → benchmarks: ${benches[*]:-nenhum encontrado}"
done

echo ""

# =============================================================================
# 4. INSTRUÇÕES PARA TROCAR PARA nvfortran
# =============================================================================

echo -e "${BOLD}--- Como trocar para nvfortran em cada make.def ---${NC}"
echo ""
echo "  SERIAL/config/make.def:"
echo "    Troque:  F77 = gfortran"
echo "    Por:     FC  = nvfortran"
echo "    Flags:   FFLAGS = -O3 -Mpreprocess -Mfree"
echo "    Flags:   FLINKFLAGS = \$(FFLAGS)"
echo ""
echo "  OMP/config/make.def:"
echo "    Troque:  F77 = gfortran (ou equivalente)"
echo "    Por:     FC  = nvfortran"
echo "    Flags:   FFLAGS = -O3 -mp -Mpreprocess -Mfree"
echo "    (o -mp ativa OpenMP no nvfortran)"
echo ""
echo "  MPI/config/make.def:"
echo "    Mantenha: MPIFC = mpif90"
echo "    Configure: export OMPI_FC=nvfortran antes de compilar"
echo "    Flags:   FFLAGS = -O3 -Mpreprocess -Mfree"
echo ""
echo "  DO_CONCURRENT/config/make.def:"
echo "    Já está correto (FC = nvfortran, -stdpar=multicore)"
echo ""

# =============================================================================
# 5. RESULTADO FINAL
# =============================================================================

echo -e "${BOLD}--- Resultado ---${NC}"
if [[ $ERRORS -eq 0 ]]; then
    ok "Ambiente OK! Execute: ./run_benchmarks.sh"
else
    fail "$ERRORS dependência(s) crítica(s) ausente(s). Corrija antes de continuar."
    exit 1
fi