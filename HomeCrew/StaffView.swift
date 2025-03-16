//
//  StaffView 2.swift
//  HomeCrew
//
//  Created by Vipul Swarup on 16/03/25.
//


import SwiftUI
import CloudKit

struct StaffView: View {
    @State private var households: [HouseHold] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    private let privateDatabase = CKContainer.default().privateCloudDatabase
    
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
                        Text("No households found")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Add a household first to manage staff")
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(households) { household in
                            NavigationLink(destination: StaffListView(household: household)) {
                                HStack {
                                    Image(systemName: "house.fill")
                                        .foregroundColor(.blue)
                                        .font(.title3)
                                    
                                    VStack(alignment: .leading) {
                                        Text(household.name)
                                            .font(.headline)
                                        Text(household.address)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Staff Management")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: fetchHouseholds) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
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
        
        let query = CKQuery(recordType: "HouseHold", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        let operation = CKQueryOperation(query: query)
        
        var fetchedHouseholds: [HouseHold] = []
        
        operation.recordMatchedBlock = { (recordID, result) in
            switch result {
            case .success(let record):
                let household = HouseHold(record: record)
                fetchedHouseholds.append(household)
            case .failure(let error):
                print("Error fetching household record: \(error.localizedDescription)")
            }
        }
        
        operation.queryResultBlock = { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success:
                    self.households = fetchedHouseholds
                case .failure(let error):
                    self.errorMessage = self.handleCloudKitError(error)
                }
            }
        }
        
        privateDatabase.add(operation)
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
