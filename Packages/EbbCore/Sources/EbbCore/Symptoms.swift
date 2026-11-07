import Foundation

/// Severity scale used everywhere in Ebb: 0 = none, 1 = mild, 2 = moderate, 3 = severe.
public enum Severity: Int, CaseIterable, Codable, Sendable, Comparable {
    case none = 0
    case mild = 1
    case moderate = 2
    case severe = 3

    public var title: String {
        switch self {
        case .none: return "None"
        case .mild: return "Mild"
        case .moderate: return "Moderate"
        case .severe: return "Severe"
        }
    }

    public static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Clamps any integer into the valid 0...3 range.
    public static func clamped(_ value: Int) -> Int { min(max(value, 0), 3) }
}

public enum SymptomCategory: String, CaseIterable, Codable, Sendable {
    case vasomotor
    case sleep
    case mood
    case cognitive
    case physical
    case intimate

    public var title: String {
        switch self {
        case .vasomotor: return "Hot flashes & sweats"
        case .sleep: return "Sleep & energy"
        case .mood: return "Mood"
        case .cognitive: return "Mind"
        case .physical: return "Body"
        case .intimate: return "Intimate health"
        }
    }
}

public struct SymptomDefinition: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let name: String
    public let category: SymptomCategory
    /// SF Symbol name used by the app.
    public let systemImage: String
    /// Whether the symptom is pre-selected during onboarding.
    public let isDefault: Bool

    public init(id: String, name: String, category: SymptomCategory, systemImage: String, isDefault: Bool) {
        self.id = id
        self.name = name
        self.category = category
        self.systemImage = systemImage
        self.isDefault = isDefault
    }
}

public enum SymptomCatalog {
    public static let hotFlashes = "hot_flashes"
    public static let nightSweats = "night_sweats"
    public static let sleepTrouble = "sleep_trouble"
    public static let fatigue = "fatigue"
    public static let moodSwings = "mood_swings"
    public static let anxiety = "anxiety"
    public static let lowMood = "low_mood"
    public static let irritability = "irritability"
    public static let brainFog = "brain_fog"
    public static let jointPain = "joint_pain"
    public static let headaches = "headaches"
    public static let palpitations = "palpitations"
    public static let bloating = "bloating"
    public static let drySkin = "dry_skin"
    public static let dizziness = "dizziness"
    public static let bladderUrgency = "bladder_urgency"
    public static let vaginalDryness = "vaginal_dryness"
    public static let lowLibido = "low_libido"

    public static let all: [SymptomDefinition] = [
        SymptomDefinition(id: hotFlashes, name: "Hot flashes", category: .vasomotor, systemImage: "flame", isDefault: true),
        SymptomDefinition(id: nightSweats, name: "Night sweats", category: .vasomotor, systemImage: "humidity", isDefault: true),
        SymptomDefinition(id: sleepTrouble, name: "Trouble sleeping", category: .sleep, systemImage: "moon.zzz", isDefault: true),
        SymptomDefinition(id: fatigue, name: "Fatigue", category: .sleep, systemImage: "battery.25", isDefault: true),
        SymptomDefinition(id: moodSwings, name: "Mood swings", category: .mood, systemImage: "theatermasks", isDefault: true),
        SymptomDefinition(id: anxiety, name: "Anxiety", category: .mood, systemImage: "bolt.heart", isDefault: true),
        SymptomDefinition(id: lowMood, name: "Low mood", category: .mood, systemImage: "cloud.rain", isDefault: false),
        SymptomDefinition(id: irritability, name: "Irritability", category: .mood, systemImage: "cloud.bolt", isDefault: false),
        SymptomDefinition(id: brainFog, name: "Brain fog", category: .cognitive, systemImage: "cloud.fog", isDefault: true),
        SymptomDefinition(id: jointPain, name: "Joint pain", category: .physical, systemImage: "figure.walk", isDefault: true),
        SymptomDefinition(id: headaches, name: "Headaches", category: .physical, systemImage: "brain.head.profile", isDefault: true),
        SymptomDefinition(id: palpitations, name: "Heart palpitations", category: .physical, systemImage: "heart", isDefault: false),
        SymptomDefinition(id: bloating, name: "Bloating", category: .physical, systemImage: "circle.dotted", isDefault: false),
        SymptomDefinition(id: drySkin, name: "Dry or itchy skin", category: .physical, systemImage: "hand.raised", isDefault: false),
        SymptomDefinition(id: dizziness, name: "Dizziness", category: .physical, systemImage: "tornado", isDefault: false),
        SymptomDefinition(id: bladderUrgency, name: "Bladder urgency", category: .intimate, systemImage: "drop.triangle", isDefault: false),
        SymptomDefinition(id: vaginalDryness, name: "Vaginal dryness", category: .intimate, systemImage: "drop", isDefault: false),
        SymptomDefinition(id: lowLibido, name: "Low libido", category: .intimate, systemImage: "heart.slash", isDefault: false)
    ]

    private static let byID: [String: SymptomDefinition] = {
        var map: [String: SymptomDefinition] = [:]
        for definition in all { map[definition.id] = definition }
        return map
    }()

    public static func definition(for id: String) -> SymptomDefinition? { byID[id] }

    /// Display name for an ID, falling back to a readable version of the ID.
    public static func name(for id: String) -> String {
        if let definition = byID[id] { return definition.name }
        return id.replacingOccurrences(of: "_", with: " ").capitalized
    }

    public static var defaultTrackedIDs: [String] { all.filter(\.isDefault).map(\.id) }

    /// Keeps catalog order and removes unknown or duplicate IDs.
    public static func normalized(_ ids: [String]) -> [String] {
        let wanted = Set(ids)
        return all.map(\.id).filter { wanted.contains($0) }
    }

    /// Lower-case name for use inside a sentence ("hot flashes", "brain fog").
    public static func phrase(for id: String) -> String {
        name(for: id).lowercased()
    }
}
