import Foundation

public struct TriggerDefinition: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let name: String
    /// Phrase used in insights: "on days you logged **alcohol**".
    public let phrase: String
    public let systemImage: String

    public init(id: String, name: String, phrase: String, systemImage: String) {
        self.id = id
        self.name = name
        self.phrase = phrase
        self.systemImage = systemImage
    }
}

/// Lifestyle factors the user can tag a day with. The pattern finder looks for
/// links between these and symptoms.
public enum TriggerCatalog {
    public static let alcohol = "alcohol"
    public static let caffeine = "caffeine"
    public static let spicyFood = "spicy_food"
    public static let sugaryFood = "sugary_food"
    public static let stress = "stress"
    public static let exercise = "exercise"
    public static let hotEnvironment = "hot_environment"
    public static let lateMeal = "late_meal"

    public static let all: [TriggerDefinition] = [
        TriggerDefinition(id: alcohol, name: "Alcohol", phrase: "alcohol", systemImage: "wineglass"),
        TriggerDefinition(id: caffeine, name: "Caffeine", phrase: "caffeine", systemImage: "cup.and.saucer"),
        TriggerDefinition(id: spicyFood, name: "Spicy food", phrase: "spicy food", systemImage: "flame"),
        TriggerDefinition(id: sugaryFood, name: "Sugary food", phrase: "sugary food", systemImage: "birthday.cake"),
        TriggerDefinition(id: stress, name: "High stress", phrase: "high stress", systemImage: "exclamationmark.circle"),
        TriggerDefinition(id: exercise, name: "Exercise", phrase: "exercise", systemImage: "figure.run"),
        TriggerDefinition(id: hotEnvironment, name: "Hot room / weather", phrase: "a hot room or weather", systemImage: "thermometer.sun"),
        TriggerDefinition(id: lateMeal, name: "Late meal", phrase: "a late meal", systemImage: "clock")
    ]

    private static let byID: [String: TriggerDefinition] = {
        var map: [String: TriggerDefinition] = [:]
        for definition in all { map[definition.id] = definition }
        return map
    }()

    public static func definition(for id: String) -> TriggerDefinition? { byID[id] }

    public static func name(for id: String) -> String {
        byID[id]?.name ?? id.replacingOccurrences(of: "_", with: " ").capitalized
    }

    public static func phrase(for id: String) -> String {
        byID[id]?.phrase ?? name(for: id).lowercased()
    }
}
