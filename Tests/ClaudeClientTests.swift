import XCTest
@testable import Hugin

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let h = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (status, data) = try h(request)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

final class ClaudeClientTests: XCTestCase {
    func makeClient() -> ClaudeClient {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [MockURLProtocol.self]
        return ClaudeClient(apiKey: "sk-test", session: URLSession(configuration: cfg))
    }

    func testParseTextUndToolUse() throws {
        let json = """
        {"content": [
            {"type": "text", "text": "Ich suche."},
            {"type": "tool_use", "id": "tu_1", "name": "list_files", "input": {"folder": "Doku"}}
        ]}
        """
        let r = try ClaudeClient.parse(Data(json.utf8))
        XCTAssertEqual(r.text, "Ich suche.")
        XCTAssertEqual(r.toolCalls.count, 1)
        XCTAssertEqual(r.toolCalls[0].name, "list_files")
        XCTAssertEqual(r.toolCalls[0].arguments["folder"]?.stringValue, "Doku")
    }

    func testRequestMitSystemToolsUndVerlauf() async throws {
        MockURLProtocol.handler = { req in
            let body = req.httpBody ?? req.httpBodyStreamData ?? Data()
            let json = try JSONValue.from(data: body)
            XCTAssertEqual(json["model"]?.stringValue, "claude-sonnet-4-5")
            if case .array(let tools)? = json["tools"] { XCTAssertEqual(tools.count, 1) } else { XCTFail("tools fehlen") }
            XCTAssertEqual(req.value(forHTTPHeaderField: "x-api-key"), "sk-test")
            XCTAssertEqual(req.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
            return (200, Data(#"{"content": [{"type": "text", "text": "ok"}]}"#.utf8))
        }
        let client = makeClient()
        let r = try await client.respond(system: "s", messages: [.user("hi")],
            tools: [ToolSpec(name: "t", description: "d", inputSchema: .object([:]))])
        XCTAssertEqual(r.text, "ok")
        XCTAssertNotNil(MockURLProtocol.handler)
        MockURLProtocol.handler = nil
    }

    func test401WirftUnauthorized() async {
        MockURLProtocol.handler = { _ in (401, Data()) }
        let client = makeClient()
        do {
            _ = try await client.respond(system: "s", messages: [], tools: [])
            XCTFail("erwartet unauthorized")
        } catch { XCTAssertEqual(error as? ModelError, .unauthorized) }
        MockURLProtocol.handler = nil
    }

    func testAbbruchWirftCancellation() async {
        MockURLProtocol.handler = { _ in throw URLError(.cancelled) }
        let client = makeClient()
        do {
            _ = try await client.respond(system: "s", messages: [.user("hi")], tools: [])
            XCTFail("Cancellation erwartet")
        } catch {
            XCTAssertTrue(error is CancellationError, "war kein Abbruch: \(error)")
        }
        MockURLProtocol.handler = nil
    }

    func testLeererAssistantTextBlockWirdAusgelassen() async throws {
        MockURLProtocol.handler = { req in
            let body = req.httpBody ?? req.httpBodyStreamData ?? Data()
            let json = try JSONValue.from(data: body)
            if case .array(let msgs)? = json["messages"] {
                if case .array(let blocks)? = msgs.first?["content"] {
                    XCTAssertFalse(blocks.contains { $0["text"]?.stringValue == "" },
                                   "leerer text-block im assistant-content")
                }
            }
            return (200, Data(#"{"content": [{"type": "text", "text": "ok"}]}"#.utf8))
        }
        let client = makeClient()
        _ = try await client.respond(system: "s",
            messages: [.assistant(text: "", toolCalls: [.init(id: "1", name: "t", arguments: .object([:]))])],
            tools: [])
        MockURLProtocol.handler = nil
    }
}
