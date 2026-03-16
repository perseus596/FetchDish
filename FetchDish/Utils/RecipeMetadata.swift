import Foundation

enum RecipeCuisine: String, CaseIterable, Identifiable {
    case italian = "Italian"
    case french = "French"
    case mexican = "Mexican"
    case japanese = "Japanese"
    case chinese = "Chinese"
    case indian = "Indian"
    case thai = "Thai"
    case mediterranean = "Mediterranean"
    case american = "American"
    case korean = "Korean"
    case middleEastern = "Middle Eastern"
    case spanish = "Spanish"
    case greek = "Greek"
    case vietnamese = "Vietnamese"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .italian: return "🇮🇹"
        case .french: return "🇫🇷"
        case .mexican: return "🇲🇽"
        case .japanese: return "🇯🇵"
        case .chinese: return "🇨🇳"
        case .indian: return "🇮🇳"
        case .thai: return "🇹🇭"
        case .mediterranean: return "🫒"
        case .american: return "🇺🇸"
        case .korean: return "🇰🇷"
        case .middleEastern: return "🧆"
        case .spanish: return "🇪🇸"
        case .greek: return "🇬🇷"
        case .vietnamese: return "🇻🇳"
        case .other: return "🍽️"
        }
    }
}

enum RecipeMood: String, CaseIterable, Identifiable {
    case spicy = "Spicy"
    case salty = "Salty"
    case sweet = "Sweet"
    case comfort = "Comfort"
    case light = "Light"
    case hearty = "Hearty"
    case quick = "Quick"
    case fancy = "Fancy"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .spicy: return "🌶️"
        case .salty: return "🧂"
        case .sweet: return "🍰"
        case .comfort: return "🫕"
        case .light: return "🥗"
        case .hearty: return "🍖"
        case .quick: return "⚡"
        case .fancy: return "✨"
        }
    }
}
