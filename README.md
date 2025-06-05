# FocusAI

FocusAI is a privacy-first AI study assistant that runs fully on-device using Mistral 7B via MLC LLM. The app allows users to upload PDFs, paste text, or submit URLs, and processes these inputs using local ML models for summarization, flashcard generation, and Q&A.

## Important Note About ML Model

⚠️ The ML model file is not included in this repository due to its large size (~4GB). You'll need to download it separately after cloning the project.

## Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/charliemking/FocusAI.git
   cd FocusAI
   ```

2. Download the Mistral 7B model (choose one method):

   **Option 1: Direct Download**
   ```bash
   # From the project root
   mkdir -p FocusAI/Resources
   curl -L https://huggingface.co/mlc-ai/Mistral-7B-Instruct-v0.3-q4f16_1-MLC/resolve/main/Mistral-7B-Instruct-v0.3-q4f16_1-MLC.mlc -o FocusAI/Resources/mistral-7b-q4f16_1
   ```

   **Option 2: Using Git LFS**
   ```bash
   git lfs install
   git clone https://huggingface.co/mlc-ai/Mistral-7B-Instruct-v0.3-q4f16_1-MLC
   mv Mistral-7B-Instruct-v0.3-q4f16_1-MLC/Mistral-7B-Instruct-v0.3-q4f16_1-MLC.mlc FocusAI/Resources/mistral-7b-q4f16_1
   rm -rf Mistral-7B-Instruct-v0.3-q4f16_1-MLC
   ```

3. Build and run:
   - Open `FocusAI.xcodeproj` in Xcode
   - Select your development team in project settings
   - Build and run on a device or simulator (iOS 17.0+)

## Features

- PDF document processing
- Text input and analysis
- URL content extraction
- Local AI-powered summarization
- Flashcard generation
- Question answering based on input content

## Technical Stack

- SwiftUI for the user interface
- MLC LLM for running Mistral 7B locally
- PDFKit for PDF processing
- Swift concurrency for performance

## Privacy

FocusAI processes all data locally on your device. No data is sent to external servers, ensuring complete privacy of your study materials.

## System Requirements

- iOS 17.0 or later
- Device with at least 4GB RAM (recommended)
- ~4GB storage space for the ML model

## Known Limitations

- Initial model loading may take a few seconds
- Processing very large documents may require more memory
- Maximum context window size is 4096 tokens

## Development Status

Currently in active development. Core features are implemented and working.
