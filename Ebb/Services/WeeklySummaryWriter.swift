import Foundation
import EbbCore
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Writes a short, friendly weekly summary using Apple's on-device language
/// model (iOS 26+, Apple Intelligence devices). Nothing is sent to a server.
/// On other devices a plain template summary is used instead.
enum WeeklySummaryWriter {
    static var isOnDeviceAIAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return true
            default: return false
            }
        }
        #endif
        return false
    }

    /// Facts the summary is allowed to use. Deterministic, computed by EbbCore.
    struct Facts {
        let daysLogged: Int
        let averageScore: Double?
        let previousAverageScore: Double?
        let topSymptoms: [(name: String, days: Int)]
        let insightTitles: [String]

        var asText: String {
            var lines: [String] = ["Days checked in this week: \(daysLogged) of 7."]
            if let averageScore {
                lines.append("Average symptom score this week: \(Int(averageScore.rounded())) out of 100 (lower is better).")
            }
            if let previousAverageScore {
                lines.append("Average symptom score the week before: \(Int(previousAverageScore.rounded())).")
            }
            if !topSymptoms.isEmpty {
                lines.append("Most frequent symptoms: " + topSymptoms.map { "\($0.name) (\($0.days) days)" }.joined(separator: ", ") + ".")
            }
            for title in insightTitles.prefix(3) {
                lines.append("Pattern: \(title).")
            }
            return lines.joined(separator: "\n")
        }
    }

    static func templateSummary(_ facts: Facts) -> String {
        guard facts.daysLogged > 0 else {
            return "No check-ins this week yet. A quick daily check-in is all it takes to start seeing your patterns."
        }
        var parts: [String] = []
        parts.append("You checked in on \(facts.daysLogged) of the last 7 days.")
        if let current = facts.averageScore, let previous = facts.previousAverageScore, previous > 0 {
            let change = (current - previous) / previous
            if change <= -0.1 {
                parts.append("Your symptom score was \(Phrasing.percent(-change)) lower than the week before.")
            } else if change >= 0.1 {
                parts.append("Your symptom score was \(Phrasing.percent(change)) higher than the week before.")
            } else {
                parts.append("Your symptom score was about the same as the week before.")
            }
        }
        if let top = facts.topSymptoms.first {
            parts.append("\(top.name) showed up most often (\(Phrasing.days(top.days))).")
        }
        return parts.joined(separator: " ")
    }

    /// Returns an on-device AI summary when available, otherwise the template.
    static func summary(_ facts: Facts) async -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), isOnDeviceAIAvailable, facts.daysLogged > 0 {
            let instructions = """
            You write a short weekly recap inside a menopause symptom tracker.
            Use only the facts provided. Never invent numbers or symptoms.
            Write 2 or 3 warm, plain sentences addressed to the user as "you".
            Do not diagnose, do not suggest medicines, doses or treatments, and do not give medical advice.
            If a pattern is mentioned, describe it as something to keep an eye on or to discuss with a clinician.
            """
            do {
                let session = LanguageModelSession(instructions: instructions)
                let response = try await session.respond(to: "Facts about this week:\n" + facts.asText)
                let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { return text }
            } catch {
                // Fall through to the template.
            }
        }
        #endif
        return templateSummary(facts)
    }
}
