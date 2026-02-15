# llama-intel environment variables
# Source this file before running llama.cpp binaries with SYCL on Intel Arc GPU

source /opt/intel/oneapi/setvars.sh 2>/dev/null || true

# Disable persistent SYCL cache (segfaults with oneAPI 2025.3)
export SYCL_CACHE_PERSISTENT=0

# Enable GPU memory queries (sysman interface)
export ZES_ENABLE_SYSMAN=1

# Allow single GPU allocations larger than 4 GB
export UR_L0_ENABLE_RELAXED_ALLOCATION_LIMITS=1

# Select the integrated Arc GPU via Level Zero
export ONEAPI_DEVICE_SELECTOR="level_zero:0"

# Default model download/cache directory
export LLAMA_CACHE="$HOME/.cache/llama.cpp"
