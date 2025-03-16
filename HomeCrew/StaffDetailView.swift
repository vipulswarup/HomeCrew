//
//  StaffDetailView.swift
//  HomeCrew
//
//  Created by Vipul Swarup on 16/03/25.
//


import SwiftUI
import CloudKit

struct StaffDetailView: View {
    let staff: Staff
    let household: HouseHold
    
    @State private var documents: [StaffDocument] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingEditSheet = false
    @State private var showingDocumentViewer = false
    @State private var selectedDocument: StaffDocument?
    
    private let privateDatabase = CKContainer.default().privateCloudDatabase
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header with status
                HStack {
                    VStack(alignment: .leading) {
                        Text(staff.fullLegalName)
                            .font(.title)
                            .bold()
                        
                        if let nickname = staff.commonlyKnownAs, !nickname.isEmpty {
                            Text("Known as: \(nickname)")
                                .font(.subheadline)
                        }
                    }
                    
                    Spacer()
                    
                    // Status badge
                    Text(staff.isActive ? "Active" : "Inactive")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(staff.isActive ? Color.green : Color.red)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .padding(.horizontal)
                
                Divider()
                
                // Employment details
                Group {
                    detailSection(title: "Employment Details") {
                        detailRow(title: "Starting Date", value: formatDate(staff.startingDate))
                        
                        if let leavingDate = staff.leavingDate {
                            detailRow(title: "Leaving Date", value: formatDate(leavingDate))
                        }
                        
                        detailRow(title: "Annual Leaves", value: "\(staff.leavesAllocated) days")
                        detailRow(title: "Monthly Salary", value: staff.formattedSalary)
                    }
                    
                    detailSection(title: "Agreed Duties") {
                        Text(staff.agreedDuties)
                            .padding(.horizontal)
                    }
                }
                
                Divider()
                
                // ID Documents
                detailSection(title: "ID Documents") {
                    if isLoading {
                        ProgressView("Loading documents...")
                            .padding()
                    } else if let error = errorMessage {
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                            .padding()
                    } else if documents.isEmpty {
                        Text("No documents available")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(documents) { document in
                                    documentThumbnail(document)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Staff Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditStaffView(staff: staff, household: household, onStaffUpdated: refreshData)
        }
        .sheet(item: $selectedDocument) { document in
            DocumentViewer(document: document)
        }
        .onAppear {
            fetchDocuments()
        }
    }
    
    private func detailSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)
            
            content()
                .padding(.bottom, 8)
        }
    }
    
    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
    }
    
    private func documentThumbnail(_ document: StaffDocument) -> some View {
        VStack {
            if let fileURL = document.fileURL,
               let image = UIImage(contentsOfFile: fileURL.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 2)
                    .onTapGesture {
                        selectedDocument = document
                    }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "doc.fill")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    )
            }
            
            Text(document.name)
                .font(.caption)
                .lineLimit(1)
                .frame(width: 100)
        }
    }
    
    private func fetchDocuments() {
        isLoading = true
        errorMessage = nil
        documents = []
        
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
                    self.documents = fetchedDocuments.sorted { $0.name < $1.name }
                case .failure(let error):
                    self.errorMessage = "Failed to load documents: \(error.localizedDescription)"
                }
            }
        }
        
        privateDatabase.add(operation)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func refreshData() {
        // This will be called after editing staff details
        fetchDocuments()
    }
}

// Document viewer for full-screen document viewing
struct DocumentViewer: View {
    let document: StaffDocument
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let fileURL = document.fileURL,
                   let image = UIImage(contentsOfFile: fileURL.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundColor(.yellow)
                        
                        Text("Document could not be loaded")
                            .foregroundColor(.white)
                            .padding()
                    }
                }
            }
            .navigationTitle(document.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}
