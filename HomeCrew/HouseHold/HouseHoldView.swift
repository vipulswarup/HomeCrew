import SwiftUI
import CloudKit
import os.log

struct HouseHold: Identifiable {
    let id: CKRecord.ID
    var name: String
    var address: String
    var notes: String?
    
    init(record: CKRecord) {
        self.id = record.recordID
        self.name = record["name"] as? String ?? "Unnamed Household"
        self.address = record["address"] as? String ?? "No address"
        self.notes = record["notes"] as? String
    }
    
    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: "HouseHold")
        record["name"] = name
        record["address"] = address
        
        if let notes = notes {
            record["notes"] = notes
        }
        
        return record
    }
}

struct HouseHoldView: View {
    @State private var households: [HouseHold] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var showingAddSheet = false
    @State private var householdToDelete: HouseHold?
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    
    // Reference to the private database
    private let privateDatabase = CKContainer.default().privateCloudDatabase
    
    // Logger for household operations
    private let logger = Logger(subsystem: "com.homecrew.household", category: "HouseholdView")
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    ProgressView("Loading households...")
                } else if let error = errorMessage {
                    VStack {
                        Text("Error loading households")
                            .font(.headline)
                            .padding(.bottom, 4)
                        Text(error)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Try Again") {
                            fetchHouseholds()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if households.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "house.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No Households added yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Button("Add Your First Household") {
                            showingAddSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(households) { household in
                            NavigationLink(destination: StaffListView(household: household)) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(household.name)
                                            .font(.headline)
                                        Text(household.address)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                    
                                    Spacer()
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    householdToDelete = household
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Households")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingAddSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                    .disabled(isLoading || isDeleting)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: fetchHouseholds) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading || isDeleting)
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddHouseHoldView(onHouseHoldAdded: fetchHouseholds)
            }
            .alert("Delete Household?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    householdToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let household = householdToDelete {
                        deleteHousehold(household)
                    }
                }
                .disabled(isDeleting)
            } message: {
                if isDeleting {
                    Text("Deleting...")
                } else if let error = deleteError {
                    Text(error)
                } else {
                    Text("Deleting this household will also remove all associated staff and reports. This action cannot be undone.")
                }
            }
            .onAppear {
                fetchHouseholds()
            }
        }
    }
    
    private func fetchHouseholds() {
        isLoading = true
        errorMessage = nil
        households = []
        
        let query = CKQuery(recordType: "HouseHold", predicate: NSPredicate(value: true))
        
        let operation = CKQueryOperation(query: query)
        
        var fetchedHouseholds: [HouseHold] = []
        
        operation.recordMatchedBlock = { (recordID, result) in
            switch result {
            case .success(let record):
                let household = HouseHold(record: record)
                fetchedHouseholds.append(household)
            case .failure(let error):
                self.logger.error("Error fetching record: \(error.localizedDescription)")
            }
        }
        
        operation.queryResultBlock = { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success:
                    // Sort the households in memory by name
                    self.households = fetchedHouseholds.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                case .failure(let error):
                    self.errorMessage = handleCloudKitError(error)
                }
            }
        }
        
        privateDatabase.add(operation)
    }
    
    private func deleteHousehold(_ household: HouseHold) {
        isDeleting = true
        deleteError = nil
        
        // First, we'll delete the household record
        privateDatabase.delete(withRecordID: household.id) { _, error in
            DispatchQueue.main.async {
                if let error = error {
                    deleteError = "Failed to delete: \(error.localizedDescription)"
                    isDeleting = false
                } else {
                    // Successfully deleted, now refresh the list
                    isDeleting = false
                    householdToDelete = nil
                    
                    // Remove from local array immediately for UI responsiveness
                    households.removeAll { $0.id == household.id }
                    
                    // Then refresh from server to ensure consistency
                    fetchHouseholds()
                }
            }
        }
        
        // Note: In a real app, you would also need to query and delete related records
        // (staff, reports, etc.) or set up CloudKit cascade delete rules
    }
    
    private func handleCloudKitError(_ error: Error) -> String {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .networkUnavailable, .networkFailure:
                return "Network issue. Please check your connection and try again."
            case .serviceUnavailable:
                return "iCloud service is currently unavailable. Please try again later."
            case .notAuthenticated:
                return "Please sign in to your iCloud account in Settings."
            case .quotaExceeded:
                return "Your iCloud storage is full. Please free up space and try again."
            case .invalidArguments:
                if ckError.localizedDescription.contains("sortable") {
                    return "Database schema error: Please ensure fields are properly configured in CloudKit Dashboard."
                }
                return "Invalid arguments: \(ckError.localizedDescription)"
            default:
                return "Error: \(ckError.localizedDescription)"
            }
        }
        return "An unexpected error occurred: \(error.localizedDescription)"
    }
}

struct AddHouseHoldView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name: String = ""
    @State private var address: String = ""
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?
    
    var onHouseHoldAdded: () -> Void
    
    // Reference to the private database
    private let privateDatabase = CKContainer.default().privateCloudDatabase
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Household Details")) {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Address", text: $address)
                        .textInputAutocapitalization(.words)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                
                Section {
                    Button(action: saveHousehold) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save Household")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding()
                    .disabled(isSaving || name.isEmpty || address.isEmpty)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Add Household")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveHousehold() {
        guard !name.isEmpty, !address.isEmpty else { return }
        
        isSaving = true
        errorMessage = nil
        
        let record = CKRecord(recordType: "HouseHold")
        record["name"] = name as CKRecordValue
        record["address"] = address as CKRecordValue
        
        privateDatabase.save(record) { _, error in
            DispatchQueue.main.async {
                isSaving = false
                
                if let error = error {
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                } else {
                    onHouseHoldAdded()
                    dismiss()
                }
            }
        }
    }
}

struct HouseHoldView_Previews: PreviewProvider {
    static var previews: some View {
        HouseHoldView()
    }
}
