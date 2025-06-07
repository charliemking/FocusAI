//
//  MessageView.swift
//  MLCChat
//

import SwiftUI
import MLCSwift
import MarkdownUI

struct MessageView: View {
    let message: MessageData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.role.rawValue.capitalized)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Markdown(message.content)
                .markdownTheme(.gitHub)
        }
        .padding()
        .background(message.role == .assistant ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

struct ImageView: View {
    let image: UIImage

    var body: some View {
        let background = Color.blue
        HStack {
            Spacer()
            Image(uiImage: image)
                .resizable()
                .frame(width: 150, height: 150)
                .padding(15)
                .background(background)
                .cornerRadius(20)
        }
        .padding()
        .listRowSeparator(.hidden)
    }
}

struct MessageView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            VStack (spacing: 0){
                ScrollView {
                    MessageView(message: MessageData(role: .user, content: "Message 1"))
                    MessageView(message: MessageData(role: .assistant, content: "Message 2"))
                    MessageView(message: MessageData(role: .user, content: "Message 3"))
                }
            }
        }
    }
}

#Preview {
    VStack {
        MessageView(message: MessageData(role: .user, content: "Hello!"))
        MessageView(message: MessageData(role: .assistant, content: "Hi there! How can I help you today?"))
    }
    .padding()
}

