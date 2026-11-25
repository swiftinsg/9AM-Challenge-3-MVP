//
//  DietaryPreferences.swift
//  9AM Challenge 3 MVP
//
//  Dietary restriction matching, restaurant ranking, and the little Munchkin
//  message shown alongside each restaurant result.
//

import SwiftUI
import CoreLocation

// MARK: - Restrictions

struct DietaryRestriction: Hashable, Identifiable {
    let key: String
    let label: String
    /// Words in a restaurant's name/cuisine that suggest it fits.
    let positive: [String]
    /// Words that suggest it does not fit.
    let negative: [String]

    var id: String { key }

    static let vegetarian = DietaryRestriction(
        key: "dietVegetarian",
        label: "vegetarian",
        positive: [
            "vegetarian", "vegan", "veggie", "veg", "meat-free", "meat free",
            "plant-based", "plant based", "plantbased"
        ],
        negative: [
            "steak", "seafood", "bbq", "barbecue", "chicken", "pork", "bacon",
            "hotpot", "burger", "grill", "fish", "meat", "kebab", "sausage",
            "ham", "duck", "lamb", "satay", "rendang", "fried rice"
        ]
    )

    static let vegan = DietaryRestriction(
        key: "dietVegan",
        label: "vegan",
        positive: [
            "vegan", "plant-based", "plant based", "plantbased", "meat-free",
            "meat free", "raw food"
        ],
        negative: [
            "steak", "seafood", "bbq", "barbecue", "chicken", "pork", "bacon",
            "hotpot", "burger", "grill", "fish", "meat", "kebab", "sausage",
            "ham", "duck", "lamb", "satay", "rendang", "cheese", "ice cream",
            "gelato", "milk", "egg", "honey", "yogurt", "butter", "cream"
        ]
    )

    static let halal = DietaryRestriction(
        key: "dietHalal",
        label: "halal-friendly",
        positive: ["halal", "halal-friendly", "halal friendly"],
        negative: ["pork", "bacon", "ham", "liquor", "alcohol", "pub", "sausage"]
    )

}

struct DietaryPreferences {
    var vegetarian: Bool
    var vegan: Bool
    var halal: Bool

    /// Reads the same keys the Profile toggles write to.
    static func current() -> DietaryPreferences {
        let defaults = UserDefaults.standard
        return DietaryPreferences(
            vegetarian: defaults.bool(forKey: "dietVegetarian"),
            vegan: defaults.bool(forKey: "dietVegan"),
            halal: defaults.bool(forKey: "dietHalal")
        )
    }

    var active: [DietaryRestriction] {
        var restrictions: [DietaryRestriction] = []
        if vegetarian { restrictions.append(.vegetarian) }
        if vegan { restrictions.append(.vegan) }
        if halal { restrictions.append(.halal) }
        return restrictions
    }

    var isEmpty: Bool { active.isEmpty }

    var summaryMessage: String {
        guard !isEmpty else {
            return "Pick a dietary restriction and I'll push the spots that fit it to the top!"
        }
        if vegan {
            return "I'll put fully vegan spots first, then places with vegan options — check the menu before ordering!"
        }
        let needs = active.count == 1
            ? "all of your dietary needs"
            : "all \(active.count) of your dietary needs"
        return "I'll only recommend spots that match \(needs) — no maybes!"
    }
}

// MARK: - Adherence

struct DietAdherence {
    let matched: [DietaryRestriction]
    let uncertain: [DietaryRestriction]
    let conflicting: [DietaryRestriction]
    let total: Int
    /// True when a vegan diner has dedicated vegan dishes to order, even if
    /// the kitchen itself is not fully vegan.
    let veganOptionsAvailable: Bool

    var adheresToAll: Bool { conflicting.isEmpty && uncertain.isEmpty }

    /// Shown in recommendation lists: full matches, plus venues that still
    /// have vegan options when the user is vegan. Those rank lower.
    var isRecommended: Bool {
        adheresToAll || (veganOptionsAvailable && conflicting.isEmpty)
    }

    /// 1.0 when every restriction is satisfied, lower when some are only
    /// unconfirmed or clash. Used to rank restaurants when the diet filter
    /// is switched off.
    var score: Double {
        guard total > 0 else { return 1 }
        let value = Double(matched.count) + 0.25 * Double(uncertain.count)
        return value / Double(total)
    }

    var message: String {
        if total == 0 {
            return "No dietary restrictions set — Munchkin says every spot is fair game!"
        }
        if adheresToAll {
            let needs = total == 1
                ? "all of your dietary needs"
                : "all \(total) of your dietary needs"
            return "Munchkin checked what we know: this spot matches \(needs)! ✅"
        }

        if veganOptionsAvailable {
            let base = "Munchkin says this spot isn't purely vegan, but it has vegan options — check the menu before ordering!"
            if matched.isEmpty {
                return base
            }
            return "Munchkin can confirm \(joined(matched.map(\.label))). This spot isn't purely vegan, but it has vegan options — check the menu!"
        }

        let confirmed = matched.map(\.label)
        let unsure = uncertain.map(\.label)
        let clashes = conflicting.map(\.label)

        if conflicting.isEmpty {
            if confirmed.isEmpty {
                return "Munchkin can't confirm \(joined(unsure)) here — please check with the restaurant."
            }
            return "Munchkin can confirm \(joined(confirmed)), but isn't sure about \(joined(unsure)) here."
        }

        if confirmed.isEmpty && unsure.isEmpty {
            return "Munchkin spotted a possible clash with \(joined(clashes)) here — please double-check."
        }

        let confirmedText = confirmed.isEmpty ? "nothing confirmed" : joined(confirmed)
        let unsureText = unsure.isEmpty ? "" : ", and isn't sure about \(joined(unsure))"
        return "Munchkin found \(confirmedText)\(unsureText), but spotted a possible clash with \(joined(clashes))."
    }

    var tint: Color {
        if total == 0 { return Color.gray.opacity(0.12) }
        if adheresToAll { return Color.green.opacity(0.16) }
        if conflicting.isEmpty { return Color.orange.opacity(0.15) }
        return Color.red.opacity(0.12)
    }

    private func joined(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        case 2: return "\(items[0]) and \(items[1])"
        default: return "\(items.dropLast().joined(separator: ", ")), and \(items[items.count - 1])"
        }
    }
}

extension Restaurant {
    /// How well this restaurant fits the selected restrictions. Curated venues
    /// carry an explicit classification; everything else falls back to keyword
    /// matching against the name and cuisine, which is deliberately worded as
    /// a "best guess" in the Munchkin message.
    func dietAdherence(for preferences: DietaryPreferences) -> DietAdherence {
        guard let dietClass else {
            return keywordAdherence(for: preferences)
        }
        return classifiedAdherence(for: preferences, classifiedAs: dietClass)
    }

    private func classifiedAdherence(
        for preferences: DietaryPreferences,
        classifiedAs dietClass: DietClass
    ) -> DietAdherence {
        var matched: [DietaryRestriction] = []
        var uncertain: [DietaryRestriction] = []
        let conflicting: [DietaryRestriction] = []
        var offersVeganOptions = false

        for restriction in preferences.active {
            switch (restriction.key, dietClass) {
            case ("dietVegetarian", .vegan),
                 ("dietVegetarian", .vegetarianWithVeganOptions),
                 ("dietVegetarian", .vegetarian),
                 ("dietVegetarian", .mixedWithVeganOptions),
                 ("dietVegan", .vegan):
                matched.append(restriction)
            case ("dietVegan", .vegetarianWithVeganOptions):
                // Vegetarian kitchens may still use dairy, eggs or honey, but
                // they do offer vegan dishes for the diner to choose.
                offersVeganOptions = true
                uncertain.append(restriction)
            case ("dietVegan", .mixedWithVeganOptions):
                // Mixed menu, but dedicated vegan options are available.
                offersVeganOptions = true
                uncertain.append(restriction)
            case ("dietVegan", .vegetarian):
                // Vegetarian-only kitchens are not guaranteed to have vegan
                // dishes, so vegan diners should check with the restaurant.
                uncertain.append(restriction)
            default:
                // Halal and any future restriction is not covered by the
                // vegetarian/vegan classification.
                uncertain.append(restriction)
            }
        }

        return DietAdherence(
            matched: matched,
            uncertain: uncertain,
            conflicting: conflicting,
            total: preferences.active.count,
            veganOptionsAvailable: offersVeganOptions
        )
    }

    private func keywordAdherence(for preferences: DietaryPreferences) -> DietAdherence {
        let searchableText = "\(name) \(cuisine)".lowercased()

        var matched: [DietaryRestriction] = []
        var uncertain: [DietaryRestriction] = []
        var conflicting: [DietaryRestriction] = []

        for restriction in preferences.active {
            // Halal status comes from the bundled MUIS list, not name guessing.
            if restriction.key == "dietHalal" && isHalalCertified {
                matched.append(restriction)
            } else if restriction.positive.contains(where: { searchableText.contains($0) }) {
                matched.append(restriction)
            } else if restriction.negative.contains(where: { searchableText.contains($0) }) {
                conflicting.append(restriction)
            } else {
                uncertain.append(restriction)
            }
        }

        // A vegan spot also satisfies a vegetarian restriction.
        if matched.contains(where: { $0.key == "dietVegan" }) {
            let impliedVegetarian = uncertain.first { $0.key == "dietVegetarian" }
                ?? conflicting.first { $0.key == "dietVegetarian" }
            uncertain.removeAll { $0.key == "dietVegetarian" }
            conflicting.removeAll { $0.key == "dietVegetarian" }
            if let impliedVegetarian { matched.append(impliedVegetarian) }
        }

        return DietAdherence(
            matched: matched,
            uncertain: uncertain,
            conflicting: conflicting,
            total: preferences.active.count,
            veganOptionsAvailable: false
        )
    }
}

// MARK: - Filtering

extension RestaurantDirectory {
    /// Restaurants that fit the selected restrictions. This is every full
    /// match, plus venues that still have vegan options when the diner is
    /// vegan. When no restrictions are selected, every restaurant is eligible.
    static func matchingDiet(
        _ restaurants: [Restaurant],
        using preferences: DietaryPreferences
    ) -> [Restaurant] {
        guard !preferences.isEmpty else { return restaurants }
        return restaurants.filter { $0.dietAdherence(for: preferences).isRecommended }
    }

    /// Weekly picks ordered by dietary fit. Full matches come first, then
    /// venues with vegan options for vegan diners, then weaker matches. The
    /// curated weekly picks break ties so the home screen stays varied.
    /// Weekly picks that honour every restriction. When Halal is selected the
    /// curated pool comes from the verified MUIS directory instead of OSM.
    static func dietAwareWeeklyPicks(
        for region: RestaurantRegion,
        using preferences: DietaryPreferences
    ) -> [Restaurant] {
        let useHalalDirectory = preferences.halal
        let picks = weeklyPicks(for: region, halalOnly: useHalalDirectory)
        guard !preferences.isEmpty else { return picks }

        let safeDirectory = matchingDiet(
            restaurants(in: region, halalOnly: useHalalDirectory),
            using: preferences
        )
        var result = matchingDiet(picks, using: preferences)
        var seenIDs = Set(result.map(\.id))

        for restaurant in safeDirectory where !seenIDs.contains(restaurant.id) {
            result.append(restaurant)
            seenIDs.insert(restaurant.id)
        }
        return result
    }

    /// Orders the weekly picks for the current taste profile. Dietary fit stays
    /// the top priority, then how well the spot matches the persona's cravings,
    /// then distance when the "Near Me" filter is active.
    static func personalizedWeeklyPicks(
        _ picks: [Restaurant],
        tasteCravings: [String],
        near location: CLLocation? = nil,
        using preferences: DietaryPreferences? = nil
    ) -> [Restaurant] {
        guard !tasteCravings.isEmpty || location != nil else { return picks }

        let activePreferences = preferences.flatMap { $0.isEmpty ? nil : $0 }

        return picks
            .map { restaurant -> (restaurant: Restaurant, diet: Double, taste: Int, distance: CLLocationDistance?) in
                let dietScore = activePreferences.map {
                    restaurant.dietAdherence(for: $0).score
                } ?? 0
                let tasteScore = restaurant.matchingCravings(tasteCravings).count
                let distance = location.map {
                    CLLocation(
                        latitude: restaurant.latitude,
                        longitude: restaurant.longitude
                    ).distance(from: $0)
                }
                return (restaurant, dietScore, tasteScore, distance)
            }
            .sorted { lhs, rhs in
                if lhs.diet != rhs.diet { return lhs.diet > rhs.diet }
                if lhs.taste != rhs.taste { return lhs.taste > rhs.taste }
                if let lhsDistance = lhs.distance, let rhsDistance = rhs.distance,
                   lhsDistance != rhsDistance {
                    return lhsDistance < rhsDistance
                }
                return lhs.restaurant.name.localizedCaseInsensitiveCompare(rhs.restaurant.name)
                    == .orderedAscending
            }
            .map(\.restaurant)
    }

}

// MARK: - Munchkin message

/// Compact note used under recommendation cards so the Munchkin verdict is
/// visible without opening the restaurant.
struct MunchkinDietNote: View {
    let adherence: DietAdherence

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            MunchkinAvatarView(size: 20)

            Text(adherence.message)
                .font(.dynaPuff(11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

struct MunchkinDietMessage: View {
    let adherence: DietAdherence
    var showMascot: Bool = true

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Text(adherence.message)
                .font(.dynaPuff(13))
                .foregroundStyle(.primary)
                .padding(10)
                .background(adherence.tint)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            if showMascot {
                MunchkinAvatarView(size: 32)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
