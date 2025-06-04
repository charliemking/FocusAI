import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            PDFInputView()
                .tabItem {
                    Label("PDF", systemImage: "doc.fill")
                }
                .tag(0)
            
            TextInputView()
                .tabItem {
                    Label("Text", systemImage: "text.justify")
                }
                .tag(1)
            
            URLInputView()
                .tabItem {
                    Label("URL", systemImage: "link")
                }
                .tag(2)
            
            StudyView()
                .tabItem {
                    Label("Study", systemImage: "brain.head.profile")
                }
                .tag(3)
        }
    }
}

#Preview {
    ContentView()
} 