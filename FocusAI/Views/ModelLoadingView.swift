import SwiftUI

struct ModelLoadingView: View {
    @ObservedObject private var modelManager = ModelManager.shared
    @State private var loadingError: Error?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Loading FocusAI")
                .font(.title)
                .fontWeight(.bold)
            
            if !modelManager.isModelLoaded {
                VStack(alignment: .leading) {
                    Text("Initializing ML Model...")
                        .foregroundColor(.secondary)
                    
                    ProgressView()
                        .scaleEffect(1.5)
                }
                .frame(maxWidth: 250)
            }
            
            if let error = loadingError {
                VStack {
                    Text("Error")
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.red.opacity(0.1))
                )
            }
        }
        .padding()
        .task {
            do {
                try await modelManager.loadModel()
            } catch {
                loadingError = error
            }
        }
    }
}

#Preview {
    ModelLoadingView()
} 