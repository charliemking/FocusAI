import SwiftUI
import AppKit

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text("FocusAI")
                    .font(Theme.headerStyle)
                    .foregroundColor(Theme.primaryColor)
                Text("A Privacy-First Study Assistant by Charlie King")
                    .font(Theme.subtitleStyle)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white)
            
            // Tab Bar
            HStack(spacing: 24) {
                ForEach(0..<3) { index in
                    Button(action: { selectedTab = index }) {
                        HStack(spacing: 4) {
                            Image(systemName: index == 0 ? "doc.fill" :
                                             index == 1 ? "text.justify" : "link")
                            Text(index == 0 ? "PDF" :
                                index == 1 ? "Text" : "URL")
                        }
                        .foregroundColor(selectedTab == index ? Theme.primaryColor : .gray)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 16)
            .frame(maxWidth: .infinity)
            .background(Theme.backgroundColor)
            
            // Content
            Group {
                if selectedTab == 0 {
                    PDFView()
                } else if selectedTab == 1 {
                    TextView()
                } else {
                    URLView()
                }
            }
        }
        .frame(minWidth: 1200, minHeight: 800)
    }
}

struct CustomTabView<Content: View>: NSViewRepresentable {
    @Binding var selection: Int
    let content: Content
    
    init(selection: Binding<Int>, @ViewBuilder content: () -> Content) {
        self._selection = selection
        self.content = content()
    }
    
    func makeNSView(context: Context) -> NSTabView {
        let tabView = NSTabView()
        tabView.tabViewType = .topTabsBezelBorder
        tabView.tabViewBorderType = .none
        tabView.tabPosition = .none // Hide the tab bar
        tabView.delegate = context.coordinator
        return tabView
    }
    
    func updateNSView(_ tabView: NSTabView, context: Context) {
        if tabView.selectedTabViewItem?.identifier as? Int != selection {
            tabView.selectTabViewItem(at: selection)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTabViewDelegate {
        var parent: CustomTabView
        
        init(_ parent: CustomTabView) {
            self.parent = parent
        }
        
        func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
            if let index = tabViewItem?.identifier as? Int {
                parent.selection = index
            }
        }
    }
} 
