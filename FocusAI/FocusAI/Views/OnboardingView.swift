import SwiftUI

public struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentStep = 0
    @State private var isCheckingOllama = false
    @State private var ollamaInstalled = false
    @State private var checkAttempted = false
    
    private let steps = [
        OnboardingStep(
            title: "Welcome to FocusAI",
            description: "Transform your documents into interactive learning materials with AI-powered summaries and flashcards.",
            icon: "brain.head.profile",
            buttonText: "Get Started"
        ),
        OnboardingStep(
            title: "Install Ollama",
            description: "FocusAI requires Ollama to run AI models locally on your Mac. This ensures your data stays private and secure.",
            icon: "shield.fill",
            buttonText: "Next",
            isInstallStep: true
        ),
        OnboardingStep(
            title: "Verify Installation",
            description: "Let's check if Ollama is properly installed and ready to use.",
            icon: "checkmark.circle.fill",
            buttonText: "Check Ollama Installation",
            isVerificationStep: true
        )
    ]
    
    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }
    
    public var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with close button
                HStack {
                    Spacer()
                    Button(action: {
                        isPresented = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            NSApplication.shared.terminate(nil)
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Close FocusAI")
                }
                .frame(height: 44)
                .padding(.horizontal, 20)
                
                // Content
                ScrollView {
                    VStack(spacing: 32) {
                        // Step indicator
                        HStack(spacing: 8) {
                            ForEach(0..<steps.count, id: \.self) { index in
                                Circle()
                                    .fill(index <= currentStep ? Theme.primaryColor : Color.gray.opacity(0.3))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.top, 20)
                        
                        // Current step content
                        VStack(spacing: 24) {
                            Image(systemName: steps[currentStep].icon)
                                .font(.system(size: 60))
                                .foregroundColor(Theme.primaryColor)
                            
                            Text(steps[currentStep].title)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                            
                            Text(steps[currentStep].description)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundColor(Color(.darkGray))
                                .padding(.horizontal)
                            
                            // Installation step specific content
                            if steps[currentStep].isInstallStep {
                                installationContent
                            }
                            
                            // Verification step specific content
                            if steps[currentStep].isVerificationStep {
                                verificationContent
                            }
                        }
                        .padding(.horizontal, 40)
                        
                        Spacer(minLength: 40)
                        
                        // Navigation buttons
                        VStack(spacing: 16) {
                            Button(action: {
                                if steps[currentStep].isVerificationStep {
                                    checkOllamaInstallation()
                                } else {
                                    nextStep()
                                }
                            }) {
                                HStack {
                                    if steps[currentStep].isVerificationStep && isCheckingOllama {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    }
                                    Text(steps[currentStep].isVerificationStep && isCheckingOllama ? "Checking..." : steps[currentStep].buttonText)
                                        .fontWeight(.medium)
                                    if currentStep < steps.count - 1 && !steps[currentStep].isVerificationStep {
                                        Image(systemName: "arrow.right")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(getButtonColor())
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(isCheckingOllama || (steps[currentStep].isVerificationStep && checkAttempted && !ollamaInstalled))
                            
                            if currentStep > 0 {
                                Button("Back") {
                                    withAnimation {
                                        currentStep -= 1
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                .foregroundColor(Color(.darkGray))
                            }
                        }
                        .padding(.horizontal, 40)
                        .padding(.bottom, 40)
                    }
                }
            }
            .background(Color(.windowBackgroundColor))
            .cornerRadius(16)
            .shadow(radius: 20)
            .padding(40)
        }
    }
    
    private var installationContent: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Terminal Installation (Recommended):")
                    .font(.headline)
                    .foregroundColor(Theme.primaryColor)
                
                VStack(alignment: .leading, spacing: 8) {
                    InstallationStep(
                        number: "1",
                        title: "Download Ollama",
                        description: "Click the button below to visit ollama.com and download the app"
                    )
                    
                    InstallationStep(
                        number: "2", 
                        title: "Open Ollama App",
                        description: "Open Terminal (Cmd+Space, type 'Terminal') and run:",
                        copyableCommand: "open -a \"Ollama\""
                    )
                    
                    InstallationStep(
                        number: "3",
                        title: "Download AI Model",
                        description: "In Terminal, copy and paste:",
                        copyableCommand: "ollama pull phi3:mini"
                    )
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(12)
            
            // App Store compliant link button
            Button(action: {
                if let url = URL(string: "https://ollama.com") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                HStack {
                    Image(systemName: "safari")
                    Text("Open Ollama Website")
                }
                .padding()
                .background(Color(.controlAccentColor))
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(spacing: 8) {
                Text("🔒 Privacy First: Terminal installation ensures your app runs completely offline")
                    .font(.caption)
                    .foregroundColor(Theme.primaryColor)
                    .multilineTextAlignment(.center)
                    .fontWeight(.medium)
                
                Text("No data reaches the cloud - everything stays on your Mac")
                    .font(.caption)
                    .foregroundColor(Color(.darkGray))
                    .multilineTextAlignment(.center)
                
                Text("Thanks and enjoy! - Charlie")
                    .font(.caption)
                    .foregroundColor(Color(.darkGray))
                    .multilineTextAlignment(.center)
                    .italic()
            }
        }
    }
    
    private var verificationContent: some View {
        VStack(spacing: 20) {
            if !checkAttempted {
                VStack(spacing: 16) {
                    Text("Ready to verify your Ollama installation?")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    
                    Text("This will check if Ollama is running and accessible on your system.")
                        .font(.subheadline)
                        .foregroundColor(Color(.darkGray))
                        .multilineTextAlignment(.center)
                }
            } else if isCheckingOllama {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.primaryColor))
                        .scaleEffect(1.5)
                    
                    Text("Checking Ollama installation...")
                        .font(.headline)
                        .foregroundColor(Theme.primaryColor)
                }
            } else if ollamaInstalled {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("✅ Ollama is installed and ready!")
                        .font(.headline)
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                    
                    Text("You can now start using FocusAI to process documents with complete privacy.")
                        .font(.subheadline)
                        .foregroundColor(Color(.darkGray))
                        .multilineTextAlignment(.center)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("❌ Ollama not found")
                        .font(.headline)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                    
                    Text("Please install Ollama using the instructions from the previous step, then try again.")
                        .font(.subheadline)
                        .foregroundColor(Color(.darkGray))
                        .multilineTextAlignment(.center)
                    
                    Button("Try Again") {
                        checkOllamaInstallation()
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Theme.primaryColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private func getButtonColor() -> Color {
        if steps[currentStep].isVerificationStep {
            if checkAttempted && !ollamaInstalled {
                return .gray
            } else if ollamaInstalled {
                return .green
            }
        }
        return Theme.primaryColor
    }
    
    private func checkOllamaInstallation() {
        isCheckingOllama = true
        checkAttempted = true
        
        Task {
            // App Store compliant check - test if Ollama server is accessible
            let isInstalled = await testOllamaConnection()
            
            await MainActor.run {
                ollamaInstalled = isInstalled
                isCheckingOllama = false
                
                if isInstalled {
                    // Update button text to "Start Using FocusAI"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        // Auto-advance after showing success
                        nextStep()
                    }
                }
            }
        }
    }
    
    private func testOllamaConnection() async -> Bool {
        // Test if Ollama is accessible via HTTP request (App Store compliant)
        guard let url = URL(string: "http://localhost:11434/api/tags") else {
            return false
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            return false
        }
    }
    
    private func nextStep() {
        if currentStep < steps.count - 1 {
            withAnimation {
                currentStep += 1
            }
        } else {
            isPresented = false
        }
    }
}

private struct OnboardingStep {
    let title: String
    let description: String
    let icon: String
    let buttonText: String
    let isInstallStep: Bool
    let isVerificationStep: Bool
    
    init(title: String, description: String, icon: String, buttonText: String, isInstallStep: Bool = false, isVerificationStep: Bool = false) {
        self.title = title
        self.description = description
        self.icon = icon
        self.buttonText = buttonText
        self.isInstallStep = isInstallStep
        self.isVerificationStep = isVerificationStep
    }
}

private struct InstallationStep: View {
    let number: String
    let title: String
    let description: String
    let copyableCommand: String?
    
    init(number: String, title: String, description: String, copyableCommand: String? = nil) {
        self.number = number
        self.title = title
        self.description = description
        self.copyableCommand = copyableCommand
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Theme.primaryColor)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(Color(.darkGray))
                
                if let command = copyableCommand {
                    HStack {
                        Text(command)
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.controlBackgroundColor))
                            .cornerRadius(4)
                            .foregroundColor(Theme.primaryColor)
                        
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(command, forType: .string)
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                                .foregroundColor(Theme.primaryColor)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .background(Color.clear)
                        .help("Copy to clipboard")
                    }
                }
            }
            
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
