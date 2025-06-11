//
//  ContentView.swift
//  FocusAI
//
//  Created by Charlie King on 6/11/25.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
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
        .padding()
        .frame(minWidth: 800, minHeight: 600)
    }
}

#Preview {
    ContentView()
}
