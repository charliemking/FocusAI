import SwiftUI
import UniformTypeIdentifiers

struct DocumentInputView: View {
    @StateObject private var processor: DocumentProcessor
    @State private var showingDocumentPicker = false
    @State private var showingURLInput = false
    @State private var urlString = ""
    @State private var plainText = ""
    @State private var selectedTab = 0
    @State private var processorError: Error?
    
    init() {
        do {
            _processor = StateObject(wrappedValue: try DocumentProcessor())
        } catch {
            _processor = StateObject(wrappedValue: DocumentProcessor())
            processorError = error
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if let error = processorError {
                    Text("Initialization Error: \(error.localizedDescription)")
                        .foregroundColor(.red)
                        .padding()
                }
                
                Picker("Input Type", selection: $selectedTab) {
                    Text("PDF").tag(0)
                    Text("Text").tag(1)
                    Text("URL").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                TabView(selection: $selectedTab) {
                    // PDF Input
                    VStack {
                        Button(action: { showingDocumentPicker = true }) {
                            Label("Select PDF", systemImage: "doc.fill")
                                .font(.headline)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .tag(0)
                    
                    // Text Input
                    VStack {
                        TextEditor(text: $plainText)
                            .frame(maxHeight: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        
                        Button(action: {
                            Task {
                                let document = Document(
                                    source: .text(plainText),
                                    title: String(plainText.prefix(50)) + "..."
                                )
                                await processor.process(document: document)
                            }
                        }) {
                            Label("Process Text", systemImage: "arrow.right.circle.fill")
                                .font(.headline)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .disabled(plainText.isEmpty)
                    }
                    .padding()
                    .tag(1)
                    
                    // URL Input
                    VStack {
                        TextField("Enter URL", text: $urlString)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .keyboardType(.URL)
                        
                        Button(action: {
                            guard let url = URL(string: urlString) else { return }
                            Task {
                                let document = Document(
                                    source: .url(url),
                                    title: url.lastPathComponent
                                )
                                await processor.process(document: document)
                            }
                        }) {
                            Label("Process URL", systemImage: "arrow.right.circle.fill")
                                .font(.headline)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .disabled(urlString.isEmpty)
                    }
                    .padding()
                    .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                if processor.isProcessing {
                    ProgressView("Processing...")
                        .padding()
                }
                
                if let error = processor.error {
                    Text(error.localizedDescription)
                        .foregroundColor(.red)
                        .padding()
                }
                
                List(processor.documents) { document in
                    NavigationLink(destination: DocumentDetailView(document: document)) {
                        Text(document.title)
                    }
                }
            }
            .navigationTitle("FocusAI")
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker { url in
                Task {
                    let document = Document(
                        source: .pdf(url),
                        title: url.deletingPathExtension().lastPathComponent
                    )
                    await processor.process(document: document)
                }
            }
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let callback: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf])
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(callback: callback)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let callback: (URL) -> Void
        
        init(callback: @escaping (URL) -> Void) {
            self.callback = callback
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            callback(url)
        }
    }
} 