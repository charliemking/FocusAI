# FocusAI

I'm building FocusAI, a privacy-first macOS study assistant written in Swift. It summarizes PDFs, generates flashcards, and 
answers questions—all locally on-device. Designed for students like me, it offers offline functionality, user 
privacy, and a distraction-free experience. This is an ongoing personal project inspired by my interest in usable, ethical AI.

## ✨ Features

- **📄 Document Processing**: Upload PDFs, paste text, or load web pages
- **🤖 AI Summarization**: Get comprehensive summaries using local AI
- **🃏 Flashcard Generation**: Automatically create study flashcards
- **❓ Question Answering**: Ask questions about your documents
- **🔒 Complete Privacy**: Everything runs locally on your Mac
- **⚡ Optimized Performance**: Smart chunking and parallel processing for speed

## 🖥️ System Requirements

- macOS 11.0 or later
- Apple Silicon (M1/M2/M3) or Intel Mac
- 8GB+ RAM recommended (16GB+ for best performance)
- ~3GB storage space for the embedded model

## 🔧 Installation

1. Download the latest release from GitHub
2. Run the setup script to download the AI model:
   ```bash
   ./setup_embedded_llm.sh
   ./setup_ollama.sh
   ```
3. Open FocusAI.xcodeproj in Xcode
4. Build and run the application

## 💡 Usage

1. **Load a Document**: Choose PDF, Text, or URL tab
2. **Wait for Processing**: The AI will analyze your content
3. **Review Results**: Get summaries, flashcards, and ask questions
4. **Study Efficiently**: Use the generated materials for learning

## 🔍 Performance Tips

- **For best speed**: Use documents under 2000 characters when possible
- **For large documents**: The app automatically uses smart chunking
- **Monitor performance**: Check the Diagnostics tab for speed metrics
- **Thermal safety**: The app is configured to avoid overheating your Mac

## 🛠️ Technical Details

- **AI Model**: Phi-3-mini-4k-instruct (Q4_K_M quantized)
- **Inference Engine**: llama.cpp (CPU-optimized build)
- **Framework**: SwiftUI with async/await
- **Privacy**: 100% on-device processing, no network required

## 📊 Benchmarks

Typical performance on M2 MacBook Pro (16GB RAM):
- **Small text** (500 words): 8-15 seconds
- **Medium PDF** (1000 words): 20-40 seconds  
- **Large document** (3000+ words): 45-90 seconds (chunked)
- **Tokens per second**: 15-25 tok/s (CPU-only)

## 🔒 Privacy & Security

- **No data leaves your device** - everything runs locally
- **No internet required** after initial setup
- **No tracking or analytics**
- **Your documents stay private**

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Note**: FocusAI prioritizes thermal safety and will not stress your hardware. All optimizations are designed to be fast while keeping your Mac cool and stable. 

---

## 🚀 Performance Optimizations (NEW!)

FocusAI now includes several performance optimizations to make summarization **significantly faster**:

### ⚡ CPU-Optimized Inference
- **Conservative threading** to prevent overheating (uses only performance cores)
- **NO GPU acceleration** for thermal safety (your computer won't overheat!)
- **Larger batch sizes** (1024) for better CPU efficiency
- **Prompt caching** enabled for repeated queries
- **Memory optimization** with larger context windows when RAM allows

### 🔪 Smart Document Chunking
- **Automatic chunking** for documents >2000 characters
- **Parallel processing** of chunks for faster results
- **Map-reduce approach**: summarize sections, then combine
- **Intelligent splitting** by paragraphs and sentences

### 📝 Text Preprocessing
- **Token optimization** by removing PDF artifacts (page numbers, URLs)
- **Whitespace cleanup** to reduce unnecessary tokens
- **Faster prompts** with streamlined templates

### 📊 Performance Monitoring
- **Real-time metrics** tracking inference speed
- **Tokens per second** measurement
- **Performance reports** in diagnostics

### Expected Speed Improvements:
- **Small documents** (<2K chars): ~30-50% faster
- **Large documents** (>2K chars): ~60-80% faster via chunking
- **Typical 1000-word PDF**: From 2+ minutes → **20-40 seconds**
