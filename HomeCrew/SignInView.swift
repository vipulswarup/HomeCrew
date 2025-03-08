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

            // App Name
            Text("HomeCrew")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 10)

            // Tagline
            Text("Manage your House Hold Staff")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .padding(.bottom, 20)

            Spacer()

            // Apple Sign-in button
            SignInWithAppleButton(action: handleSignInWithApple)
                .frame(width: 280, height: 50)
                .padding()

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 173/255, green: 101/255, blue: 199/255).ignoresSafeArea()) // #ad65c7
    }

    // Function to handle sign-in
    private func handleSignInWithApple() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.performRequests()
    }
}

struct SignInWithAppleButton: View {
    let action: () -> Void // Action callback

    var body: some View {
        SignInWithAppleButtonView(action: action)
            .frame(width: 280, height: 50)
            .cornerRadius(10)
    }
}

struct SignInWithAppleButtonView: UIViewRepresentable {
    let action: () -> Void

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton()
        button.addTarget(context.coordinator, action: #selector(Coordinator.didTapButton), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}

    func makeCoordinator() -> Coordinator {
        return Coordinator(action: action)
    }

    class Coordinator: NSObject {
        let action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func didTapButton() {
            action() // Calls handleSignInWithApple()
        }
    }
}
