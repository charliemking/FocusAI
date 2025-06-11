import SwiftUI
import PDFKit

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text("FocusAI")
                    .font(Theme.headerStyle)
                    .foregroundColor(Theme.primaryBlue)
                Text("A Privacy-First Study Assistant by Charlie King")
                    .font(Theme.subtitleStyle)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                Color.white
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
            
            // Tab View
            TabView(selection: $selectedTab) {
                PDFView()
                    .tabItem {
                        Label("PDF", systemImage: "doc.fill")
                    }
                    .tag(0)
                
                TextView()
                    .tabItem {
                        Label("Text", systemImage: "text.justify")
                    }
                    .tag(1)
                
                URLView()
                    .tabItem {
                        Label("URL", systemImage: "link")
                    }
                    .tag(2)
            }
            .tabViewStyle(.automatic)
        }
        .frame(minWidth: 800, minHeight: 600)
    }
} 