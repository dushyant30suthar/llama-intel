#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
IPEX_DIR="$SCRIPT_DIR/ipex-llm"
BIN_DIR="$HOME/.local/bin"

IPEX_VERSION="2.3.0b20250724"
IPEX_TARBALL="llama-cpp-ipex-llm-${IPEX_VERSION}-ubuntu-core.tgz"
IPEX_URL="https://github.com/ipex-llm/ipex-llm/releases/download/v2.3.0-nightly/${IPEX_TARBALL}"

# --- Prerequisites ---
echo "==> Checking prerequisites..."

if [[ ! -f /opt/intel/oneapi/setvars.sh ]]; then
    echo "ERROR: Intel oneAPI not found at /opt/intel/oneapi/setvars.sh" >&2
    echo "       Install oneAPI Base Toolkit: https://www.intel.com/content/www/us/en/developer/tools/oneapi/base-toolkit-download.html" >&2
    exit 1
fi

missing=()
command -v curl >/dev/null || missing+=(curl)
command -v tar  >/dev/null || missing+=(tar)
if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: Missing prerequisites: ${missing[*]}" >&2
    exit 1
fi
echo "    All prerequisites found."

# --- Download ipex-llm portable zip ---
if [[ -d "$IPEX_DIR" ]]; then
    echo "==> ipex-llm already exists at $IPEX_DIR, skipping download."
    echo "    To re-download, run: rm -rf $IPEX_DIR && bash setup.sh"
else
    echo "==> Downloading ipex-llm portable zip ($IPEX_VERSION)..."
    mkdir -p "$IPEX_DIR"
    curl -L --progress-bar "$IPEX_URL" | tar xz -C "$IPEX_DIR" --strip-components=1
    echo "    Extracted to $IPEX_DIR"
fi

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
