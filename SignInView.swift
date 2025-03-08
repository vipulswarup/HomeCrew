import SwiftUI
import AuthenticationServices

struct SignInView: View {
    var body: some View {
        VStack {
            // App Logo
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .padding(.top, 50)

            Spacer()

            // Apple Sign-in button
            SignInWithAppleButton()
                .frame(width: 280, height: 50)
                .padding()

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Add this line to make VStack fill the screen
        .background(Color.purple.ignoresSafeArea()) // Updated to newer API
    }
}

struct SignInWithAppleButton: View {
    var body: some View {
        SignInWithAppleButtonView()
            .frame(width: 280, height: 50)
            .cornerRadius(10)
    }
}

struct SignInWithAppleButtonView: UIViewRepresentable {
    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        return ASAuthorizationAppleIDButton()
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}
}

struct SignInView_Previews: PreviewProvider {
    static var previews: some View {
        SignInView()
    }
}
