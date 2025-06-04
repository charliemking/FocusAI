//
//  TextInputView.swift
//  FocusAI
//
//  Created by Charlie King on 6/3/25.
//
//

import SwiftUI

struct TextInputView: View {
    @State private var inputText = ""

    var body: some View {
        VStack {
            Text("Paste in your notes or text")
                .font(.title2)
            TextEditor(text: $inputText)
                .frame(height: 200)
                .border(Color.gray)
                .padding()
            Button("Summarize") {
                // This will trigger the summarization later
                print("Summarizing: \(inputText)")
            }
            .padding()
        }
        .padding()
    }
}
