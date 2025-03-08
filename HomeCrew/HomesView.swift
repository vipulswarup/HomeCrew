//
//  HomesView.swift
//  HomeCrew
//
//  Created by Vipul Swarup on 08/03/25.
//


import SwiftUI
import CloudKit

struct HomesView: View {
    @State private var homes: [Home] = []
    @State private var showingAddHome = false

    var body: some View {
        NavigationView {
            VStack {
                if homes.isEmpty {
                    Text("No homes added yet.")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    List(homes) { home in
                        VStack(alignment: .leading) {
                            Text(home.name)
                                .font(.headline)
                            Text(home.address)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("Your Homes")
            .toolbar {
                Button(action: { showingAddHome.toggle() }) {
                    Image(systemName: "plus")
                }
            }
            .onAppear {
                fetchHomes()
            }
            .sheet(isPresented: $showingAddHome) {
                AddHomeView(onHomeAdded: fetchHomes)
            }
        }
    }

    func fetchHomes() {
        let database = CKContainer.default().privateCloudDatabase
        let query = CKQuery(recordType: "Home", predicate: NSPredicate(value: true))
        
        database.perform(query, inZoneWith: nil) { records, error in
            if let records = records {
                DispatchQueue.main.async {
                    self.homes = records.map { Home(record: $0) }
                }
            }
        }
    }
}

struct Home: Identifiable {
    var id: CKRecord.ID
    var name: String
    var address: String

    init(record: CKRecord) {
        self.id = record.recordID
        self.name = record["name"] as? String ?? "Unknown"
        self.address = record["address"] as? String ?? "No address"
    }
}
