# llama-intel

One-command setup for running [llama.cpp](https://github.com/ggml-org/llama.cpp)
on Intel Arc iGPUs (Arrow Lake) with SYCL.

## Hardware

- **CPU:** Intel Core Ultra 7 255H (16 threads)
- **GPU:** Intel Arc Graphics (Arrow Lake-P integrated, Xe-LPG+)
- **RAM:** 32 GB shared with GPU
- **OS:** Fedora 43, kernel 6.18+ (xe driver)

## Prerequisites

- [Intel oneAPI Base Toolkit](https://www.intel.com/content/www/us/en/developer/tools/oneapi/base-toolkit-download.html) (`icx`, `icpx` compilers)
- `cmake`, `git`
- `~/.local/bin` in your `PATH`

## Quick Start

```bash
git clone https://github.com/dushyantsutharsl/llama-intel.git ~/Projects/llama-intel
cd ~/Projects/llama-intel
bash setup.sh
```

This will:
1. Clone llama.cpp to `~/Applications/llama.cpp`
2. Build with SYCL + Intel GPU support
3. Symlink `llama-serve`, `llama-chat`, `llama-bench` into `~/.local/bin/`

## Build

To rebuild after a `git pull` in llama.cpp:

```bash
bash build.sh
```

For a clean rebuild, delete the build directory first:

```bash
rm -rf ~/Applications/llama.cpp/build
bash build.sh
```

### Build Flags

The Intel compiler (`icpx`) doesn't auto-detect CPU features like GCC does,
even with `GGML_NATIVE=ON`. The build explicitly enables:

| Flag | Purpose |
|------|---------|
| `GGML_SYCL=ON` | SYCL backend for Intel GPU |
| `GGML_AVX2=ON` | AVX2 instructions |
| `GGML_FMA=ON` | Fused multiply-add |
| `GGML_F16C=ON` | Half-precision float conversion |
| `GGML_AVX_VNNI=ON` | Vector Neural Network Instructions |

## Usage

**Serve a model (web UI at http://localhost:8080):**
```bash
llama-serve -m ~/.cache/llama.cpp/Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf -ngl 99 -c 8192
```

**Download from HuggingFace directly:**
```bash
llama-serve -hf bartowski/Qwen3-Coder-30B-A3B-Instruct-GGUF:Q4_K_M -ngl 99 -c 8192
```

**Chat in terminal:**
```bash
llama-chat -m ~/.cache/llama.cpp/Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf -ngl 99 -c 8192 -cnv
```

**Benchmark:**
```bash
llama-bench -m ~/.cache/llama.cpp/Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf -ngl 99
```

**OpenAI-compatible API (while server is running):**
```bash
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"any","messages":[{"role":"user","content":"Hello"}]}'
```

### Key Flags

| Flag | Purpose |
|------|---------|
| `-ngl 99` | Offload all layers to GPU |
| `-c 8192` | Context size in tokens |
| `-cnv` | Conversation/chat mode (llama-cli only) |
| `-hf repo:quant` | Download model from HuggingFace |
| `-t N` | CPU threads (default: auto) |

## Environment Variables

Set by `env.sh` (sourced automatically by the launchers):

| Variable | Value | Why |
|----------|-------|-----|
| `SYCL_CACHE_PERSISTENT` | `0` | `=1` segfaults with oneAPI 2025.3 (`PersistentDeviceCodeCache` bug) |
| `ZES_ENABLE_SYSMAN` | `1` | Enables GPU memory queries (broken on xe driver + Level Zero 1.26, but set anyway) |
| `UR_L0_ENABLE_RELAXED_ALLOCATION_LIMITS` | `1` | Allow single GPU allocations >4 GB |
| `ONEAPI_DEVICE_SELECTOR` | `level_zero:0` | Select the integrated Arc GPU |
| `LLAMA_CACHE` | `~/.cache/llama.cpp` | Default model download directory |

## Models

Stored in `~/.cache/llama.cpp/`:

| Model | Size | Notes |
|-------|------|-------|
| Qwen3-Coder-30B-A3B-Instruct-Q4_K_M | 18 GB | Coding, MoE 128 experts / 8 active |
| NVIDIA-Nemotron-3-Nano-30B-A3B-Q3_K_L | 20 GB | General, MoE |
| GLM-4.7-Flash-Q4_K_M | 17 GB | General |
| gpt-oss-20b-MXFP4 | 12 GB | General |
| Ministral-3-14B-Reasoning-2512-Q4_K_M | 8.5 GB | Reasoning |
| rnj-1-instruct-Q4_K_M | 5 GB | Small general |
| Qwen3-VL-4B-Instruct-Q4_K_M | 3.2 GB | Vision-language |
| LFM2.5-1.2B-Instruct-Q8_0 | 1.2 GB | Tiny, fast testing |

## Known Issues

- **`ext_intel_free_memory` warnings:** `ZES_ENABLE_SYSMAN` doesn't work with
  Level Zero 1.26 + xe kernel driver. llama.cpp falls back to reporting total
  system RAM as free GPU memory. Harmless but means `-ngl` auto-fitting is
  unreliable — always specify `-ngl` explicitly.

- **Flash Attention disabled on SYCL:** "Flash Attention tensor is assigned to
  device CPU" — expected on the current SYCL backend for this architecture.

- **oneAPI setvars.sh required:** Without it, binaries fail with
  `libsvml.so: cannot open shared object file`. The launchers handle this
  automatically.

## Troubleshooting

**Binary fails with `libsvml.so: cannot open shared object file`**
The oneAPI environment isn't set. Use the launchers (`llama-serve`, etc.) which
source `env.sh` automatically, or run `source /opt/intel/oneapi/setvars.sh`
manually.

**Segfault on startup**
Check that `SYCL_CACHE_PERSISTENT=0` is set. The persistent cache has a known
bug in oneAPI 2025.3.

**Build fails with "icx: command not found"**
Install the Intel oneAPI Base Toolkit and ensure `setvars.sh` has been sourced
before building.

**GPU not detected / "no devices found"**
Verify `ONEAPI_DEVICE_SELECTOR=level_zero:0` is set and that the xe kernel
driver is loaded (`lsmod | grep xe`).
