import SwiftUI
import UniformTypeIdentifiers
import os.log

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?
    var allowedContentTypes: [UTType]
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedContentTypes, asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        // Logger for document operations
        private let logger = Logger(subsystem: "com.homecrew.documents", category: "DocumentPicker")
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Create a local copy in the app's temporary directory
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
            
            copyDocument(from: url, to: tempURL)
            parent.selectedURL = tempURL
        }
        
        private func copyDocument(from sourceURL: URL, to destinationURL: URL) {
            do {
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                logger.info("Document copied successfully: \(sourceURL.lastPathComponent)")
            } catch {
                logger.error("Error copying document: \(error.localizedDescription)")
            }
        }
    }
}
