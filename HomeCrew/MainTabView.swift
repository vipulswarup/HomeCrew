import SwiftUI
import CloudKit

struct MainTabView: View {
    @State private var userName: String = "User"
    @State private var isSignedIn: Bool = false

    var body: some View {
        VStack {
            VStack(spacing: 10) {
                Text("Welcome, \(userName)!")
                    .font(.title)
                    .bold()
                
                Text(isSignedIn ? "Signed in to iCloud ✅" : "Not signed in ❌")
                    .foregroundColor(isSignedIn ? .green : .red)
                    .font(.subheadline)
            }
            .padding()
            
            TabView {
                HouseHoldView()
                    .tabItem {
                        Label("Households", systemImage: "house.fill")
                    }
                
                StaffView()
                    .tabItem {
                        Label("Staff", systemImage: "person.3.fill")
                    }
                
                ReportsView()
                    .tabItem {
                        Label("Reports", systemImage: "chart.bar.fill")
                    }
                
                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "gearshape.fill")
                    }
            }
        }
        .onAppear {
            fetchiCloudUserInfo()
        }
    }

    private func fetchiCloudUserInfo() {
        let container = CKContainer.default()
        
        container.accountStatus { status, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("iCloud Error: \(error.localizedDescription)")
                    self.isSignedIn = false
                    return
                }
                
                self.isSignedIn = (status == .available)
                
                if status == .available {
                    container.fetchUserRecordID { recordID, error in
                        if let recordID = recordID {
                            container.privateCloudDatabase.fetch(withRecordID: recordID) { record, error in
                                DispatchQueue.main.async {
                                    if let name = record?["firstName"] as? String {
                                        self.userName = name
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
