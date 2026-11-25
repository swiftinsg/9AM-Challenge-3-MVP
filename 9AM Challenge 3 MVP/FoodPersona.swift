//
//  FoodPersona.swift
//  9AM Challenge 3 MVP
//
//  Food personas picked during onboarding. The chosen Munchkin is the single
//  source of truth for the pet shown across the app and for weekly picks.
//

import Foundation
import SwiftUI

extension Notification.Name {
    /// Posted when onboarding picks a new Munchkin so screens showing the pet
    /// can refresh before the onboarding sheet is dismissed.
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
}

// MARK: - Stored persona

struct FoodPersonaSnapshot {
    let persona: FoodPersona
    let explanation: String
}

/// The pet picked during onboarding is the only thing that decides the
/// Munchkin shown in the app and the tastes used for weekly recommendations.
enum FoodPersonaStore {
    private enum Key {
        static let persona = "persona_id"
        static let preferred = "preferredPersona"
        static let reason = "persona_recommendation_reason"
    }

    static func preferredPersona() -> FoodPersona? {
        UserDefaults.standard.string(forKey: Key.preferred)
            .flatMap { FoodPersona(rawValue: $0) }
    }

    static func setPreferredPersona(_ persona: FoodPersona?, reason: String? = nil) {
        let defaults = UserDefaults.standard
        if let persona {
            defaults.set(persona.rawValue, forKey: Key.preferred)
        } else {
            defaults.removeObject(forKey: Key.preferred)
        }

        if let reason {
            defaults.set(reason, forKey: Key.reason)
        } else {
            defaults.removeObject(forKey: Key.reason)
        }

        NotificationCenter.default.post(name: .personaDidChange, object: nil)
    }

    static func resolve() -> FoodPersonaSnapshot {
        let defaults = UserDefaults.standard

        if let preferred = preferredPersona() {
            let explanation = defaults.string(forKey: Key.reason)
                .flatMap { $0.isEmpty ? nil : $0 }
                ?? "This is the Munchkin that matches your taste."
            return FoodPersonaSnapshot(persona: preferred, explanation: explanation)
        }

        // Older builds stored the resolved pet here instead of a preference.
        if let saved = defaults.string(forKey: Key.persona)
            .flatMap({ FoodPersona(rawValue: $0) }) {
            return FoodPersonaSnapshot(
                persona: saved,
                explanation: "This is the Munchkin that matches your taste."
            )
        }

        return FoodPersonaSnapshot(
            persona: .munchkin,
            explanation: "Pick a Munchkin in the tutorial to get picks made for you."
        )
    }
}
