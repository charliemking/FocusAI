//
//  URLInputView.swift
//  FocusAI
//
//  Created by Charlie King on 6/3/25.
//
//

import SwiftUI

struct URLInputView: View {
    @State private var urlString = ""

    var body: some View {
        VStack {
            Text("Paste article link")
                .font(.title2)
            TextField("https://example.com", text: $urlString)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            Button("Fetch & Summarize") {
                print("Fetching from: \(urlString)")
            }
            .padding()
        }
        .padding()
    }
}
