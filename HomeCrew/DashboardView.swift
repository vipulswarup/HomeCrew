//
//  DashboardView.swift
//  HomeCrew
//
//  Created by Vipul Swarup on 08/03/25.
//


import SwiftUI

struct DashboardView: View {
    var firstName: String {
        UserDefaults.standard.string(forKey: "firstName") ?? "User"
    }

    var body: some View {
        VStack {
            Text("Welcome, \(firstName)!")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.black)
                .padding()

            Spacer()

            Text("Your dashboard will show up here.")
                .font(.system(size: 18))
                .foregroundColor(.gray)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
    }
}
