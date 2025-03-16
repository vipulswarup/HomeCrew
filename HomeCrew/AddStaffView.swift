//
//  AddStaffView.swift
//  HomeCrew
//
//  Created by Vipul Swarup on 16/03/25.
//


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
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var documentNames: [String] = []
    
    // Form state
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?
    @State private var showingCurrencyPicker = false
    
    // Available currencies
    let currencies = Locale.isoCurrencyCodes.sorted()
    
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
                    PhotosPicker(selection: $selectedItems, matching: .images, photoLibrary: .shared()) {
                        Label("Select ID Documents", systemImage: "doc.badge.plus")
                    }
                    
                    if !selectedImages.isEmpty {
                        ForEach(0..<selectedImages.count, id: \.self) { index in
                            HStack {
                                Image(uiImage: selectedImages[index])
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 60)
                                
                                TextField("Document Name", text: Binding(
                                    get: {
                                        index < documentNames.count ? documentNames[index] : "ID Document \(index + 1)"
                                    },
                                    set: { newValue in
                                        if index >= documentNames.count {
                                            documentNames.append(newValue)
                                        } else {
                                            documentNames[index] = newValue
                                        }
                                    }
                                ))
                                
                                Button(action: {
                                    selectedImages.remove(at: index)
                                    if index < documentNames.count {
                                        documentNames.remove(at: index)
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
            .onChange(of: selectedItems) { newItems in
                loadSelectedImages(from: newItems)
            }
        }
    }
    
    private var isFormValid: Bool {
        !fullLegalName.isEmpty &&
        !monthlySalary.isEmpty &&
        !agreedDuties.isEmpty &&
        !selectedImages.isEmpty &&
        (Double(monthlySalary) ?? 0) > 0 &&
        (Int(leavesAllocated) ?? 0) >= 0
    }
    
    private func loadSelectedImages(from items: [PhotosPickerItem]) {
        Task {
            selectedImages = []
            
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.selectedImages.append(image)
                        
                        // Add default document name if needed
                        if self.documentNames.count < self.selectedImages.count {
                            self.documentNames.append("ID Document \(self.documentNames.count + 1)")
                        }
                    }
                }
            }
        }
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
            self.saveIDDocuments(for: savedRecord.recordID)
        }
    }
    
    private func saveIDDocuments(for staffID: CKRecord.ID) {
        let group = DispatchGroup()
        var documentReferences: [CKRecord.Reference] = []
        var saveError: Error?
        
        // Save each document
        for (index, image) in selectedImages.enumerated() {
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
                documentRecord["staffID"] = CKRecord.Reference(recordID: staffID, action: .deleteSelf)
                documentRecord["name"] = index < documentNames.count ? documentNames[index] : "ID Document \(index + 1)"
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
        
        // Update staff record with document references
        group.notify(queue: .main) {
            if let error = saveError {
                self.errorMessage = "Error saving documents: \(error.localizedDescription)"
                self.isSaving = false
                return
            }
            
            if !documentReferences.isEmpty {
                // Fetch the existing record first
                self.privateDatabase.fetch(withRecordID: staffID) { record, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self.errorMessage = "Error fetching staff record: \(error.localizedDescription)"
                            self.isSaving = false
                            return
                        }
                        
                        guard var staffRecord = record else {
                            self.errorMessage = "Staff record not found"
                            self.isSaving = false
                            return
                        }
                        
                        // Update the record with document references
                        staffRecord["idCards"] = documentReferences
                        
                        // Save the updated record
                        self.privateDatabase.save(staffRecord) { _, error in
                            if let error = error {
                                self.errorMessage = "Error updating staff with documents: \(error.localizedDescription)"
                            } else {
                                self.onStaffAdded()
                                self.dismiss()
                            }
                            self.isSaving = false
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.onStaffAdded()
                    self.dismiss()
                    self.isSaving = false
                }
            }
        }
    }
}
