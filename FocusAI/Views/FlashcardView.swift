import SwiftUI

struct FlashcardView: View {
    let question: String
    let answer: String
    @State private var isFlipped = false
    
    var body: some View {
        VStack {
            ZStack {
                // Question Side
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.1))
                    .overlay(
                        Text(question)
                            .padding()
                    )
                    .opacity(isFlipped ? 0 : 1)
                
                // Answer Side
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.green.opacity(0.1))
                    .overlay(
                        Text(answer)
                            .padding()
                    )
                    .opacity(isFlipped ? 1 : 0)
            }
            .frame(height: 150)
            .rotation3DEffect(
                .degrees(isFlipped ? 180 : 0),
                axis: (x: 0, y: 1, z: 0)
            )
            .animation(.default, value: isFlipped)
            .onTapGesture {
                withAnimation {
                    isFlipped.toggle()
                }
            }
        }
        .padding(.horizontal)
    }
}

struct FlashcardDeckView: View {
    let document: Document
    @State private var currentIndex = 0
    
    var body: some View {
        VStack {
            if !document.flashcards.isEmpty {
                TabView(selection: $currentIndex) {
                    ForEach(0..<document.flashcards.count, id: \.self) { index in
                        let flashcard = document.flashcards[index]
                        FlashcardView(question: flashcard.question, answer: flashcard.answer)
                    }
                }
                .tabViewStyle(.page)
            } else {
                Text("No flashcards available")
            }
        }
        .navigationTitle("Flashcards")
    }
}

#Preview {
    FlashcardView(question: "What is the capital of France?", answer: "Paris")
} 