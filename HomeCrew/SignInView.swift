import SwiftUI
import CloudKit

struct CloudKitAuthView: View {
    @State private var isCloudAvailable = false
    @State private var isChecking = true
    @State private var errorMessage: String?
    
    var body: some View {
        Group {
            if isChecking {
                // Loading state while checking iCloud status
                VStack {
                    ProgressView("Checking iCloud status...")
                    Text("Please wait...")
                        .font(.caption)
                        .padding()
                }
            } else if isCloudAvailable {
                // User is signed in to iCloud, show main app
                MainTabView()
            } else {
                // User needs to sign in to iCloud
                VStack(spacing: 20) {
                    Image(systemName: "icloud.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("iCloud Account Required")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                    } else {
                        Text("Please sign in to iCloud in your device settings to use HomeCrew.")
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                    
                    Button("Try Again") {
                        checkiCloudAccountStatus()
                    }
                    .padding()
                }
                .padding()
            }
        }
        .onAppear {
            checkiCloudAccountStatus()
        }
    }
    
    private func checkiCloudAccountStatus() {
        isChecking = true
        errorMessage = nil
        
        CKContainer.default().accountStatus { status, error in
            DispatchQueue.main.async {
                isChecking = false
                
                if let error = error {
                    errorMessage = "Error checking iCloud status: \(error.localizedDescription)"
                    isCloudAvailable = false
                    return
                }
                
                switch status {
                case .available:
                    // User is signed in to iCloud and can use the app
                    isCloudAvailable = true
                case .noAccount:
                    errorMessage = "No iCloud account found. Please sign in to iCloud in Settings."
                    isCloudAvailable = false
                case .restricted:
                    errorMessage = "Your iCloud account is restricted and cannot be used."
                    isCloudAvailable = false
                case .couldNotDetermine:
                    errorMessage = "Could not determine iCloud account status. Please try again."
                    isCloudAvailable = false
                @unknown default:
                    errorMessage = "Unknown iCloud account status. Please try again."
                    isCloudAvailable = false
                }
            }
        }
    }
}
