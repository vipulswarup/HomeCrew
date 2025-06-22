import SwiftUI
import CloudKit
import PhotosUI

struct AddStaffView: View {
    let household: HouseHold
    var onStaffAdded: () -> Void
    
    @Environment(\.dismiss) var dismiss
    
    // Form fields
    @State private var fullLegalName: String = ""
    @State private var commonlyKnownAs: String = ""
    @State private var startingDate: Date = Date()
    @State private var leavesAllocated: String = "12"
    @State private var monthlySalary: String = ""
    @State private var currencyCode: String = "INR"
    @State private var agreedDuties: String = ""
    
    // ID Card documents
    @State private var documents: [DocumentItem] = []
    
    // Form state
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?
    @State private var showingCurrencyPicker = false
    
    // Available currencies
    let currencies = Locale.Currency.isoCurrencies.map { $0.identifier }.sorted()
    
    // Document manager
    private let documentManager = StaffDocumentManager()
    
    // CloudKit
    private let privateDatabase = CKContainer.default().privateCloudDatabase
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Personal Information")) {
                    TextField("Full Legal Name", text: $fullLegalName)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Commonly Known As (Optional)", text: $commonlyKnownAs)
                        .textInputAutocapitalization(.words)
                }
                
                Section(header: Text("Employment Details")) {
                    DatePicker("Starting Date", selection: $startingDate, displayedComponents: .date)
                    
                    TextField("Annual Leaves Allocated", text: $leavesAllocated)
                        .keyboardType(.numberPad)
                    
                    HStack {
                        TextField("Monthly Salary", text: $monthlySalary)
                            .keyboardType(.decimalPad)
                        
                        Spacer()
                        
                        Button(currencyCode) {
                            showingCurrencyPicker = true
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    if showingCurrencyPicker {
                        Picker("Currency", selection: $currencyCode) {
                            ForEach(currencies, id: \.self) { currency in
                                Text(currency)
                            }
                        }
                        .pickerStyle(.wheel)
                    }
                }
                
                Section(header: Text("Agreed Duties")) {
                    TextEditor(text: $agreedDuties)
                        .frame(minHeight: 100)
                }
                
                Section(header: Text("ID Documents (Required)")) {
                    DocumentSelectionView(documents: $documents)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                
                Section {
                    Button(action: saveStaffMember) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save Staff Member")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding()
                    .disabled(isSaving || !isFormValid)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Add Staff Member")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !fullLegalName.isEmpty &&
        !monthlySalary.isEmpty &&
        !agreedDuties.isEmpty &&
        !documents.isEmpty &&
        (Double(monthlySalary) ?? 0) > 0 &&
        (Int(leavesAllocated) ?? 0) >= 0
    }
    
    private func saveStaffMember() {
        guard isFormValid else { return }
        
        isSaving = true
        errorMessage = nil
        
        // Create staff record
        let staffRecord = CKRecord(recordType: "Staff")
        
        // Set household reference
        staffRecord["householdID"] = CKRecord.Reference(recordID: household.id, action: .deleteSelf)
        
        // Set mandatory fields
        staffRecord["fullLegalName"] = fullLegalName
        staffRecord["startingDate"] = startingDate
        staffRecord["leavesAllocated"] = Int(leavesAllocated) ?? 12
        staffRecord["monthlySalary"] = Double(monthlySalary) ?? 0.0
        staffRecord["currencyCode"] = currencyCode
        staffRecord["agreedDuties"] = agreedDuties
        staffRecord["isActive"] = true
        
        // Set optional fields
        if !commonlyKnownAs.isEmpty {
            staffRecord["commonlyKnownAs"] = commonlyKnownAs
        }
        
        // Save the staff record first
        privateDatabase.save(staffRecord) { savedRecord, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to save staff: \(error.localizedDescription)"
                    self.isSaving = false
                }
                return
            }
            
            guard let savedRecord = savedRecord else {
                DispatchQueue.main.async {
                    self.errorMessage = "Unknown error occurred while saving staff"
                    self.isSaving = false
                }
                return
            }
            
            // Now save the ID documents
            self.documentManager.saveDocuments(documents: self.documents, for: savedRecord.recordID) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.errorMessage = "Error saving documents: \(error.localizedDescription)"
                        self.isSaving = false
                    } else {
                        self.onStaffAdded()
                        self.dismiss()
                    }
                }
            }
        }
    }
}
