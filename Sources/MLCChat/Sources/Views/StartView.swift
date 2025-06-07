import SwiftUI

public struct StartView: View {
    @StateObject private var appState = AppState()
    @State private var isShowingError = false
    @State private var errorMessage = ""
    
    public var body: some View {
        NavigationView {
            List {
                ForEach($appState.modelStates) { $modelState in
                    ModelView(isRemoving: $modelState.isRemoving)
                        .environmentObject(modelState)
                        .environmentObject(appState.chatState)
                }
            }
            .navigationTitle("Models")
            .alert("Error", isPresented: $isShowingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                Task {
                    do {
                        try await appState.loadModels()
                    } catch {
                        errorMessage = error.localizedDescription
                        isShowingError = true
                    }
                }
            }
        }
    }
    
    public init() {}
} 