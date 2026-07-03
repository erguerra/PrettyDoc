import Foundation
import Combine

enum ThemeMode: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark
    case sepia

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        case .sepia: return "Sepia"
        }
    }

    var symbolName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        case .sepia: return "eye"
        }
    }
}

enum ReadingWidth: String, CaseIterable, Identifiable, Codable {
    case comfortable
    case fluid

    var id: String { rawValue }

    var label: String {
        switch self {
        case .comfortable: return "Comfortable"
        case .fluid: return "Fluid"
        }
    }
}

enum ReaderFont: String, CaseIterable, Identifiable, Codable {
    case system
    case serif
    case rounded
    case mono

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Sans"
        case .serif: return "Serif"
        case .rounded: return "Rounded"
        case .mono: return "Mono"
        }
    }
}

/// User-facing reading preferences. Persisted to `UserDefaults` and serialized
/// to JSON so the web canvas can apply them instantly.
@MainActor
final class ReaderSettings: ObservableObject {
    private enum Key {
        static let theme = "pd.themeMode"
        static let readingWidth = "pd.readingWidth"
        static let fontScale = "pd.fontScale"
        static let lineHeight = "pd.lineHeight"
        static let letterSpacing = "pd.letterSpacing"
        static let fontFamily = "pd.fontFamily"
        static let maxWidthCh = "pd.maxWidthCh"
        static let fluidScaling = "pd.fluidScaling"
    }

    private let defaults: UserDefaults

    @Published var themeMode: ThemeMode { didSet { defaults.set(themeMode.rawValue, forKey: Key.theme) } }
    @Published var readingWidth: ReadingWidth { didSet { defaults.set(readingWidth.rawValue, forKey: Key.readingWidth) } }
    /// Manual multiplier applied on top of the fluid base size. 0.7 ... 2.0
    @Published var fontScale: Double { didSet { defaults.set(fontScale, forKey: Key.fontScale) } }
    @Published var lineHeight: Double { didSet { defaults.set(lineHeight, forKey: Key.lineHeight) } }
    /// In em units. -0.02 ... 0.12
    @Published var letterSpacing: Double { didSet { defaults.set(letterSpacing, forKey: Key.letterSpacing) } }
    @Published var fontFamily: ReaderFont { didSet { defaults.set(fontFamily.rawValue, forKey: Key.fontFamily) } }
    /// Column width (in ch) used by the Comfortable reading mode.
    @Published var maxWidthCh: Double { didSet { defaults.set(maxWidthCh, forKey: Key.maxWidthCh) } }
    /// When true, the base font grows/shrinks with window width (the differentiator).
    @Published var fluidScaling: Bool { didSet { defaults.set(fluidScaling, forKey: Key.fluidScaling) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.themeMode = ThemeMode(rawValue: defaults.string(forKey: Key.theme) ?? "") ?? .system
        self.readingWidth = ReadingWidth(rawValue: defaults.string(forKey: Key.readingWidth) ?? "") ?? .comfortable
        self.fontScale = defaults.object(forKey: Key.fontScale) as? Double ?? 1.0
        self.lineHeight = defaults.object(forKey: Key.lineHeight) as? Double ?? 1.6
        self.letterSpacing = defaults.object(forKey: Key.letterSpacing) as? Double ?? 0.0
        self.fontFamily = ReaderFont(rawValue: defaults.string(forKey: Key.fontFamily) ?? "") ?? .system
        self.maxWidthCh = defaults.object(forKey: Key.maxWidthCh) as? Double ?? 74
        self.fluidScaling = defaults.object(forKey: Key.fluidScaling) as? Bool ?? true
    }

    // MARK: - Convenience mutations used by menu commands

    func bumpFontScale(_ delta: Double) {
        fontScale = min(2.0, max(0.7, (fontScale + delta).rounded(to: 2)))
    }

    func resetTypography() {
        fontScale = 1.0
        lineHeight = 1.6
        letterSpacing = 0.0
    }

    // MARK: - Serialization for the web canvas

    var payload: [String: Any] {
        [
            "theme": themeMode.rawValue,
            "readingWidth": readingWidth.rawValue,
            "fontScale": fontScale,
            "lineHeight": lineHeight,
            "letterSpacing": letterSpacing,
            "fontFamily": fontFamily.rawValue,
            "maxWidthCh": maxWidthCh,
            "fluidScaling": fluidScaling
        ]
    }

    var payloadJSON: String {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}

private extension Double {
    func rounded(to places: Int) -> Double {
        let p = pow(10.0, Double(places))
        return (self * p).rounded() / p
    }
}
