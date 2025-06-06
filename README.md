# FocusAI

A privacy-first iOS study assistant powered by Mistral 7B running locally via MLC LLM. FocusAI helps students learn more effectively by providing AI-powered document analysis, summarization, flashcard generation, and interactive Q&A - all while keeping your data completely private.

## Features

- 🔒 **Privacy-First**: All processing happens locally on your device
- 📚 **Document Analysis**: Process PDFs, text, and other study materials
- ✍️ **Smart Summarization**: Get concise summaries of your study materials
- 🎴 **Flashcard Generation**: Automatically create study flashcards
- ❓ **Interactive Q&A**: Ask questions about your study materials
- 📱 **Native iOS Experience**: Built with SwiftUI for a smooth, native feel
- 🧠 **Powered by Mistral 7B**: State-of-the-art language model optimized for mobile

## Requirements

- iOS 15.0+
- Xcode 14.0+
- Swift 5.5+
- Device with at least 6GB RAM (iPhone 12 or newer recommended)
- ~4GB storage space for the ML model

## Installation

1. Clone the repository:
```bash
git clone https://github.com/charliemking/FocusAI.git
cd FocusAI
```

2. Download the model files:
The app uses Mistral-7B-Instruct-v0.2 in MLC format. The model files are already included in the `Resources/models/mistral` directory:
- model.mlc (compiled model)
- tokenizer files
- model parameters

3. Open the project:
```bash
xed .
```

4. Build and run:
- Select your development team in project settings
- Choose your target device (iPhone 12 or newer recommended)
- Build and run the project

## Project Structure

```
FocusAI/
├── FocusAI/              # Main app source code
│   ├── Views/           # SwiftUI views
│   ├── Models/          # Data models
│   ├── Services/        # Business logic
│   └── Utils/           # Helper utilities
├── Resources/           # Resource files
│   └── models/         # ML model files
│       └── mistral/    # Mistral model
├── Tests/              # Unit tests
└── UITests/            # UI tests
```

## Technical Details

### ML Model

- **Model**: Mistral-7B-Instruct-v0.2
- **Quantization**: q4f16_1 (4-bit quantization)
- **Framework**: MLC LLM for efficient on-device inference
- **Context Window**: 4096 tokens
- **Performance**: ~10 tokens/second on recent devices

### Privacy Features

- All processing happens locally on device
- No data is sent to external servers
- No analytics or tracking
- No network access required after model download

## Development Status

- ✅ Core ML functionality implemented
- ✅ Basic UI implemented
- ✅ Model integration complete
- 🚧 Advanced features in development
- 🚧 Performance optimizations ongoing

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [MLC LLM](https://github.com/mlc-ai/mlc-llm) for the efficient model deployment framework
- [Mistral AI](https://mistral.ai) for the base model
- The open-source community for various tools and libraries used in this project 