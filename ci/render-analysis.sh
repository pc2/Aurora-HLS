set -euo pipefail

cd "${CI_PROJECT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
mkdir -p build-analysis/tmp
export TMPDIR="$PWD/build-analysis/tmp" TMP="$PWD/build-analysis/tmp" TEMP="$PWD/build-analysis/tmp"
export XDG_CACHE_HOME="$PWD/build-analysis/cache"
export XDG_DATA_HOME="$PWD/build-analysis/data"
export XDG_CONFIG_HOME="$PWD/build-analysis/config"
export QUARTO_USER_DATA_PATH="$PWD/build-analysis/quarto"

ml devel/quarto/1.8.26
ml lang/JuliaHPC/1.12.6-foss-2025a
export HPC_CI_STORAGE_DIR="${HPC_CI_STORAGE_DIR:-/scratch/pc2-mitarbeiter/papeg/hpc-ci}"
export HPC_CI_PACKAGE_NAME="${HPC_CI_PACKAGE_NAME:-aurora-flow}"
export HPC_CI_PACKAGE_VERSION="${HPC_CI_PACKAGE_VERSION:-1.0.0}"
export AURORA_JULIA_DEPOT="${AURORA_JULIA_DEPOT:-$HPC_CI_STORAGE_DIR/$HPC_CI_PACKAGE_NAME/$HPC_CI_PACKAGE_VERSION/julia-depot}"
mkdir -p "$AURORA_JULIA_DEPOT"
export JULIA_DEPOT_PATH="$AURORA_JULIA_DEPOT"
export JULIA_NUM_THREADS=2
export JULIA_NUM_PRECOMPILE_TASKS=2
export QUARTO_JULIA_PROJECT="$PWD/analysis"
export AURORA_RESULTS_FILE="${AURORA_RESULTS_FILE:-$PWD/collected/hpc-ci-results.json}"

julia --startup-file=no --project=analysis -e 'using Pkg; Pkg.instantiate()'
julia --startup-file=no --project=analysis analysis/test_results.jl
quarto render analysis
test -s analysis/_site/index.html
