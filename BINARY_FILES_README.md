# Binary Files Setup

Due to GitHub's file size limitations, the following large binary files are not included in this repository:

## Required Files

### Model File
- **Location**: `FocusAI/Resources/Models/phi-3-mini-4k-instruct.gguf` (2.2GB)
- **Download**: Get from Hugging Face: `microsoft/Phi-3-mini-4K-instruct-gguf`
- **Alternative**: Use the setup script: `./setup_embedded_llm.sh`

### Dynamic Libraries
- **Location**: `FocusAI/Resources/Libraries/`
- **Files**:
  - `libggml.dylib`
  - `libmtmd.dylib`
  - `libggml-base.dylib`
  - `libggml-blas.dylib`
  - `libllama.dylib`
  - `libggml-cpu.dylib`
  - `libggml-metal.dylib`
- **Source**: Built from llama.cpp repository
- **Alternative**: Use the setup script: `./setup_embedded_llm.sh`

### Server Binary
- **Location**: `FocusAI/Resources/Binaries/llama-server`
- **Source**: Built from llama.cpp repository
- **Alternative**: Use the setup script: `./setup_embedded_llm.sh`

## Setup Instructions

1. **Automated Setup** (Recommended):
   ```bash
   ./setup_embedded_llm.sh
   ```

2. **Manual Setup**:
   - Download the model from Hugging Face
   - Build llama.cpp and copy the required files
   - Ensure all files are in the correct locations as listed above

## Verification

After setup, verify the files exist:
```bash
ls -la FocusAI/Resources/Models/
ls -la FocusAI/Resources/Libraries/
ls -la FocusAI/Resources/Binaries/
```

The app will not function without these binary files. 