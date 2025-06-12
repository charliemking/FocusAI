# FocusAI

A privacy-first study assistant built with SwiftUI for macOS. FocusAI helps you analyze documents, generate summaries, create flashcards, and answer questions about your study material.

## Features

- Multiple input methods:
  - PDF document upload and analysis
  - Text input for direct content processing
  - URL input for web content analysis
- AI-powered tools:
  - Automatic summarization
  - Flashcard generation
  - Interactive Q&A system
- Privacy-focused design
- Native macOS experience with SwiftUI

## Project Structure

```
FocusAI/
├── FocusAI/
│   ├── FocusAIApp.swift          # App entry point and window configuration
│   ├── ContentView.swift         # Main view with tab navigation
│   ├── Theme.swift              # App-wide styling and colors
│   │
│   ├── Views/
│   │   ├── PDFView.swift        # PDF document handling and display
│   │   ├── TextView.swift       # Direct text input processing
│   │   └── URLView.swift        # Web content processing
│   │
│   ├── Models/
│   │   └── Flashcard.swift      # Flashcard data model
│   │
│   └── Assets.xcassets/         # App icons and images
│
└── README.md                    # Project documentation
```

## Requirements

- macOS 13.0 or later
- Xcode 14.0 or later
- Swift 5.7 or later

## Installation

1. Clone the repository:
```bash
git clone https://github.com/charliemking/FocusAI.git
```

2. Open the project in Xcode:
```bash
cd FocusAI
open FocusAI.xcodeproj
```

3. Build and run the project (⌘R)

## Development

The app is built using SwiftUI and follows Apple's Human Interface Guidelines. The UI is designed to be intuitive and responsive, with a clean and modern aesthetic.

### Key Components

- **PDFView**: Handles PDF document upload, display, and processing
- **TextView**: Provides direct text input and processing capabilities
- **URLView**: Manages web content retrieval and analysis
- **Theme**: Centralizes app styling with an emerald green color scheme


## Author

Charlie King 