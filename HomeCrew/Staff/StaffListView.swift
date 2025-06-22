import SwiftUI
import CloudKit

struct StaffListView: View {
    let household: HouseHold
    
    @State private var staffMembers: [Staff] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingAddSheet = false
    @State private var showInactiveStaff = false
    
    private let privateDatabase = CKContainer.default().privateCloudDatabase
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    ProgressView("Loading staff members...")
                } else if let errorMessage = errorMessage {
                    ErrorView(message: errorMessage) {
                        loadStaffMembers()
                    }
                } else if filteredStaff.isEmpty {
                    EmptyStateView(showInactiveStaff: showInactiveStaff) {
                        showingAddSheet = true
                    }
                } else {
                    List {
                        if !showInactiveStaff && inactiveStaffCount > 0 {
                            Button("Show \(inactiveStaffCount) inactive staff member\(inactiveStaffCount == 1 ? "" : "s")") {
                                withAnimation {
                                    showInactiveStaff = true
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(.blue)
                        } else if showInactiveStaff && inactiveStaffCount > 0 {
                            Button("Hide inactive staff") {
                                withAnimation {
                                    showInactiveStaff = false
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(.blue)
                        }
                        
                        ForEach(filteredStaff) { staff in
                            NavigationLink(destination: StaffDetailView(staff: staff, onStaffUpdated: loadStaffMembers)) {
                                StaffListItemView(staff: staff)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable {
                        await refreshStaffMembers()
                    }
                }
            }
            .navigationTitle("Staff Members")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingAddSheet = true
                    }) {
                        Label("Add Staff", systemImage: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddStaffView(household: household) {
                    loadStaffMembers()
                }
            }
            .onAppear {
                if staffMembers.isEmpty {
                    loadStaffMembers()
                }
            }
        }
    }
    
    private var filteredStaff: [Staff] {
        Staff.filterActive(staffMembers, includeInactive: showInactiveStaff)
    }
    
    private var inactiveStaffCount: Int {
        staffMembers.filter { !$0.isActive }.count
    }
    
    private func loadStaffMembers() {
        isLoading = true
        errorMessage = nil
        
        // Create a reference to the household
        let householdReference = CKRecord.Reference(recordID: household.id, action: .none)
        
        // Query staff for this household
        let predicate = NSPredicate(format: "householdID == %@", householdReference)
        let query = CKQuery(recordType: "Staff", predicate: predicate)
        
        privateDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let records):
                    self.staffMembers = records.map { Staff(record: $0) }
                    self.staffMembers = Staff.sortedByName(self.staffMembers)
                case .failure(let error):
                    self.errorMessage = "Failed to load staff: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func refreshStaffMembers() async {
        await withCheckedContinuation { continuation in
            loadStaffMembers()
            continuation.resume()
        }
    }
}

// MARK: - Supporting Views

struct StaffListItemView: View {
    let staff: Staff
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(staff.displayName)
                    .font(.headline)
                
                Spacer()
                
                if !staff.isActive {
                    Text("Inactive")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .cornerRadius(4)
                }
            }
            
            Text(staff.formattedSalary + " monthly")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Employed for \(staff.employmentDuration)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct EmptyStateView: View {
    let showInactiveStaff: Bool
    let onAddTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(showInactiveStaff ? "No staff members found" : "No active staff members")
                .font(.headline)
            
            Text("Add your first staff member to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: onAddTapped) {
                Label("Add Staff Member", systemImage: "person.badge.plus")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 40)
            .padding(.top, 10)
        }
        .padding()
    }
}

struct ErrorView: View {
    let message: String
    let onRetryTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Something went wrong")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: onRetryTapped) {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 40)
            .padding(.top, 10)
        }
        .padding()
    }
}
