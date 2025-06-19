#!/usr/bin/env python3
"""
Simple performance test for FocusAI summarization
Tests the optimized chunking and inference speed
"""

import requests
import time
import json

def test_summarization_performance():
    # Read our test document
    with open('test_document.txt', 'r') as f:
        text = f.read()
    
    print(f"📄 Test document: {len(text)} characters, ~{len(text.split())} words")
    
    # Build the prompt (similar to FocusAI's format)
    prompt = f"""<|system|>You are an expert summarization assistant. Create comprehensive, well-structured summaries that capture the main ideas, key arguments, supporting details, and conclusions.<|end|>
<|user|>Please analyze the following text and create a detailed summary:

{text[:8000]}  

Please provide a comprehensive summary:<|end|>
<|assistant|>"""
    
    print(f"🚀 Starting performance test...")
    print(f"📊 Prompt length: {len(prompt)} characters")
    
    # Test the summarization
    start_time = time.time()
    
    try:
        response = requests.post(
            'http://127.0.0.1:8080/completion',
            headers={'Content-Type': 'application/json'},
            json={
                'prompt': prompt,
                'n_predict': 500,
                'temperature': 0.7,
                'top_p': 0.9,
                'repeat_penalty': 1.1,
                'stream': False
            },
            timeout=120  # 2 minute timeout
        )
        
        end_time = time.time()
        duration = end_time - start_time
        
        if response.status_code == 200:
            result = response.json()
            content = result.get('content', '')
            tokens_predicted = result.get('tokens_predicted', 0)
            
            print(f"✅ SUCCESS!")
            print(f"⏱️  Duration: {duration:.2f} seconds")
            print(f"🎯 Tokens generated: {tokens_predicted}")
            print(f"🚄 Speed: {tokens_predicted/duration:.1f} tokens/second")
            print(f"📝 Summary length: {len(content)} characters")
            print(f"\n📖 Generated Summary:")
            print("-" * 50)
            print(content[:500] + "..." if len(content) > 500 else content)
            print("-" * 50)
            
            # Performance evaluation
            if duration < 30:
                print("🎉 EXCELLENT: Under 30 seconds!")
            elif duration < 60:
                print("👍 GOOD: Under 1 minute")
            elif duration < 120:
                print("⚠️  ACCEPTABLE: Under 2 minutes")
            else:
                print("❌ SLOW: Over 2 minutes")
                
        else:
            print(f"❌ Error: {response.status_code}")
            print(response.text)
            
    except requests.exceptions.Timeout:
        print("⏰ TIMEOUT: Request took longer than 2 minutes")
    except Exception as e:
        print(f"❌ ERROR: {e}")

if __name__ == "__main__":
    test_summarization_performance() 