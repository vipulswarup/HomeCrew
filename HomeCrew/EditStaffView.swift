//
//  EditStaffView.swift
//  HomeCrew
//
//  Created by Vipul Swarup on 16/03/25.
//


import SwiftUI
import CloudKit
import PhotosUI

struct EditStaffView: View {
    let staff: Staff
    let household: HouseHold
    var onStaffUpdated: () -> Void
    
    @Environment(\.dismiss) var dismiss
    
    // Form fields
    @State private var fullLegalName: String
    @State private var commonlyKnownAs: String
    @State private var startingDate: Date
    @State private var leavingDate: Date?
    @State private var isActive: Bool
    @State private var leavesAllocated: String
    @State private var monthlySalary: String
    @State private var currencyCode: String
    @State private var agreedDuties: String
    
    // ID Card documents
    @State private var existingDocuments: [StaffDocument] = []
    @State private var documentsToDelete: [CKRecord.ID] = []
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var newImages: [UIImage] = []
    @State private var newDocumentNames: [String] = []
    
    // Form state
    @State private var isSaving: Bool = false
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var showingCurrencyPicker = false
    @State private var showingLeavingDatePicker = false
    
    // Available currencies
    let currencies = Locale.isoCurrencyCodes.sorted()
    
    // CloudKit
    private let privateDatabase = CKContainer.default().privateCloudDatabase
    
    init(staff: Staff, household: HouseHold, onStaffUpdated: @escaping () -> Void) {
        self.staff = staff
        self.household = household
        self.onStaffUpdated = onStaffUpdated
        
        // Initialize state with staff values
        _fullLegalName = State(initialValue: staff.fullLegalName)
        _commonlyKnownAs = State(initialValue: staff.commonlyKnownAs ?? "")
        _startingDate = State(initialValue: staff.startingDate)
        _leavingDate = State(initialValue: staff.leavingDate)
        _isActive = State(initialValue: staff.isActive)
        _leavesAllocated = State(initialValue: String(staff.leavesAllocated))
        _monthlySalary = State(initialValue: String(format: "%.2f", staff.monthlySalary))
        _currencyCode = State(initialValue: staff.currencyCode)
        _agreedDuties = State(initialValue: staff.agreedDuties)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Personal Information")) {
                    TextField("Full Legal Name", text: $fullLegalName)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Commonly Known As (Optional)", text: $commonlyKnownAs)
                        .textInputAutocapitalization(.words)
                }
                
                Section(header: Text("Employment Status")) {
                    Toggle("Active Staff Member", isOn: $isActive)
                        .onChange(of: isActive) { newValue in
                            if !newValue && leavingDate == nil {
                                leavingDate = Date()
                                showingLeavingDatePicker = true
                            } else if newValue {
                                leavingDate = nil
                                showingLeavingDatePicker = false
                            }
                        }
                    
                    if !isActive || showingLeavingDatePicker {
                        DatePicker("Leaving Date", selection: Binding(
                            get: { leavingDate ?? Date() },
                            set: { leavingDate = $0 }
                        ), displayedComponents: .date)
                    }
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
                
                Section(header: Text("Existing ID Documents")) {
                    if isLoading {
                        ProgressView("Loading documents...")
                    } else if existingDocuments.isEmpty {
                        Text("No existing documents")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(existingDocuments) { document in
                            HStack {
                                if let fileURL = document.fileURL,
                                   let image = UIImage(contentsOfFile: fileURL.path) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 60)
                                } else {
                                    Image(systemName: "doc.fill")
                                        .font(.largeTitle)
                                }
                                
                                Text(document.name)
                                
                                Spacer()
                                
                                Button(action: {
                                    documentsToDelete.append(document.id)
                                    existingDocuments.removeAll { $0.id == document.id }
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Add New ID Documents")) {
                    PhotosPicker(selection: $selectedItems, matching: .images, photoLibrary: .shared()) {
                        Label("Select ID Documents", systemImage: "doc.badge.plus")
                    }
                    
                    if !newImages.isEmpty {
                        ForEach(0..<newImages.count, id: \.self) { index in
                            HStack {
                                Image(uiImage: newImages[index])
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 60)
                                
                                TextField("Document Name", text: Binding(
                                    get: {
                                        index < newDocumentNames.count ? newDocumentNames[index] : "ID Document \(index + 1)"
                                    },
                                    set: { newValue in
                                        if index >= newDocumentNames.count {
                                            newDocumentNames.append(newValue)
                                        } else {
                                            newDocumentNames[index] = newValue
                                        }
                                    }
                                ))
                                
                                Button(action: {
                                    newImages.remove(at: index)
                                    if index < newDocumentNames.count {
                                        newDocumentNames.remove(at: index)
                                    }
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
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
                            Text("Save Changes")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding()
                    .disabled(isSaving || !isFormValid)
                    .frame(maxWidth: .infinity, alignment: .center)
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
            .onChange(of: selectedItems) { newItems in
                loadSelectedImages(from: newItems)
            }
            .onAppear {
                fetchExistingDocuments()
            }
        }
    }
    
    private var isFormValid: Bool {
        !fullLegalName.isEmpty &&
        !monthlySalary.isEmpty &&
        !agreedDuties.isEmpty &&
        (existingDocuments.count + newImages.count > 0) &&
        (Double(monthlySalary) ?? 0) > 0 &&
        (Int(leavesAllocated) ?? 0) >= 0
    }
    
    private func loadSelectedImages(from items: [PhotosPickerItem]) {
        Task {
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.newImages.append(image)
                        
                        // Add default document name if needed
                        if self.newDocumentNames.count < self.newImages.count {
                            self.newDocumentNames.append("ID Document \(self.newDocumentNames.count + 1)")
                        }
                    }
                }
            }
        }
    }
    
    private func fetchExistingDocuments() {
        isLoading = true
        
        // Create a reference to the staff
        let staffReference = CKRecord.Reference(recordID: staff.id, action: .none)
        
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
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success:
                    // Sort documents by name
                    self.existingDocuments = fetchedDocuments.sorted { $0.name < $1.name }
                case .failure(let error):
                    self.errorMessage = "Failed to load documents: \(error.localizedDescription)"
                }
            }
        }
        
        privateDatabase.add(operation)
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
                self.deleteMarkedDocuments {
                    // Then save new documents
                    self.saveNewDocuments()
                }
            }
        }
    }
    
    private func deleteMarkedDocuments(completion: @escaping () -> Void) {
        if documentsToDelete.isEmpty {
            completion()
            return
        }
        
        let group = DispatchGroup()
        
        for documentID in documentsToDelete {
            group.enter()
            
            privateDatabase.delete(withRecordID: documentID) { _, error in
                if let error = error {
                    print("Error deleting document: \(error.localizedDescription)")
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion()
        }
    }
    private func saveNewDocuments() {
            if newImages.isEmpty {
                DispatchQueue.main.async {
                    self.onStaffUpdated()
                    self.dismiss()
                    self.isSaving = false
                }
                return
            }
            
            let group = DispatchGroup()
            var documentReferences: [CKRecord.Reference] = []
            var saveError: Error?
            
            // Save each new document
            for (index, image) in newImages.enumerated() {
                group.enter()
                
                // Create temporary file for the image
                guard let imageData = image.jpegData(compressionQuality: 0.7) else {
                    group.leave()
                    continue
                }
                
                let tempDirectory = FileManager.default.temporaryDirectory
                let fileName = UUID().uuidString + ".jpg"
                let fileURL = tempDirectory.appendingPathComponent(fileName)
                
                do {
                    try imageData.write(to: fileURL)
                    
                    // Create document record
                    let documentRecord = CKRecord(recordType: "StaffDocument")
                    documentRecord["staffID"] = CKRecord.Reference(recordID: staff.id, action: .deleteSelf)
                    documentRecord["name"] = index < newDocumentNames.count ? newDocumentNames[index] : "ID Document \(index + 1)"
                    documentRecord["document"] = CKAsset(fileURL: fileURL)
                    
                    // Save document record
                    privateDatabase.save(documentRecord) { savedDoc, error in
                        defer {
                            try? FileManager.default.removeItem(at: fileURL)
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
                                        self.errorMessage = "Error saving documents: \(error.localizedDescription)"
                                        self.isSaving = false
                                        return
                                    }
                                    
                                    // We don't need to update the staff record with document references
                                    // since they are linked via the staffID reference in each document
                                    
                                    self.onStaffUpdated()
                                    self.dismiss()
                                    self.isSaving = false
                                }
                            }
                        }
