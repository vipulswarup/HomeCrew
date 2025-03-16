import SwiftUI
import CloudKit

struct HouseHoldProfileView: View {
    let household: CKRecord // The household record passed from HouseHoldView
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(household["name"] as? String ?? "Unknown")
                .font(.largeTitle)
                .bold()
            
            Text(household["address"] as? String ?? "No Address")
                .font(.title3)
                .foregroundColor(.gray)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Household Details")
    }
}
