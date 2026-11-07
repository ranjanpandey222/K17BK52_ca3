import Foundation

/// Answer to the single optional onboarding question "When was your last period?".
public enum LastPeriodAnswer: String, CaseIterable, Codable, Sendable, Identifiable {
    case withinThreeMonths
    case threeToTwelveMonths
    case overTwelveMonths
    case otherReason
    case notSure
    case preferNotToSay

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .withinThreeMonths: return "In the last 3 months"
        case .threeToTwelveMonths: return "3 to 12 months ago"
        case .overTwelveMonths: return "More than 12 months ago"
        case .otherReason: return "I don't have periods for another reason"
        case .notSure: return "I'm not sure"
        case .preferNotToSay: return "Prefer not to say"
        }
    }

    public var subtitle: String? {
        switch self {
        case .otherReason: return "e.g. hysterectomy, hormonal IUD or birth control"
        default: return nil
        }
    }
}

public enum MenopauseStage: String, Codable, Sendable {
    case possiblyPerimenopause
    case likelyLatePerimenopause
    case likelyPostmenopause
    case unclear
}

public struct StageEstimate: Hashable, Sendable {
    public let stage: MenopauseStage
    public let title: String
    public let explanation: String
    /// Always shown with the estimate.
    public static let disclaimer = "This is an estimate to help you understand your experience, not a diagnosis. Only a clinician can confirm your stage."
}

/// Gives a gentle, non-diagnostic description of where someone may be in the
/// menopause transition. Menopause is defined as 12 months in a row without a
/// period; perimenopause usually starts in the 40s.
public enum StageEstimator {
    public static func estimate(lastPeriod: LastPeriodAnswer?, age: Int?) -> StageEstimate {
        switch lastPeriod {
        case .overTwelveMonths:
            return StageEstimate(
                stage: .likelyPostmenopause,
                title: "You may have reached menopause",
                explanation: "Menopause is usually confirmed after 12 months in a row without a period. Symptoms like hot flashes and poor sleep can continue for years afterwards, so tracking still helps. Any bleeding after 12 months without a period should be checked by a doctor."
            )
        case .threeToTwelveMonths:
            return StageEstimate(
                stage: .likelyLatePerimenopause,
                title: "You may be in late perimenopause",
                explanation: "Long gaps between periods are common in the later part of the transition. Symptoms such as hot flashes and night sweats are often at their most noticeable around this time."
            )
        case .withinThreeMonths:
            if let age, age >= 40 {
                return StageEstimate(
                    stage: .possiblyPerimenopause,
                    title: "Your symptoms may be perimenopause",
                    explanation: "Perimenopause often begins in the 40s, while periods are still coming, and can last several years. Changes in sleep, mood, focus and temperature are common signs."
                )
            }
            return StageEstimate(
                stage: .unclear,
                title: "Let's learn what your body is telling you",
                explanation: "Perimenopause usually starts in the 40s, but it can begin earlier for some people. Tracking your symptoms over a few weeks gives you and your clinician a clearer picture."
            )
        case .otherReason:
            return StageEstimate(
                stage: .unclear,
                title: "Your symptoms tell the story",
                explanation: "When periods aren't a guide, your age and symptoms matter more. Tracking how you feel over time gives you and your clinician the clearest picture."
            )
        case .notSure, .preferNotToSay, .none:
            return StageEstimate(
                stage: .unclear,
                title: "Let's learn what your body is telling you",
                explanation: "Tracking your symptoms over a few weeks shows what's really going on and gives you something concrete to discuss with your clinician."
            )
        }
    }

    /// Age from a birth year, if known.
    public static func age(birthYear: Int?, today: Date, calendar: Calendar = .current) -> Int? {
        guard let birthYear, birthYear > 1900 else { return nil }
        let year = calendar.component(.year, from: today)
        let age = year - birthYear
        return (0...120).contains(age) ? age : nil
    }
}
