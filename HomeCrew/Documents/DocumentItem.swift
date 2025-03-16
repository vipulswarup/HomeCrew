import SwiftUI
import UniformTypeIdentifiers

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
        
        // Determine document type
        if let uti = UTType(filenameExtension: url.pathExtension) {
            if uti.conforms(to: .image) {
                self.type = .image
                // Try to load image preview
                self.image = UIImage(contentsOfFile: url.path)
            } else if uti.conforms(to: .pdf) {
                self.type = .pdf
                // For PDF, we could generate a thumbnail but that's more complex
            } else {
                self.type = .other
            }
        } else {
            self.type = .other
        }
    }
}
