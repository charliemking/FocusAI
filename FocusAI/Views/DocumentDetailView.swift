import SwiftUI

struct DocumentDetailView: View {
    @ObservedObject var document: Document
    @StateObject private var processor = DocumentProcessor.shared
    @State private var summary: String = ""
    @State private var flashcards: [Flashcard] = []
    @State private var userQuestion: String = ""
    @State private var answer: String = ""
    @State private var isLoading = false
    @State private var error: Error?
    @State private var selectedTab = 0
    
    var body: some View {
        VStack {
            Picker("View Type", selection: $selectedTab) {
                Text("Summary").tag(0)
                Text("Flashcards").tag(1)
                Text("Q&A").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            TabView(selection: $selectedTab) {
                // Summary View
                VStack {
                    if summary.isEmpty && !isLoading {
                        Button(action: generateSummary) {
                            Label("Generate Summary", systemImage: "text.badge.plus")
                                .font(.headline)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    } else {
                        ScrollView {
                            Text(summary)
                                .padding()
                        }
                    }
                }
                .tag(0)
                
                // Flashcards View
                VStack {
                    if flashcards.isEmpty && !isLoading {
                        Button(action: generateFlashcards) {
                            Label("Generate Flashcards", systemImage: "rectangle.stack.badge.plus")
                                .font(.headline)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 20) {
                                ForEach(flashcards) { card in
                                    FlashcardView(question: card.question,
                                                answer: card.answer)
                                }
                            }
                            .padding()
                        }
                    }
                }
                .tag(1)
                
                // Q&A View
                VStack {
                    TextField("Ask a question...", text: $userQuestion)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                    
                    Button(action: askQuestion) {
                        Label("Ask", systemImage: "questionmark.circle.fill")
                            .font(.headline)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(userQuestion.isEmpty)
                    
                    if !answer.isEmpty {
                        ScrollView {
                            Text(answer)
                                .padding()
                        }
                    }
                }
                .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            if isLoading {
                ProgressView("Processing...")
                    .padding()
            }
            
            if let error = error {
                Text(error.localizedDescription)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .navigationTitle("Document Details")
    }
    
    private func generateSummary() {
        isLoading = true
        error = nil
        
        Task {
            do {
                summary = try await processor.generateSummary(for: document)
            } catch {
                self.error = error
            }
            isLoading = false
        }
    }
    
    private func generateFlashcards() {
        isLoading = true
        error = nil
        
        Task {
            do {
                flashcards = try await processor.generateFlashcards(for: document)
            } catch {
                self.error = error
            }
            isLoading = false
        }
    }
    
    private func askQuestion() {
        guard !userQuestion.isEmpty else { return }
        isLoading = true
        error = nil
        
        Task {
            do {
                answer = try await processor.answerQuestion(userQuestion, using: document)
            } catch {
                self.error = error
            }
            isLoading = false
        }
    }
}

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