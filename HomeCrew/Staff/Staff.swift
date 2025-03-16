import Foundation
import CloudKit

struct Staff: Identifiable {
    let id: CKRecord.ID
    let householdReference: CKRecord.Reference
    let fullLegalName: String
    let commonlyKnownAs: String?
    let startingDate: Date
    let leavingDate: Date?
    let leavesAllocated: Int
    let monthlySalary: Double
    let currencyCode: String
    let agreedDuties: String
    let isActive: Bool
    
    // Computed properties for display
    var displayName: String {
        commonlyKnownAs?.isEmpty == false ? commonlyKnownAs! : fullLegalName
    }
    
    var formattedSalary: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSNumber(value: monthlySalary)) ?? "\(currencyCode) \(monthlySalary)"
    }
    
    var employmentStatus: String {
        isActive ? "Active" : "Inactive"
    }
    
    var employmentDuration: String {
        let endDate = leavingDate ?? Date()
        let components = Calendar.current.dateComponents([.year, .month], from: startingDate, to: endDate)
        
        if let years = components.year, let months = components.month {
            if years > 0 {
                return "\(years) year\(years == 1 ? "" : "s"), \(months) month\(months == 1 ? "" : "s")"
            } else {
                return "\(months) month\(months == 1 ? "" : "s")"
            }
        }
        
        return "Unknown"
    }
    
    init(record: CKRecord) {
        self.id = record.recordID
        self.householdReference = record["householdID"] as! CKRecord.Reference
        self.fullLegalName = record["fullLegalName"] as! String
        self.commonlyKnownAs = record["commonlyKnownAs"] as? String
        self.startingDate = record["startingDate"] as! Date
        self.leavingDate = record["leavingDate"] as? Date
        self.leavesAllocated = record["leavesAllocated"] as? Int ?? 12
        self.monthlySalary = record["monthlySalary"] as? Double ?? 0.0
        self.currencyCode = record["currencyCode"] as? String ?? "USD"
        self.agreedDuties = record["agreedDuties"] as? String ?? ""
        self.isActive = record["isActive"] as? Bool ?? true
    }
    
    // Helper method to get household ID
    var householdID: CKRecord.ID {
        return householdReference.recordID
    }
}

// Extension for sorting and filtering
extension Staff {
    static func sortedByName(_ staffList: [Staff]) -> [Staff] {
        return staffList.sorted { $0.fullLegalName.lowercased() < $1.fullLegalName.lowercased() }
    }
    
    static func filterActive(_ staffList: [Staff], includeInactive: Bool = false) -> [Staff] {
        if includeInactive {
            return staffList
        } else {
            return staffList.filter { $0.isActive }
        }
    }
}
