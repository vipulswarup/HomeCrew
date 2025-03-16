import SwiftUI
import CloudKit

struct MainTabView: View {
    // MARK: - State Properties
    
    /// User's first name for personalized greeting
    @AppStorage("userName") private var userName: String = "User"
    
    /// Tracks if user is signed into iCloud
    @State private var iCloudStatus: iCloudAccountStatus = .checking
    
    /// Controls visibility of the iCloud error alert
    @State private var showingCloudKitErrorAlert = false
    
    /// Stores CloudKit error messages
    @State private var cloudKitErrorMessage: String?
    
    // MARK: - Body
    
    var body: some View {
        TabView {
            HouseHoldView()
                .tabItem {
                    Label("Households", systemImage: "house.fill")
                }
            
//            StaffView()
//                .tabItem {
//                    Label("Staff", systemImage: "person.3.fill")
//                }
            
//            ReportsView()
//                .tabItem {
//                    Label("Reports", systemImage: "chart.bar.fill")
//                }
//
//            ProfileView()
//                .tabItem {
//                    Label("Profile", systemImage: "gearshape.fill")
//                }
        }
        .overlay(
            // Only show the welcome banner briefly when the view appears
            welcomeBanner
                .opacity(iCloudStatus == .checking ? 1 : 0)
                .animation(.easeOut(duration: 2), value: iCloudStatus)
        )
        .alert(isPresented: $showingCloudKitErrorAlert) {
            Alert(
                title: Text("iCloud Error"),
                message: Text(cloudKitErrorMessage ?? "An unknown error occurred with iCloud."),
                primaryButton: .default(Text("Settings")) {
                    // Open Settings app to allow user to sign in to iCloud
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                },
                secondaryButton: .cancel(Text("Dismiss"))
            )
        }
        .onAppear {
            checkiCloudStatus()
            loadUserName()
        }
        // Listen for iCloud account changes while app is running
        .onReceive(NotificationCenter.default.publisher(for: .CKAccountChanged)) { _ in
            checkiCloudStatus()
        }
    }
    
    // MARK: - UI Components
    
    /// Welcome banner that shows during loading
    private var welcomeBanner: some View {
        VStack(spacing: 10) {
            Text("Welcome to HomeCrew")
                .font(.title2)
                .bold()
            
            switch iCloudStatus {
            case .checking:
                ProgressView("Checking iCloud status...")
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding(.top, 5)
            case .available:
                Text("Welcome, \(userName)!")
                    .font(.headline)
                    .foregroundColor(.green)
            case .unavailable(let reason):
                Text(reason)
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
                .shadow(radius: 2)
        )
        .padding()
    }
    
    // MARK: - CloudKit Methods
    
    /// Checks the user's iCloud account status
    private func checkiCloudStatus() {
        iCloudStatus = .checking
        
        CKContainer.default().accountStatus { status, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.cloudKitErrorMessage = "Error checking iCloud: \(error.localizedDescription)"
                    self.showingCloudKitErrorAlert = true
                    self.iCloudStatus = .unavailable("Unable to access iCloud")
                    return
                }
                
                switch status {
                case .available:
                    self.iCloudStatus = .available
                case .noAccount:
                    self.iCloudStatus = .unavailable("Please sign in to iCloud in Settings")
                    self.cloudKitErrorMessage = "You need to be signed in to iCloud to use this app."
                    self.showingCloudKitErrorAlert = true
                case .restricted:
                    self.iCloudStatus = .unavailable("Your iCloud account is restricted")
                    self.cloudKitErrorMessage = "Your iCloud account has restrictions that prevent using this app."
                    self.showingCloudKitErrorAlert = true
                case .couldNotDetermine:
                    self.iCloudStatus = .unavailable("Could not access iCloud")
                    self.cloudKitErrorMessage = "Could not determine iCloud status. Please check your connection."
                    self.showingCloudKitErrorAlert = true
                @unknown default:
                    self.iCloudStatus = .unavailable("Unknown iCloud status")
                    self.cloudKitErrorMessage = "Unknown iCloud account status. Please try again."
                    self.showingCloudKitErrorAlert = true
                }
            }
        }
    }
    
    /// Loads the user's name from UserDefaults or attempts to fetch from device
    private func loadUserName() {
        // If we already have a stored name, use it
        if userName != "User" {
            return
        }
        
        // Try to get the user's name from the device
        let deviceName = UIDevice.current.name
        if deviceName != "iPhone" && deviceName != "iPad" && !deviceName.isEmpty {
            // Some users name their devices with their own name
            let components = deviceName.components(separatedBy: "'s")
            if components.count > 1 && !components[0].isEmpty {
                // If the device name is something like "John's iPhone"
                userName = components[0]
                return
            }
        }
        
        // As a fallback, we could try to get the name from the Apple ID
        // This requires requesting permission from the user
        requestAppleIDName()
    }
    
    /// Requests the user's name from their Apple ID (requires permission)
    private func requestAppleIDName() {
        // This is a simplified example - in a real app, you would use Sign in with Apple
        // to request the user's name with their permission
        
        // For now, we'll just keep the default "User" name
        // If you want to implement this, you would use ASAuthorizationAppleIDProvider
        // as shown in the previous SignInView code
    }
}

// MARK: - Supporting Types

/// Represents the possible states of iCloud account status
enum iCloudAccountStatus: Equatable {
    case checking
    case available
    case unavailable(String)
}

// MARK: - Notification Extension

extension Notification.Name {
    /// Notification sent when the iCloud account changes
    static let CKAccountChanged = Notification.Name("CKAccountChanged")
}
