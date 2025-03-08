//
//  AddHomeView.swift
//  HomeCrew
//
//  Created by Vipul Swarup on 08/03/25.
//


import SwiftUI
import CloudKit

struct AddHomeView: View {
    @State private var homeName = ""
    @State private var homeAddress = ""
    @Environment(\.presentationMode) var presentationMode
    var onHomeAdded: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Home Details")) {
                    TextField("Home Name", text: $homeName)
                    TextField("Address", text: $homeAddress)
                }
                
                Section {
                    Button("Save Home") {
                        saveHome()
                    }
                    .disabled(homeName.isEmpty || homeAddress.isEmpty)
                }
            }
            .navigationTitle("Add Home")
            .toolbar {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }

    func saveHome() {
        let database = CKContainer.default().privateCloudDatabase
        let record = CKRecord(recordType: "Home")
        record["name"] = homeName
        record["address"] = homeAddress

        database.save(record) { _, error in
            if error == nil {
                DispatchQueue.main.async {
                    onHomeAdded()
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}
