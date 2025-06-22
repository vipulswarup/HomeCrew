//
//  AuthManager.swift
//  HomeCrew
//
//  Created by Vipul Swarup on 08/03/25.
//


import AuthenticationServices
import Security
import os.log

class AuthManager: ObservableObject {
    @Published var currentUser: User?
    
    // Logger for authentication events
    private let logger = Logger(subsystem: "com.homecrew.auth", category: "Authentication")
    
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
                logger.info("User signed in successfully: \(user.userId)")
            }
        case .failure(let error):
            logger.error("Sign in with Apple failed: \(error.localizedDescription)")
        }
    }
    
    func signOut() {
        self.currentUser = nil
        deleteUserFromKeychain()
        logger.info("User signed out")
    }
    
    func checkUserState() {
        if let savedUser = loadUserFromKeychain() {
            self.currentUser = savedUser
            logger.info("Restored user session: \(savedUser.userId)")
        }
    }
    
    // MARK: - Keychain Storage
    
    private func saveUserToKeychain(_ user: User) {
        guard let data = try? JSONEncoder().encode(user) else {
            logger.error("Failed to encode user data for keychain")
            return
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "appleUser",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete any existing entry first
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            logger.info("User data saved to keychain successfully")
        } else {
            logger.error("Failed to save user data to keychain: \(status)")
        }
    }
    
    private func loadUserFromKeychain() -> User? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "appleUser",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let user = try? JSONDecoder().decode(User.self, from: data) {
            return user
        } else {
            logger.error("Failed to load user data from keychain: \(status)")
            return nil
        }
    }
    
    private func deleteUserFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "appleUser"
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess {
            logger.info("User data deleted from keychain successfully")
        } else {
            logger.error("Failed to delete user data from keychain: \(status)")
        }
    }
}
