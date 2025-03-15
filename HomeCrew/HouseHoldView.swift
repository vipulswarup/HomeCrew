import SwiftUI
import CloudKit

struct HouseHoldView: View {
    @StateObject private var viewModel = HouseHoldViewModel()
    @State private var showingAddHousehold = false

    var body: some View {
        NavigationView {
            VStack {
                if viewModel.houseHolds.isEmpty {
                    Text("No households added yet.")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    List(viewModel.houseHolds) { houseHold in
                        NavigationLink(destination: HouseHoldProfileView(houseHold: houseHold)) {
                            VStack(alignment: .leading) {
                                Text(houseHold.name)
                                    .font(.headline)
                                Text(houseHold.address)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Your Households")
            .toolbar {
                Button(action: { showingAddHousehold.toggle() }) {
                    Image(systemName: "plus")
                }
            }
            .onAppear {
                viewModel.fetchHouseHolds()
            }
            .sheet(isPresented: $showingAddHousehold) {
                AddHouseHoldView(onHouseHoldAdded: viewModel.fetchHouseHolds)
            }
        }
    }
}
