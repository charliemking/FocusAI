#!/bin/bash

echo "🔍 FocusAI Inference Testing Script"
echo "=================================="
echo ""

# Check if the model files exist
echo "📁 Checking model files..."
if [ -f "FocusAI/FocusAI/Resources/Models/phi-3-mini-4k-instruct.gguf" ]; then
    echo "✅ Model file found: $(ls -lh FocusAI/FocusAI/Resources/Models/phi-3-mini-4k-instruct.gguf | awk '{print $5}')"
else
    echo "❌ Model file not found!"
    echo "   Expected: FocusAI/FocusAI/Resources/Models/phi-3-mini-4k-instruct.gguf"
fi

if [ -f "FocusAI/FocusAI/Resources/Binaries/llama-server" ]; then
    echo "✅ Server binary found"
    echo "   Permissions: $(ls -la FocusAI/FocusAI/Resources/Binaries/llama-server | awk '{print $1}')"
else
    echo "❌ Server binary not found!"
    echo "   Expected: FocusAI/FocusAI/Resources/Binaries/llama-server"
fi

echo ""

# Check if the server can start manually
echo "🚀 Testing server startup..."
echo "   (This will start the server and test it manually)"
echo ""

# Check system resources
echo "💻 System Resources:"
echo "   CPU Cores: $(sysctl -n hw.ncpu)"
echo "   Memory: $(sysctl -n hw.memsize | awk '{print $1/1024/1024/1024 " GB"}')"
echo "   Architecture: $(uname -m)"
echo ""

# Offer to run the server manually for testing
read -p "🤔 Do you want to test the server manually? (y/n): " test_server

if [ "$test_server" = "y" ]; then
    echo ""
    echo "📝 Starting server manually..."
    echo "   This will help identify if the server starts correctly"
    echo "   Press Ctrl+C to stop the server when done"
    echo ""
    
    if [ -f "FocusAI/FocusAI/Resources/Binaries/llama-server" ] && [ -f "FocusAI/FocusAI/Resources/Models/phi-3-mini-4k-instruct.gguf" ]; then
        echo "🔧 Server command:"
        echo "   ./FocusAI/FocusAI/Resources/Binaries/llama-server \\"
        echo "     --model FocusAI/FocusAI/Resources/Models/phi-3-mini-4k-instruct.gguf \\"
        echo "     --port 8080 \\"
        echo "     --host 127.0.0.1 \\"
        echo "     --ctx-size 4096 \\"
        echo "     --threads $(sysctl -n hw.ncpu) \\"
        echo "     --n-gpu-layers 0 \\"
        echo "     --verbose"
        echo ""
        
        # Make sure the binary is executable
        chmod +x FocusAI/FocusAI/Resources/Binaries/llama-server
        
        # Start the server
        ./FocusAI/FocusAI/Resources/Binaries/llama-server \
            --model FocusAI/FocusAI/Resources/Models/phi-3-mini-4k-instruct.gguf \
            --port 8080 \
            --host 127.0.0.1 \
            --ctx-size 4096 \
            --threads $(sysctl -n hw.ncpu) \
            --n-gpu-layers 0 \
            --verbose
            
    else
        echo "❌ Cannot start server - missing files!"
    fi
else
    echo ""
    echo "💡 Next steps:"
    echo "   1. Build and run your FocusAI app in Xcode"
    echo "   2. Go to the 'Debug' tab to see diagnostics"
    echo "   3. Run the inference tests to see what's happening"
    echo "   4. Check the server logs for any errors"
    echo ""
    echo "🐛 If you're still getting stub outputs:"
    echo "   - Check if the server is actually starting"
    echo "   - Look for error messages in the logs"
    echo "   - Verify the model file isn't corrupted"
    echo "   - Make sure the server binary has execute permissions"
fi

echo ""
echo "🎯 Remember: The updated code has better diagnostics and logging!"
echo "   Use the Debug tab in your app to see detailed information." 