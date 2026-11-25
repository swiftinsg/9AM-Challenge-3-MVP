//
//  ContentView.swift
//  9AM Challenge 3 MVP
//
//  Created by Ashmi Sharma on 13/11/26.
//

import SwiftUI

enum ContentTab: Hashable {
    case home
    case mixer
    case goals
    case shop
    case profile
}

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage(AppAppearance.storageKey) private var appearanceMode = AppAppearance.device

    @StateObject private var location = UserLocationProvider()
    @State private var showLocationPrompt = false
    @State private var selectedTab: ContentTab = .home

    private func openShop() {
        selectedTab = .shop
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: .home) {
                HomeView(onCurrencyTap: openShop)
                    .balancedContentWidth()
            }
            Tab("Munchie Mixer", systemImage: "mug.fill", value: .mixer) {
                MunchieMixerView()
                    .balancedContentWidth()
            }
            Tab("Goals", systemImage: "target", value: .goals) {
                GoalsView(onCurrencyTap: openShop)
                    .balancedContentWidth()
            }
            Tab("Munchkin Shop", systemImage: "bag.fill", value: .shop) {
                NavigationStack {
                    ShopView()
                }
                .balancedContentWidth()
            }
            Tab("Profile", systemImage: "person.crop.circle.fill", value: .profile) {
                ProfileView()
                    .balancedContentWidth()
            }
        }
        .preferredColorScheme(AppAppearance.colorScheme(for: appearanceMode))
        .onAppear {
            location.refreshStatus()
            if hasCompletedOnboarding && !location.isAuthorized {
                showLocationPrompt = true
            }
        }
        .onChange(of: hasCompletedOnboarding) { _, completed in
            // Ask again on every open while permission is missing, including
            // right after the tutorial finishes on first launch.
            if completed && !location.isAuthorized {
                showLocationPrompt = true
            }
        }
        .alert("Find spots near you?", isPresented: $showLocationPrompt) {
            Button("Allow Location") {
                location.requestPermission()
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("Munchkins can sort weekly picks by distance. You can still browse every region with Anywhere.")
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { !hasCompletedOnboarding },
                set: { hasCompletedOnboarding = !$0 }
            )
        ) {
            OnboardingView()
                .balancedContentWidth(maxWidth: 820)
        }
    }
}

#Preview {
    ContentView()
}
