//
//  StaffDocument.swift
//  HomeCrew
//
//  Created by Vipul Swarup on 16/03/25.
//


import Foundation
import CloudKit
import UIKit
import SwiftUI 

struct StaffDocument: Identifiable {
    let id: CKRecord.ID
    let staffReference: CKRecord.Reference
    let name: String
    let fileURL: URL?
    let asset: CKAsset?
    
    var fileType: String {
        fileURL?.pathExtension.lowercased() ?? ""
    }
    
    var isImage: Bool {
        ["jpg", "jpeg", "png", "heic", "heif"].contains(fileType)
    }
    
    var isPDF: Bool {
        fileType == "pdf"
    }
    
    var thumbnailImage: UIImage? {
        if isImage, let fileURL = fileURL {
            return UIImage(contentsOfFile: fileURL.path)
        }
        return nil
    }
    
    var iconName: String {
        if isImage {
            return "photo"
        } else if isPDF {
            return "doc.text.fill"
        } else {
            return "doc.fill"
        }
    }
    
    var iconColor: UIColor {
        if isImage {
            return .systemBlue
        } else if isPDF {
            return .systemRed
        } else {
            return .systemGray
        }
    }
    
    init(record: CKRecord) {
        self.id = record.recordID
        self.staffReference = record["staffID"] as! CKRecord.Reference
        self.name = record["name"] as? String ?? "Document"
        self.asset = record["document"] as? CKAsset
        
        if let asset = self.asset {
            self.fileURL = asset.fileURL
        } else {
            self.fileURL = nil
        }
    }
    
    // Helper method to get staff ID
    var staffID: CKRecord.ID {
        return staffReference.recordID
    }
}

// Extension to handle document display
extension StaffDocument {
    // Create a view for displaying this document
    @ViewBuilder
    func documentView() -> some View {
        if isImage, let image = thumbnailImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .cornerRadius(8)
        } else {
            HStack {
                Image(systemName: iconName)
                    .font(.largeTitle)
                    .foregroundColor(Color(iconColor))
                
                Text(name)
                    .lineLimit(1)
                
                Spacer()
                
                if isPDF {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 8)
        }
    }
}
