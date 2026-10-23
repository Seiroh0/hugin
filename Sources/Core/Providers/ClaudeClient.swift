import Foundation

final class ClaudeClient: ModelProvider, @unchecked Sendable {
    let name = "Claude"
    let actor: Actor = .claude   // Frost
    private let apiKey: String
    private let model: String
    private let session: URLSession

    init(apiKey: String, model: String = "claude-sonnet-4-5", session: URLSession = URLSession(configuration: .ephemeral)) {
        self.apiKey = apiKey; self.model = model; self.session = session
    }

    func respond(system: String, messages: [ProviderMessage], tools: [ToolSpec]) async throws -> ProviderResponse {
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try encodeBody(system: system, messages: messages, tools: tools)
        let data: Data; let resp: URLResponse
        do { (data, resp) = try await session.data(for: req) }
        catch { throw ModelError.network(error.localizedDescription) }
        guard let http = resp as? HTTPURLResponse else { throw ModelError.network("Keine HTTP-Antwort") }
        guard http.statusCode == 200 else {
            if http.statusCode == 401 { throw ModelError.unauthorized }
            throw ModelError.network("HTTP \(http.statusCode)")
        }
        return try Self.parse(data)
    }

    private func encodeBody(system: String, messages: [ProviderMessage], tools: [ToolSpec]) throws -> Data {
        var msgs: [JSONValue] = []
        for m in messages {
            switch m {
            case .user(let t):
                msgs.append(.object(["role": .string("user"), "content": .string(t)]))
            case .assistant(let t, let calls):
                var blocks: [JSONValue] = [.object(["type": .string("text"), "text": .string(t)])]
                for c in calls {
                    blocks.append(.object(["type": .string("tool_use"), "id": .string(c.id),
                                            "name": .string(c.name), "input": c.arguments]))
                }
                msgs.append(.object(["role": .string("assistant"), "content": .array(blocks)]))
            case .toolResult(let id, let content):
                msgs.append(.object(["role": .string("user"), "content": .array([
                    .object(["type": .string("tool_result"), "tool_use_id": .string(id), "content": .string(content)])])]))
            }
        }
        let toolsJSON: [JSONValue] = tools.map {
            .object(["name": .string($0.name), "description": .string($0.description), "input_schema": $0.inputSchema])
        }
        let body: JSONValue = .object([
            "model": .string(model), "max_tokens": .number(4096),
            "system": .string(system), "messages": .array(msgs), "tools": .array(toolsJSON)
        ])
        return try body.data()
    }

    static func parse(_ data: Data) throws -> ProviderResponse {
        let root = try JSONValue.from(data: data)
        var text = ""
        var calls: [ToolCall] = []
        guard case .array(let blocks)? = root["content"] else { return ProviderResponse(text: "", toolCalls: []) }
        for b in blocks {
            switch b["type"]?.stringValue {
            case "text": text += b["text"]?.stringValue ?? ""
            case "tool_use":
                calls.append(ToolCall(id: b["id"]?.stringValue ?? UUID().uuidString,
                                      name: b["name"]?.stringValue ?? "",
                                      arguments: b["input"] ?? .object([:])))
            default: break
            }
        }
        return ProviderResponse(text: text, toolCalls: calls)
    }
}

extension URLRequest {
    var httpBodyStreamData: Data? {
        guard let stream = httpBodyStream else { return nil }
        stream.open(); defer { stream.close() }
        var data = Data(); let bufSize = 4096
        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
        defer { buf.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buf, maxLength: bufSize)
            if read <= 0 { break }
            data.append(buf, count: read)
        }
        return data
    }
}
