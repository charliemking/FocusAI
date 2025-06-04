import SwiftUI

struct TextInputView: View {
    @State private var inputText = ""
    
    var body: some View {
        NavigationView {
            VStack {
                TextEditor(text: $inputText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding()
                
                Button("Analyze Text") {
                    // TODO: Implement text analysis
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .navigationTitle("Text Analysis")
        }
    }
}

#Preview {
    TextInputView()
} 