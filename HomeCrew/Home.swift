//
//  Home.swift
//  HomeCrew
//
//  Created by Vipul Swarup on 08/03/25.
//

import SwiftUI
import CloudKit

/// Model representing a Home entity in CloudKit
struct HomeModel: Identifiable {
    var id: CKRecord.ID
    var name: String
    var address: String

    /// Initialize from a CloudKit record
    init(record: CKRecord) {
        self.id = record.recordID
        self.name = record["name"] as? String ?? "Unknown"
        self.address = record["address"] as? String ?? "No address"
    }
}

/// ViewModel to manage CloudKit data operations for Home
class HomeViewModel: ObservableObject {
    @Published var homes: [HomeModel] = []
    private let database = CKContainer.default().publicCloudDatabase
    
    /// Fetches all homes from CloudKit
    func fetchHomes() {
        let query = CKQuery(recordType: "Home", predicate: NSPredicate(value: true))
        let operation = CKQueryOperation(query: query)
        
        operation.resultsLimit = CKQueryOperation.maximumResults
        var fetchedHomes: [HomeModel] = []

        // ✅ Use `recordMatchedBlock` instead of `recordFetchedBlock`
        operation.recordMatchedBlock = { recordID, result in
            switch result {
            case .success(let record):
                DispatchQueue.main.async {
                    fetchedHomes.append(HomeModel(record: record))
                }
            case .failure(let error):
                print("Error fetching record \(recordID): \(error.localizedDescription)")
            }
        }

        // ✅ Use `queryResultBlock` instead of `queryCompletionBlock`
        operation.queryResultBlock = { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.homes = fetchedHomes
                case .failure(let error):
                    print("Error completing query: \(error.localizedDescription)")
                }
            }
        }

        database.add(operation)
    }


    
    /// Adds a new home record to CloudKit
    func addHome(name: String, address: String) {
        let record = CKRecord(recordType: "Home")
        record["name"] = name as CKRecordValue
        record["address"] = address as CKRecordValue
        
        database.save(record) { _, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error saving home: \(error.localizedDescription)")
                } else {
                    self.fetchHomes()
                }
            }
        }
    }
}

/// View for managing and adding homes
struct HomeProfileView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var homeName = ""
    @State private var homeAddress = ""
    
    var body: some View {
        NavigationView {
            VStack {
                Form {
                    /// Section for adding a new home
                    Section(header: Text("Add Home")) {
                        TextField("Home Name", text: $homeName)
                        TextField("Address", text: $homeAddress)
                        Button("Save") {
                            viewModel.addHome(name: homeName, address: homeAddress)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                homeName = ""
                                homeAddress = ""
                            }
                        }
                    }
                    
                    /// Section displaying the list of homes
                    Section(header: Text("Your Homes")) {
                        List(viewModel.homes) { home in
                            VStack(alignment: .leading) {
                                Text(home.name).font(.headline)
                                Text(home.address).font(.subheadline)
                            }
                        }
                    }
                }
            }
            .onAppear { viewModel.fetchHomes() }
            .navigationTitle("Home Profile")
        }
    }
}
