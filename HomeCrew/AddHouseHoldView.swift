//
//  AddHouseHoldView.swift
//  HomeCrew
//
//  Created by Vipul Swarup on 09/03/25.
//

import SwiftUI
import CloudKit

struct AddHouseHoldView: View {
    @Environment(\.dismiss) var dismiss // Allows closing the sheet after saving
    @State private var name: String = "" // Stores household name input
    @State private var address: String = "" // Stores household address input
    @State private var isSaving: Bool = false // Tracks saving state
    @State private var errorMessage: String? // Stores error messages

    var onHouseHoldAdded: () -> Void // Callback to refresh household list

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Household Details")) {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words) // Capitalizes words automatically
                    
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
                            ProgressView() // Shows a loading spinner while saving
                        } else {
                            Text("Save Household")
                        }
                    }
                    .buttonStyle(.borderedProminent) // Makes it look like a proper iOS button
                    .controlSize(.large) // Makes button size standard for iOS
                    .padding()
                    .disabled(isSaving || name.isEmpty || address.isEmpty) // Prevents saving empty data
                }
            }
            .navigationTitle("Add Household")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss() // Closes the sheet
                    }
                }
            }
        }
    }

    /// Saves the household data to CloudKit
    private func saveHousehold() {
        guard !name.isEmpty, !address.isEmpty else { return }
        
        isSaving = true
        errorMessage = nil // Clear previous errors

        let record = CKRecord(recordType: "HouseHold")
        record["name"] = name as CKRecordValue
        record["address"] = address as CKRecordValue

        CKContainer.default().publicCloudDatabase.save(record) { _, error in
            DispatchQueue.main.async {
                isSaving = false

                if let error = error {
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                } else {
                    onHouseHoldAdded() // Refresh the list in HouseHoldView
                    dismiss() // Close the add screen
                }
            }
        }
    }
}
