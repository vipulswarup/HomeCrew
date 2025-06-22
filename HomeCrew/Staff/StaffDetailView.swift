import SwiftUI
import CloudKit
import os.log

struct StaffDetailView: View {
    let staff: Staff
    var onStaffUpdated: () -> Void
    
    @State private var documents: [StaffDocument] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    
    private let documentManager = StaffDocumentManager()
    private let privateDatabase = CKContainer.default().privateCloudDatabase
    
    // Logger for staff operations
    private let logger = Logger(subsystem: "com.homecrew.staff", category: "StaffDetailView")
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Staff header
                StaffHeaderView(staff: staff)
                
                Divider()
                
                // Employment details
                EmploymentDetailsView(staff: staff)
                
                Divider()
                
                // Agreed duties
                DutiesView(duties: staff.agreedDuties)
                
                Divider()
                
                // ID Documents
                DocumentsView(
                    documents: documents,
                    isLoading: isLoading,
                    errorMessage: errorMessage
                )
            }
            .padding()
        }
        .navigationTitle(staff.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
            
            ToolbarItem(placement: .destructiveAction) {
                Button("Delete") {
                    showingDeleteConfirmation = true
                }
                .foregroundColor(.red)
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditStaffView(staff: staff) {
                onStaffUpdated()
            }
        }
        .alert("Delete Staff Member", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteStaffMember()
            }
        } message: {
            Text("Are you sure you want to delete this staff member? This action cannot be undone.")
        }
        .onAppear {
            loadStaffDocuments()
        }
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
                    self.documents = documents
                }
            }
        }
    }
    
    private func deleteStaffMember() {
        // First delete all documents
        let documentIDs = documents.map { $0.id }
        
        documentManager.deleteDocuments(with: documentIDs) { error in
            if let error = error {
                self.logger.error("Error deleting documents: \(error.localizedDescription)")
                // Continue with staff deletion anyway
            }
            
            // Then delete the staff record
            privateDatabase.delete(withRecordID: staff.id) { _, error in
                if let error = error {
                    self.logger.error("Error deleting staff: \(error.localizedDescription)")
                }
                
                // Notify parent view regardless of success/failure
                onStaffUpdated()
            }
        }
    }
}

// MARK: - Subviews

struct StaffHeaderView: View {
    let staff: Staff
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(staff.fullLegalName)
                .font(.title)
                .fontWeight(.bold)
            
            if let commonlyKnownAs = staff.commonlyKnownAs, !commonlyKnownAs.isEmpty {
                Text("Known as: \(commonlyKnownAs)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Label(staff.employmentStatus, systemImage: staff.isActive ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(staff.isActive ? .green : .red)
                    .font(.subheadline)
            }
            .padding(.top, 4)
        }
    }
}

struct EmploymentDetailsView: View {
    let staff: Staff
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Employment Details")
                .font(.headline)
            
            DetailRow(title: "Starting Date", value: formattedDate(staff.startingDate))
            
            if !staff.isActive, let leavingDate = staff.leavingDate {
                DetailRow(title: "Leaving Date", value: formattedDate(leavingDate))
            }
            
            DetailRow(title: "Monthly Salary", value: staff.formattedSalary)
            DetailRow(title: "Annual Leaves", value: "\(staff.leavesAllocated) days")
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .fontWeight(.medium)
            
            Spacer()
        }
        .font(.subheadline)
    }
}

struct DutiesView: View {
    let duties: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Agreed Duties")
                .font(.headline)
            
            Text(duties)
                .font(.body)
                .padding(.top, 4)
        }
    }
}

struct DocumentsView: View {
    let documents: [StaffDocument]
    let isLoading: Bool
    let errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ID Documents")
                .font(.headline)
            
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.subheadline)
                    .padding()
            } else if documents.isEmpty {
                Text("No documents available")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
                    ForEach(documents) { document in
                        DocumentItemView(document: document)
                    }
                }
            }
        }
    }
}

struct DocumentItemView: View {
    let document: StaffDocument
    @State private var showingDocumentViewer = false
    
    var body: some View {
        VStack {
            if document.isImage, let image = document.thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                    .cornerRadius(8)
                    .shadow(radius: 2)
                    .onTapGesture {
                        showingDocumentViewer = true
                    }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                        .frame(height: 120)
                    
                    Image(systemName: document.iconName)
                        .font(.system(size: 40))
                        .foregroundColor(Color(document.iconColor))
                }
                .shadow(radius: 2)
                .onTapGesture {
                    showingDocumentViewer = true
                }
            }
            
            Text(document.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showingDocumentViewer) {
            NavigationStack {
                DocumentViewerView(document: document)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                showingDocumentViewer = false
                            }
                        }
                    }
            }
        }
    }
}
