//
//  MainWeeklyRecsView.swift
//  9AM Challenge 3 MVP
//
//  Created by Ashmi Sharma on 13/11/26.
//


import SwiftUI

struct WeeklyRecsView: View {

    @AppStorage("preferredLocation")
    private var preferredLocation = "Anywhere"

    @AppStorage("dietVegetarian") private var vegetarian = false
    @AppStorage("dietVegan") private var vegan = false
    @AppStorage("dietHalal") private var halal = false

    @State private var selectedRestaurant: Restaurant?
    @State private var searchText = ""

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
        RestaurantDirectory.dietAwareWeeklyPicks(for: region, using: diet)
    }

    private var visibleRestaurants: [Restaurant] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return restaurants }
        return restaurants.filter { restaurant in
            restaurant.name.localizedCaseInsensitiveContains(query)
                || restaurant.cuisine.localizedCaseInsensitiveContains(query)
                || restaurant.area.localizedCaseInsensitiveContains(query)
        }
    }

    /// True for a vegan-friendly pick that is not fully vegan, so Munchkin can
    /// explain why it still appears further down the list.
    private func showsDietNote(for restaurant: Restaurant) -> Bool {
        guard !diet.isEmpty else { return false }
        let adherence = restaurant.dietAdherence(for: diet)
        return adherence.isRecommended && !adherence.adheresToAll
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {

                Text("Weekly Recommendations")
                    .font(.dynaPuff(34))
                    .fontWeight(.medium)

                Text(
                    region.isAnywhere
                        ? "Handpicked by Munchkin, just for you!"
                        : "Handpicked by Munchkin for the \(region.rawValue) region!"
                )
                .font(.dynaPuff(15))
                .foregroundStyle(AppColor.secondaryText)

                RegionFilterBar(selection: $preferredLocation)

                if visibleRestaurants.isEmpty {
                    ContentUnavailableView(
                        !searchText.isEmpty
                            ? "No results for \"\(searchText)\""
                            : (diet.isEmpty
                                ? "No picks for \(region.rawValue) yet"
                                : "No dietary matches in \(region.rawValue)"),
                        systemImage: searchText.isEmpty ? "fork.knife" : "magnifyingglass",
                        description: Text(
                            !searchText.isEmpty
                                ? "Try a different name, cuisine or area."
                                : (diet.isEmpty
                                    ? "Try another region or choose Anywhere."
                                    : "No spots match all your dietary needs here. Try another region or relax a restriction.")
                        )
                    )
                }

                ForEach(visibleRestaurants) { restaurant in
                    VStack(alignment: .leading, spacing: 6) {
                        Button {
                            selectedRestaurant = restaurant
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
            .padding(20)
        }
        .background(
            AppColor.background
        )
        .searchable(text: $searchText, prompt: "Search name, cuisine or area")

        // Opens the half-sheet
        .sheet(item: $selectedRestaurant) { restaurant in
            RestaurantPreviewSheet(
                restaurant: restaurant,
                reason: restaurant.recommendationReason,
                adherence: restaurant.dietAdherence(for: diet)
            )
        }
    }
}

#Preview {
    NavigationStack {
        WeeklyRecsView()
    }
}
