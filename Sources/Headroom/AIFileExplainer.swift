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

enum OpenAIFileExplainer {
    private struct Request: Encodable {
        let model: String
        let messages: [Message]
        let responseFormat: ResponseFormat

        enum CodingKeys: String, CodingKey { case model, messages; case responseFormat = "response_format" }
    }
    private struct Message: Encodable { let role: String; let content: String }
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
    }

    static func explain(_ input: AIFileExplanationInput, apiKey: String, model: String) async throws -> FileUseExplanation {
        let inputData = try JSONEncoder().encode(input)
        guard let inputJSON = String(data: inputData, encoding: .utf8) else { throw Error.invalidMetadata }
        let system = """
        You explain what an unfamiliar Mac file is likely used for. Be calm and specific, but never claim certainty beyond the supplied metadata. Do not tell the person to delete anything. Do not ask for file contents, search the internet, or infer personal details. Return only JSON with headline, summary, confidence (high, medium, or low), evidence (an array of at most three short facts from the supplied metadata), and caution. Explain in everyday language.
        """
        let user = "Here is the metadata-only file context: \(inputJSON)"
        let body = Request(model: model, messages: [
            Message(role: "system", content: system),
            Message(role: "user", content: user)
        ], responseFormat: ResponseFormat(type: "json_object"))
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw Error.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw Error.api(status: http.statusCode, detail: detail)
        }
        let payload = try JSONDecoder().decode(Response.self, from: data)
        guard let content = payload.choices.first?.message.content,
              let explanationData = content.data(using: .utf8) else { throw Error.invalidResponse }
        let explanation = try JSONDecoder().decode(Explanation.self, from: explanationData)
        return FileUseExplanation(id: input.fileName + "-ai", source: .ai,
                                  headline: explanation.headline, summary: explanation.summary,
                                  confidence: explanation.confidence, evidence: explanation.evidence,
                                  caution: explanation.caution)
    }

    enum Error: LocalizedError {
        case invalidMetadata, invalidResponse, api(status: Int, detail: String)
        var errorDescription: String? {
            switch self {
            case .invalidMetadata: "Headroom could not prepare the file metadata for an explanation."
            case .invalidResponse: "The AI service returned an explanation Headroom could not read."
            case let .api(status, detail): "The AI service returned \(status): \(detail.prefix(180))"
            }
        }
    }
}
