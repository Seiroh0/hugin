import SwiftUI

struct OrderView: View {
    let vm: ChatViewModel
    var onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(HuginColor.border1)
            HStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        userMessage
                        ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                            StepNode(card: card, isRunning: isLastRunning(index))
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                        if vm.status == .thinking { runningRow }
                    }
                    .padding(36)
                }
                FundstueckView(vm: vm).frame(width: 290)
            }
            QueueBar(vm: vm).padding(12)
        }
        .background(HuginColor.basalt)
    }

    private var cards: [ActionCard] {
        vm.status == .thinking ? vm.liveCards : vm.messages.flatMap(\.cards)
    }

    private var header: some View {
        HStack(spacing: 16) {
            Button("← Start", action: onBack).buttonStyle(.plain).foregroundStyle(HuginColor.asche)
            VStack(alignment: .leading, spacing: 6) {
                monoLabel("Auftrag · \(vm.grants.first?.name ?? "Freigaben")")
                Text(vm.munin.first(where: { $0.id == vm.currentOrderID })?.title ?? "Auftrag")
                    .font(HuginFont.geist(22, .semibold))
            }
            Spacer()
            if let running = vm.running {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    HStack(spacing: 10) {
                        WispView(state: .denkt, actor: running.actor, size: 9)
                        Text(running.actor == .claude ? "Claude" : "Lokal")
                            .font(HuginFont.geist(14, .medium))
                        monoText(Self.stepLabel(running), size: 12, color: HuginColor.asche)
                    }
                    .padding(.horizontal, 14).frame(minHeight: 40)
                    .background(Capsule().fill(HuginColor.composer).stroke(HuginColor.border2))
                }
            }
            if vm.status == .thinking {
                Button { vm.stop() } label: {
                    Label("Anhalten", systemImage: "stop.fill").font(HuginFont.geist(14))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16).frame(minHeight: 44)
                .background(Capsule().stroke(HuginColor.border3))
            }
        }
        .padding(.horizontal, 32).padding(.vertical, 20)
    }

    static func stepLabel(_ running: ChatViewModel.RunningInfo) -> String {
        let elapsed = Int(Date().timeIntervalSince(running.startedAt))
        return "Schritt \(running.step + 1) · \(elapsed / 60):\(String(format: "%02d", elapsed % 60))"
    }

    @ViewBuilder private var userMessage: some View {
        if let first = vm.messages.first, first.role == .user {
            VStack(alignment: .leading, spacing: 8) {
                monoLabel("DU · \(first.createdAt.formatted(.dateTime.hour().minute()))")
                Text("„\(first.text)“").font(HuginFont.geist(26)).lineSpacing(6)
            }
        }
    }

    private var runningRow: some View {
        HStack(spacing: 12) {
            WispView(state: .fliegt, actor: vm.running?.actor ?? .local, size: 18)
            monoText("Hugin arbeitet …", size: 12, color: HuginColor.asche)
        }
        .padding(.leading, 40)
    }

    private func isLastRunning(_ index: Int) -> Bool {
        vm.status == .thinking && index == cards.count - 1
    }
}
