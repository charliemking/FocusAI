#!/usr/bin/env python3
"""
Performance test for FocusAI optimizations
Tests the new aggressive speed optimizations
"""

import requests
import time
import json

def test_optimized_performance():
    print("🚀 Testing Super-Optimized FocusAI Performance")
    print("=" * 50)
    
    # Load test document
    with open('test_document.txt', 'r') as f:
        test_text = f.read()
    
    print(f"📄 Document length: {len(test_text)} characters")
    
    # Test 1: Super short prompt (optimized)
    print("\n🔥 Test 1: Maximum Speed Optimization")
    start_time = time.time()
    
    try:
        response = requests.post('http://127.0.0.1:8080/completion', 
            json={
                "prompt": f"<|system|>Summarize briefly.<|end|>\n<|user|>{test_text[:1500]}\n\nSummary:<|end|>\n<|assistant|>",
                "n_predict": 150,  # Even shorter response
                "temperature": 0.4,  # Lower temperature
                "top_p": 0.7,      # Lower top-p
                "top_k": 15,       # Smaller top-k
                "repeat_penalty": 1.02,  # Lower penalty
                "stream": False,
                "stop": ["<|end|>", "<|user|>"]
            },
            timeout=45  # Shorter timeout
        )
        
        if response.status_code == 200:
            result = response.json()
            content = result.get('content', '')
            duration = time.time() - start_time
            
            print(f"✅ SUCCESS: {duration:.2f} seconds")
            print(f"📝 Response length: {len(content)} chars")
            print(f"🎯 Response preview: {content[:100]}...")
            
            # Calculate speed improvement
            original_time = 180  # 3 minutes original
            improvement = original_time / duration
            print(f"🚀 Speed improvement: {improvement:.1f}x faster than original!")
            
        else:
            print(f"❌ HTTP Error: {response.status_code}")
            print(f"Response: {response.text}")
            
    except requests.exceptions.Timeout:
        duration = time.time() - start_time
        print(f"⏰ TIMEOUT after {duration:.2f} seconds")
    except Exception as e:
        duration = time.time() - start_time
        print(f"❌ ERROR after {duration:.2f} seconds: {e}")
    
    # Test 2: Micro document test (ultra-fast)
    print("\n⚡ Test 2: Micro Document (Ultra-Fast)")
    micro_text = test_text[:800]  # Very small text
    start_time = time.time()
    
    try:
        response = requests.post('http://127.0.0.1:8080/completion', 
            json={
                "prompt": f"<|system|>Brief summary:<|end|>\n<|user|>{micro_text}<|end|>\n<|assistant|>",
                "n_predict": 100,
                "temperature": 0.3,
                "top_p": 0.6,
                "top_k": 10,
                "repeat_penalty": 1.01,
                "stream": False,
                "stop": ["<|end|>", "<|user|>"]
            },
            timeout=30
        )
        
        if response.status_code == 200:
            result = response.json()
            content = result.get('content', '')
            duration = time.time() - start_time
            
            print(f"✅ SUCCESS: {duration:.2f} seconds")
            print(f"📝 Response: {content.strip()}")
            
            if duration < 15:
                print("🎉 EXCELLENT: Under 15 seconds!")
            elif duration < 30:
                print("👍 GOOD: Under 30 seconds!")
            else:
                print("⚠️ SLOW: Over 30 seconds")
                
        else:
            print(f"❌ HTTP Error: {response.status_code}")
            
    except Exception as e:
        duration = time.time() - start_time
        print(f"❌ ERROR after {duration:.2f} seconds: {e}")
    
    print("\n" + "=" * 50)
    print("🎯 Target: Under 30 seconds for most documents")
    print("🚀 Goal: 4-6x faster than original 3-minute processing")

if __name__ == "__main__":
    # Check if server is running
    try:
        response = requests.get('http://127.0.0.1:8080/health', timeout=5)
        if response.status_code == 200:
            test_optimized_performance()
        else:
            print("❌ Server not responding properly")
    except:
        print("❌ Server not running on port 8080")
        print("💡 Please start FocusAI app first!") 