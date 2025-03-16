//
//  StaffDocumentManager.swift
//  HomeCrew
//
//  Created by Vipul Swarup on 16/03/25.
//


import Foundation
import CloudKit
import UIKit

class StaffDocumentManager {
    private let privateDatabase = CKContainer.default().privateCloudDatabase
    
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
                print("Error fetching document record: \(error.localizedDescription)")
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
        let group = DispatchGroup()
        var documentReferences: [CKRecord.Reference] = []
        var saveError: Error?
        
        // Save each document
        for document in documents {
            group.enter()
            
            do {
                // Create document record
                let documentRecord = CKRecord(recordType: "StaffDocument")
                documentRecord["staffID"] = CKRecord.Reference(recordID: staffID, action: .deleteSelf)
                documentRecord["name"] = document.name
                documentRecord["document"] = CKAsset(fileURL: document.url)
                
                // Save document record
                privateDatabase.save(documentRecord) { savedDoc, error in
                    defer {
                        group.leave()
                    }
                    
                    if let error = error {
                        saveError = error
                        return
                    }
                    
                    if let savedDoc = savedDoc {
                        let reference = CKRecord.Reference(recordID: savedDoc.recordID, action: .deleteSelf)
                        documentReferences.append(reference)
                    }
                }
            } catch {
                saveError = error
                group.leave()
            }
        }
        
        // Update staff record with document references if needed
        group.notify(queue: .main) {
            if let error = saveError {
                completion(error)
                return
            }
            
            if !documentReferences.isEmpty {
                // Fetch the staff record first
                self.privateDatabase.fetch(withRecordID: staffID) { record, error in
                    if let error = error {
                        completion(error)
                        return
                    }
                    
                    guard var staffRecord = record else {
                        completion(NSError(domain: "StaffDocumentManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Staff record not found"]))
                        return
                    }
                    
                    // Update the record with document references
                    staffRecord["idCards"] = documentReferences
                    
                    // Save the updated record
                    self.privateDatabase.save(staffRecord) { _, error in
                        completion(error)
                    }
                }
            } else {
                completion(nil)
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
