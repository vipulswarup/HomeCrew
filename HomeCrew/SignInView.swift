import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @State private var isSignedIn = false  // Track login status
    @StateObject private var authDelegate = AuthenticationDelegate() // Store delegate to prevent deallocation

    var body: some View {
        if isSignedIn {
            DashboardView()  // Show dashboard after successful login
        } else {
            VStack {
                // App Logo
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .padding(.top, 50)

                // App Title
                Text("HomeCrew")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 10)

                // Tagline
                Text("Manage your Household Staff")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.bottom, 20)

                Spacer()

                // Apple Sign-In Button
                SignInWithAppleButton(onRequest: { request in
                    handleSignInWithApple()
                }, onCompletion: { result in
                    switch result {
                    case .success(let auth):
                        print("Authorization successful: \(auth)")
                    case .failure(let error):
                        print("Authorization failed: \(error.localizedDescription)")
                    }
                })
                .frame(width: 280, height: 50)
                .padding()

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 173/255, green: 101/255, blue: 199/255).ignoresSafeArea()) // Custom background color
        }
    }

    /// Handles Sign-In with Apple request
    private func handleSignInWithApple() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email] // Request user details

        // Assign a completion handler to the delegate
        authDelegate.completion = { firstName in
            if let firstName = firstName {
                UserDefaults.standard.set(firstName, forKey: "firstName")
            }
            isSignedIn = true
        }

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = authDelegate
        controller.performRequests()
    }
}

/// Authentication delegate for handling Apple Sign-In responses
class AuthenticationDelegate: NSObject, ASAuthorizationControllerDelegate, ObservableObject {
    var completion: ((String?) -> Void)?

    /// Called when authentication is successful
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let firstName = credential.fullName?.givenName ?? "User" // Default name if not provided
            completion?(firstName)
        } else {
            completion?(nil)
        }
    }

    /// Called when authentication fails
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Sign in with Apple failed: \(error.localizedDescription)")
        completion?(nil)
    }
}

