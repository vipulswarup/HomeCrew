import SwiftUI
import UniformTypeIdentifiers
import os.log

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?
    var allowedContentTypes: [UTType]
    
    // Logger for document picker operations
    private let logger = Logger(subsystem: "com.homecrew.documents", category: "DocumentPicker")
    
    func makeUIViewController(context: Context) -> UIViewController {
        logger.info("Creating DocumentPicker with allowed content types: \(allowedContentTypes.map { $0.identifier })")
        
        // Use UIDocumentPickerViewController for both iOS and Mac Catalyst
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedContentTypes, asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        picker.shouldShowFileExtensions = true
        
        // Set presentation style for better compatibility
        picker.modalPresentationStyle = .formSheet
        
        logger.info("DocumentPicker configured with delegate: \(picker.delegate != nil)")
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Ensure the delegate is set if the view controller is recreated
        if let picker = uiViewController as? UIDocumentPickerViewController {
            if picker.delegate == nil {
                picker.delegate = context.coordinator
                logger.info("Re-set delegate on picker during update")
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        logger.info("Creating Coordinator")
        return Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        // Logger for document operations
        private let logger = Logger(subsystem: "com.homecrew.documents", category: "DocumentPicker")
        
        // Track security-scoped resource access
        private var securityScopedURLs: [URL] = []
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
            super.init()
            logger.info("DocumentPicker Coordinator initialized")
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            logger.info("documentPicker didPickDocumentsAt called with \(urls.count) URLs")
            
            guard let url = urls.first else { 
                logger.warning("No URL selected in document picker")
                return 
            }
            
            logger.info("Document selected: \(url.lastPathComponent)")
            logger.info("File extension: \(url.pathExtension)")
            logger.info("File path: \(url.path)")
            
            // Start accessing the security-scoped resource
            let hasAccess = url.startAccessingSecurityScopedResource()
            logger.info("Security-scoped resource access: \(hasAccess)")
            
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            // Verify file exists and is readable
            guard FileManager.default.fileExists(atPath: url.path) else {
                logger.error("Selected file does not exist at path: \(url.path)")
                return
            }
            
            guard FileManager.default.isReadableFile(atPath: url.path) else {
                logger.error("Selected file is not readable at path: \(url.path)")
                return
            }
            
            // Check if it's a PDF specifically
            if url.pathExtension.lowercased() == "pdf" {
                logger.info("PDF file detected: \(url.lastPathComponent)")
            }
            
            // When using asCopy: true, the file is already copied to a temporary location
            // We need to copy it to our own temp directory to ensure it persists
            let uniqueFilename = "\(UUID().uuidString)_\(url.lastPathComponent)"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(uniqueFilename)
            logger.info("Temporary URL: \(tempURL.path)")
            
            // Copy the document synchronously
            if copyDocument(from: url, to: tempURL) {
                logger.info("Document copied successfully to: \(tempURL.path)")
                // Verify the copy exists before setting it
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    // Update on main thread
                    DispatchQueue.main.async {
                        self.parent.selectedURL = tempURL
                        self.logger.info("selectedURL set to: \(tempURL.path)")
                        // Dismiss the picker
                        controller.dismiss(animated: true) {
                            self.logger.info("Document picker dismissed after selection")
                        }
                    }
                } else {
                    logger.error("Copy completed but file not found at destination: \(tempURL.path)")
                }
            } else {
                logger.error("Failed to copy document from \(url.path) to \(tempURL.path)")
            }
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
            logger.info("documentPicker didPickDocumentAt called with URL: \(url.path)")
            // This is the older delegate method, call the newer one
            documentPicker(controller, didPickDocumentsAt: [url])
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            logger.info("Document picker was cancelled")
            // Dismiss the picker
            DispatchQueue.main.async {
                controller.dismiss(animated: true)
            }
        }
        
        private func copyDocument(from sourceURL: URL, to destinationURL: URL) -> Bool {
            do {
                // Verify source file exists
                guard FileManager.default.fileExists(atPath: sourceURL.path) else {
                    logger.error("Source file does not exist: \(sourceURL.path)")
                    return false
                }
                
                // Remove any existing file at destination
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                // Copy the file
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                
                // Verify the copy was successful
                guard FileManager.default.fileExists(atPath: destinationURL.path) else {
                    logger.error("File copy completed but destination file not found")
                    return false
                }
                
                logger.info("Document copied successfully: \(sourceURL.lastPathComponent)")
                return true
            } catch {
                logger.error("Error copying document: \(error.localizedDescription)")
                return false
            }
        }
        
        deinit {
            // Clean up security-scoped resource access
            for url in securityScopedURLs {
                url.stopAccessingSecurityScopedResource()
            }
        }
    }
}

