import SwiftUI

struct DocumentSearchView: View {
    @StateObject private var searchService = SearchService.shared
    @State private var searchText = ""
    @State private var selectedDocument: Document?
    
    var body: some View {
        List {
            if searchService.isSearching {
                ProgressView("Searching...")
            } else if searchService.searchResults.isEmpty {
                Text("No results found")
                    .foregroundColor(.secondary)
            } else {
                ForEach(searchService.searchResults) { document in
                    DocumentRow(document: document)
                        .onTapGesture {
                            selectedDocument = document
                        }
                }
            }
        }
        .searchable(text: $searchText)
        .onChange(of: searchText) { _, newValue in
            Task {
                do {
                    _ = try await searchService.searchDocuments(query: newValue)
                } catch {
                    print("Search error: \(error)")
                }
            }
        }
        .navigationTitle("Search")
        .sheet(item: $selectedDocument) { document in
            DocumentDetailView(document: document)
        }
    }
} 