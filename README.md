# llama-intel

Run [llama.cpp](https://github.com/ggml-org/llama.cpp) on Intel Arc iGPU
(Arrow Lake) using [ipex-llm](https://github.com/ipex-llm/ipex-llm)'s optimized
SYCL backend — **~2x faster** than upstream llama.cpp SYCL.

## How it works

```
┌──────────────────────────────────────────────────────────────┐
│ llama-intel                                                  │
│                                                              │
│  bin/llama-serve ──┐                                         │
│  bin/llama-chat  ──┼── source env.sh ──> exec ipex-llm/*-bin │
│  bin/llama-bench ──┘       │                    │            │
│                            │                    │            │
│  env.sh:                   │    ipex-llm/:      │            │
│    source setvars.sh       │      llama-server-bin           │
│    set LD_LIBRARY_PATH     │      llama-cli-bin              │
│    set SYCL env vars       │      libggml-sycl.so (fast!)    │
│                            │      libllama.so                │
│  templates/:               │      libsycl.so.8              │
│    qwen3-coder.jinja       │      ... (all deps bundled)     │
└──────────────────────────────────────────────────────────────┘

Models: ~/.cache/llama.cpp/*.gguf (standard GGUF files, any source)
```

**ipex-llm** is a pre-built llama.cpp fork with custom Intel Xe SYCL kernels
(ESIMD linear, XMX-accelerated attention, optimized MUL_MAT). The source is
closed (Intel's private `llm.cpp` repo). The project was archived by Intel in
Jan 2026. We use the last community build (July 2025). It runs any standard GGUF
model.

## Hardware

| Component | Spec |
|-----------|------|
| CPU | Intel Core Ultra 7 255H (16 threads) |
| GPU | Intel Arc Graphics (Arrow Lake-P, Xe-LPG+, integrated) |
| RAM | 32 GB LPDDR5x-8400 (~134 GB/s, shared with GPU) |
| OS | Fedora 43, kernel 6.18+ (xe driver) |

## Prerequisites

- **Intel oneAPI Base Toolkit** — provides `libsycl`, `libmkl`, `libsvml`
  runtime libraries. Install from
  [Intel](https://www.intel.com/content/www/us/en/developer/tools/oneapi/base-toolkit-download.html)
  or `sudo dnf install intel-oneapi-base-toolkit`.
- **ocl-icd** — OpenCL ICD loader: `sudo dnf install ocl-icd`
- **curl** — for downloading the ipex-llm tarball
- **~/.local/bin in PATH** — Fedora's default `.bashrc` already does this

## Quick Start

```bash
git clone https://github.com/dushyant30suthar/llama-intel.git ~/Projects/llama-intel
cd ~/Projects/llama-intel
bash setup.sh
```

This downloads the ipex-llm portable zip (~123 MB) and symlinks launchers into
`~/.local/bin/`. No cmake, no compiling.

## Usage

### Serve a model (web UI + OpenAI API at http://localhost:8080)

```bash
llama-serve -m ~/.cache/llama.cpp/Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf -ngl 99 -c 8192
```

### Chat in terminal

```bash
llama-chat -m ~/.cache/llama.cpp/Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf -ngl 99 -c 8192 -cnv
```

### Benchmark

```bash
llama-bench -m ~/.cache/llama.cpp/Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf -ngl 99
```

### OpenAI-compatible API

```bash
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"any","messages":[{"role":"user","content":"Hello"}]}'
```

### Downloading models

ipex-llm's build lacks CURL support, so `-hf` won't work. Download GGUF files
manually:

```bash
# From HuggingFace (example)
curl -L -o ~/.cache/llama.cpp/Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf \
  "https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/resolve/main/Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf"
```

### Key flags

| Flag | Purpose |
|------|---------|
| `-ngl 99` | Offload all layers to GPU |
| `-c N` | Context size in tokens |
| `-cnv` | Conversation/chat mode (llama-cli only) |
| `-t N` | CPU threads (default: auto) |

## Using with opencode

1. Start `llama-serve` in one terminal (see above)
2. Configure opencode (`~/.config/opencode/opencode.json`):

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "llama": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "llama.cpp (local)",
      "options": {
        "baseURL": "http://localhost:8080/v1"
      },
      "models": {
        "local": {
          "name": "Local Model",
          "limit": {
            "context": 8192,
            "output": 4096
          }
        }
      }
    }
  },
  "model": "llama/local"
}
```

3. Run `opencode` in another terminal

### Tool calling / agent mode

`llama-serve` passes `--jinja` automatically. If a model's built-in chat
template crashes (e.g. Qwen3-Coder's old template uses `.keys()` which the
Jinja engine doesn't support), add a fixed template to `templates/` and pass
it via `--chat-template-file`.

The launcher currently applies `templates/qwen3-coder.jinja` by default. To
use a different model without a custom template, run `llama-server-bin`
directly or edit `bin/llama-serve`.

## Performance expectations

### Why iGPU is slow on large prompts

The iGPU shares LPDDR5x-8400 with the CPU. Max memory bandwidth is ~134 GB/s,
but effective bandwidth is lower due to CPU contention and access patterns. For
each prompt token, the GPU must read the entire model weights. A 7B Q4_K_M
model is ~4.5 GB, so:

- **100 tokens**: 4.5 GB × 100 = 450 GB → ~3-4 seconds
- **1000 tokens**: 4.5 GB × 1000 = 4.5 TB → ~35-45 seconds
- **10000 tokens**: 4.5 GB × 10000 = 45 TB → ~6-8 minutes

Token generation is faster (one token at a time), but large prompt processing is
the bottleneck. This is a hardware limitation, not a software issue.

### Model size recommendations for iGPU

| Use case | Model size | Prompt speed | Generation speed |
|----------|-----------|-------------|-----------------|
| Coding agent (opencode) | 1-4B | Usable | ~30-40 tok/s |
| Interactive chat | 7-8B | Slow on long prompts | ~15-25 tok/s |
| Casual chat | 14-30B | Very slow | ~5-15 tok/s |

For agent/tool use where prompts are 10k+ tokens, **smaller models are faster
end-to-end** even if they're less capable per token.

### ipex-llm vs upstream SYCL

Benchmarks on Intel Arc B580 (7B Q4_K_M):

| Metric | Upstream SYCL | ipex-llm SYCL | Speedup |
|--------|--------------|--------------|---------|
| Prompt (pp512) | 877 tok/s | 2336 tok/s | **2.7x** |
| Generation (tg128) | 36 tok/s | 66 tok/s | **1.8x** |

iGPU numbers will be lower (shared memory), but the relative speedup holds.

## Environment variables

Set by `env.sh` (sourced automatically by launchers):

| Variable | Value | Why |
|----------|-------|-----|
| `SYCL_CACHE_PERSISTENT` | `1` | Cache JIT kernels — first run slow, then fast |
| `SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS` | `1` | Lower GPU submission latency |
| `ZES_ENABLE_SYSMAN` | `1` | GPU memory queries (broken on xe + LZ 1.26, set anyway) |
| `UR_L0_ENABLE_RELAXED_ALLOCATION_LIMITS` | `1` | Allow GPU allocs >4 GB |
| `ONEAPI_DEVICE_SELECTOR` | `level_zero:0` | Select the integrated Arc GPU |
| `LLAMA_CACHE` | `~/.cache/llama.cpp` | Default model directory |

## Models

Stored in `~/.cache/llama.cpp/`:

| Model | Size | Notes |
|-------|------|-------|
| Qwen2.5-Coder-7B-Instruct-Q4_K_M | 4.5 GB | Coding, good for agent use |
| Qwen3-Coder-30B-A3B-Instruct-Q4_K_M | 18 GB | Coding MoE, slow on iGPU |
| NVIDIA-Nemotron-3-Nano-30B-A3B-Q3_K_L | 20 GB | General MoE |
| GLM-4.7-Flash-Q4_K_M | 17 GB | General |
| gpt-oss-20b-MXFP4 | 12 GB | General |
| Ministral-3-14B-Reasoning-2512-Q4_K_M | 8.5 GB | Reasoning |
| rnj-1-instruct-Q4_K_M | 5 GB | Small general |
| Qwen3-VL-4B-Instruct-Q4_K_M | 3.2 GB | Vision-language |
| LFM2.5-1.2B-Instruct-Q8_0 | 1.2 GB | Tiny, fast testing |

## File structure

```
~/Projects/llama-intel/
├── README.md              # This file
├── setup.sh               # One-command setup: downloads ipex-llm, installs launchers
├── env.sh                 # Sourceable env vars (oneAPI + SYCL + LD_LIBRARY_PATH)
├── templates/
│   └── qwen3-coder.jinja  # Fixed Qwen3-Coder chat template (tool calling support)
├── bin/
│   ├── llama-serve        # Launcher: env.sh + llama-server-bin + --jinja
│   ├── llama-chat         # Launcher: env.sh + llama-cli-bin
│   └── llama-bench        # Launcher: env.sh + llama-bench-bin
├── ipex-llm/              # Downloaded by setup.sh (~123 MB, git-ignored)
│   ├── llama-server-bin   # Pre-built llama-server with Intel SYCL optimizations
│   ├── llama-cli-bin      # Pre-built llama-cli
│   ├── llama-bench-bin    # Pre-built llama-bench
│   ├── libggml-sycl.so    # Optimized SYCL kernels (the secret sauce)
│   ├── libllama.so        # llama.cpp core library
│   ├── libsycl.so.8       # Bundled SYCL runtime
│   ├── libmkl_*.so        # Bundled MKL libraries
│   └── ...                # Other bundled dependencies
└── .gitignore
```

## Known issues

- **First run is slow (1-3 min):** SYCL JIT compiles kernels for your GPU.
  Subsequent runs use persistent cache.

- **`-hf` flag doesn't work:** ipex-llm was built without CURL. Download models
  manually with `curl -L -o`.

- **Qwen3-Coder Jinja crash (`Unknown method: keys`):** The GGUF has an old chat
  template. Fixed by `--chat-template-file templates/qwen3-coder.jinja` (the
  launcher does this automatically).

- **`ext_intel_free_memory` warnings:** Harmless. `ZES_ENABLE_SYSMAN` doesn't
  work with LZ 1.26 + xe driver. Always specify `-ngl` explicitly.

- **Flash Attention disabled:** Expected on current SYCL backend for this arch.

- **ipex-llm is archived:** Intel archived the repo Jan 2026. Community fork
  published last builds July 2025. No future updates expected. When upstream
  llama.cpp SYCL catches up in performance, switch to building from source.

## Troubleshooting

**`libsvml.so: cannot open shared object file`**
oneAPI environment not loaded. The launchers handle this automatically. If
running binaries directly, run `source /opt/intel/oneapi/setvars.sh` first.

**`libOpenCL.so.1: cannot open shared object file`**
Install OpenCL ICD loader: `sudo dnf install ocl-icd`

**Segfault on startup**
Delete SYCL cache and retry: `rm -rf ~/.cache/sycl_cache`

**GPU not detected**
Check: `ONEAPI_DEVICE_SELECTOR=level_zero:0` is set, xe driver loaded
(`lsmod | grep xe`).

**Blank output / silent exit**
If `setvars.sh` fails under `set -e`, the script dies silently. The current
`env.sh` handles this with `set +e` around the source call. If you still hit
issues, run `source /opt/intel/oneapi/setvars.sh` manually to see errors.

## Alternatives considered

| Approach | Verdict |
|----------|---------|
| Upstream llama.cpp + SYCL | Works, ~2x slower, but always latest features |
| Upstream llama.cpp + Vulkan | No oneAPI needed, competitive TG speed, worse PP |
| OpenVINO Model Server | Docker-based, validated on ARL-H, actively maintained |
| llama.cpp + OpenVINO backend | Open PR (#15307), not merged yet — watch this |
| ipex-llm .so swap into upstream | ABI incompatible, won't work |
