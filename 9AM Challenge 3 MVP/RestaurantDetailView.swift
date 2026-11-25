//
//  RestaurantDetailView.swift
//  9AM Challenge 3 MVP
//
//  Created by Ashmi Sharma on 13/11/26.
//



import SwiftUI

struct RestaurantDetailView: View {

    let restaurant: Restaurant

    /// The tick is stored directly, never derived from visit history, so an
    /// unchecked box stays unchecked when the screen is reopened.
    @AppStorage("checked_restaurant_ids_v2") private var checkedRaw = ""

    private var checkedIDs: Set<String> {
        Set(checkedRaw.split(separator: ",").map(String.init))
    }

    private var hasVisited: Bool {
        checkedIDs.contains(restaurant.id)
    }

    private func setVisited(_ visited: Bool) {
        var ids = checkedIDs
        if visited {
            ids.insert(restaurant.id)
        } else {
            ids.remove(restaurant.id)
        }
        checkedRaw = ids.sorted().joined(separator: ",")
    }

    /// Directory phone numbers can contain spaces or tabs, so strip anything
    /// that is not part of a dialable number before building the tel: link.
    private var phoneNumber: String {
        restaurant.phone.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var phoneDialURL: URL? {
        let digits = phoneNumber.filter { $0.isASCII && ($0.isNumber || $0 == "+") }
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel://\(digits)")
    }

    // Kept here so the detail screen can show Munchkin's dietary check too.
    @AppStorage("dietVegetarian") private var vegetarian = false
    @AppStorage("dietVegan") private var vegan = false
    @AppStorage("dietHalal") private var halal = false

    private var diet: DietaryPreferences {
        DietaryPreferences(
            vegetarian: vegetarian,
            vegan: vegan,
            halal: halal
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {

                // MARK: Restaurant photo
                Text(restaurant.emoji)
                    .font(.dynaPuff(110))
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(
                        RoundedRectangle(cornerRadius: 20)
                    )

                // MARK: Restaurant name
                VStack(alignment: .leading, spacing: 8) {
                    Text(restaurant.name)
                        .font(.dynaPuff(34))
                        .fontWeight(.bold)

                    Text(restaurant.description)
                        .font(.dynaPuff(15))
                        .foregroundStyle(AppColor.secondaryText)

                    if restaurant.isHalalCertified {
                        Text("MUIS halal certified")
                            .font(.dynaPuff(13).weight(.medium))
                            .foregroundStyle(AppColor.secondaryText)
                    }

                    if !restaurant.summary.isEmpty {
                        Text(restaurant.summary)
                            .font(.dynaPuff(15))
                            .foregroundStyle(.secondary)
                    }

                    MunchkinDietMessage(
                        adherence: restaurant.dietAdherence(for: diet)
                    )
                }

                Divider()

                // MARK: Restaurant information
                VStack(alignment: .leading, spacing: 15) {

                    Text("Restaurant Information")
                        .font(.dynaPuff(22))
                        .fontWeight(.medium)

                    Label(
                        "Location: \(restaurant.locationLine)",
                        systemImage: "mappin.circle.fill"
                    )

                    Label(
                        "Cuisine: \(restaurant.cuisine)",
                        systemImage: "fork.knife"
                    )

                    Label(
                        "Region: \(restaurant.region.rawValue)",
                        systemImage: "map.circle.fill"
                    )

                    if !phoneNumber.isEmpty {
                        if let phoneDialURL {
                            Link(destination: phoneDialURL) {
                                Label(
                                    "Phone: \(phoneNumber)",
                                    systemImage: "phone.circle.fill"
                                )
                            }
                            .tint(.orange)
                            .accessibilityLabel("Call \(phoneNumber)")
                        } else {
                            Label(
                                "Phone: \(phoneNumber)",
                                systemImage: "phone.circle.fill"
                            )
                        }
                    }

                    if let websiteURL = restaurant.websiteURL {
                        Link(destination: websiteURL) {
                            Label("Website", systemImage: "globe")
                        }
                    }
                }

                Divider()

                // MARK: Menu
                VStack(alignment: .leading, spacing: 12) {
                    Text("Menu Highlights 🍽️")
                        .font(.dynaPuff(22))
                        .fontWeight(.medium)

                    Text("🍜 Signature Dish")
                    Text("🥟 Chef's Special")
                    Text("🥤 House Drink")
                }

                Divider()

                // MARK: Visited status
                VStack(alignment: .leading, spacing: 15) {
                    Text("Have you visited?")
                        .font(.dynaPuff(22))
                        .fontWeight(.medium)

                    Button {
                        if hasVisited {
                            setVisited(false)
                            uncheckVisit()
                        } else {
                            setVisited(true)
                            recordVisitIfNeeded()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: hasVisited ? "checkmark.square.fill" : "square")
                                .font(.dynaPuff(22))
                                .foregroundStyle(hasVisited ? .orange : AppColor.secondaryText)
                            Text("I've eaten here!")
                                .foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)

                    Text("Each spot counts once, for one quest only. Cuisine goals need different cuisines.")
                        .font(.dynaPuff(13))
                        .foregroundStyle(AppColor.secondaryText)
                }
            }
            .padding(20)
        }
        .background(
            AppColor.background
        )
        .navigationTitle("Restaurant Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Visit progress

    /// Checking a spot pays the first unfinished food goal. A spot already
    /// spent on another quest is ignored, so a new goal needs new restaurants.
    func recordVisitIfNeeded() {
        VisitedRestaurants.markVisited(restaurant.id)

        guard RestaurantGoalCredits.credit(for: restaurant.id) == nil,
              let goal = activeFoodGoal() else { return }

        let cuisineKey = GoalKeywords.isCuisineRelated(goal.title)
            ? RestaurantGoalCredits.normalized(restaurant.cuisine)
            : nil

        // "New cuisines" means a cuisine no previous quest has claimed.
        if let cuisineKey, RestaurantGoalCredits.usesCuisine(cuisineKey) { return }

        RestaurantGoalCredits.add(RestaurantGoalCredit(
            restaurantID: restaurant.id,
            goalID: goal.id,
            cuisineKey: cuisineKey
        ))
        incrementRestaurantGoal(goalID: goal.id)
    }

    /// Unchecking returns that spot's point to the goal it paid.
    func uncheckVisit() {
        guard let credit = RestaurantGoalCredits.remove(for: restaurant.id) else { return }
        decrementRestaurantGoal(goalID: credit.goalID)
    }

    private func activeFoodGoal() -> GoalItem? {
        guard let data = UserDefaults.standard.data(forKey: "goals_v1"),
              let goals = try? JSONDecoder().decode([GoalItem].self, from: data)
        else { return nil }
        return goals.first { $0.completedAt == nil && GoalKeywords.isFoodRelated($0.title) }
    }

    private func incrementRestaurantGoal(goalID: UUID) {
        var goals = loadGoals()
        guard let idx = goals.firstIndex(where: { $0.id == goalID }) else { return }
        // Already paid out — toggling a box must not reopen the reward.
        guard goals[idx].rewardClaimed != true else { return }

        goals[idx].progress += 1
        if goals[idx].progress >= goals[idx].target {
            goals[idx].progress = goals[idx].target
            goals[idx].completedAt = Date()
            // Explicitly mark the reward as unclaimed. Completed goals with a
            // nil flag are treated as legacy by the Goals screen, so a fresh
            // completion must say "not paid yet" rather than leaving it unset.
            goals[idx].rewardClaimed = false
        }

        saveGoals(goals)
    }

    private func decrementRestaurantGoal(goalID: UUID) {
        var goals = loadGoals()
        guard let idx = goals.firstIndex(where: { $0.id == goalID }) else { return }
        // Claimed rewards are history; leave the paid goal untouched.
        guard goals[idx].rewardClaimed != true else { return }

        goals[idx].progress = max(0, goals[idx].progress - 1)
        if goals[idx].progress < goals[idx].target {
            // No longer earned: drop the completed flag/checkmark as well, so
            // the goal goes back to being plainly in progress.
            goals[idx].completedAt = nil
        }

        saveGoals(goals)
    }

    private func loadGoals() -> [GoalItem] {
        guard let data = UserDefaults.standard.data(forKey: "goals_v1"),
              let goals = try? JSONDecoder().decode([GoalItem].self, from: data)
        else { return [] }
        return goals
    }

    private func saveGoals(_ goals: [GoalItem]) {
        guard let data = try? JSONEncoder().encode(goals) else { return }
        UserDefaults.standard.set(data, forKey: "goals_v1")
    }

}

#Preview {
    NavigationStack {
        RestaurantDetailView(restaurant: .preview)
    }
}
