//
//  MainTabView.swift
//  HomeCrew
//
//  Created by Vipul Swarup on 08/03/25.
//


import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomesView()
                .tabItem {
                    Label("Homes", systemImage: "house.fill")
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
}
