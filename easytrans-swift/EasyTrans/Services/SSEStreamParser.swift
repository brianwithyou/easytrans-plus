import Foundation

enum SSEStreamParser {
    /// 从 SSE `data:` 行解析文本增量，兼容 OpenAI 兼容格式与 `{ "delta": "..." }` 格式。
    static func delta(from payload: String) -> String? {
        guard payload != "[DONE]",
              let jsonData = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }

        if let delta = json["delta"] as? String, !delta.isEmpty {
            return delta
        }

        guard let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let delta = first["delta"] as? [String: Any],
              let content = delta["content"] as? String,
              !content.isEmpty else {
            return nil
        }
        return content
    }

    static func consume(
        lines: AsyncLineSequence<URLSession.AsyncBytes>,
        onDelta: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        var fullText = ""
        for try await line in lines {
            guard line.hasPrefix("data:") else { continue }
            let payload = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            guard let chunk = delta(from: payload) else { continue }
            fullText += chunk
            onDelta(chunk)
        }

        let result = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else {
            throw TranslationError.emptyResponse
        }
        return result
    }
}
