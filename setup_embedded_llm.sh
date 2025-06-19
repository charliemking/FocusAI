#!/bin/bash

# FocusAI Embedded LLM Setup Script
# This script downloads and prepares the Phi-3 model and llama.cpp server
# for embedding in the macOS app bundle.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
LLAMA_CPP_VERSION="b3601"
PHI3_MODEL_NAME="phi-3-mini-4k-instruct-q4.gguf"
RESOURCES_DIR="FocusAI/FocusAI/Resources"
BINARIES_DIR="$RESOURCES_DIR/Binaries"
MODELS_DIR="$RESOURCES_DIR/Models"

echo -e "${BLUE}🚀 FocusAI Embedded LLM Setup${NC}"
echo "================================="

# Create directories
echo -e "${YELLOW}📁 Creating directories...${NC}"
mkdir -p "$BINARIES_DIR"
mkdir -p "$MODELS_DIR"

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}❌ This script must be run on macOS${NC}"
    exit 1
fi

# Function to download with progress
download_with_progress() {
    local url=$1
    local output=$2
    local description=$3
    
    echo -e "${YELLOW}⬇️  Downloading $description...${NC}"
    curl -L --progress-bar "$url" -o "$output"
}

# Download llama.cpp pre-built binary for macOS
echo -e "${BLUE}🔧 Setting up llama.cpp server...${NC}"

# Check if we need to build llama.cpp or download pre-built
if command -v cmake &> /dev/null && command -v make &> /dev/null; then
    echo -e "${YELLOW}🛠️  Building llama.cpp from source...${NC}"
    
    # Clone llama.cpp if not exists
    if [ ! -d "llama.cpp" ]; then
        git clone https://github.com/ggerganov/llama.cpp.git
    fi
    
    cd llama.cpp
    git checkout "$LLAMA_CPP_VERSION"
    
    # Build with optimizations for macOS
    cmake -B build -DLLAMA_METAL=OFF -DLLAMA_ACCELERATE=ON -DCMAKE_BUILD_TYPE=Release
    cmake --build build --config Release --target llama-server
    
    # Copy the built binary
    cp build/bin/llama-server "../$BINARIES_DIR/"
    cd ..
    
    echo -e "${GREEN}✅ Built llama.cpp server successfully${NC}"
else
    echo -e "${YELLOW}⚠️  CMake/Make not found. Please install Xcode Command Line Tools:${NC}"
    echo "xcode-select --install"
    echo
    echo "Or download a pre-built binary manually and place it at:"
    echo "$BINARIES_DIR/llama-server"
    echo
    echo "You can get pre-built binaries from:"
    echo "https://github.com/ggerganov/llama.cpp/releases"
    exit 1
fi

# Download Phi-3 model
echo -e "${BLUE}🤖 Downloading Phi-3 model...${NC}"

# Check if model already exists
if [ -f "$MODELS_DIR/$PHI3_MODEL_NAME" ]; then
    echo -e "${GREEN}✅ Phi-3 model already exists${NC}"
else
    # Download from Hugging Face
    PHI3_URL="https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf"
    download_with_progress "$PHI3_URL" "$MODELS_DIR/$PHI3_MODEL_NAME" "Phi-3 model (Q4 quantized)"
    echo -e "${GREEN}✅ Downloaded Phi-3 model successfully${NC}"
fi

# Verify files
echo -e "${BLUE}🔍 Verifying files...${NC}"

if [ ! -f "$BINARIES_DIR/llama-server" ]; then
    echo -e "${RED}❌ llama-server binary not found${NC}"
    exit 1
fi

if [ ! -f "$MODELS_DIR/$PHI3_MODEL_NAME" ]; then
    echo -e "${RED}❌ Phi-3 model not found${NC}"
    exit 1
fi

# Make binary executable
chmod +x "$BINARIES_DIR/llama-server"

# Get file sizes
SERVER_SIZE=$(du -h "$BINARIES_DIR/llama-server" | cut -f1)
MODEL_SIZE=$(du -h "$MODELS_DIR/$PHI3_MODEL_NAME" | cut -f1)

echo -e "${GREEN}✅ All files verified:${NC}"
echo "   • llama-server: $SERVER_SIZE"
echo "   • Phi-3 model: $MODEL_SIZE"

# Create licensing information
echo -e "${BLUE}📄 Creating license information...${NC}"

cat > "$RESOURCES_DIR/LICENSES.md" << 'EOF'
# Third-Party Licenses

## Phi-3 Model
- **Source**: Microsoft Corporation
- **License**: MIT License
- **URL**: https://github.com/microsoft/Phi-3-mini
- **Description**: Phi-3-mini-4k-instruct language model

### MIT License (Phi-3)
Copyright (c) Microsoft Corporation.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## llama.cpp
- **Source**: Georgi Gerganov and contributors
- **License**: MIT License
- **URL**: https://github.com/ggerganov/llama.cpp
- **Description**: LLM inference engine

### MIT License (llama.cpp)
Copyright (c) 2023 Georgi Gerganov

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

echo -e "${GREEN}✅ Created license information${NC}"

# Update entitlements for subprocess execution
echo -e "${BLUE}🔐 Updating entitlements...${NC}"

# The existing entitlements should be updated to allow subprocess execution
cat > "FocusAI/FocusAI/FocusAI.entitlements" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-only</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
EOF

echo -e "${GREEN}✅ Updated entitlements${NC}"

# Create Info.plist addition for bundle resources
echo -e "${BLUE}📋 Creating bundle configuration...${NC}"

cat > "$RESOURCES_DIR/bundle_info.txt" << EOF
# Add these resources to your Xcode project:

## Files to add to "Copy Bundle Resources":
1. Resources/Models/phi-3-mini-4k-instruct-q4.gguf
2. Resources/Binaries/llama-server  
3. Resources/LICENSES.md

## Xcode Build Settings:
- Set "Other Linker Flags" to include: -sectcreate __TEXT __info_plist Info.plist
- Ensure "Bundle Resources" includes all model and binary files
- Set executable permissions on llama-server in build phases

## Code Signing:
- The embedded binary will be signed with your app
- Entitlements allow subprocess execution
- No additional provisioning needed for local execution
EOF

echo
echo -e "${GREEN}🎉 Setup completed successfully!${NC}"
echo
echo -e "${YELLOW}📋 Next steps:${NC}"
echo "1. Add the Resources folder to your Xcode project"
echo "2. Ensure files are added to 'Copy Bundle Resources'"
echo "3. Update your project to use EmbeddedLLMInterface"
echo "4. Test the embedded model locally"
echo "5. Build and sign for distribution"
echo
echo -e "${BLUE}📊 Bundle size impact:${NC}"
echo "   • Binary: $SERVER_SIZE"
echo "   • Model: $MODEL_SIZE"
echo "   • Total additional size: ~2.5GB"
echo
echo -e "${YELLOW}⚠️  Important notes:${NC}"
echo "• The large model size may affect App Store review time"
echo "• Consider offering model download as optional for smaller initial size"
echo "• Test thoroughly on different Mac configurations"
echo "• Ensure you comply with both MIT licenses in your app's credits" 