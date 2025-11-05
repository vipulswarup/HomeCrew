//
//  StaffDocumentManager.swift
//  HomeCrew
//
//  Created by Vipul Swarup on 16/03/25.
//


import Foundation
import CloudKit
import UIKit
import os.log

class StaffDocumentManager {
    private let privateDatabase = CKContainer.default().privateCloudDatabase
    
    // Logger for document operations
    private let logger = Logger(subsystem: "com.homecrew.documents", category: "StaffDocumentManager")
    
    // MARK: - Fetch Documents
    
    func fetchDocuments(for staffID: CKRecord.ID, completion: @escaping ([StaffDocument]?, Error?) -> Void) {
        // Create a reference to the staff
        let staffReference = CKRecord.Reference(recordID: staffID, action: .none)
        
        // Query documents for this staff
        let predicate = NSPredicate(format: "staffID == %@", staffReference)
        let query = CKQuery(recordType: "StaffDocument", predicate: predicate)
        
        let operation = CKQueryOperation(query: query)
        
        var fetchedDocuments: [StaffDocument] = []
        
        operation.recordMatchedBlock = { (recordID, result) in
            switch result {
            case .success(let record):
                let document = StaffDocument(record: record)
                fetchedDocuments.append(document)
            case .failure(let error):
                self.logger.error("Error fetching document record: \(error.localizedDescription)")
            }
        }
        
        operation.queryResultBlock = { result in
            switch result {
            case .success:
                // Sort documents by name
                let sortedDocuments = fetchedDocuments.sorted { $0.name < $1.name }
                completion(sortedDocuments, nil)
            case .failure(let error):
                completion(nil, error)
            }
        }
        
        privateDatabase.add(operation)
    }
    
    // MARK: - Save Documents
    
    func saveDocuments(documents: [DocumentItem], for staffID: CKRecord.ID, completion: @escaping (Error?) -> Void) {
        // If no documents to save, just complete successfully
        if documents.isEmpty {
            completion(nil)
            return
        }
        
        // Validate all files exist before starting uploads
        var validationErrors: [String] = []
        for document in documents {
            let fileExists = FileManager.default.fileExists(atPath: document.url.path)
            if !fileExists {
                validationErrors.append("File not found: \(document.name)")
                logger.error("Document file does not exist: \(document.url.path)")
            } else {
                // Verify file is readable
                guard FileManager.default.isReadableFile(atPath: document.url.path) else {
                    validationErrors.append("File not readable: \(document.name)")
                    logger.error("Document file is not readable: \(document.url.path)")
                    continue
                }
            }
        }
        
        if !validationErrors.isEmpty {
            let errorMessage = "One or more documents are invalid:\n" + validationErrors.joined(separator: "\n")
            let error = NSError(domain: "StaffDocumentManager", code: 400, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            logger.error("Document validation failed: \(errorMessage)")
            completion(error)
            return
        }
        
        // First verify that the staff record exists
        privateDatabase.fetch(withRecordID: staffID) { record, error in
            if let error = error {
                let ckError = self.handleCloudKitError(error)
                self.logger.error("Failed to fetch staff record for document saving: \(ckError.localizedDescription)")
                completion(ckError)
                return
            }
            
            guard record != nil else {
                let error = NSError(domain: "StaffDocumentManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Staff record not found"])
                self.logger.error("Staff record not found for document saving")
                completion(error)
                return
            }
            
            // Save documents with improved error handling
            self.saveDocumentsToCloudKit(documents: documents, for: staffID, completion: completion)
        }
    }
    
    private func saveDocumentsToCloudKit(documents: [DocumentItem], for staffID: CKRecord.ID, completion: @escaping (Error?) -> Void) {
        let group = DispatchGroup()
        var saveResults: [(success: Bool, documentName: String, error: Error?)] = []
        let lock = NSLock()
        
        // Save each document
        for document in documents {
            group.enter()
            
            // Verify file still exists before creating CKAsset
            guard FileManager.default.fileExists(atPath: document.url.path) else {
                let error = NSError(domain: "StaffDocumentManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "File not found: \(document.name)"])
                lock.lock()
                saveResults.append((success: false, documentName: document.name, error: error))
                lock.unlock()
                self.logger.error("File no longer exists when attempting upload: \(document.url.path)")
                group.leave()
                continue
            }
            
            // Create document record
            let documentRecord = CKRecord(recordType: "StaffDocument")
            documentRecord["staffID"] = CKRecord.Reference(recordID: staffID, action: .deleteSelf)
            documentRecord["name"] = document.name
            
            // Create CKAsset with file URL - ensure file is accessible
            let asset = CKAsset(fileURL: document.url)
            documentRecord["document"] = asset
            
            // Save document record
            self.privateDatabase.save(documentRecord) { savedDoc, error in
                defer {
                    group.leave()
                }
                
                lock.lock()
                if let error = error {
                    let ckError = self.handleCloudKitError(error)
                    self.logger.error("Failed to save document '\(document.name)': \(ckError.localizedDescription)")
                    saveResults.append((success: false, documentName: document.name, error: ckError))
                } else if savedDoc != nil {
                    self.logger.info("Successfully saved document: \(document.name)")
                    saveResults.append((success: true, documentName: document.name, error: nil))
                } else {
                    let error = NSError(domain: "StaffDocumentManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error saving document: \(document.name)"])
                    saveResults.append((success: false, documentName: document.name, error: error))
                }
                lock.unlock()
            }
        }
        
        // Wait for all uploads to complete
        group.notify(queue: .main) {
            let failures = saveResults.filter { !$0.success }
            let successes = saveResults.filter { $0.success }
            
            if failures.isEmpty {
                // All documents saved successfully
                self.logger.info("Successfully saved all \(successes.count) documents")
                completion(nil)
            } else {
                // Some documents failed - provide detailed error message
                let failureNames = failures.map { $0.documentName }
                let errorMessages = failures.compactMap { $0.error?.localizedDescription }
                
                var errorMessage = "Failed to save \(failures.count) of \(documents.count) documents:\n"
                errorMessage += failureNames.joined(separator: ", ")
                
                if !errorMessages.isEmpty {
                    errorMessage += "\n\nErrors:\n" + errorMessages.joined(separator: "\n")
                }
                
                let error = NSError(domain: "StaffDocumentManager", code: 500, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                self.logger.error("Document save completed with failures: \(errorMessage)")
                completion(error)
            }
        }
    }
    
    private func handleCloudKitError(_ error: Error) -> Error {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .networkUnavailable, .networkFailure:
                return NSError(domain: "StaffDocumentManager", code: ckError.code.rawValue, userInfo: [NSLocalizedDescriptionKey: "Network error. Please check your connection and try again."])
            case .serviceUnavailable:
                return NSError(domain: "StaffDocumentManager", code: ckError.code.rawValue, userInfo: [NSLocalizedDescriptionKey: "iCloud service is currently unavailable. Please try again later."])
            case .notAuthenticated:
                return NSError(domain: "StaffDocumentManager", code: ckError.code.rawValue, userInfo: [NSLocalizedDescriptionKey: "Please sign in to your iCloud account in Settings."])
            case .quotaExceeded:
                return NSError(domain: "StaffDocumentManager", code: ckError.code.rawValue, userInfo: [NSLocalizedDescriptionKey: "Your iCloud storage is full. Please free up space and try again."])
            case .assetFileNotFound:
                return NSError(domain: "StaffDocumentManager", code: ckError.code.rawValue, userInfo: [NSLocalizedDescriptionKey: "Document file not found. Please reselect the document."])
            case .assetFileModified:
                return NSError(domain: "StaffDocumentManager", code: ckError.code.rawValue, userInfo: [NSLocalizedDescriptionKey: "Document file was modified. Please reselect the document."])
            default:
                return NSError(domain: "StaffDocumentManager", code: ckError.code.rawValue, userInfo: [NSLocalizedDescriptionKey: "CloudKit error: \(ckError.localizedDescription)"])
            }
        }
        return error
    }
    
    // MARK: - Delete Documents
    
    func deleteDocuments(with recordIDs: [CKRecord.ID], completion: @escaping (Error?) -> Void) {
        if recordIDs.isEmpty {
            completion(nil)
            return
        }
        
        let group = DispatchGroup()
        var deleteError: Error?
        
        for documentID in recordIDs {
            group.enter()
            
            privateDatabase.delete(withRecordID: documentID) { _, error in
                if let error = error {
                    deleteError = error
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(deleteError)
        }
    }
    
    // MARK: - Convert StaffDocument to DocumentItem
    
    func convertToDocumentItems(from staffDocuments: [StaffDocument]) -> [DocumentItem] {
        return staffDocuments.compactMap { document in
            guard let fileURL = document.fileURL else { return nil }
            return DocumentItem(url: fileURL, name: document.name)
        }
    }
}
