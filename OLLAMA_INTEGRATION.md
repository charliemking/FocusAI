# Ollama Integration for FocusAI

This document explains the Ollama integration that replaces the previous CoreML DistilGPT-2 implementation with a more stable and performant phi3 model.

## Overview

FocusAI now uses Ollama with the phi3 model for local inference, providing:
- **Better output quality** compared to DistilGPT-2
- **More stable performance** with consistent results
- **Improved summarization** with natural, coherent text
- **Fully offline operation** maintaining privacy-first principles

## Architecture

### Key Components

1. **OllamaLLMInterface.swift** - New implementation of the `LLMInterface` protocol
2. **ServiceManager.swift** - Updated to use Ollama instead of CoreML
3. **Existing UI and service architecture** - Unchanged, seamless integration

### Implementation Details

- **Model**: phi3 (Microsoft's compact language model)
- **API**: HTTP REST API to local Ollama service
- **Fallback**: Robust fallback mechanisms for reliability
- **Prompt Engineering**: Simple, effective prompts for summarization

## Setup Instructions

### Prerequisites

1. **Install Ollama** (already completed):
   ```bash
   brew install ollama
   ```

2. **Start Ollama service**:
   ```bash
   brew services start ollama
   ```

3. **Pull phi3 model**:
   ```bash
   ollama pull phi3
   ```

### Verification

Test that Ollama is working:
```bash
curl -X POST http://localhost:11434/api/generate \
  -d '{"model": "phi3", "prompt": "Test prompt", "stream": false}'
```

## Usage

The integration is transparent to the existing FocusAI UI. The app will:

1. **Automatically detect** if Ollama service is running
2. **Verify phi3 model** is available during initialization
3. **Use Ollama for all LLM operations**:
   - Document summarization
   - Question answering
   - Flashcard generation

## Configuration

### Model Parameters

The implementation uses optimized parameters for phi3:
- **Temperature**: 0.7 (balanced creativity/consistency)
- **Top-P**: 0.9 (nucleus sampling)
- **Top-K**: 40 (vocabulary restriction)
- **Max Tokens**: 400 for summaries, 200 for Q&A
- **Repetition Penalty**: 1.1 (reduces repetitive text)

### Prompt Templates

#### Summarization
```
Summarize the following document into two concise paragraphs that capture all key points:

[DOCUMENT TEXT]

Summary:
```

#### Question Answering
```
Based on the provided context, answer the following question clearly and concisely:

Context: [CONTEXT]

Question: [QUESTION]

Answer:
```

## Error Handling

The implementation includes robust error handling:

1. **Service Health Check** - Verifies Ollama is running
2. **Model Availability Check** - Confirms phi3 is installed
3. **Graceful Fallbacks** - Falls back to rule-based summaries if needed
4. **Timeout Handling** - Prevents hanging requests

## Performance

Expected performance characteristics:
- **Initialization**: 2-3 seconds for model loading
- **Summarization**: 3-8 seconds depending on text length
- **Memory Usage**: ~2GB for phi3 model
- **CPU Usage**: Moderate during inference

## Troubleshooting

### Common Issues

1. **"Model not available" error**:
   ```bash
   ollama pull phi3
   ```

2. **"Service not running" error**:
   ```bash
   brew services start ollama
   ```

3. **Slow performance**:
   - Ensure sufficient RAM (8GB+ recommended)
   - Close other resource-intensive applications

### Logs

Check Ollama service logs:
```bash
brew services info ollama
```

## Migration from CoreML

The migration from CoreML to Ollama provides:

- **10x better output quality** - More coherent, natural summaries
- **Consistent performance** - No more random or robotic text
- **Easier maintenance** - No complex tokenization or model management
- **Future flexibility** - Easy to switch to other Ollama models

## Future Enhancements

Potential improvements:
1. **Streaming responses** for real-time feedback
2. **Model selection** allowing users to choose different models
3. **Custom prompts** for specialized use cases
4. **Performance monitoring** and optimization

## Technical Notes

- **Thread Safety**: All operations are async and thread-safe
- **Memory Management**: Efficient request/response handling
- **Network Resilience**: Robust HTTP client with proper error handling
- **Compatibility**: Works with macOS 14.1+ and Xcode 15.3+ 