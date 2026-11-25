//
//  VisitedRestaurants.swift
//  9AM Challenge 3 MVP
//
//  Remembers which restaurants the user has eaten at, and which food goal each
//  checked restaurant has paid. A spot can only ever pay one quest, and cuisine
//  goals count each cuisine once no matter how many spots serve it.
//

import Foundation

enum VisitedRestaurants {
    private static let key = "visited_restaurant_ids_v1"

    static func all() -> Set<String> {
        let defaults = UserDefaults.standard

        if let data = defaults.data(forKey: key),
           let saved = try? JSONDecoder().decode([String].self, from: data) {
            return Set(saved)
        }

        return []
    }

    static func contains(_ id: String) -> Bool {
        all().contains(id)
    }

    /// Returns true only the first time a restaurant is marked as visited.
    @discardableResult
    static func markVisited(_ id: String) -> Bool {
        var ids = all()
        let inserted = ids.insert(id).inserted
        if inserted { save(ids) }
        return inserted
    }

    private static func save(_ ids: Set<String>) {
        guard let data = try? JSONEncoder().encode(ids.sorted()) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

/// A checked restaurant pays exactly one food goal. Keeping the pairing means
/// a spot already spent on one quest can never complete another, even one that
/// is added later.
struct RestaurantGoalCredit: Codable {
    let restaurantID: String
    let goalID: UUID
    /// Set only for cuisine goals, so two spots serving the same cuisine still
    /// pay just once.
    let cuisineKey: String?
}

enum RestaurantGoalCredits {
    private static let key = "restaurant_goal_credits_v1"

    static func all() -> [RestaurantGoalCredit] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([RestaurantGoalCredit].self, from: data)
        else { return [] }
        return decoded
    }

    static func credit(for restaurantID: String) -> RestaurantGoalCredit? {
        all().first { $0.restaurantID == restaurantID }
    }

    /// True once any quest has used a spot serving this cuisine.
    static func usesCuisine(_ key: String) -> Bool {
        let target = normalized(key)
        return all().contains { credit in
            // Credits from older builds predate cuisineKey, so fall back to
            // the restaurant saved in the directory.
            let cuisine = credit.cuisineKey
                ?? RestaurantDirectory.all.first { $0.id == credit.restaurantID }?.cuisine
                ?? ""
            return normalized(cuisine) == target
        }
    }

    static func add(_ credit: RestaurantGoalCredit) {
        var credits = all().filter { $0.restaurantID != credit.restaurantID }
        credits.append(credit)
        save(credits)
    }

    @discardableResult
    static func remove(for restaurantID: String) -> RestaurantGoalCredit? {
        let credits = all()
        guard let found = credits.first(where: { $0.restaurantID == restaurantID }) else { return nil }
        save(credits.filter { $0.restaurantID != restaurantID })
        return found
    }

    static func normalized(_ cuisine: String) -> String {
        cuisine.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private static func save(_ credits: [RestaurantGoalCredit]) {
        guard let data = try? JSONEncoder().encode(credits) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
