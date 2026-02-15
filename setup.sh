#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
LLAMA_DIR="${LLAMA_DIR:-$HOME/Applications/llama.cpp}"
BIN_DIR="$HOME/.local/bin"

# --- Prerequisites ---
echo "==> Checking prerequisites..."

missing=()
command -v git   >/dev/null || missing+=(git)
command -v cmake >/dev/null || missing+=(cmake)
command -v icx   >/dev/null && command -v icpx >/dev/null || {
    # Try sourcing oneAPI first
    if [[ -f /opt/intel/oneapi/setvars.sh ]]; then
        source /opt/intel/oneapi/setvars.sh 2>/dev/null || true
        command -v icx  >/dev/null || missing+=(icx)
        command -v icpx >/dev/null || missing+=(icpx)
    else
        echo "ERROR: Intel oneAPI not found at /opt/intel/oneapi/setvars.sh" >&2
        echo "       Install oneAPI Base Toolkit: https://www.intel.com/content/www/us/en/developer/tools/oneapi/base-toolkit-download.html" >&2
        exit 1
    fi
}

if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: Missing prerequisites: ${missing[*]}" >&2
    exit 1
fi
echo "    All prerequisites found."

# --- Clone llama.cpp ---
if [[ -d "$LLAMA_DIR" ]]; then
    echo "==> llama.cpp already exists at $LLAMA_DIR, skipping clone."
else
    echo "==> Cloning llama.cpp to $LLAMA_DIR..."
    git clone https://github.com/ggml-org/llama.cpp.git "$LLAMA_DIR"
fi

# --- Build ---
echo "==> Running build..."
LLAMA_DIR="$LLAMA_DIR" bash "$SCRIPT_DIR/build.sh"

# --- Install launchers ---
echo "==> Symlinking launchers into $BIN_DIR..."
mkdir -p "$BIN_DIR"

for launcher in "$SCRIPT_DIR"/bin/llama-*; do
    name="$(basename "$launcher")"
    ln -sf "$launcher" "$BIN_DIR/$name"
    echo "    $BIN_DIR/$name -> $launcher"
done

echo ""
echo "==> Setup complete!"
echo ""
echo "    Make sure ~/.local/bin is in your PATH, then try:"
echo ""
echo "    llama-serve -m ~/.cache/llama.cpp/Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf -ngl 99 -c 8192"
echo "    llama-chat  -m ~/.cache/llama.cpp/Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf -ngl 99 -c 8192 -cnv"
echo "    llama-bench -m ~/.cache/llama.cpp/Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf -ngl 99"
