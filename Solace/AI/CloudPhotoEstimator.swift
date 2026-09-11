//
//  CloudPhotoEstimator.swift
//  Solace
//

import Foundation

enum CloudPhotoEstimatorError: LocalizedError, Equatable {
    case notConfigured
    case invalidOrDeprecatedModel(String)
    case server(Int, String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Enable AI features and add an API key in Settings first."
        case .invalidOrDeprecatedModel(let model):
            return "The model \"\(model)\" was rejected by your provider — it may be renamed, retired, or misspelled. Update it in Settings."
        case .server(let code, let message):
            return "Provider returned an error (\(code)): \(message)"
        case .decoding:
            return "Couldn't understand the provider's response."
        }
    }
}

/// Tier 2 AI (Section 7) — BYOK, opt-in, powers photo-based food logging via
/// any OpenAI-compatible `/chat/completions` endpoint. Direct client-to-
/// provider calls are fine for a user-supplied key (not a shared developer
/// key baked into every install).
enum CloudPhotoEstimator {
    static func estimate(imageData: Data, userContext: String?, settings: AIProviderSettings, apiKey: String) async throws -> PhotoEstimateResult {
        guard settings.isEnabled, !apiKey.isEmpty, !settings.modelString.isEmpty else {
            throw CloudPhotoEstimatorError.notConfigured
        }

        var request = URLRequest(url: URL(string: settings.baseURL.trimmingCharacters(in: .init(charactersIn: "/")) + "/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let dataURL = "data:image/jpeg;base64,\(imageData.base64EncodedString())"
        let body: [String: Any] = [
            "model": settings.modelString,
            "response_format": ["type": "json_object"],
            "messages": [
                [
                    "role": "system",
                    "content": """
                        You estimate the food and portion sizes visible in a photo. \
                        Reply with ONLY a JSON object of this exact shape, no prose: \
                        {"items": [{"name": string, "estimatedGrams": number, "kcal": number, \
                        "proteinG": number, "carbG": number, "fatG": number}], "confidence": number between 0 and 1}
                        """,
                ],
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": userContext?.isEmpty == false ? userContext! : "Estimate the food in this photo."],
                        ["type": "image_url", "image_url": ["url": dataURL]],
                    ],
                ],
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw CloudPhotoEstimatorError.decoding }

        guard (200...299).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { $0["error"] as? [String: Any] }
                .flatMap { $0["message"] as? String } ?? String(data: data, encoding: .utf8) ?? "Unknown error"
            if http.statusCode == 404 || message.lowercased().contains("model") {
                throw CloudPhotoEstimatorError.invalidOrDeprecatedModel(settings.modelString)
            }
            throw CloudPhotoEstimatorError.server(http.statusCode, message)
        }

        return try parse(data)
    }

    static func parse(_ data: Data) throws -> PhotoEstimateResult {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = root["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String,
              let contentData = content.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any],
              let rawItems = payload["items"] as? [[String: Any]]
        else { throw CloudPhotoEstimatorError.decoding }

        let items = rawItems.compactMap { item -> PhotoEstimateItem? in
            guard let name = item["name"] as? String else { return nil }
            return PhotoEstimateItem(
                name: name,
                estimatedGrams: (item["estimatedGrams"] as? NSNumber)?.doubleValue ?? 0,
                kcal: (item["kcal"] as? NSNumber)?.doubleValue ?? 0,
                proteinG: (item["proteinG"] as? NSNumber)?.doubleValue ?? 0,
                carbG: (item["carbG"] as? NSNumber)?.doubleValue ?? 0,
                fatG: (item["fatG"] as? NSNumber)?.doubleValue ?? 0
            )
        }
        guard !items.isEmpty else { throw CloudPhotoEstimatorError.decoding }
        let confidence = (payload["confidence"] as? NSNumber)?.doubleValue ?? 0
        return PhotoEstimateResult(items: items, confidence: min(max(confidence, 0), 1))
    }
}
