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
        
        let group = DispatchGroup()
        var documentReferences: [CKRecord.Reference] = []
        var saveError: Error?
        
        // First verify that the staff record exists
        privateDatabase.fetch(withRecordID: staffID) { record, error in
            if let error = error {
                self.logger.error("Failed to fetch staff record for document saving: \(error.localizedDescription)")
                completion(error)
                return
            }
            
            guard record != nil else {
                let error = NSError(domain: "StaffDocumentManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Staff record not found"])
                self.logger.error("Staff record not found for document saving")
                completion(error)
                return
            }
            
            // Save each document
            for document in documents {
                group.enter()
                
                // Create document record
                let documentRecord = CKRecord(recordType: "StaffDocument")
                documentRecord["staffID"] = CKRecord.Reference(recordID: staffID, action: .deleteSelf)
                documentRecord["name"] = document.name
                documentRecord["document"] = CKAsset(fileURL: document.url)
                
                // Save document record
                self.privateDatabase.save(documentRecord) { savedDoc, error in
                    defer {
                        group.leave()
                    }
                    
                    if let error = error {
                        self.logger.error("Failed to save document record: \(error.localizedDescription)")
                        saveError = error
                        return
                    }
                    
                    if let savedDoc = savedDoc {
                        let reference = CKRecord.Reference(recordID: savedDoc.recordID, action: .deleteSelf)
                        documentReferences.append(reference)
                        self.logger.info("Successfully saved document: \(document.name)")
                    }
                }
            }
            
            // Update staff record with document references if needed
            group.notify(queue: .main) {
                if let error = saveError {
                    completion(error)
                    return
                }
                
                if !documentReferences.isEmpty {
                    // Fetch the staff record again to ensure we have the latest version
                    self.privateDatabase.fetch(withRecordID: staffID) { record, error in
                        if let error = error {
                            self.logger.error("Failed to fetch staff record for reference update: \(error.localizedDescription)")
                            completion(error)
                            return
                        }
                        
                        guard var staffRecord = record else {
                            let error = NSError(domain: "StaffDocumentManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Staff record not found during reference update"])
                            self.logger.error("Staff record not found during reference update")
                            completion(error)
                            return
                        }
                        
                        // Get existing references or create new array
                        var existingReferences = staffRecord["idCards"] as? [CKRecord.Reference] ?? []
                        existingReferences.append(contentsOf: documentReferences)
                        
                        // Update the record with document references
                        staffRecord["idCards"] = existingReferences
                        
                        // Save the updated record
                        self.privateDatabase.save(staffRecord) { _, error in
                            if let error = error {
                                self.logger.error("Failed to save staff record with document references: \(error.localizedDescription)")
                            } else {
                                self.logger.info("Successfully updated staff record with \(documentReferences.count) document references")
                            }
                            completion(error)
                        }
                    }
                } else {
                    completion(nil)
                }
            }
        }
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
