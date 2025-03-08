//
//  AuthManager.swift
//  HomeCrew
//
//  Created by Vipul Swarup on 08/03/25.
//


import AuthenticationServices

class AuthManager: ObservableObject {
    @Published var currentUser: User?
    
    struct User: Codable {
        let userId: String
        let fullName: String?
        let email: String?
    }
    
    func handleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }
    
    func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            if let appleIDCredential = auth.credential as? ASAuthorizationAppleIDCredential {
                let user = User(
                    userId: appleIDCredential.user,
                    fullName: appleIDCredential.fullName?.givenName,
                    email: appleIDCredential.email
                )
                self.currentUser = user
                saveUserToKeychain(user)
            }
        case .failure(let error):
            print("Sign in with Apple failed: \(error.localizedDescription)")
        }
    }
    
    func signOut() {
        self.currentUser = nil
        deleteUserFromKeychain()
    }
    
    func checkUserState() {
        if let savedUser = loadUserFromKeychain() {
            self.currentUser = savedUser
        }
    }
    
    // MARK: - Keychain Storage
    
    private func saveUserToKeychain(_ user: User) {
        let data = try? JSONEncoder().encode(user)
        UserDefaults.standard.set(data, forKey: "appleUser")
    }
    
    private func loadUserFromKeychain() -> User? {
        if let data = UserDefaults.standard.data(forKey: "appleUser"),
           let user = try? JSONDecoder().decode(User.self, from: data) {
            return user
        }
        return nil
    }
    
    private func deleteUserFromKeychain() {
        UserDefaults.standard.removeObject(forKey: "appleUser")
    }
}
