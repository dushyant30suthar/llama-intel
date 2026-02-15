# llama-intel environment variables
# Source this file before running llama.cpp binaries with SYCL on Intel Arc GPU

IPEX_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/ipex-llm"

# Save positional params — setvars.sh reads "$@" from the calling script
_llama_args=("$@")
set --
set +e
source /opt/intel/oneapi/setvars.sh &>/dev/null
set -e
set -- "${_llama_args[@]}"
unset _llama_args

# ipex-llm bundled libraries (libggml-sycl.so, libllama.so, etc.)
export LD_LIBRARY_PATH="${IPEX_DIR}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# Enable persistent SYCL cache (ipex-llm handles the oneAPI bug)
export SYCL_CACHE_PERSISTENT=1

# Use immediate command lists for lower GPU submission latency
export SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS=1

# Enable GPU memory queries (sysman interface)
export ZES_ENABLE_SYSMAN=1

# Allow single GPU allocations larger than 4 GB
export UR_L0_ENABLE_RELAXED_ALLOCATION_LIMITS=1

# Select the integrated Arc GPU via Level Zero
export ONEAPI_DEVICE_SELECTOR="level_zero:0"

# Default model download/cache directory
export LLAMA_CACHE="$HOME/.cache/llama.cpp"
