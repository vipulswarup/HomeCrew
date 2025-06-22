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
        if isImage {
            // Try to load from cache first
            if let cachedImage = ImageCache.shared.get(forKey: id.recordName) {
                return cachedImage
            }
            
            // If not in cache, try to load from file URL
            if let fileURL = fileURL, let image = UIImage(contentsOfFile: fileURL.path) {
                ImageCache.shared.set(image, forKey: id.recordName)
                return image
            }
            
            // If file URL fails, try to load from asset
            if let asset = asset, let assetURL = asset.fileURL, let image = UIImage(contentsOfFile: assetURL.path) {
                ImageCache.shared.set(image, forKey: id.recordName)
                return image
            }
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

// MARK: - Image Cache

class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        cache.countLimit = 100 // Maximum number of images to cache
        
        // Create cache directory if it doesn't exist
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = cachesDirectory.appendingPathComponent("ImageCache")
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func set(_ image: UIImage, forKey key: String) {
        // Save to memory cache
        cache.setObject(image, forKey: key as NSString)
        
        // Save to disk cache
        let fileURL = cacheDirectory.appendingPathComponent(key)
        if let data = image.jpegData(compressionQuality: 0.7) {
            try? data.write(to: fileURL)
        }
    }
    
    func get(forKey key: String) -> UIImage? {
        // Try memory cache first
        if let cachedImage = cache.object(forKey: key as NSString) {
            return cachedImage
        }
        
        // Try disk cache
        let fileURL = cacheDirectory.appendingPathComponent(key)
        if let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            // Add to memory cache
            cache.setObject(image, forKey: key as NSString)
            return image
        }
        
        return nil
    }
    
    func clear() {
        cache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}

// MARK: - Document Display

extension StaffDocument {
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
