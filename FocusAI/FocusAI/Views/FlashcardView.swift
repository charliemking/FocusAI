import SwiftUI

public struct FlashcardView: View {
    let flashcards: [Flashcard]
    @State private var currentIndex = 0
    @State private var isShowingAnswer = false

    
    public init(flashcards: [Flashcard]) {
        self.flashcards = flashcards
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            if flashcards.isEmpty {
                Text("No flashcards available")
                    .font(Theme.bodyStyle)
                    .foregroundColor(Color(.darkGray))
            } else {
                // Progress indicator
                HStack {
                    Text("Card \(currentIndex + 1) of \(flashcards.count)")
                        .font(Theme.subtitleStyle)
                        .foregroundColor(Theme.primaryColor)
                    
                    Spacer()
                    
                    // Progress bar
                    ProgressView(value: Double(currentIndex + 1), total: Double(flashcards.count))
                        .progressViewStyle(LinearProgressViewStyle(tint: Theme.primaryColor))
                        .frame(width: 100)
                }
                .padding(.horizontal, 8)
                
                // Main flashcard with overlaid navigation
                ZStack {
                    flashcardBody
                    
                    // Overlaid navigation controls
                    VStack {
                        Spacer()
                        overlaidNavigationControls
                    }
                }
                
                // Action buttons (more compact)
                compactActionButtons
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
    
    private var flashcardBody: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.backgroundWhite)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.primaryColor.opacity(0.2), lineWidth: 1)
                )
            
            VStack(spacing: 16) {
                // Card type indicator
                HStack {
                    Text(isShowingAnswer ? "ANSWER" : "QUESTION")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(isShowingAnswer ? .green : Theme.primaryColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill((isShowingAnswer ? .green : Theme.primaryColor).opacity(0.1))
                        )
                    
                    Spacer()
                    
                    // Flip hint
                    Text("Tap to flip")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Card content
                VStack(spacing: 12) {
                    if isShowingAnswer {
                        ScrollView {
                            Text(currentFlashcard.answer)
                                .font(.system(size: 15))
                                .foregroundColor(Color(.darkGray))
                                .multilineTextAlignment(.center)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 8)
                        }
                        .frame(maxHeight: 100)
                    } else {
                        ScrollView {
                            Text(currentFlashcard.question)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(Theme.primaryColor)
                                .multilineTextAlignment(.center)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 8)
                        }
                        .frame(maxHeight: 100)
                    }
                }
                
                Spacer()
                
                // Tags (if any)
                if !currentFlashcard.tags.isEmpty {
                    HStack {
                        ForEach(currentFlashcard.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Theme.lightAccent)
                                .foregroundColor(Theme.primaryColor)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(20)
        }
        .frame(minHeight: 200, maxHeight: 220)
        .transition(.opacity)
        .onTapGesture {
            flipCard()
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: currentIndex)
    }
    
    private var overlaidNavigationControls: some View {
        HStack(spacing: 20) {
            // Previous button (compact, overlaid)
            Button(action: previousCard) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(currentIndex > 0 ? Theme.primaryColor : .gray)
                    .padding(12)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    )
            }
            .disabled(currentIndex <= 0)
            .opacity(currentIndex > 0 ? 1.0 : 0.3)
            
            Spacer()
            
            // Next button (compact, overlaid)
            Button(action: nextCard) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(currentIndex < flashcards.count - 1 ? Theme.primaryColor : .gray)
                    .padding(12)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    )
            }
            .disabled(currentIndex >= flashcards.count - 1)
            .opacity(currentIndex < flashcards.count - 1 ? 1.0 : 0.3)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
    
    private var navigationControls: some View {
        HStack(spacing: 20) {
            // Previous button
            Button(action: previousCard) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Previous")
                }
                .font(Theme.subtitleStyle)
                .foregroundColor(currentIndex > 0 ? Theme.primaryColor : .gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(currentIndex > 0 ? Theme.primaryColor : .gray, lineWidth: 1)
                )
            }
            .disabled(currentIndex <= 0)
            
            Spacer()
            
            // Reset button
            Button(action: resetToQuestion) {
                Image(systemName: "arrow.clockwise")
                    .font(Theme.subtitleStyle)
                    .foregroundColor(Theme.primaryColor)
                    .padding(8)
                    .background(
                        Circle()
                            .stroke(Theme.primaryColor, lineWidth: 1)
                    )
            }
            
            Spacer()
            
            // Next button
            Button(action: nextCard) {
                HStack {
                    Text("Next")
                    Image(systemName: "chevron.right")
                }
                .font(Theme.subtitleStyle)
                .foregroundColor(currentIndex < flashcards.count - 1 ? Theme.primaryColor : .gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(currentIndex < flashcards.count - 1 ? Theme.primaryColor : .gray, lineWidth: 1)
                )
            }
            .disabled(currentIndex >= flashcards.count - 1)
        }
        .padding(.horizontal)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            // Shuffle button
            Button(action: shuffleCards) {
                HStack {
                    Image(systemName: "shuffle")
                    Text("Shuffle")
                }
                .font(Theme.subtitleStyle)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Theme.primaryColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Restart button
            Button(action: restartDeck) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Restart")
                }
                .font(Theme.subtitleStyle)
                .foregroundColor(Theme.primaryColor)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Theme.primaryColor, lineWidth: 1)
                )
            }
        }
    }
    
    private var compactActionButtons: some View {
        HStack(spacing: 12) {
            // Shuffle button (compact)
            Button(action: shuffleCards) {
                HStack(spacing: 4) {
                    Image(systemName: "shuffle")
                    Text("Shuffle")
                }
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.primaryColor)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            // Restart button (compact)
            Button(action: restartDeck) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Restart")
                }
                .font(.caption)
                .foregroundColor(Theme.primaryColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Theme.primaryColor, lineWidth: 1)
                )
            }
        }
    }
    
    private var currentFlashcard: Flashcard {
        flashcards[currentIndex]
    }
    
    // MARK: - Actions
    
    private func flipCard() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isShowingAnswer.toggle()
        }
    }
    
    private func nextCard() {
        guard currentIndex < flashcards.count - 1 else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentIndex += 1
            isShowingAnswer = false
        }
    }
    
    private func previousCard() {
        guard currentIndex > 0 else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentIndex -= 1
            isShowingAnswer = false
        }
    }
    
    private func resetToQuestion() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isShowingAnswer = false
        }
    }
    
    private func shuffleCards() {
        // Note: This would require making flashcards mutable
        // For now, just reset to first card
        withAnimation(.easeInOut(duration: 0.3)) {
            currentIndex = 0
            isShowingAnswer = false
        }
    }
    
    private func restartDeck() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentIndex = 0
            isShowingAnswer = false
        }
    }
}

// MARK: - Preview
struct FlashcardView_Previews: PreviewProvider {
    static var previews: some View {
        FlashcardView(flashcards: [
            Flashcard(question: "What is photosynthesis?", answer: "The process by which plants convert sunlight into chemical energy using chlorophyll.", tags: ["biology", "plants"]),
            Flashcard(question: "What is the chemical equation for photosynthesis?", answer: "6CO2 + 6H2O + light energy → C6H12O6 + 6O2", tags: ["chemistry", "equations"]),
            Flashcard(question: "Where does photosynthesis occur?", answer: "In the chloroplasts of plant cells, specifically in the thylakoid membranes.", tags: ["biology", "cells"])
        ])
        .environmentObject(ServiceManager())
    }
} 