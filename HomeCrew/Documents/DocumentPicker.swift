import SwiftUI
import UniformTypeIdentifiers
import os.log
#if canImport(AppKit)
import AppKit
#endif

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?
    var allowedContentTypes: [UTType]
    
    // Logger for document picker operations
    private let logger = Logger(subsystem: "com.homecrew.documents", category: "DocumentPicker")
    
    func makeUIViewController(context: Context) -> UIViewController {
        logger.info("Creating DocumentPicker with allowed content types: \(allowedContentTypes.map { $0.identifier })")
        
        // Check if we're on Mac more explicitly
        let isMac = ProcessInfo.processInfo.isiOSAppOnMac || ProcessInfo.processInfo.isMacCatalystApp
        logger.info("Platform detection - isMac: \(isMac), isiOSAppOnMac: \(ProcessInfo.processInfo.isiOSAppOnMac), isMacCatalystApp: \(ProcessInfo.processInfo.isMacCatalystApp)")
        
        if isMac {
            // Use NSOpenPanel for Mac
            logger.info("Using NSOpenPanel for Mac")
            #if canImport(AppKit)
            let openPanel = NSOpenPanel()
            openPanel.allowsMultipleSelection = false
            openPanel.canChooseDirectories = false
            openPanel.canChooseFiles = true
            
            // Convert UTTypes to file extensions
            var allowedExtensions: [String] = []
            for utType in allowedContentTypes {
                if let extensions = utType.tags[.filenameExtension] as? [String] {
                    allowedExtensions.append(contentsOf: extensions)
                } else if let preferredExtension = utType.preferredFilenameExtension {
                    allowedExtensions.append(preferredExtension)
                }
            }
            
            logger.info("Allowed file extensions: \(allowedExtensions)")
            openPanel.allowedContentTypes = allowedExtensions
            
            // Show the panel
            openPanel.begin { response in
                if response == .OK {
                    if let url = openPanel.url {
                        logger.info("File selected via NSOpenPanel: \(url.path)")
                        self.handleSelectedFile(url)
                    }
                } else {
                    logger.info("NSOpenPanel was cancelled")
                }
            }
            #else
            logger.error("AppKit not available for NSOpenPanel")
            #endif
            
            // Return a dummy view controller since we're using NSOpenPanel
            return UIViewController()
        } else {
            // Use UIDocumentPickerViewController for iOS
            logger.info("Using UIDocumentPickerViewController for iOS")
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedContentTypes, asCopy: true)
            picker.allowsMultipleSelection = false
            picker.delegate = context.coordinator
            picker.shouldShowFileExtensions = true
            
            // Set presentation style for better compatibility
            picker.modalPresentationStyle = .formSheet
            
            logger.info("DocumentPicker configured with delegate: \(picker.delegate != nil)")
            return picker
        }
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        logger.info("Creating Coordinator")
        return Coordinator(self)
    }
    
    private func handleSelectedFile(_ url: URL) {
        logger.info("Handling selected file: \(url.lastPathComponent)")
        logger.info("File extension: \(url.pathExtension)")
        logger.info("File path: \(url.path)")
        
        // Check if it's a PDF specifically
        if url.pathExtension.lowercased() == "pdf" {
            logger.info("PDF file detected: \(url.lastPathComponent)")
        }
        
        // Create a local copy in the app's temporary directory
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
        logger.info("Temporary URL: \(tempURL.path)")
        
        // Copy the document synchronously
        if copyDocument(from: url, to: tempURL) {
            logger.info("Document copied successfully to: \(tempURL.path)")
            selectedURL = tempURL
        } else {
            logger.error("Failed to copy document from \(url.path) to \(tempURL.path)")
            // Try to use the original URL as fallback
            logger.info("Using original URL as fallback: \(url.path)")
            selectedURL = url
        }
    }
    
    private func copyDocument(from sourceURL: URL, to destinationURL: URL) -> Bool {
        do {
            // Remove any existing file at destination
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // Copy the file
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            logger.info("Document copied successfully: \(sourceURL.lastPathComponent)")
            return true
        } catch {
            logger.error("Error copying document: \(error.localizedDescription)")
            return false
        }
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        // Logger for document operations
        private let logger = Logger(subsystem: "com.homecrew.documents", category: "DocumentPicker")
        
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
            guard url.startAccessingSecurityScopedResource() else {
                logger.error("Failed to start accessing security-scoped resource")
                return
            }
            
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            // Check if it's a PDF specifically
            if url.pathExtension.lowercased() == "pdf" {
                logger.info("PDF file detected: \(url.lastPathComponent)")
            }
            
            // Create a local copy in the app's temporary directory
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
            logger.info("Temporary URL: \(tempURL.path)")
            
            // Copy the document synchronously
            if copyDocument(from: url, to: tempURL) {
                logger.info("Document copied successfully to: \(tempURL.path)")
                parent.selectedURL = tempURL
            } else {
                logger.error("Failed to copy document from \(url.path) to \(tempURL.path)")
                // Try to use the original URL as fallback
                logger.info("Using original URL as fallback: \(url.path)")
                parent.selectedURL = url
            }
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
            logger.info("documentPicker didPickDocumentAt called with URL: \(url.path)")
            // This is the older delegate method, call the newer one
            documentPicker(controller, didPickDocumentsAt: [url])
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            logger.info("Document picker was cancelled")
            logger.info("Picker controller: \(controller)")
            logger.info(<#OSLogMessage#>"Picker delegate: \(controller.delegate != nil ? \"set\" : \"nil\")")
        }
        
        private func copyDocument(from sourceURL: URL, to destinationURL: URL) -> Bool {
            do {
                // Remove any existing file at destination
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                // Copy the file
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                logger.info("Document copied successfully: \(sourceURL.lastPathComponent)")
                return true
            } catch {
                logger.error("Error copying document: \(error.localizedDescription)")
                return false
            }
        }
    }
}
