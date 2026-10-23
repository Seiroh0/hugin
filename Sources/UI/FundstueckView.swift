import SwiftUI

struct FundstueckView: View {
    let vm: ChatViewModel

    static func latestRead(in messages: [ChatMessage]) -> String? {
        let reads = messages.flatMap(\.cards).filter { $0.kind == .read }
        return reads.last?.detail.split(separator: "/").last.map(String.init)
    }

    static func findings(in messages: [ChatMessage]) -> [Finding] {
        messages.flatMap(\.findings)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                monoLabel("FUNDSTÜCK")
                Spacer()
                if vm.status == .thinking {
                    monoText("● live", size: 11, color: HuginColor.frost)
                }
            }
            .padding(.bottom, 14)
            .overlay(alignment: .bottom) { Divider().overlay(HuginColor.border2) }

            if let file = activeRead {
                VStack(alignment: .leading, spacing: 4) {
                    monoText(file, size: 15, color: HuginColor.knochen)
                    Text(vm.grants.first?.name ?? "").font(HuginFont.geist(13))
                        .foregroundStyle(HuginColor.asche)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                monoLabel("BISHER GEFUNDEN")
                ForEach(activeFindings) { finding in
                    HStack(spacing: 10) {
                        Circle().fill(HuginColor.actor(finding.actor)).frame(width: 7, height: 7)
                        Text(finding.name).font(HuginFont.geist(14))
                        Spacer()
                        monoText(finding.value, size: 13, color: HuginColor.knochen)
                    }
                }
            }

            Spacer()
            Text("Punktfarbe = wer es gelesen hat: Glut lokal, Frost Claude.")
                .font(HuginFont.geist(12)).foregroundStyle(HuginColor.asche)
                .padding(.leading, 12)
                .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 1)
                    .fill(HuginColor.glut).frame(width: 2) }
        }
        .padding(24)
        .background(Color(hex: 0x111216))   // Design §5.3, nicht Basalt
        .overlay(alignment: .leading) { Rectangle().fill(Color(hex: 0x1C1E23)).frame(width: 1) }
    }

    /// Während des Laufs: Live-Spiegel; danach: aus dem gespeicherten Auftrag
    private var activeFindings: [Finding] {
        vm.status == .thinking ? vm.liveFindings : Self.findings(in: vm.messages)
    }
    private var activeRead: String? {
        let source = vm.status == .thinking ? vm.liveCards : vm.messages.flatMap(\.cards)
        return source.last(where: { $0.kind == .read })?.detail.split(separator: "/").last.map(String.init)
    }
}
