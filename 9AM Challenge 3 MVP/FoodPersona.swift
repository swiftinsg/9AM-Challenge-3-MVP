//
//  FoodPersona.swift
//  9AM Challenge 3 MVP
//
//  Food personas, inferred from the ratings and feedback the user leaves on
//  restaurants. The pet changes when the reviews change; with no reviews it
//  stays on the starting pet chosen in onboarding.
//

import Foundation
import SwiftUI

extension Notification.Name {
    /// Posted when onboarding picks a new starting Munchkin so screens showing
    /// the pet can refresh before the onboarding sheet is dismissed.
    static let personaDidChange = Notification.Name("personaDidChange")
}

// MARK: - Personas

enum FoodPersona: String, CaseIterable, Identifiable {
    case munchkin = "Munchkin"
    case cookie = "Cookie"
    case fiery = "Fiery"
    // Legacy raw value is kept so personas saved by older builds still load.
    case panda = "Leo"
    case terry = "Terry"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .munchkin: return "🐱"
        case .cookie: return "🐶"
        case .fiery: return "🦊"
        case .panda: return "🐼"
        case .terry: return "🐯"
        }
    }

    var name: String {
        switch self {
        case .munchkin: return "Munchkin, the Cat"
        case .cookie: return "Cookie, the Puppy"
        case .fiery: return "Fiery, the Fox"
        case .panda: return "Pam, the Panda"
        case .terry: return "Terry, the Tiger"
        }
    }

    var tagline: String {
        switch self {
        case .munchkin:
            return "You're a certified food lover — spicy, sweet or savoury, if it's edible, you're in!"
        case .cookie:
            return "Like Cookie the puppy, lying on the couch while eating a tub of ice cream from Yo-Chi is your thing!"
        case .fiery:
            return "Spicy delicacies make your mouth water — you live for that fiery, burning sensation!"
        case .panda:
            return "Like Pam the Panda, you love indulging in a nice tangy, juicy treat!"
        case .terry:
            return "Like Terry the Tiger, you love the taste of a nice savoury treat after a long day of work."
        }
    }

    var shortTaste: String {
        switch self {
        case .munchkin: return "a little bit of everything"
        case .cookie: return "sweet things"
        case .fiery: return "spicy things"
        case .panda: return "tangy things"
        case .terry: return "savoury things"
        }
    }

    /// Craving tags used to rank weekly picks. These match the keys in
    /// `Restaurant.matchingCravings`, so a persona's picks reflect its taste.
    var tasteCravings: [String] {
        switch self {
        case .munchkin: return ["Spicy", "Sweet", "Tangy", "Savoury"]
        case .cookie: return ["Sweet"]
        case .fiery: return ["Spicy"]
        case .panda: return ["Tangy"]
        case .terry: return ["Savoury"]
        }
    }

    var accent: Color {
        switch self {
        case .munchkin: return AppColor.personaMunchkin
        case .cookie: return AppColor.personaCookie
        case .fiery: return AppColor.personaFiery
        case .panda: return AppColor.personaPanda
        case .terry: return AppColor.personaTerry
        }
    }

    /// Maps the flavour tags used by the mixer and the review form to a persona.
    static func from(flavour: String) -> FoodPersona? {
        switch flavour.lowercased() {
        case "spicy": return .fiery
        case "sweet": return .cookie
        case "tangy": return .panda
        case "savoury", "salty": return .terry
        default: return nil
        }
    }
}

// MARK: - Review history

enum ReviewHistory {
    /// Every review saved through the restaurant detail screen, including
    /// reviews saved by older versions of the app (which had no date).
    static func all() -> [RestaurantReviewData] {
        UserDefaults.standard.dictionaryRepresentation().compactMap { key, value in
            guard key.hasPrefix("review_"), let data = value as? Data else { return nil }
            return try? JSONDecoder().decode(RestaurantReviewData.self, from: data)
        }
    }
}

// MARK: - Weekly snapshot

struct FoodPersonaSnapshot {
    let persona: FoodPersona
    let explanation: String
    let reviewCount: Int
}

/// Resolves and caches this week's persona. New reviews immediately update the
/// choice, but otherwise the same persona is shown for the whole week.
enum FoodPersonaStore {
    private enum Key {
        static let persona = "persona_id"
        static let fingerprint = "persona_review_fingerprint"
        static let preferred = "preferredPersona"
        static let overrideFingerprint = "persona_override_fingerprint"
        static let reason = "persona_recommendation_reason"
    }

    /// The pet chosen by onboarding is only a starting point. It is shown
    /// until the next review is saved, then the user's feedback decides.
    static func preferredPersona() -> FoodPersona? {
        UserDefaults.standard.string(forKey: Key.preferred)
            .flatMap { FoodPersona(rawValue: $0) }
    }

    static func setPreferredPersona(_ persona: FoodPersona?, reason: String? = nil) {
        // The pet is decided by food preferences only. Once the user has left
        // ratings, those reviews are the sole source of truth and the starting
        // pet can no longer be swapped (e.g. by replaying the tutorial).
        guard ReviewHistory.all().isEmpty else { return }

        let defaults = UserDefaults.standard
        if let persona {
            defaults.set(persona.rawValue, forKey: Key.preferred)
            defaults.set(
                fingerprint(for: ReviewHistory.all()),
                forKey: Key.overrideFingerprint
            )
        } else {
            defaults.removeObject(forKey: Key.preferred)
            defaults.removeObject(forKey: Key.overrideFingerprint)
        }

        if let reason {
            defaults.set(reason, forKey: Key.reason)
        } else {
            defaults.removeObject(forKey: Key.reason)
        }

        _ = resolve(force: true)
    }

    /// The single source of truth used by the Home and Profile persona cards.
    /// Reviews are the only thing that changes the pet after the starting pet.
    static func resolve(force: Bool = false) -> FoodPersonaSnapshot {
        let defaults = UserDefaults.standard
        let reviews = ReviewHistory.all()
        let fingerprint = self.fingerprint(for: reviews)

        // Migrate pets saved by earlier builds into the one-time starting pet.
        if defaults.string(forKey: Key.preferred) != nil,
           defaults.string(forKey: Key.overrideFingerprint) == nil {
            defaults.set(fingerprint, forKey: Key.overrideFingerprint)
        }

        let savedFingerprint = defaults.string(forKey: Key.fingerprint)
        let savedPersona = defaults.string(forKey: Key.persona)
            .flatMap { FoodPersona(rawValue: $0) }

        // The onboarding pet is a starting point. It stays until the user
        // saves a review, then their feedback takes over automatically.
        let overridePersona = preferredPersona()
        let overrideIsCurrent =
            overridePersona != nil
            && defaults.string(forKey: Key.overrideFingerprint) == fingerprint

        if overrideIsCurrent, let preferred = overridePersona {
            defaults.set(fingerprint, forKey: Key.fingerprint)
            defaults.set(preferred.rawValue, forKey: Key.persona)

            let baseExplanation: String
            if let reason = defaults.string(forKey: Key.reason), !reason.isEmpty {
                baseExplanation = reason
            } else {
                baseExplanation = "You picked \(preferred.name) as your starting pet."
            }
            let explanation = baseExplanation
                + " Once you rate a few places, I'll change with your feedback."

            return FoodPersonaSnapshot(
                persona: preferred,
                explanation: explanation,
                reviewCount: reviews.count
            )
        }

        // New reviews have arrived, so the starting pet is no longer in charge.
        if overridePersona != nil {
            defaults.removeObject(forKey: Key.preferred)
            defaults.removeObject(forKey: Key.overrideFingerprint)
            defaults.removeObject(forKey: Key.reason)
        }

        if !force,
           savedFingerprint == fingerprint,
           let savedPersona {
            return FoodPersonaSnapshot(
                persona: savedPersona,
                explanation: explanation(for: savedPersona, reviews: reviews),
                reviewCount: reviews.count
            )
        }

        let chosen = choosePersona(reviews: reviews)

        defaults.set(fingerprint, forKey: Key.fingerprint)
        defaults.set(chosen.id, forKey: Key.persona)

        return FoodPersonaSnapshot(
            persona: chosen,
            explanation: explanation(for: chosen, reviews: reviews),
            reviewCount: reviews.count
        )
    }

    // MARK: Persona choice

    /// Picks the pet that best matches the user's reviews. This is fully
    /// deterministic — the same reviews always produce the same pet, and a
    /// new review can change it immediately. No weekly rotation is involved.
    private static func choosePersona(reviews: [RestaurantReviewData]) -> FoodPersona {
        let scores = self.scores(from: reviews)

        let ranked = FoodPersona.allCases.enumerated().map { order, persona in
            (persona: persona, score: scores[persona] ?? 0, order: order)
        }

        guard let winner = ranked.max(by: { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score < rhs.score }
            return lhs.order > rhs.order
        }), winner.score > 0 else {
            // Nothing to learn from yet — Munchkin is the neutral default.
            return .munchkin
        }

        return winner.persona
    }

    private static func scores(from reviews: [RestaurantReviewData]) -> [FoodPersona: Double] {
        var scores: [FoodPersona: Double] = [:]

        for review in reviews {
            let weight: Double
            switch review.rating {
            case 4...5: weight = Double(review.rating - 3) // 4★ = 1, 5★ = 2
            case 3: weight = 0.5
            default: weight = -0.75 // low ratings push that taste down
            }

            var liked: Set<FoodPersona> = []

            // Explicit flavour tags from the review form.
            for tag in review.flavours {
                let cleaned = tag.lowercased()
                    .replacingOccurrences(of: "[^a-z ]", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                if let persona = FoodPersona.from(flavour: cleaned) {
                    liked.insert(persona)
                } else if cleaned.contains("fresh") {
                    liked.insert(.panda)
                }
            }

            // Words in the written feedback.
            let comment = review.comment.lowercased()
            for (persona, keywords) in commentKeywords where keywords.contains(where: { comment.contains($0) }) {
                liked.insert(persona)
            }

            // The restaurant's own cuisine is a weaker, implicit signal.
            if let restaurant = RestaurantDirectory.all.first(where: { $0.name == review.restaurantName }) {
                for craving in restaurant.matchingCravings(["Spicy", "Sweet", "Tangy", "Savoury"]) {
                    if let persona = FoodPersona.from(flavour: craving) {
                        liked.insert(persona)
                    }
                }
            }

            for persona in liked {
                scores[persona, default: 0] += weight
            }

            // Loving several kinds of food (or none in particular) is very
            // "Munchkin" — the cat who likes absolutely everything.
            if weight > 0 {
                if liked.count >= 3 {
                    scores[.munchkin, default: 0] += weight * 1.5
                } else if liked.count == 0 {
                    scores[.munchkin, default: 0] += weight * 0.5
                }
            }
        }

        return scores
    }

    private static let commentKeywords: [FoodPersona: [String]] = [
        .cookie: [
            "sweet", "dessert", "ice cream", "gelato", "cake", "chocolate",
            "sugar", "sugary", "pastry", "candy", "honey", "milkshake", "bubble tea"
        ],
        .fiery: [
            "spicy", "chilli", "chili", "fiery", "mala", "sambal", "curry",
            "pepper", "spice", "hot and sour", "burn"
        ],
        .panda: [
            "tangy", "sour", "citrus", "lemon", "lime", "tamarind", "pickle",
            "zingy", "acidic", "refreshing"
        ],
        .terry: [
            "savoury", "salty", "umami", "grill", "roast", "roasted", "noodle",
            "rice", "meat", "cheese", "hearty", "rich"
        ]
    ]

    // MARK: Copy

    private static func fingerprint(for reviews: [RestaurantReviewData]) -> String {
        let latest = reviews.map(\.date.timeIntervalSince1970).max() ?? 0
        return "\(reviews.count)-\(Int(latest))"
    }

    private static func explanation(for persona: FoodPersona, reviews: [RestaurantReviewData]) -> String {
        guard !reviews.isEmpty else {
            return "No ratings yet — rate a few places and I'll change to match your taste!"
        }

        let count = reviews.count
        let prefix = "From your \(count) \(count == 1 ? "rating" : "ratings") and reviews"
        return "\(prefix), you're all about \(persona.shortTaste) — \(persona.name) suits you!"
    }
}

/// Small helper so every mascot placeholder in the app shows the pet currently
/// matched to the user's reviews (or their starting pet).
enum MunchkinPet {
    static var emoji: String {
        FoodPersonaStore.resolve().persona.emoji
    }
}
