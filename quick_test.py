#!/usr/bin/env python3
"""
Quick test for optimized FocusAI performance
Tests the new shorter prompts and chunking strategy
"""

import requests
import time
import json

def test_short_prompt_performance():
    # Test with a shorter, optimized prompt similar to our new implementation
    short_text = """
    Artificial Intelligence has evolved from science fiction to reality. Early development began in the 1940s with Alan Turing's work. The term was coined in 1956 at the Dartmouth Conference. Modern AI includes machine learning, neural networks, and deep learning. Applications span healthcare, finance, transportation, and entertainment. Recent breakthroughs in large language models have revolutionized natural language processing.
    """
    
    print(f"📄 Testing with shorter text: {len(short_text)} characters")
    
    # Optimized prompt (much shorter like our new implementation)
    prompt = f"""<|system|>Create a comprehensive summary.<|end|>
<|user|>{short_text}

Summary:<|end|>
<|assistant|>"""
    
    print("🚀 Testing optimized short prompt...")
    start_time = time.time()
    
    try:
        response = requests.post(
            'http://127.0.0.1:8080/completion',
            json={
                'prompt': prompt,
                'n_predict': 100,  # Reduced tokens like our optimization
                'temperature': 0.7,
                'top_p': 0.9,
                'repeat_penalty': 1.1,
                'stream': False
            },
            timeout=120
        )
        
        duration = time.time() - start_time
        
        if response.status_code == 200:
            result = response.json()
            content = result.get('content', '')
            print(f"✅ SUCCESS! Duration: {duration:.2f}s")
            print(f"📊 Speed: {len(content.split()) / duration:.1f} words/second")
            print(f"📝 Response: {content[:200]}...")
            return duration
        else:
            print(f"❌ Error: {response.status_code}")
            return None
            
    except Exception as e:
        print(f"❌ Request failed: {e}")
        return None

def test_chunking_simulation():
    # Simulate our chunking approach with multiple small requests
    print("\n🔪 Testing chunking simulation (multiple small requests)...")
    
    chunks = [
        "AI history began in the 1940s with Alan Turing's foundational work on machine intelligence.",
        "The 1956 Dartmouth Conference officially coined the term 'artificial intelligence'.",
        "Modern AI includes machine learning, neural networks, and deep learning technologies.",
        "Applications span healthcare, finance, transportation, and entertainment industries."
    ]
    
    start_time = time.time()
    chunk_summaries = []
    
    for i, chunk in enumerate(chunks):
        print(f"⚡ Processing chunk {i+1}/{len(chunks)}...")
        
        prompt = f"""<|system|>Summarize in 2-3 sentences.<|end|>
<|user|>{chunk}

Summary:<|end|>
<|assistant|>"""
        
        try:
            response = requests.post(
                'http://127.0.0.1:8080/completion',
                json={
                    'prompt': prompt,
                    'n_predict': 50,  # Very short for chunk summaries
                    'temperature': 0.7,
                    'top_p': 0.9,
                    'repeat_penalty': 1.1,
                    'stream': False
                },
                timeout=60
            )
            
            if response.status_code == 200:
                result = response.json()
                content = result.get('content', '').strip()
                chunk_summaries.append(content)
                print(f"  ✅ Chunk {i+1}: {content[:100]}...")
            else:
                print(f"  ❌ Chunk {i+1} failed: {response.status_code}")
                
        except Exception as e:
            print(f"  ❌ Chunk {i+1} error: {e}")
    
    # Combine step
    if chunk_summaries:
        print("🔗 Combining summaries...")
        combined = "\n\n".join(chunk_summaries)
        
        combine_prompt = f"""<|system|>Combine into one comprehensive summary.<|end|>
<|user|>{combined}

Unified summary:<|end|>
<|assistant|>"""
        
        try:
            response = requests.post(
                'http://127.0.0.1:8080/completion',
                json={
                    'prompt': combine_prompt,
                    'n_predict': 150,
                    'temperature': 0.7,
                    'top_p': 0.9,
                    'repeat_penalty': 1.1,
                    'stream': False
                },
                timeout=60
            )
            
            duration = time.time() - start_time
            
            if response.status_code == 200:
                result = response.json()
                final_summary = result.get('content', '').strip()
                print(f"✅ CHUNKING SUCCESS! Total duration: {duration:.2f}s")
                print(f"📝 Final summary: {final_summary[:200]}...")
                return duration
            else:
                print(f"❌ Combine step failed: {response.status_code}")
                
        except Exception as e:
            print(f"❌ Combine step error: {e}")
    
    return None

if __name__ == "__main__":
    print("🧪 FocusAI Optimization Test")
    print("=" * 40)
    
    # Test 1: Short prompt
    short_duration = test_short_prompt_performance()
    
    # Test 2: Chunking simulation  
    chunk_duration = test_chunking_simulation()
    
    print("\n📊 RESULTS SUMMARY:")
    print("=" * 40)
    if short_duration:
        print(f"⚡ Short prompt: {short_duration:.2f}s")
    if chunk_duration:
        print(f"🔪 Chunking approach: {chunk_duration:.2f}s")
    
    if short_duration and chunk_duration:
        if short_duration < chunk_duration:
            print("🏆 Short prompt is faster!")
        else:
            print("🏆 Chunking approach is faster!") 