//
//  SignInView.swift
//  HomeCrew
//
//  Created by Vipul Swarup on 08/03/25.
//


import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @StateObject private var authManager = AuthManager()
    
    var body: some View {
        VStack {
            Spacer()
            
            if let user = authManager.currentUser {
                Text("Welcome, \(user.fullName ?? "User")!")
                    .font(.title)
                    .padding()
                
                Button("Sign Out") {
                    authManager.signOut()
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
                
            } else {
                SignInWithAppleButton(.signIn) { request in
                    authManager.handleSignInRequest(request)
                } onCompletion: { result in
                    authManager.handleSignInResult(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .padding()
            }
            
            Spacer()
        }
        .onAppear {
            authManager.checkUserState()
        }
    }
}
