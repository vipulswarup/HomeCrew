//
//  Staff.swift
//  HomeCrew
//
//  Created by Vipul Swarup on 16/03/25.
//


import Foundation
import CloudKit

struct Staff: Identifiable {
    let id: CKRecord.ID
    let householdReference: CKRecord.Reference
    // Computed property to get the actual ID
       var householdID: CKRecord.ID {
           return householdReference.recordID
       }
    // Mandatory fields
    var fullLegalName: String
    var startingDate: Date
    var leavesAllocated: Int
    var monthlySalary: Double
    var currencyCode: String
    var agreedDuties: String
    
    // Optional fields
    var commonlyKnownAs: String?
    var leavingDate: Date?
    var isActive: Bool
    
    // Document references
    var idCardReferences: [CKRecord.Reference]
    
    init(record: CKRecord) {
        self.id = record.recordID
        self.householdReference = record["householdID"] as! CKRecord.Reference
        
        self.fullLegalName = record["fullLegalName"] as? String ?? ""
        self.startingDate = record["startingDate"] as? Date ?? Date()
        self.leavesAllocated = record["leavesAllocated"] as? Int ?? 0
        self.monthlySalary = record["monthlySalary"] as? Double ?? 0.0
        self.currencyCode = record["currencyCode"] as? String ?? "INR"
        self.agreedDuties = record["agreedDuties"] as? String ?? ""
        
        self.commonlyKnownAs = record["commonlyKnownAs"] as? String
        self.leavingDate = record["leavingDate"] as? Date
        self.isActive = record["isActive"] as? Bool ?? true
        
        if let references = record["idCards"] as? [CKRecord.Reference] {
            self.idCardReferences = references
        } else {
            self.idCardReferences = []
        }
    }
    
    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: "Staff")
        
        // Set all properties
        record["householdID"] = householdReference  // Use the reference directly
        record["fullLegalName"] = fullLegalName
        record["startingDate"] = startingDate
        record["leavesAllocated"] = leavesAllocated
        record["monthlySalary"] = monthlySalary
        record["currencyCode"] = currencyCode
        record["agreedDuties"] = agreedDuties
        record["isActive"] = isActive
        
        // Set optional properties
        if let commonlyKnownAs = commonlyKnownAs {
            record["commonlyKnownAs"] = commonlyKnownAs
        }
        
        if let leavingDate = leavingDate {
            record["leavingDate"] = leavingDate
        }
        
        // ID card references will be handled separately
        
        return record
    }
    
    // Helper computed properties
    var displayName: String {
        return commonlyKnownAs ?? fullLegalName
    }
    
    var formattedSalary: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSNumber(value: monthlySalary)) ?? "\(currencyCode) \(monthlySalary)"
    }
    
    var employmentStatus: String {
        if isActive {
            return "Active"
        } else {
            if let leavingDate = leavingDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return "Left on \(formatter.string(from: leavingDate))"
            } else {
                return "Inactive"
            }
        }
    }
}

// Document model for ID Cards
struct StaffDocument: Identifiable {
    let id: CKRecord.ID
    let staffReference: CKRecord.Reference  // Changed from staffID: CKRecord.ID
    
    // Computed property to get the actual ID
    var staffID: CKRecord.ID {
        return staffReference.recordID
    }
    
    let name: String
    let fileURL: URL?
    let asset: CKAsset?
    
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
}
