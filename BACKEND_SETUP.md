# 🏪 MAC APP STORE BUNDLING GUIDE

## 🎯 **Perfect Model Choice: DistilGPT-2**

For your FocusAI Mac App Store distribution, **DistilGPT-2** is the ideal choice:

### **Why DistilGPT-2?**
- ✅ **Size**: ~350MB (fits perfectly in 4GB App Store limit)  
- ✅ **Pre-built**: Available as ready-to-use CoreML model
- ✅ **Fast**: Optimized for Apple Silicon Neural Engine
- ✅ **Quality**: Excellent text generation for summaries/flashcards
- ✅ **Memory**: Works on 8GB+ Macs without issues

### **Download & Setup Instructions:**

1. **Download the Model**:
   ```bash
   # Download DistilGPT-2 CoreML model
   curl -L "https://huggingface.co/distilbert/distilgpt2/resolve/main/coreml/text-generation/float32_model.mlpackage.zip" -o distilgpt2.zip
   
   # Extract the model
   unzip distilgpt2.zip
   
   # The extracted folder should be named "float32_model.mlpackage"
   # Rename it to "distilgpt2.mlpackage" for consistency
   mv float32_model.mlpackage distilgpt2.mlpackage
   ```

2. **Add to Xcode Project**:
   - Open your FocusAI project in Xcode
   - Drag `distilgpt2.mlpackage` into your project
   - ✅ Check "Add to target: FocusAI"
   - ✅ Check "Copy items if needed"
   - Rename to `distilgpt2.mlpackage` for consistency

3. **Update Your Code**: 

# FocusAI Backend Setup Guide

## Overview
FocusAI uses a sophisticated backend architecture with both **stub services** (for development/demo) and **CoreML integration** (for local AI inference). This guide covers setup, configuration, and troubleshooting.

## Quick Start

### 1. **Download CoreML Model (Required for AI Features)**
The DistilGPT-2 CoreML model is too large for GitHub (459MB). Download it separately:

```bash
# Option 1: Download from Hugging Face
curl -L "https://huggingface.co/apple/DistilGPT2-CoreML/resolve/main/distilgpt2.mlmodel" -o "FocusAI/FocusAI/distilgpt2.mlmodel"

# Option 2: Use Python to convert from Hugging Face
pip install transformers coremltools
python3 -c "
from transformers import GPT2LMHeadModel, GPT2Tokenizer
import coremltools as ct
model = GPT2LMHeadModel.from_pretrained('distilgpt2')
# Convert to CoreML (requires additional setup)
"
```

**Note**: If you can't download the model, the app will work perfectly with stub services by default.

### 2. **Choose Your Backend Mode**