//
//  DocumentSelectionView.swift
//  HomeCrew
//
//  Created by Vipul Swarup on 16/03/25.
//


import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct DocumentSelectionView: View {
    @Binding var documents: [DocumentItem]
    
    @State private var showingDocumentPicker = false
    @State private var selectedDocumentURL: URL?
    @State private var selectedItems: [PhotosPickerItem] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button(action: {
                    showingDocumentPicker = true
                }) {
                    Label("Select File", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.bordered)
                
                PhotosPicker(selection: $selectedItems, matching: .images, photoLibrary: .shared()) {
                    Label("Select Photo", systemImage: "photo.badge.plus")
                }
                .buttonStyle(.bordered)
            }
            
            if !documents.isEmpty {
                Text("Selected Documents:")
                    .font(.headline)
                    .padding(.top, 8)
                
                ForEach(documents) { document in
                    DocumentItemRow(document: document) { name in
                        updateDocumentName(document: document, newName: name)
                    } onDelete: {
                        deleteDocument(document: document)
                    }
                }
            }
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(
                selectedURL: $selectedDocumentURL,
                allowedContentTypes: [.pdf, .image, .jpeg, .png, .text]
            )
        }
        .onChange(of: selectedDocumentURL) { _, newURL in
            if let url = newURL {
                let document = DocumentItem(url: url)
                documents.append(document)
                selectedDocumentURL = nil
            }
        }
        .onChange(of: selectedItems) { _, newItems in
            loadSelectedImages(from: newItems)
        }
    }
    
    private func updateDocumentName(document: DocumentItem, newName: String) {
        if let index = documents.firstIndex(where: { $0.id == document.id }) {
            let updatedDocument = DocumentItem(url: document.url, name: newName)
            documents[index] = updatedDocument
        }
    }
    
    private func deleteDocument(document: DocumentItem) {
        documents.removeAll { $0.id == document.id }
    }
    
    private func loadSelectedImages(from items: [PhotosPickerItem]) {
        Task {
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    // Create a temporary file
                    let tempDirectory = FileManager.default.temporaryDirectory
                    let fileName = UUID().uuidString + ".jpg"
                    let fileURL = tempDirectory.appendingPathComponent(fileName)
                    
                    if let jpegData = image.jpegData(compressionQuality: 0.7) {
                        try? jpegData.write(to: fileURL)
                        
                        DispatchQueue.main.async {
                            let document = DocumentItem(url: fileURL, name: "Photo \(self.documents.count + 1)")
                            self.documents.append(document)
                        }
                    }
                }
            }
            // Clear selection after processing
            selectedItems = []
        }
    }
}

struct DocumentItemRow: View {
    let document: DocumentItem
    let onNameChange: (String) -> Void
    let onDelete: () -> Void
    
    @State private var documentName: String
    
    init(document: DocumentItem, onNameChange: @escaping (String) -> Void, onDelete: @escaping () -> Void) {
        self.document = document
        self.onNameChange = onNameChange
        self.onDelete = onDelete
        _documentName = State(initialValue: document.name)
    }
    
    var body: some View {
        HStack {
            if let image = document.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 60)
                    .cornerRadius(4)
            } else {
                Image(systemName: document.type.iconName)
                    .font(.largeTitle)
                    .foregroundColor(document.type.color)
                    .frame(width: 60, height: 60)
            }
            
            TextField("Document Name", text: $documentName)
                .onChange(of: documentName) { _, newValue in
                    onNameChange(newValue)
                }
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}
