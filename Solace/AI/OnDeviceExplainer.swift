//
//  OnDeviceExplainer.swift
//  Solace
//

import FoundationModels

@Generable
struct ScoreExplanation {
    @Guide(description: "One or two plain-English sentences, using only the data given")
    let summary: String
}

enum OnDeviceExplainerError: Error {
    case unavailable(SystemLanguageModel.Availability.UnavailableReason)
}

/// Tier 1 AI (Section 7) — explains an already-computed score using only the
/// numbers passed in. Never invents nutrition figures, never calls out to
/// the network.
enum OnDeviceExplainer {
    static var availability: SystemLanguageModel.Availability {
        SystemLanguageModel.default.availability
    }

    static func explain(food: FoodScoringInput, result: ScoreResult) async throws -> String {
        switch availability {
        case .available: break
        case .unavailable(let reason): throw OnDeviceExplainerError.unavailable(reason)
        }

        let session = LanguageModelSession {
            "You explain packaged-food nutrition data to a shopper. Use only the numbers given. Never invent values."
        }

        let grades = [
            result.nutriScoreGrade.map { "Nutri-Score \($0.uppercased())" },
            result.novaGroup.map { "NOVA \($0)" },
            result.greenScoreGrade.map { "Green-Score \($0.uppercased())" },
        ].compactMap { $0 }.joined(separator: ", ")

        let prompt = """
            \(grades.isEmpty ? "No regulatory grades available." : grades).
            Per 100g: sugar \(food.sugars100g.map { "\($0)g" } ?? "unknown"), \
            saturated fat \(food.saturatedFat100g.map { "\($0)g" } ?? "unknown"), \
            sodium \(food.sodium100g.map { "\($0)g" } ?? "unknown"), \
            protein \(food.proteins100g.map { "\($0)g" } ?? "unknown"), \
            fiber \(food.fiber100g.map { "\($0)g" } ?? "unknown").
            Explain briefly why it scored this way.
            """

        let response = try await session.respond(to: prompt, generating: ScoreExplanation.self)
        return response.content.summary
    }
}

extension SystemLanguageModel.Availability.UnavailableReason {
    var userFacingMessage: String {
        switch self {
        case .deviceNotEligible:
            return "This device doesn't support Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in Settings to get on-device explanations."
        case .modelNotReady:
            return "The on-device model is still downloading — try again shortly."
        @unknown default:
            return "On-device AI is unavailable right now."
        }
    }
}
