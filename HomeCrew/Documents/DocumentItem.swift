import SwiftUI
import UniformTypeIdentifiers
import os.log

struct DocumentItem: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let type: DocumentType
    var image: UIImage?
    
    enum DocumentType {
        case image
        case pdf
        case other
        
        var iconName: String {
            switch self {
            case .image: return "photo"
            case .pdf: return "doc.text"
            case .other: return "doc"
            }
        }
        
        var color: Color {
            switch self {
            case .image: return .blue
            case .pdf: return .red
            case .other: return .gray
            }
        }
    }
    
    init(url: URL, name: String? = nil) {
        self.url = url
        self.name = name ?? url.lastPathComponent
        
        let logger = Logger(subsystem: "com.homecrew.documents", category: "DocumentItem")
        logger.info("Initializing DocumentItem for: \(url.path)")
        
        // Determine document type
        if let uti = UTType(filenameExtension: url.pathExtension) {
            logger.info("UTType for \(url.pathExtension): \(uti.identifier)")
            
            if uti.conforms(to: .image) {
                self.type = .image
                logger.info("Document identified as image")
                // Try to load image preview
                self.image = UIImage(contentsOfFile: url.path)
            } else if uti.conforms(to: .pdf) {
                self.type = .pdf
                logger.info("Document identified as PDF")
                // For PDF, we could generate a thumbnail but that's more complex
            } else {
                self.type = .other
                logger.info("Document identified as other type")
            }
        } else {
            self.type = .other
            logger.warning("Could not determine UTType for extension: \(url.pathExtension)")
        }
        
        let typeString: String
        switch self.type {
        case .image: typeString = "image"
        case .pdf: typeString = "pdf"
        case .other: typeString = "other"
        }
        
        logger.info("DocumentItem created: (self.name), type: \(typeString)")
    }
}
