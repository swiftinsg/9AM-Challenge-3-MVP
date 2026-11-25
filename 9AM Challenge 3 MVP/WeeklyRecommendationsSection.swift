//
//  WeeklyRecommendationsSection.swift
//  9AM Challenge 3 MVP
//
//  Created by Ashmi Sharma on 13/11/26.
//

import SwiftUI

struct WeeklyRecommendationsSection: View {
    @AppStorage("preferredLocation")
    private var preferredLocation = "Anywhere"

    @AppStorage("dietVegetarian") private var vegetarian = false
    @AppStorage("dietVegan") private var vegan = false
    @AppStorage("dietHalal") private var halal = false

    @StateObject private var location = UserLocationProvider()

    /// The unrestricted region option becomes "Near Me" only while location is
    /// available. Without permission it stays "Anywhere" and shows every spot.
    private var isNearMe: Bool {
        preferredLocation == "Anywhere" && location.isAuthorized
    }

    private var persona: FoodPersona {
        FoodPersonaStore.resolve().persona
    }

    private var region: RestaurantRegion {
        RestaurantRegion.from(preference: preferredLocation)
    }

    private var diet: DietaryPreferences {
        DietaryPreferences(
            vegetarian: vegetarian,
            vegan: vegan,
            halal: halal
        )
    }

    private var restaurants: [Restaurant] {
        let picks = RestaurantDirectory.dietAwareWeeklyPicks(for: region, using: diet)
        let ranked = RestaurantDirectory.personalizedWeeklyPicks(
            picks,
            tasteCravings: persona.tasteCravings,
            near: isNearMe ? location.location : nil,
            using: diet
        )
        return Array(ranked.prefix(3))
    }

    /// True for a vegan-friendly pick that is not fully vegan, so Munchkin can
    /// explain why it still appears further down the list.
    private func showsDietNote(for restaurant: Restaurant) -> Bool {
        guard !diet.isEmpty else { return false }
        let adherence = restaurant.dietAdherence(for: diet)
        return adherence.isRecommended && !adherence.adheresToAll
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("Top Weekly Recommendations")
                    .font(.dynaPuff(17))

                Spacer()

                NavigationLink(destination: WeeklyRecsView()) {
                    HStack(spacing: 4) {
                        Text("View All")

                        Image(systemName: "arrow.right")
                    }
                    .font(.dynaPuff(15))
                    .foregroundStyle(.blue)
                }
            }

            Text("Picked for \(persona.shortTaste) tastes")
                .font(.dynaPuff(12))
                .foregroundStyle(AppColor.secondaryText)

            HStack {
                Menu {
                    Picker("Region", selection: $preferredLocation) {
                        ForEach(RestaurantRegion.allCases) { region in
                            Text(region.isAnywhere && location.isAuthorized
                                 ? "Near Me"
                                 : region.rawValue)
                                .tag(region.rawValue)
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: isNearMe
                              ? "location.fill"
                              : "mappin.circle.fill")

                        Text(
                            isNearMe
                                ? "Near Me"
                                : (region.isAnywhere ? "Anywhere" : "\(region.rawValue) region")
                        )

                        Image(systemName: "chevron.down")
                            .font(.dynaPuff(11))
                    }
                    .font(.dynaPuff(13).weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
                }
                .accessibilityLabel(isNearMe ? "Near Me" : "Preferred region")

                Spacer()
            }

            NearMeStatusMessage(location: location, isActive: isNearMe)

            if restaurants.isEmpty {
                Text(diet.isEmpty
                     ? "No picks in this region yet. Try another region."
                     : "No spots here match all your dietary needs. Try another region or relax a restriction.")
                    .font(.dynaPuff(13))
                    .foregroundStyle(AppColor.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                ForEach(restaurants) { restaurant in
                    VStack(alignment: .leading, spacing: 6) {
                        NavigationLink {
                            RestaurantDetailView(restaurant: restaurant)
                        } label: {
                            RestaurantCard(restaurant: restaurant)
                        }
                        .buttonStyle(.plain)

                        if showsDietNote(for: restaurant) {
                            MunchkinDietNote(adherence: restaurant.dietAdherence(for: diet))
                                .padding(.horizontal, 6)
                        }
                    }
                }
            }
        }
        .onAppear {
            location.refreshStatus()
            if isNearMe { location.requestLocation() }
        }
        .onChange(of: isNearMe) { _, newValue in
            if newValue { location.requestLocation() }
        }
    }
}
