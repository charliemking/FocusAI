//
//  ContentView.swift
//  FocusAI
//
//  Created by Charlie King on 6/3/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            PDFInputView()
                .tabItem {
                    Label("PDF", systemImage: "doc.text")
                }

            TextInputView()
                .tabItem {
                    Label("Text", systemImage: "square.and.pencil")
                }

            URLInputView()
                .tabItem {
                    Label("Link", systemImage: "link")
                }
        }
    }
}

#Preview {
    ContentView()
}
