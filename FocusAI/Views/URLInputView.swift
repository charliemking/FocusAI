import SwiftUI

struct URLInputView: View {
    @State private var urlString = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("Enter URL", text: $urlString)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .keyboardType(.URL)
                    .padding()
                
                if isLoading {
                    ProgressView("Loading content...")
                }
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
                
                Button("Extract Content") {
                    // TODO: Implement URL content extraction
                }
                .buttonStyle(.borderedProminent)
                .disabled(urlString.isEmpty)
                .padding()
                
                Spacer()
            }
            .navigationTitle("URL Analysis")
        }
    }
}

#Preview {
    URLInputView()
} 