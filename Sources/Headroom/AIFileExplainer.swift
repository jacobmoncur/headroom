import AppKit
import Foundation
import HeadroomCore
import Security

enum KeychainSecretStore {
    private static let service = "dev.moncur.headroom"
    private static let account = "openai-api-key"

    static func loadAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8), !key.isEmpty else { return nil }
        return key
    }

    static func saveAPIKey(_ key: String) throws {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary)
        var item = base
        item[kSecValueData as String] = Data(key.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.saveFailed(status) }
    }

    static func deleteAPIKey() {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ] as CFDictionary)
    }

    enum KeychainError: LocalizedError {
        case saveFailed(OSStatus)
        var errorDescription: String? { "Headroom could not save the API key in your Mac’s Keychain." }
    }
}

@MainActor
enum OpenAIFileExplainer {
    struct OrganizationGroup: Sendable {
        let title: String
        let detail: String
        let reason: String
        let suggestedFolder: String
        let confidence: Confidence
        let fileIDs: [String]
    }

    private struct Request: Encodable {
        let model: String
        let messages: [Message]
        let responseFormat: ResponseFormat

        enum CodingKeys: String, CodingKey { case model, messages; case responseFormat = "response_format" }
    }

    private struct Message: Encodable {
        let role: String
        let content: MessageContent
    }

    private enum MessageContent: Encodable {
        case text(String)
        case parts([ContentPart])

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case let .text(value): try container.encode(value)
            case let .parts(value): try container.encode(value)
            }
        }
    }

    private struct ContentPart: Encodable {
        let type: String
        let text: String?
        let imageURL: ImageURL?

        enum CodingKeys: String, CodingKey { case type, text; case imageURL = "image_url" }

        static func text(_ value: String) -> ContentPart {
            ContentPart(type: "text", text: value, imageURL: nil)
        }

        static func image(_ dataURL: String) -> ContentPart {
            ContentPart(type: "image_url", text: nil, imageURL: ImageURL(url: dataURL, detail: "low"))
        }
    }

    private struct ImageURL: Encodable { let url: String; let detail: String }
    private struct ResponseFormat: Encodable { let type: String }
    private struct Response: Decodable { let choices: [Choice] }
    private struct Choice: Decodable { let message: AssistantMessage }
    private struct AssistantMessage: Decodable { let content: String? }
    private struct Explanation: Decodable {
        let headline: String
        let summary: String
        let confidence: FileExplanationConfidence
        let evidence: [String]
        let caution: String
        let decision: FileDecision
        let decisionReason: String
        let organizationSuggestion: String?

        enum CodingKeys: String, CodingKey {
            case headline, summary, confidence, evidence, caution, decision
            case decisionReason = "decision_reason"
            case organizationSuggestion = "organization_suggestion"
        }
    }

    private struct OrganizationResponse: Decodable {
        let groups: [Group]

        struct Group: Decodable {
            let title: String
            let detail: String
            let reason: String
            let suggestedFolder: String
            let confidence: Confidence
            let fileIDs: [String]

            enum CodingKeys: String, CodingKey {
                case title, detail, reason, confidence
                case suggestedFolder = "suggested_folder"
                case fileIDs = "file_ids"
            }
        }
    }

    static func explain(_ input: AIFileExplanationInput, previewDataURL: String?,
                        apiKey: String, model: String) async throws -> FileUseExplanation {
        let inputData = try JSONEncoder().encode(input)
        guard let inputJSON = String(data: inputData, encoding: .utf8) else { throw Error.invalidMetadata }
        let system = """
        You are Headroom's cautious Mac file advisor. Explain what the file is likely used for, then make one clear recommendation: keep, offload, remove, or review. Base every claim on the supplied metadata and optional image preview. Never imply that you inspected contents unless a preview is attached. Recommend remove only for clearly replaceable generated data, verified duplicates, or old one-time installers. Prefer offload over remove for potentially unique personal or project files. Return only JSON with headline, summary, confidence (high, medium, or low), evidence (at most four short supplied or visually observed facts), caution, decision (keep, offload, remove, or review), decision_reason, and organization_suggestion (a short destination or grouping idea, or null). Use everyday language and explain why the choice fits this specific file.
        """
        var userParts = [ContentPart.text("Here is the file context: \(inputJSON)")]
        if let previewDataURL {
            userParts.append(.image(previewDataURL))
            userParts.append(.text("A reduced preview is attached with the user's explicit permission. You may describe visible product, project, document, or reference context, but do not identify people or infer sensitive personal details."))
        }
        let body = Request(model: model, messages: [
            Message(role: "system", content: .text(system)),
            Message(role: "user", content: .parts(userParts))
        ], responseFormat: ResponseFormat(type: "json_object"))
        let content = try await perform(body, apiKey: apiKey)
        guard let explanationData = content.data(using: .utf8) else { throw Error.invalidResponse }
        let explanation = try JSONDecoder().decode(Explanation.self, from: explanationData)
        return FileUseExplanation(id: input.fileName + "-ai", source: .ai,
                                  headline: explanation.headline, summary: explanation.summary,
                                  confidence: explanation.confidence, evidence: Array(explanation.evidence.prefix(4)),
                                  caution: explanation.caution, decision: explanation.decision,
                                  decisionReason: explanation.decisionReason,
                                  organizationSuggestion: explanation.organizationSuggestion,
                                  previewWasAnalyzed: previewDataURL != nil)
    }

    static func organize(_ candidates: [AIOrganizationCandidate], apiKey: String,
                         model: String) async throws -> [OrganizationGroup] {
        let inputData = try JSONEncoder().encode(candidates)
        guard let inputJSON = String(data: inputData, encoding: .utf8) else { throw Error.invalidMetadata }
        let system = """
        You are Headroom's file-organization advisor. Find strong project, topic, or lifecycle relationships between files that are currently in different folders. Use only the supplied metadata. Do not group files merely because they share a broad file type. Do not recommend moving generated dependencies, caches, app bundles, or files whose location may be required by software. Return only JSON with a groups array. Each group must contain title, detail, reason, suggested_folder, confidence (high, medium, or low), and file_ids. Use only supplied file IDs, include at least two files from at least two parent folders, and return at most eight high-value groups. An empty groups array is better than a weak guess.
        """
        let body = Request(model: model, messages: [
            Message(role: "system", content: .text(system)),
            Message(role: "user", content: .text("Organize this metadata-only file set: \(inputJSON)"))
        ], responseFormat: ResponseFormat(type: "json_object"))
        let content = try await perform(body, apiKey: apiKey)
        guard let data = content.data(using: .utf8) else { throw Error.invalidResponse }
        return try JSONDecoder().decode(OrganizationResponse.self, from: data).groups.map {
            OrganizationGroup(title: $0.title, detail: $0.detail, reason: $0.reason,
                              suggestedFolder: $0.suggestedFolder, confidence: $0.confidence,
                              fileIDs: $0.fileIDs)
        }
    }

    static func previewDataURL(for item: ScannedItem) -> String? {
        let supported = ["jpg", "jpeg", "png", "heic", "tif", "tiff", "gif"]
        guard supported.contains(item.url.pathExtension.lowercased()),
              let image = NSImage(contentsOf: item.url), image.size.width > 0, image.size.height > 0 else { return nil }
        let limit: CGFloat = 1_024
        let scale = min(1, limit / max(image.size.width, image.size.height))
        let size = NSSize(width: max(1, image.size.width * scale), height: max(1, image.size.height * scale))
        let resized = NSImage(size: size)
        resized.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: size), from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1)
        resized.unlockFocus()
        guard let tiff = resized.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.72]) else { return nil }
        return "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
    }

    private static func perform(_ body: Request, apiKey: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw Error.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw Error.api(status: http.statusCode, detail: detail)
        }
        let payload = try JSONDecoder().decode(Response.self, from: data)
        guard let content = payload.choices.first?.message.content else { throw Error.invalidResponse }
        return content
    }

    enum Error: LocalizedError {
        case invalidMetadata, invalidResponse, api(status: Int, detail: String)
        var errorDescription: String? {
            switch self {
            case .invalidMetadata: "Headroom could not prepare the file metadata for AI."
            case .invalidResponse: "The AI service returned a recommendation Headroom could not read."
            case let .api(status, detail): "The AI service returned \(status): \(detail.prefix(180))"
            }
        }
    }
}
