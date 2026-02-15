#!/usr/bin/env bash
set -euo pipefail

LLAMA_DIR="${LLAMA_DIR:-$HOME/Applications/llama.cpp}"
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

echo "==> Sourcing oneAPI environment..."
source /opt/intel/oneapi/setvars.sh 2>/dev/null || {
    echo "ERROR: Failed to source oneAPI setvars.sh" >&2
    exit 1
}

echo "==> Configuring cmake..."
cmake "$LLAMA_DIR" -B "$LLAMA_DIR/build" \
    -DGGML_SYCL=ON \
    -DGGML_SYCL_TARGET=INTEL \
    -DGGML_AVX2=ON \
    -DGGML_FMA=ON \
    -DGGML_F16C=ON \
    -DGGML_AVX_VNNI=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=icx \
    -DCMAKE_CXX_COMPILER=icpx

echo "==> Building with $(nproc) threads..."
cmake --build "$LLAMA_DIR/build" --config Release -j"$(nproc)"

echo "==> Build complete."
echo "    Binaries are in $LLAMA_DIR/build/bin/"
