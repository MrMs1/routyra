//
//  ColorTheme.swift
//  Routyra
//
//  Theme protocol defining all color properties for the app.
//  Implement this protocol to create new color themes.
//

import SwiftUI

// MARK: - Color Theme Protocol

/// Protocol defining all color properties required for app theming.
/// Implement this protocol to create custom themes.
protocol ColorTheme {
    // MARK: - Backgrounds
    var background: Color { get }
    var cardBackground: Color { get }
    var cardBackgroundCompleted: Color { get }
    var groupedCardBackground: Color { get }
    var groupedCardBackgroundCompleted: Color { get }
    var cardBackgroundSecondary: Color { get }

    // MARK: - Accent Colors
    var accentBlue: Color { get }
    var mutedBlue: Color { get }
    var streakOrange: Color { get }

    // MARK: - Calendar Colors
    var weekendSaturday: Color { get }
    var weekendSunday: Color { get }

    // MARK: - Text Colors
    var textPrimary: Color { get }
    var textSecondary: Color { get }
    var textMuted: Color { get }

    // MARK: - UI Elements
    var divider: Color { get }
    var dotEmpty: Color { get }
    var dotFilled: Color { get }
}

// MARK: - Theme Type Enum

/// Enum representing available theme types.
/// Used for persistence and theme selection.
enum ThemeType: String, Codable, CaseIterable {
    case dark
    case midnight
    case kuromi
    case lime
    case light
    case gruvboxLight
    case gruvboxDark
    case serenity
    case blossom
    case lavenderDusk
    case roseTea
    case matchaCream
    case apricotSand
    case powderBlue
    case ocean

    /// User-facing localized name for the theme.
    var localizedName: String {
        switch self {
        case .dark:
            return L10n.tr("theme_dark")
        case .midnight:
            return L10n.tr("theme_midnight")
        case .kuromi:
            return L10n.tr("theme_kuromi")
        case .lime:
            return L10n.tr("theme_lime")
        case .light:
            return L10n.tr("theme_light")
        case .gruvboxLight:
            return L10n.tr("theme_gruvbox_light")
        case .gruvboxDark:
            return L10n.tr("theme_gruvbox_dark")
        case .serenity:
            return L10n.tr("theme_serenity")
        case .blossom:
            return L10n.tr("theme_blossom")
        case .lavenderDusk:
            return L10n.tr("theme_lavender_dusk")
        case .roseTea:
            return L10n.tr("theme_rose_tea")
        case .matchaCream:
            return L10n.tr("theme_matcha_cream")
        case .apricotSand:
            return L10n.tr("theme_apricot_sand")
        case .powderBlue:
            return L10n.tr("theme_powder_blue")
        case .ocean:
            return L10n.tr("theme_ocean")
        }
    }

    /// Returns the ColorTheme instance for this theme type.
    var theme: ColorTheme {
        switch self {
        case .dark:
            return DarkTheme()
        case .midnight:
            return MidnightTheme()
        case .kuromi:
            return KuromiTheme()
        case .lime:
            return LimeTheme()
        case .light:
            return LightTheme()
        case .gruvboxLight:
            return GruvboxLightTheme()
        case .gruvboxDark:
            return GruvboxDarkTheme()
        case .serenity:
            return SerenityTheme()
        case .blossom:
            return BlossomTheme()
        case .lavenderDusk:
            return LavenderDuskTheme()
        case .roseTea:
            return RoseTeaTheme()
        case .matchaCream:
            return MatchaCreamTheme()
        case .apricotSand:
            return ApricotSandTheme()
        case .powderBlue:
            return PowderBlueTheme()
        case .ocean:
            return OceanTheme()
        }
    }

    /// Returns the system color scheme for this theme.
    var colorScheme: ColorScheme {
        switch self {
        case .dark, .midnight, .kuromi, .lime, .ocean, .gruvboxDark:
            return .dark
        case .light, .gruvboxLight, .serenity, .blossom, .lavenderDusk, .roseTea,
             .matchaCream, .apricotSand, .powderBlue:
            return .light
        }
    }

    /// Uses text color for selected tab tint (Gruvbox themes).
    var prefersTabTextTint: Bool {
        switch self {
        case .gruvboxLight, .gruvboxDark:
            return true
        default:
            return false
        }
    }

    /// Ordered by similar hues for display grouping.
    static let darkThemes: [ThemeType] = [
        .dark,
        .midnight,
        .kuromi,
        .lime,
        .ocean,
        .gruvboxDark,
    ]

    /// Ordered by similar hues for display grouping.
    static let lightThemes: [ThemeType] = [
        .light,
        .powderBlue,
        .serenity,
        .matchaCream,
        .gruvboxLight,
        .apricotSand,
        .roseTea,
        .blossom,
        .lavenderDusk,
    ]
}

// MARK: - Dark Theme (Default)

/// The default dark theme with current app colors.
struct DarkTheme: ColorTheme {
    // MARK: - Backgrounds
    let background = Color(hex: "0F0F10")
    let cardBackground = Color(hex: "1C1C1E")
    let cardBackgroundCompleted = Color(hex: "1A1A1C")
    let groupedCardBackground = Color(hex: "1C1C1E")
    let groupedCardBackgroundCompleted = Color(hex: "1A1A1C")
    let cardBackgroundSecondary = Color(hex: "141416")

    // MARK: - Accent Colors
    let accentBlue = Color(hex: "0A84FF")
    let mutedBlue = Color(hex: "2C5282")
    let streakOrange = Color(hex: "FF9500")

    // MARK: - Calendar Colors
    let weekendSaturday = Color(hex: "64D2FF")
    let weekendSunday = Color(hex: "FF453A")

    // MARK: - Text Colors
    let textPrimary = Color.white
    let textSecondary = Color(hex: "8E8E93")
    let textMuted = Color(hex: "636366")

    // MARK: - UI Elements
    let divider = Color(hex: "38383A")
    let dotEmpty = Color(hex: "48484A")
    let dotFilled = Color(hex: "0A84FF")
}

// MARK: - Midnight Theme

/// A deep blue night sky inspired theme.
/// Evokes the feeling of a calm midnight workout session.
struct MidnightTheme: ColorTheme {
    // MARK: - Backgrounds
    /// Discord-inspired deep graphite background
    let background = Color(hex: "1E1F22")
    /// Card surface
    let cardBackground = Color(hex: "2B2D31")
    /// Completed card surface
    let cardBackgroundCompleted = Color(hex: "2A2C30")
    /// Elevated card surface
    let groupedCardBackground = Color(hex: "2B2D31")
    /// Completed elevated card surface
    let groupedCardBackgroundCompleted = Color(hex: "2A2C30")
    /// Secondary card background for nested elements
    let cardBackgroundSecondary = Color(hex: "26282C")

    // MARK: - Accent Colors
    /// Discord blurple accent
    let accentBlue = Color(hex: "5865F2")
    /// Muted blurple for secondary accents
    let mutedBlue = Color(hex: "4752C4")
    /// Discord warning yellow for streaks
    let streakOrange = Color(hex: "FEE75C")

    // MARK: - Calendar Colors
    /// Discord success green for Saturday
    let weekendSaturday = Color(hex: "3BA55D")
    /// Discord danger red for Sunday
    let weekendSunday = Color(hex: "ED4245")

    // MARK: - Text Colors
    /// Discord primary text
    let textPrimary = Color(hex: "F2F3F5")
    /// Discord secondary text
    let textSecondary = Color(hex: "B5BAC1")
    /// Discord muted text
    let textMuted = Color(hex: "949BA4")

    // MARK: - UI Elements
    /// Subtle divider
    let divider = Color(hex: "4B4E56")
    /// Empty dot
    let dotEmpty = Color(hex: "4F545C")
    /// Filled dot matches accent
    let dotFilled = Color(hex: "5865F2")
}

// MARK: - Kuromi Theme

/// A dark theme inspired by Sanrio's Kuromi with vivid purple accents.
struct KuromiTheme: ColorTheme {
    // MARK: - Backgrounds
    /// Deep purple-black background
    let background = Color(hex: "17161A")
    /// Dark purple-gray for cards
    let cardBackground = Color(hex: "201E25")
    /// Darker for completed cards
    let cardBackgroundCompleted = Color(hex: "232128")
    /// Elevated card surface
    let groupedCardBackground = Color(hex: "201E25")
    /// Completed grouped card
    let groupedCardBackgroundCompleted = Color(hex: "232128")
    /// Secondary card background for nested elements
    let cardBackgroundSecondary = Color(hex: "1C1B1F")

    // MARK: - Accent Colors
    /// Vivid purple accent
    let accentBlue = Color(hex: "AA5EF8")
    /// Muted purple for secondary elements
    let mutedBlue = Color(hex: "7B4BB0")
    /// Bright pink-purple for streaks
    let streakOrange = Color(hex: "DA7CFA")

    // MARK: - Calendar Colors
    /// Purple for Saturday
    let weekendSaturday = Color(hex: "AA5EF8")
    /// Pink-purple for Sunday
    let weekendSunday = Color(hex: "DA7CFA")

    // MARK: - Text Colors
    /// Soft off-white with purple tint
    let textPrimary = Color(hex: "F3EEFD")
    /// Muted lavender secondary text
    let textSecondary = Color(hex: "C0B7D2")
    /// Muted purple-gray text
    let textMuted = Color(hex: "8A8299")

    // MARK: - UI Elements
    /// Subtle purple-tinted divider
    let divider = Color(hex: "3A3840")
    /// Empty dot
    let dotEmpty = Color(hex: "3A3840")
    /// Filled dot matches accent
    let dotFilled = Color(hex: "AA5EF8")
}

// MARK: - Lime Theme

/// A Spotify-inspired dark theme with a vivid lime accent.
struct LimeTheme: ColorTheme {
    // MARK: - Backgrounds
    /// Deep charcoal background
    let background = Color(hex: "131313")
    /// Dark surface for cards
    let cardBackground = Color(hex: "1D1D1D")
    /// Completed cards should feel "muted" but still distinct from background
    let cardBackgroundCompleted = Color(hex: "171717")
    /// Elevated card surface
    let groupedCardBackground = Color(hex: "1D1D1D")
    /// Completed grouped card should also remain visible against background
    let groupedCardBackgroundCompleted = Color(hex: "171717")
    /// Secondary card background for nested elements
    let cardBackgroundSecondary = Color(hex: "171717")

    // MARK: - Accent Colors
    /// Spotify-style lime accent
    let accentBlue = Color(hex: "00CF60")
    /// Muted accent matches lime for minimal palette
    let mutedBlue = Color(hex: "00CF60")
    /// Streak uses the same lime accent
    let streakOrange = Color(hex: "00CF60")

    // MARK: - Calendar Colors
    /// Lime for Saturday
    let weekendSaturday = Color(hex: "00CF60")
    /// Red for Sunday
    let weekendSunday = Color(hex: "FF453A")

    // MARK: - Text Colors
    /// Primary text is pure white
    let textPrimary = Color(hex: "FFFFFF")
    /// Secondary text is Spotify gray
    let textSecondary = Color(hex: "AAAAAA")
    /// Muted text matches secondary
    let textMuted = Color(hex: "AAAAAA")

    // MARK: - UI Elements
    /// Subtle divider
    let divider = Color(hex: "2A2A2A")
    /// Empty dot matches surface
    let dotEmpty = Color(hex: "3A3A3A")
    /// Filled dot uses lime
    let dotFilled = Color(hex: "00CF60")
}

// MARK: - Light Theme

/// A clean, bright light theme for daytime use.
/// High contrast for easy readability in well-lit environments.
struct LightTheme: ColorTheme {
    // MARK: - Backgrounds
    /// Light warm gray background
    let background = Color(hex: "EBEBED")
    /// Pure white cards for clear contrast
    let cardBackground = Color(hex: "FFFFFF")
    /// Slightly gray for completed cards
    let cardBackgroundCompleted = Color(hex: "E8E8EA")
    /// Elevated card with subtle gray
    let groupedCardBackground = Color(hex: "FFFFFF")
    /// Completed grouped card
    let groupedCardBackgroundCompleted = Color(hex: "E8E8EA")
    /// Secondary card background for nested elements
    let cardBackgroundSecondary = Color(hex: "F5F5F7")

    // MARK: - Accent Colors
    /// iOS system blue for light mode
    let accentBlue = Color(hex: "007AFF")
    /// Muted blue for secondary elements
    let mutedBlue = Color(hex: "5AC8FA")
    /// Vibrant orange for streaks
    let streakOrange = Color(hex: "FF9500")

    // MARK: - Calendar Colors
    /// Teal for Saturday
    let weekendSaturday = Color(hex: "32ADE6")
    /// Red for Sunday
    let weekendSunday = Color(hex: "FF3B30")

    // MARK: - Text Colors
    /// Near black for primary text
    let textPrimary = Color(hex: "1C1C1E")
    /// Medium gray for secondary text
    let textSecondary = Color(hex: "6C6C70")
    /// Light gray for muted text
    let textMuted = Color(hex: "AEAEB2")

    // MARK: - UI Elements
    /// Light gray divider
    let divider = Color(hex: "D1D1D6")
    /// Light gray empty dot
    let dotEmpty = Color(hex: "D1D1D6")
    /// Blue filled dot
    let dotFilled = Color(hex: "007AFF")
}

// MARK: - Gruvbox Light Theme

/// A warm, low-noise light theme based on the Gruvbox Light (Medium) palette.
struct GruvboxLightTheme: ColorTheme {
    // MARK: - Backgrounds
    /// Gruvbox light0 background
    let background = Color(hex: "FBF1C7")
    /// Gruvbox light1 for cards
    let cardBackground = Color(hex: "EBDBB2")
    /// Slightly deeper light2 for completed cards
    let cardBackgroundCompleted = Color(hex: "BDAE93")
    /// Light2 for grouped cards
    let groupedCardBackground = Color(hex: "EBDBB2")
    /// Light3 for completed grouped cards
    let groupedCardBackgroundCompleted = Color(hex: "BDAE93")
    /// Secondary card background for nested elements
    let cardBackgroundSecondary = Color(hex: "D5C4A1")

    // MARK: - Accent Colors
    /// Gruvbox blue
    let accentBlue = Color(hex: "458588")
    /// Softer blue for secondary elements
    let mutedBlue = Color(hex: "83A598")
    /// Gruvbox orange for streaks
    let streakOrange = Color(hex: "D65D0E")

    // MARK: - Calendar Colors
    /// Gruvbox aqua for Saturday
    let weekendSaturday = Color(hex: "689D6A")
    /// Gruvbox red for Sunday
    let weekendSunday = Color(hex: "CC241D")

    // MARK: - Text Colors
    /// Gruvbox dark1 for primary text
    let textPrimary = Color(hex: "3C3836")
    /// Gruvbox dark2 for secondary text
    let textSecondary = Color(hex: "504945")
    /// Gruvbox dark3 for muted text
    let textMuted = Color(hex: "665C54")

    // MARK: - UI Elements
    /// Gruvbox light3 divider
    let divider = Color(hex: "BDAE93")
    /// Gruvbox light4 empty dot
    let dotEmpty = Color(hex: "A89984")
    /// Filled dot matches accent
    let dotFilled = Color(hex: "458588")
}

// MARK: - Gruvbox Dark Theme

/// A warm, high-contrast dark theme based on the Gruvbox Dark (Medium) palette.
struct GruvboxDarkTheme: ColorTheme {
    // MARK: - Backgrounds
    /// Warm deep charcoal background
    let background = Color(hex: "262322")
    /// Warmer mid charcoal for cards
    let cardBackground = Color(hex: "32302F")
    /// Slightly darker for completed cards
    let cardBackgroundCompleted = Color(hex: "32302F")
    /// Lifted card background for grouped cards
    let groupedCardBackground = Color(hex: "32302F")
    /// Completed grouped cards
    let groupedCardBackgroundCompleted = Color(hex: "32302F")
    /// Secondary card background for nested elements
    let cardBackgroundSecondary = Color(hex: "2B2826")

    // MARK: - Accent Colors
    /// Gruvbox blue
    let accentBlue = Color(hex: "458588")
    /// Softer blue for secondary elements
    let mutedBlue = Color(hex: "83A598")
    /// Gruvbox orange for streaks
    let streakOrange = Color(hex: "D65D0E")

    // MARK: - Calendar Colors
    /// Gruvbox aqua for Saturday
    let weekendSaturday = Color(hex: "689D6A")
    /// Gruvbox red for Sunday
    let weekendSunday = Color(hex: "CC241D")

    // MARK: - Text Colors
    /// Gruvbox light0 for primary text
    let textPrimary = Color(hex: "FBF1C7")
    /// Gruvbox light2 for secondary text
    let textSecondary = Color(hex: "D5C4A1")
    /// Gruvbox light3 for muted text
    let textMuted = Color(hex: "BDAE93")

    // MARK: - UI Elements
    /// Soft divider with better separation
    let divider = Color(hex: "44403D")
    /// Empty dot with warmer contrast
    let dotEmpty = Color(hex: "5C5349")
    /// Filled dot matches accent
    let dotFilled = Color(hex: "458588")
}

// MARK: - Serenity Theme

/// A soft aqua/light blue theme with a calm, feminine aesthetic.
/// Features gentle pastels and soothing colors for a serene experience.
struct SerenityTheme: ColorTheme {
    // MARK: - Backgrounds
    /// Very soft aqua-tinted background
    let background = Color(hex: "D9EBF1")
    /// White cards for clear contrast
    let cardBackground = Color(hex: "FFFFFF")
    /// Soft aqua for completed cards
    let cardBackgroundCompleted = Color(hex: "DCE9EE")
    /// Light aqua for grouped cards
    let groupedCardBackground = Color(hex: "FFFFFF")
    /// Completed grouped card
    let groupedCardBackgroundCompleted = Color(hex: "DCE9EE")
    /// Secondary card background for nested elements
    let cardBackgroundSecondary = Color(hex: "F0F8FA")

    // MARK: - Accent Colors
    /// Soft teal accent
    let accentBlue = Color(hex: "4FBFD1")
    /// Muted aqua for secondary elements
    let mutedBlue = Color(hex: "97D2DF")
    /// Soft coral for streaks
    let streakOrange = Color(hex: "F5A88E")

    // MARK: - Calendar Colors
    /// Soft sky blue for Saturday
    let weekendSaturday = Color(hex: "5CB3C6")
    /// Soft rose for Sunday
    let weekendSunday = Color(hex: "D98989")

    // MARK: - Text Colors
    /// Dark slate for primary text
    let textPrimary = Color(hex: "2C3E50")
    /// Muted teal-gray for secondary text
    let textSecondary = Color(hex: "516A75")
    /// Light blue-gray for muted text
    let textMuted = Color(hex: "7F96A3")

    // MARK: - UI Elements
    /// Soft aqua divider
    let divider = Color(hex: "A8C7D1")
    /// Light aqua empty dot
    let dotEmpty = Color(hex: "B3D1DC")
    /// Teal filled dot
    let dotFilled = Color(hex: "5AC8D8")
}

// MARK: - Blossom Theme

/// A soft pink light theme inspired by Serenity, with warmer blush tones.
struct BlossomTheme: ColorTheme {
    // MARK: - Backgrounds
    /// Light blush background
    let background = Color(hex: "F0E4E9")
    /// White cards for clear contrast
    let cardBackground = Color(hex: "FFFFFF")
    /// Soft blush for completed cards
    let cardBackgroundCompleted = Color(hex: "EBDBE2")
    /// Light pink for grouped cards
    let groupedCardBackground = Color(hex: "FFFFFF")
    /// Completed grouped card
    let groupedCardBackgroundCompleted = Color(hex: "EBDBE2")
    /// Secondary card background for nested elements
    let cardBackgroundSecondary = Color(hex: "F8F0F3")

    // MARK: - Accent Colors
    /// Soft rose accent
    let accentBlue = Color(hex: "E26A8D")
    /// Muted rose for secondary elements
    let mutedBlue = Color(hex: "F2B3C4")
    /// Warm coral for streaks
    let streakOrange = Color(hex: "F59E8B")

    // MARK: - Calendar Colors
    /// Soft lavender for Saturday
    let weekendSaturday = Color(hex: "BFA3D6")
    /// Soft rose for Sunday
    let weekendSunday = Color(hex: "E07A8C")

    // MARK: - Text Colors
    /// Deep rose-gray for primary text
    let textPrimary = Color(hex: "3C2A33")
    /// Muted rose-gray for secondary text
    let textSecondary = Color(hex: "6B4C5A")
    /// Light rose-gray for muted text
    let textMuted = Color(hex: "8C6A78")

    // MARK: - UI Elements
    /// Soft pink divider
    let divider = Color(hex: "D6B8C3")
    /// Light pink empty dot
    let dotEmpty = Color(hex: "E2C3CE")
    /// Rose filled dot
    let dotFilled = Color(hex: "E26A8D")
}

// MARK: - Lavender Dusk Theme

/// A soft lavender light theme with calm gray undertones.
struct LavenderDuskTheme: ColorTheme {
    // MARK: - Backgrounds
    /// Soft lavender background
    let background = Color(hex: "E5DFED")
    /// White cards for clear contrast
    let cardBackground = Color(hex: "FFFFFF")
    /// Light lavender for completed cards
    let cardBackgroundCompleted = Color(hex: "E0D9E9")
    /// Light lavender for grouped cards
    let groupedCardBackground = Color(hex: "FFFFFF")
    /// Completed grouped card
    let groupedCardBackgroundCompleted = Color(hex: "E0D9E9")
    /// Secondary card background for nested elements
    let cardBackgroundSecondary = Color(hex: "F5F2F9")

    // MARK: - Accent Colors
    /// Soft lavender accent
    let accentBlue = Color(hex: "8D7AD9")
    /// Muted lavender for secondary elements
    let mutedBlue = Color(hex: "B9A9E5")
    /// Soft rose for streaks
    let streakOrange = Color(hex: "F2A7B5")

    // MARK: - Calendar Colors
    /// Cool lavender for Saturday
    let weekendSaturday = Color(hex: "9CB3E6")
    /// Soft rose for Sunday
    let weekendSunday = Color(hex: "E49AB3")

    // MARK: - Text Colors
    /// Deep violet-gray for primary text
    let textPrimary = Color(hex: "2F2A3A")
    /// Muted violet-gray for secondary text
    let textSecondary = Color(hex: "5A516B")
    /// Soft gray-purple for muted text
    let textMuted = Color(hex: "7C728E")

    // MARK: - UI Elements
    /// Lavender divider
    let divider = Color(hex: "C9BDD8")
    /// Light lavender empty dot
    let dotEmpty = Color(hex: "D6CAE4")
    /// Filled dot matches accent
    let dotFilled = Color(hex: "8D7AD9")
}

// MARK: - Rose Tea Theme

/// A warm rose and beige light theme with a gentle, cozy tone.
struct RoseTeaTheme: ColorTheme {
    // MARK: - Backgrounds
    /// Soft beige-pink background
    let background = Color(hex: "EDE4DE")
    /// White cards for clear contrast
    let cardBackground = Color(hex: "FFFFFF")
    /// Warm blush for completed cards
    let cardBackgroundCompleted = Color(hex: "E6DAD3")
    /// Light rose-beige for grouped cards
    let groupedCardBackground = Color(hex: "FFFFFF")
    /// Completed grouped card
    let groupedCardBackgroundCompleted = Color(hex: "E6DAD3")
    /// Secondary card background for nested elements
    let cardBackgroundSecondary = Color(hex: "F8F3F0")

    // MARK: - Accent Colors
    /// Rose accent
    let accentBlue = Color(hex: "C47A8A")
    /// Muted rose for secondary elements
    let mutedBlue = Color(hex: "E2B7C2")
    /// Warm tea amber for streaks
    let streakOrange = Color(hex: "F2A26E")

    // MARK: - Calendar Colors
    /// Soft mauve for Saturday
    let weekendSaturday = Color(hex: "B58EC9")
    /// Soft rose for Sunday
    let weekendSunday = Color(hex: "D97585")

    // MARK: - Text Colors
    /// Deep rose-brown for primary text
    let textPrimary = Color(hex: "3C2A2E")
    /// Muted rose-brown for secondary text
    let textSecondary = Color(hex: "6B4D54")
    /// Soft rose-gray for muted text
    let textMuted = Color(hex: "8C7077")

    // MARK: - UI Elements
    /// Soft rose divider
    let divider = Color(hex: "D9C1C6")
    /// Light rose empty dot
    let dotEmpty = Color(hex: "E4CFD4")
    /// Filled dot matches accent
    let dotFilled = Color(hex: "C47A8A")
}

// MARK: - Matcha Cream Theme

/// A calm sage and cream light theme inspired by matcha tones.
struct MatchaCreamTheme: ColorTheme {
    // MARK: - Backgrounds
    /// Soft sage background
    let background = Color(hex: "E6EBE3")
    /// White cards for clear contrast
    let cardBackground = Color(hex: "FFFFFF")
    /// Sage-tinted completed cards
    let cardBackgroundCompleted = Color(hex: "E0E7DC")
    /// Light sage for grouped cards
    let groupedCardBackground = Color(hex: "FFFFFF")
    /// Completed grouped card
    let groupedCardBackgroundCompleted = Color(hex: "E0E7DC")
    /// Secondary card background for nested elements
    let cardBackgroundSecondary = Color(hex: "F4F7F2")

    // MARK: - Accent Colors
    /// Sage accent
    let accentBlue = Color(hex: "6BA58C")
    /// Muted sage for secondary elements
    let mutedBlue = Color(hex: "A8C9B8")
    /// Warm apricot for streaks
    let streakOrange = Color(hex: "F0B36A")

    // MARK: - Calendar Colors
    /// Sage for Saturday
    let weekendSaturday = Color(hex: "7FB89B")
    /// Soft rose for Sunday
    let weekendSunday = Color(hex: "C97D7D")

    // MARK: - Text Colors
    /// Deep green-gray for primary text
    let textPrimary = Color(hex: "2E3A33")
    /// Muted green-gray for secondary text
    let textSecondary = Color(hex: "54665C")
    /// Soft green-gray for muted text
    let textMuted = Color(hex: "75877C")

    // MARK: - UI Elements
    /// Soft sage divider
    let divider = Color(hex: "C7D4C8")
    /// Light sage empty dot
    let dotEmpty = Color(hex: "D6E2D7")
    /// Filled dot matches accent
    let dotFilled = Color(hex: "6BA58C")
}

// MARK: - Apricot Sand Theme

/// A warm apricot and sand light theme with a cozy, sunny feel.
struct ApricotSandTheme: ColorTheme {
    // MARK: - Backgrounds
    /// Soft sand background
    let background = Color(hex: "EDE5DC")
    /// White cards for clear contrast
    let cardBackground = Color(hex: "FFFFFF")
    /// Apricot-tinted completed cards
    let cardBackgroundCompleted = Color(hex: "E6DCD0")
    /// Light sand for grouped cards
    let groupedCardBackground = Color(hex: "FFFFFF")
    /// Completed grouped card
    let groupedCardBackgroundCompleted = Color(hex: "E6DCD0")
    /// Secondary card background for nested elements
    let cardBackgroundSecondary = Color(hex: "F8F4EF")

    // MARK: - Accent Colors
    /// Apricot accent
    let accentBlue = Color(hex: "E59A6F")
    /// Muted apricot for secondary elements
    let mutedBlue = Color(hex: "F0C3A8")
    /// Warm amber for streaks
    let streakOrange = Color(hex: "E9A23B")

    // MARK: - Calendar Colors
    /// Soft apricot for Saturday
    let weekendSaturday = Color(hex: "DAA57B")
    /// Soft coral for Sunday
    let weekendSunday = Color(hex: "D9817E")

    // MARK: - Text Colors
    /// Deep brown for primary text
    let textPrimary = Color(hex: "3D2F25")
    /// Warm brown for secondary text
    let textSecondary = Color(hex: "6D5646")
    /// Soft brown for muted text
    let textMuted = Color(hex: "8B7160")

    // MARK: - UI Elements
    /// Sand divider
    let divider = Color(hex: "DCC6B5")
    /// Light sand empty dot
    let dotEmpty = Color(hex: "E7D4C6")
    /// Filled dot matches accent
    let dotFilled = Color(hex: "E59A6F")
}

// MARK: - Powder Blue Theme

/// A cool powder blue light theme with crisp, airy tones.
struct PowderBlueTheme: ColorTheme {
    // MARK: - Backgrounds
    /// Soft powder blue background
    let background = Color(hex: "E3EAF2")
    /// White cards for clear contrast
    let cardBackground = Color(hex: "FFFFFF")
    /// Blue-tinted completed cards
    let cardBackgroundCompleted = Color(hex: "DEE6EE")
    /// Light blue for grouped cards
    let groupedCardBackground = Color(hex: "FFFFFF")
    /// Completed grouped card
    let groupedCardBackgroundCompleted = Color(hex: "DEE6EE")
    /// Secondary card background for nested elements
    let cardBackgroundSecondary = Color(hex: "F3F7FA")

    // MARK: - Accent Colors
    /// Powder blue accent
    let accentBlue = Color(hex: "6CA0D5")
    /// Muted blue for secondary elements
    let mutedBlue = Color(hex: "A5C3E3")
    /// Soft coral for streaks
    let streakOrange = Color(hex: "F1A4A0")

    // MARK: - Calendar Colors
    /// Sky blue for Saturday
    let weekendSaturday = Color(hex: "7CB7D8")
    /// Soft rose for Sunday
    let weekendSunday = Color(hex: "E58FA5")

    // MARK: - Text Colors
    /// Deep slate for primary text
    let textPrimary = Color(hex: "2C3A47")
    /// Muted slate for secondary text
    let textSecondary = Color(hex: "556778")
    /// Soft slate for muted text
    let textMuted = Color(hex: "75889A")

    // MARK: - UI Elements
    /// Blue-gray divider
    let divider = Color(hex: "C3D3E3")
    /// Light blue empty dot
    let dotEmpty = Color(hex: "D6E2EE")
    /// Filled dot matches accent
    let dotFilled = Color(hex: "6CA0D5")
}

// MARK: - Ocean Theme

/// A deep aqua/teal dark theme inspired by ocean depths.
/// The dark counterpart to Serenity with rich, calming colors.
struct OceanTheme: ColorTheme {
    // MARK: - Backgrounds
    /// Deep ocean blue background
    let background = Color(hex: "0A1A20")
    /// Dark teal for cards
    let cardBackground = Color(hex: "122830")
    /// Deeper teal for completed cards
    let cardBackgroundCompleted = Color(hex: "142830")
    /// Elevated card with cyan tint
    let groupedCardBackground = Color(hex: "122830")
    /// Completed grouped card
    let groupedCardBackgroundCompleted = Color(hex: "142830")
    /// Secondary card background for nested elements
    let cardBackgroundSecondary = Color(hex: "0E2028")

    // MARK: - Accent Colors
    /// Bright aqua accent
    let accentBlue = Color(hex: "4DD0E1")
    /// Muted teal for secondary elements
    let mutedBlue = Color(hex: "26808F")
    /// Warm coral for streaks
    let streakOrange = Color(hex: "FF8A80")

    // MARK: - Calendar Colors
    /// Bright aqua for Saturday
    let weekendSaturday = Color(hex: "80DEEA")
    /// Soft coral for Sunday
    let weekendSunday = Color(hex: "F48FB1")

    // MARK: - Text Colors
    /// Soft white with slight cyan tint
    let textPrimary = Color(hex: "E0F7FA")
    /// Muted aqua for secondary text
    let textSecondary = Color(hex: "80CBC4")
    /// Deeper teal for muted text
    let textMuted = Color(hex: "4DB6AC")

    // MARK: - UI Elements
    /// Dark teal divider
    let divider = Color(hex: "1E3A40")
    /// Muted teal empty dot
    let dotEmpty = Color(hex: "2A4A52")
    /// Bright aqua filled dot
    let dotFilled = Color(hex: "4DD0E1")
}
