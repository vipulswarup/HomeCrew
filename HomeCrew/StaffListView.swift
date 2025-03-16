//
//  StaffListView.swift
//  HomeCrew
//
//  Created by Vipul Swarup on 16/03/25.
//


import SwiftUI
import CloudKit

struct StaffListView: View {
    let household: HouseHold
    
    @State private var staffMembers: [Staff] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingAddStaffSheet = false
    @State private var showingActiveStaffOnly = true
    @State private var staffToDelete: Staff?
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    
    private let privateDatabase = CKContainer.default().privateCloudDatabase
    
    var body: some View {
        ZStack {
            if isLoading {
                ProgressView("Loading staff members...")
            } else if let error = errorMessage {
                VStack {
                    Text("Error loading staff")
                        .font(.headline)
                        .padding(.bottom, 4)
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Try Again") {
                        fetchStaffMembers()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if filteredStaff.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text(showingActiveStaffOnly ? "No active staff members" : "No staff members")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Button("Add Staff Member") {
                        showingAddStaffSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    Section {
                        Toggle("Show Active Staff Only", isOn: $showingActiveStaffOnly)
                    }
                    
                    ForEach(filteredStaff) { staff in
                        NavigationLink(destination: StaffDetailView(staff: staff, household: household)) {
                            StaffRowView(staff: staff)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                staffToDelete = staff
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("\(household.name) Staff")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    showingAddStaffSheet = true
                }) {
                    Image(systemName: "plus")
                }
                .disabled(isLoading || isDeleting)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: fetchStaffMembers) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading || isDeleting)
            }
        }
        .sheet(isPresented: $showingAddStaffSheet) {
            AddStaffView(household: household, onStaffAdded: fetchStaffMembers)
        }
        .alert("Delete Staff Member?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                staffToDelete = nil
            }
            
            Button("Delete Permanently", role: .destructive) {
                if let staff = staffToDelete {
                    deleteStaffMember(staff, retainHistory: false)
                }
            }
            
            Button("Mark as Inactive", role: .none) {
                if let staff = staffToDelete {
                    markStaffInactive(staff)
                }
            }
        } message: {
            if let staff = staffToDelete {
                Text("How would you like to remove \(staff.displayName)?\n\n• Delete Permanently: Removes all data\n• Mark as Inactive: Preserves history for reports")
            } else {
                Text("Please select an option")
            }
        }
        .onAppear {
            fetchStaffMembers()
        }
    }
    
    private var filteredStaff: [Staff] {
        if showingActiveStaffOnly {
            return staffMembers.filter { $0.isActive }
        } else {
            return staffMembers
        }
    }
    
    private func fetchStaffMembers() {
        isLoading = true
        errorMessage = nil
        staffMembers = []
        
        // Create a reference to the household
        let householdReference = CKRecord.Reference(recordID: household.id, action: .none)
        
        // Query staff members for this household
        let predicate = NSPredicate(format: "householdID == %@", householdReference)
        let query = CKQuery(recordType: "Staff", predicate: predicate)
        
        let operation = CKQueryOperation(query: query)
        
        var fetchedStaff: [Staff] = []
        
        operation.recordMatchedBlock = { (recordID, result) in
            switch result {
            case .success(let record):
                let staff = Staff(record: record)
                fetchedStaff.append(staff)
            case .failure(let error):
                print("Error fetching staff record: \(error.localizedDescription)")
            }
        }
        
        operation.queryResultBlock = { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success:
                    // Sort staff by name
                    self.staffMembers = fetchedStaff.sorted { $0.fullLegalName < $1.fullLegalName }
                case .failure(let error):
                    self.errorMessage = handleCloudKitError(error)
                }
            }
        }
        
        privateDatabase.add(operation)
    }
    
    private func deleteStaffMember(_ staff: Staff, retainHistory: Bool) {
        isDeleting = true
        
        if retainHistory {
            // Just mark as inactive with leaving date
            markStaffInactive(staff)
        } else {
            // Permanently delete the record
            privateDatabase.delete(withRecordID: staff.id) { _, error in
                DispatchQueue.main.async {
                    if let error = error {
                        errorMessage = "Failed to delete: \(error.localizedDescription)"
                    } else {
                        // Remove from local array
                        staffMembers.removeAll { $0.id == staff.id }
                    }
                    isDeleting = false
                    staffToDelete = nil
                }
            }
        }
    }
    
    private func markStaffInactive(_ staff: Staff) {
        isDeleting = true
        
        // Create a mutable copy of the staff
        var updatedStaff = staff
        updatedStaff.isActive = false
        updatedStaff.leavingDate = Date()
        
        // Update the record
        let record = updatedStaff.toRecord()
        
        privateDatabase.save(record) { _, error in
            DispatchQueue.main.async {
                if let error = error {
                    errorMessage = "Failed to update: \(error.localizedDescription)"
                } else {
                    // Update local array
                    if let index = staffMembers.firstIndex(where: { $0.id == staff.id }) {
                        staffMembers[index] = updatedStaff
                    }
                }
                isDeleting = false
                staffToDelete = nil
            }
        }
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
            default:
                return "Error: \(ckError.localizedDescription)"
            }
        }
        return "An unexpected error occurred: \(error.localizedDescription)"
    }
}

struct StaffRowView: View {
    let staff: Staff
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(staff.fullLegalName)
                    .font(.headline)
                
                if let nickname = staff.commonlyKnownAs, !nickname.isEmpty {
                    Text("(\(nickname))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status indicator
                Circle()
                    .fill(staff.isActive ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
            }
            
            Text(staff.formattedSalary)
                .font(.subheadline)
            
            Text(staff.employmentStatus)
                .font(.caption)
                .foregroundColor(staff.isActive ? .green : .red)
        }
        .padding(.vertical, 4)
    }
}
