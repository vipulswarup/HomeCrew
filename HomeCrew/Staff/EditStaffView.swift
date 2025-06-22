import SwiftUI
import CloudKit
import PhotosUI
import os.log

struct EditStaffView: View {
    let staff: Staff
    var onStaffUpdated: () -> Void
    
    @Environment(\.dismiss) var dismiss
    
    // Logger for debugging
    private let logger = Logger(subsystem: "com.homecrew.staff", category: "EditStaffView")
    
    // Form fields
    @State private var fullLegalName: String
    @State private var commonlyKnownAs: String
    @State private var startingDate: Date
    @State private var leavingDate: Date?
    @State private var leavesAllocated: String
    @State private var monthlySalary: String
    @State private var currencyCode: String
    @State private var agreedDuties: String
    @State private var isActive: Bool
    
    // ID Card documents
    @State private var existingDocuments: [StaffDocument] = []
    @State private var documents: [DocumentItem] = []
    @State private var documentsToDelete: [CKRecord.ID] = []
    
    // Form state
    @State private var isSaving: Bool = false
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var showingCurrencyPicker = false
    
    // Available currencies
    let currencies = Locale.Currency.isoCurrencies.map { $0.identifier }.sorted()
    
    // Document manager
    private let documentManager = StaffDocumentManager()
    
    // CloudKit
    private let privateDatabase = CKContainer.default().privateCloudDatabase
    
    init(staff: Staff, onStaffUpdated: @escaping () -> Void) {
        self.staff = staff
        self.onStaffUpdated = onStaffUpdated
        
        // Initialize state with staff data
        _fullLegalName = State(initialValue: staff.fullLegalName)
        _commonlyKnownAs = State(initialValue: staff.commonlyKnownAs ?? "")
        _startingDate = State(initialValue: staff.startingDate)
        _leavingDate = State(initialValue: staff.leavingDate)
        _leavesAllocated = State(initialValue: String(staff.leavesAllocated))
        _monthlySalary = State(initialValue: String(staff.monthlySalary))
        _currencyCode = State(initialValue: staff.currencyCode)
        _agreedDuties = State(initialValue: staff.agreedDuties)
        _isActive = State(initialValue: staff.isActive)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding()
                            Spacer()
                        }
                    }
                } else {
                    Section(header: Text("Personal Information")) {
                        TextField("Full Legal Name", text: $fullLegalName)
                            .textInputAutocapitalization(.words)
                        
                        TextField("Commonly Known As (Optional)", text: $commonlyKnownAs)
                            .textInputAutocapitalization(.words)
                    }
                    
                    Section(header: Text("Employment Details")) {
                        DatePicker("Starting Date", selection: $startingDate, displayedComponents: .date)
                        
                        Toggle("Active", isOn: $isActive)
                        
                        if !isActive {
                            DatePicker("Leaving Date", selection: Binding(
                                get: { self.leavingDate ?? Date() },
                                set: { self.leavingDate = $0 }
                            ), displayedComponents: .date)
                        }
                        
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
                    
                    Section(header: Text("ID Documents")) {
                        // Existing documents
                        ForEach(existingDocuments) { document in
                            HStack {
                                document.documentView()
                                
                                Spacer()
                                
                                Button(action: {
                                    deleteExistingDocument(document)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        
                        // New document selection
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
                        Button(action: updateStaffMember) {
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("Update Staff Member")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding()
                        .disabled(isSaving || !isFormValid)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("Edit Staff Member")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadStaffDocuments()
            }
        }
    }
    
    private var isFormValid: Bool {
        let valid = !fullLegalName.isEmpty &&
        !monthlySalary.isEmpty &&
        !agreedDuties.isEmpty &&
        (Double(monthlySalary) ?? 0) > 0 &&
        (Int(leavesAllocated) ?? 0) >= 0
        
        logger.info("Form validation: name=\(!fullLegalName.isEmpty), salary=\(!monthlySalary.isEmpty), duties=\(!agreedDuties.isEmpty), salaryValue=\(Double(monthlySalary) ?? 0), leaves=\(Int(leavesAllocated) ?? 0), valid=\(valid)")
        
        return valid
    }
    
    private func loadStaffDocuments() {
        documentManager.fetchDocuments(for: staff.id) { documents, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Error loading documents: \(error.localizedDescription)"
                    return
                }
                
                if let documents = documents {
                    self.existingDocuments = documents
                }
            }
        }
    }
    
    private func deleteExistingDocument(_ document: StaffDocument) {
        documentsToDelete.append(document.id)
        existingDocuments.removeAll { $0.id == document.id }
        logger.info("Deleted existing document: \(document.name), documentsToDelete count: \(documentsToDelete.count)")
    }
    
    private func updateStaffMember() {
        guard isFormValid else { return }
        
        isSaving = true
        errorMessage = nil
        
        // First, fetch the existing record
        privateDatabase.fetch(withRecordID: staff.id) { record, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to fetch staff record: \(error.localizedDescription)"
                    self.isSaving = false
                }
                return
            }
            
            guard var staffRecord = record else {
                DispatchQueue.main.async {
                    self.errorMessage = "Staff record not found"
                    self.isSaving = false
                }
                return
            }
            
            // Update the record with new values
            staffRecord["fullLegalName"] = self.fullLegalName
            staffRecord["startingDate"] = self.startingDate
            staffRecord["leavesAllocated"] = Int(self.leavesAllocated) ?? 12
            staffRecord["monthlySalary"] = Double(self.monthlySalary) ?? 0.0
            staffRecord["currencyCode"] = self.currencyCode
            staffRecord["agreedDuties"] = self.agreedDuties
            staffRecord["isActive"] = self.isActive
            
            // Set optional fields
            if !self.commonlyKnownAs.isEmpty {
                staffRecord["commonlyKnownAs"] = self.commonlyKnownAs
            } else {
                staffRecord["commonlyKnownAs"] = nil
            }
            
            if let leavingDate = self.leavingDate {
                staffRecord["leavingDate"] = leavingDate
            } else {
                staffRecord["leavingDate"] = nil
            }
            
            // Save the updated record
            self.privateDatabase.save(staffRecord) { savedRecord, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to save staff: \(error.localizedDescription)"
                        self.isSaving = false
                    }
                    return
                }
                
                // Delete documents marked for deletion
                self.documentManager.deleteDocuments(with: self.documentsToDelete) { error in
                    if let error = error {
                        DispatchQueue.main.async {
                            self.errorMessage = "Error deleting documents: \(error.localizedDescription)"
                            self.isSaving = false
                        }
                        return
                    }
                    
                    // Only save new documents if there are any
                    if !self.documents.isEmpty {
                        self.documentManager.saveDocuments(documents: self.documents, for: self.staff.id) { error in
                            DispatchQueue.main.async {
                                if let error = error {
                                    self.errorMessage = "Error saving documents: \(error.localizedDescription)"
                                } else {
                                    self.onStaffUpdated()
                                    self.dismiss()
                                }
                                self.isSaving = false
                            }
                        }
                    } else {
                        // No new documents to save, just complete the update
                        DispatchQueue.main.async {
                            self.onStaffUpdated()
                            self.dismiss()
                            self.isSaving = false
                        }
                    }
                }
            }
        }
    }
}
