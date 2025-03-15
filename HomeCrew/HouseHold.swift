//
//  HouseHold.swift
//  HomeCrew
//
//  Created by Vipul Swarup on 09/03/25.
//

import SwiftUI
import CloudKit

struct HouseHoldModel: Identifiable {
    var id: CKRecord.ID
    var name: String
    var address: String
    
    init(record: CKRecord) {
        self.id = record.recordID
        self.name = record["name"] as? String ?? "Unknown"
        self.address = record["address"] as? String ?? "No address"
    }
    
    /// Convert back to CKRecord for saving
    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: "HouseHold", recordID: id)
        record["name"] = name as CKRecordValue
        record["address"] = address as CKRecordValue
        return record
    }
}

/// ViewModel to manage CloudKit data operations for HouseHold
class HouseHoldViewModel: ObservableObject {
    @Published var houseHolds: [HouseHoldModel] = []
    private let database = CKContainer.default().publicCloudDatabase

    /// Fetches all households from CloudKit
    func fetchHouseHolds() {
        let query = CKQuery(recordType: "HouseHold", predicate: NSPredicate(value: true))
        let operation = CKQueryOperation(query: query)
        
        operation.resultsLimit = CKQueryOperation.maximumResults
        var fetchedHouseHolds: [HouseHoldModel] = []

        // Fetch records asynchronously
        operation.recordMatchedBlock = { recordID, result in
            switch result {
            case .success(let record):
                DispatchQueue.main.async {
                    fetchedHouseHolds.append(HouseHoldModel(record: record))
                }
            case .failure(let error):
                print("Error fetching record \(recordID): \(error.localizedDescription)")
            }
        }

        // Update UI only once after fetching all records
        operation.queryResultBlock = { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.houseHolds = fetchedHouseHolds
                case .failure(let error):
                    print("Error completing query: \(error.localizedDescription)")
                }
            }
        }

        database.add(operation)
    }

    /// Adds a new household record to CloudKit
    func addHouseHold(name: String, address: String) {
        let record = CKRecord(recordType: "HouseHold")
        record["name"] = name as CKRecordValue
        record["address"] = address as CKRecordValue
        
        database.save(record) { savedRecord, error in
            DispatchQueue.main.async {
                if let savedRecord = savedRecord {
                    print("Successfully saved household: \(savedRecord)")
                }
                
                if let error = error {
                    print("Error saving household: \(error.localizedDescription)")
                }

                // Always refresh from CloudKit after adding a household
                self.fetchHouseHolds()
            }
        }
    }
}
