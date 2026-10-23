import SwiftUI
import Observation

@MainActor
@Observable
final class ChatViewModel {
    enum Mode: String, Codable { case auto, onDevice, claude }
    enum Status: Equatable { case idle, thinking, error(String) }

    struct Confirmation: Identifiable {
        let id = UUID()
        let request: ConfirmRequest   // Pfad + alt/neu für Diff im Halten-Dialog
        var continuation: CheckedContinuation<Bool, Never>?
    }

    struct RunningInfo: Equatable {
        let actor: Actor
        var step: Int          // var: Live-Mirror inkrementiert je Werkzeugaufruf
        let startedAt: Date
    }

    private(set) var munin: [OrderSummary] = []   // Auftrags-Historie
    var currentOrderID: UUID?                     // nil = Start-Screen
    var messages: [ChatMessage] = []
    var status: Status = .idle
    var mode: Mode = UserDefaults.standard.string(forKey: "hugin.mode").flatMap(Mode.init(rawValue:)) ?? .auto {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: "hugin.mode") }
    }
    var grants: [Grant] = []
    var draft = ""
    var queuedDraft: String?                     // „Nächsten Auftrag vormerken …"
    var running: RunningInfo?                    // Running-Pill (Akteur, Schritt, Zeit)
    var liveCards: [ActionCard] = []            // Flugbahn während des Laufs („● live“)
    var liveFindings: [Finding] = []            // Fundstück während des Laufs
    var pendingConfirmation: Confirmation?

    private let security: SecurityStore
    private let store: HuginStore?
    // @MainActor-Closure, IUO: Zuweisung NACH allen anderen Properties (self-Capture erst dann erlaubt);
    // CardBuffer/FindingBuffer laufen als Parameter mit – kein MainActor-State aus @Sendable-Closures gelesen
    private var makeProvider: (@MainActor (Mode, CardBuffer, FindingBuffer) throws -> ModelProvider)!
    private var runTask: Task<Void, Never>?

    init(security: SecurityStore = SecurityStore(),
         store: HuginStore? = nil,
         makeProvider: (@MainActor (Mode, CardBuffer, FindingBuffer) throws -> ModelProvider)? = nil) {
        self.security = security
        self.store = store
        self.makeProvider = makeProvider ?? { [weak self] mode, cards, findings in
            guard let self else { throw ModelError.network("ViewModel nicht mehr verfügbar") }
            switch mode {
            case .onDevice:
                guard let onDevice = AppleSystemModel(fileTools: self.fileTools(),
                                                      backupDir: self.backupDir,
                                                      onCard: { cards.add($0) },
                                                      onFinding: { findings.add($0) },
                                                      confirm: self.confirmBridge) else {
                    throw ModelError.unavailable
                }
                return onDevice
            case .claude, .auto:
                guard let key = self.security.loadKey() else { throw ModelError.unauthorized }
                return ClaudeClient(apiKey: key)
            }
        }
    }

    func load() {
        let (loaded, skipped) = security.loadGrants()
        grants = loaded
        if skipped > 0 && loaded.isEmpty {
            status = .error("Alle Freigaben abgelaufen – bitte Ordner neu freigeben.")
        }
        if let store { munin = store.listOrders() }
    }

    /// Munin-Eintrag antippen: Auftrag einsehen (read-only; Fortsetzung = neuer Auftrag)
    func open(orderID: UUID) {
        currentOrderID = orderID
        messages = store?.load(orderID: orderID) ?? []
        status = .idle
        running = nil
    }

    /// Zurück zum Start-Screen
    func closeOrder() {
        currentOrderID = nil
        messages = []
        status = .idle
    }

    /// „Anhalten" (Design: Stop-Knopf in der Auftragsleiste)
    func stop() { runTask?.cancel() }

    func addGrant(url: URL) {
        do { _ = try security.addGrant(url: url); grants = security.loadGrants() }
        catch { status = .error("Freigabe fehlgeschlagen: \(error)") }
    }

    func saveKey(_ key: String) {
        do { try security.saveKey(key) } catch { status = .error("Key speichern fehlgeschlagen: \(error)") }
    }

    private var backupDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(".backups")
    }

    private func fileTools() -> FileTools {
        FileTools(roots: security.loadGrants().grants)
    }

    func run(_ text: String) {
        guard status != .thinking else { return }
        // Einmal-Override aus dem Auftragstext (Spec: „nutz Claude“/„nutz lokal“)
        var modeForRun = mode
        var prompt = text
        let lower = text.lowercased()
        if lower.contains("nutz claude") {
            modeForRun = .claude
            prompt = prompt.replacingOccurrences(of: "nutz Claude", with: "", options: .caseInsensitive)
        } else if lower.contains("nutz lokal") || lower.contains("nutz on-device") {
            modeForRun = .onDevice
            prompt = prompt.replacingOccurrences(of: "nutz lokal", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "nutz on-device", with: "", options: .caseInsensitive)
        }
        // Neuer Auftrag (Munin-Eintrag), frischer Verlauf
        let orderID = UUID()
        currentOrderID = orderID
        messages = [ChatMessage(role: .user, text: text)]
        let title = String(text.prefix(48))
        running = nil
        status = .thinking
        runTask = Task { [weak self] in
            guard let self else { return }
            await self.executeRun(orderID: orderID, title: title, prompt: prompt, modeForRun: modeForRun)
        }
    }

    /// „Nächsten Auftrag schon vormerken …“ (Queue-Bar, Design-Auftragsansicht)
    func queueDraft(_ text: String) {
        guard !text.isEmpty else { return }
        queuedDraft = text
    }

    private func startQueuedIfAny() {
        guard status != .thinking, let next = queuedDraft else { return }
        queuedDraft = nil
        run(next)
    }

    func waitForRunEnd() async {
        await runTask?.value
    }

    private func executeRun(orderID: UUID, title: String, prompt: String, modeForRun: Mode) async {
        let cards = CardBuffer()
        let findings = FindingBuffer()
        liveCards = []; liveFindings = []
        defer { running = nil; status = .idle; startQueuedIfAny() }
        do {
            let (provider, hint) = try resolveProvider(mode: modeForRun, cards: cards, findings: findings)
            if let hint { cards.add(hint); liveCards.append(hint) }
            running = RunningInfo(actor: provider.actor, step: 0, startedAt: Date())
            let (finalText, stepCards, found) = try await runAgent(
                provider: provider, cards: cards, findings: findings, text: prompt)
            messages.append(ChatMessage(role: .assistant, text: finalText, cards: stepCards, findings: found))
            liveCards = []; liveFindings = []
            persist(orderID: orderID, title: title, actor: provider.actor)
        } catch is CancellationError {
            messages.append(ChatMessage(role: .assistant, text: "Angehalten.", cards: cards.all, findings: findings.all))
            liveCards = []; liveFindings = []
            persist(orderID: orderID, title: title, actor: nil)
        } catch let urlError as URLError where urlError.code == .cancelled {
            // Abbruch während eines Netzaufrufs → ebenfalls „Angehalten“, kein Fake-Fehler
            messages.append(ChatMessage(role: .assistant, text: "Angehalten.", cards: cards.all, findings: findings.all))
            liveCards = []; liveFindings = []
            persist(orderID: orderID, title: title, actor: nil)
        } catch {
            // Laufzeit-Eskalation (nur auto): onDevice-Modell versagt mitten im Lauf → Claude.
            // Init-Fälle eskaliert resolveProvider bereits; Claude-Netzwerk-/Key-Fehler → klare
            // Meldung, on-device bleibt über den Botengang nutzbar (Spec: „Kein Internet → nur on-device“)
            if modeForRun == .auto, (error as? ModelError) == .unavailable,
               let claude = try? makeProvider(.claude, cards, findings) {
                let handover = ActionCard(id: UUID(), kind: .handover, actor: .claude,
                                          title: "Übergabe: On-Device fehlgeschlagen – Claude übernimmt",
                                          detail: "\(error)", durationMS: nil, createdAt: Date())
                cards.add(handover); liveCards.append(handover)
                do {
                    running = RunningInfo(actor: .claude, step: 0, startedAt: Date())
                    let (finalText, stepCards, found) = try await runAgent(
                        provider: claude, cards: cards, findings: findings, text: prompt)
                    messages.append(ChatMessage(role: .assistant, text: finalText,
                                               cards: cards.all, findings: findings.all))
                    liveCards = []; liveFindings = []
                    persist(orderID: orderID, title: title, actor: .claude)
                    return   // defer übernimmt running/status/Queue
                } catch { /* fällt unten in die Fehlermeldung durch */ }
            }
            let errorCard = ActionCard(id: UUID(), kind: .error, actor: nil, title: "Fehler",
                                       detail: "\(error)", durationMS: nil, createdAt: Date())
            messages.append(ChatMessage(role: .assistant, text: errorText(error),
                                       cards: cards.all + [errorCard], findings: findings.all))
            liveCards = []; liveFindings = []
            persist(orderID: orderID, title: title, actor: nil)
        }
    }

    private func persist(orderID: UUID, title: String, actor: Actor?) {
        guard let store else { return }
        let actorName = actor == .claude ? "Claude" : "lokal"
        try? store.save(orderID: orderID, title: title, actor: actorName, messages: messages)
        munin = store.listOrders()
    }

    private func runAgent(provider: ModelProvider, cards: CardBuffer, findings: FindingBuffer,
                          text: String) async throws -> (String, [ActionCard], [Finding]) {
        // Live-Spiegel über AsyncStream (Swift-6-sicher: Continuations sind Sendable,
        // kein MainActor-State aus @Sendable-Closures gelesen)
        let (cardStream, cardContinuation) = AsyncStream<ActionCard>.makeStream()
        let (findingStream, findingContinuation) = AsyncStream<Finding>.makeStream()
        let cardMirror = Task { @MainActor in
            for await card in cardStream {
                liveCards.append(card)
                running?.step += 1
            }
        }
        let findingMirror = Task { @MainActor in
            for await finding in findingStream { liveFindings.append(finding) }
        }
        defer {
            cardContinuation.finish(); findingContinuation.finish()
            cardMirror.cancel(); findingMirror.cancel()
        }
        let runner = AgentRunner(provider: provider, fileTools: fileTools(), backupDir: backupDir,
                                 onCard: { c in cards.add(c); cardContinuation.yield(c) },
                                 onFinding: { f in findings.add(f); findingContinuation.yield(f) },
                                 confirm: confirmBridge)
        let result = try await runner.run(userText: text, prior: [])
        let finalText: String
        switch result {
        case .completed(let t, _): finalText = t
        case .limitReached(let t, _): finalText = t
        }
        return (finalText, cards.all, findings.all)
    }

    private func resolveProvider(mode: Mode, cards: CardBuffer, findings: FindingBuffer)
        throws -> (ModelProvider, ActionCard?) {
        switch mode {
        case .onDevice:
            return (try makeProvider(.onDevice, cards, findings), nil)
        case .claude:
            return (try makeProvider(.claude, cards, findings), nil)
        case .auto:
            do { return (try makeProvider(.onDevice, cards, findings), nil) }
            catch {
                let handover = ActionCard(id: UUID(), kind: .handover, actor: .claude,
                                          title: "Übergabe: On-Device nicht möglich – Claude übernimmt",
                                          detail: "\(error)", durationMS: nil, createdAt: Date())
                return (try makeProvider(.claude, cards, findings), handover)
            }
        }
    }

    private lazy var confirmBridge: @Sendable (ConfirmRequest) async -> Bool = { [weak self] request in
        await MainActor.run {
            await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
                // Defensive: eine etwaige ältere Continuation freigeben (kein Deadlock/Leak)
                self?.pendingConfirmation?.continuation?.resume(returning: false)
                self?.pendingConfirmation = Confirmation(request: request, continuation: c)
            }
        }
    }

    private func errorText(_ error: Error) -> String {
        switch error as? ModelError {
        case .unauthorized: return "Claude-API-Key ungültig – bitte in den Einstellungen prüfen. On-Device-Modus bleibt nutzbar."
        case .network(let msg): return "Netzwerkfehler: \(msg). On-Device-Modus bleibt nutzbar."
        case .unavailable: return "On-Device-Modell nicht verfügbar."
        case nil: return "Fehler: \(error)"
        }
    }

    func resolveConfirmation(_ allowed: Bool) {
        pendingConfirmation?.continuation?.resume(returning: allowed)
        pendingConfirmation = nil
    }
}
