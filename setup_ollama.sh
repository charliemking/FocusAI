#!/bin/bash

echo "🚀 FocusAI Ollama Setup Script"
echo "================================"

# Check if Ollama is installed
if ! command -v ollama &> /dev/null; then
    echo "📥 Installing Ollama..."
    curl -fsSL https://ollama.ai/install.sh | sh
    
    if [ $? -ne 0 ]; then
        echo "❌ Failed to install Ollama"
        exit 1
    fi
    
    echo "✅ Ollama installed successfully"
else
    echo "✅ Ollama is already installed"
fi

# Start Ollama service if not running
echo "🔄 Starting Ollama service..."
ollama serve &
OLLAMA_PID=$!

# Wait a moment for the service to start
sleep 3

# Check if Ollama is responding
if curl -s http://localhost:11434/api/tags > /dev/null; then
    echo "✅ Ollama service is running"
else
    echo "❌ Ollama service failed to start"
    exit 1
fi

# Pull the Phi-3 model
echo "📥 Pulling Phi-3 Mini model (this may take a few minutes)..."
ollama pull phi3:mini

if [ $? -eq 0 ]; then
    echo "✅ Phi-3 Mini model downloaded successfully"
else
    echo "❌ Failed to download Phi-3 Mini model"
    exit 1
fi

# Test the model
echo "🧪 Testing model..."
TEST_RESPONSE=$(ollama run phi3:mini "Hello! Please respond with just 'Hi there!'" 2>/dev/null)

if [[ "$TEST_RESPONSE" == *"Hi there"* ]]; then
    echo "✅ Model test successful"
else
    echo "⚠️ Model test may have issues, but continuing..."
fi

echo ""
echo "🎉 Ollama setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Build and run the FocusAI app"
echo "2. The app will automatically use Ollama for AI generation"
echo "3. If you restart your computer, run 'ollama serve' to start the service"
echo ""
echo "💡 Tips:"
echo "- Ollama runs on http://localhost:11434"
echo "- To stop Ollama: kill the ollama process"
echo "- To see available models: ollama list"
echo "- To remove a model: ollama rm phi3:mini"
echo ""
echo "🔧 If you have issues, you can switch to embedded mode by changing"
echo "   the backend parameter in FocusAIApp.swift from .ollama to .embedded" 