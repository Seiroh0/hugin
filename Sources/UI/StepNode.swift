import SwiftUI

struct StepNode: View {
    let card: ActionCard
    var isRunning: Bool = false

    static func label(for kind: CardKind) -> String {
        switch kind {
        case .list: "AUFLISTEN"; case .search: "SUCHEN"; case .read: "LESEN"
        case .write: "SCHREIBEN"; case .rename: "UMBENENNEN"; case .move: "VERSCHIEBEN"
        case .handover: "ÜBERGABE"; case .backup: "SICHERUNG"
        case .error: "FEHLER"; case .hint: "HINWEIS"
        }
    }

    static func formatDuration(_ ms: Int?) -> String {
        guard let ms else { return "" }
        if ms < 60_000 {
            // Floor auf Zehntelsekunden – 59_999 ms bleibt „59,9 s" (kein Rundungs-Grenzbruch)
            let tenths = Int(floor(Double(ms) / 100.0))
            return String(format: "%.1f", Double(tenths) / 10)
                .replacingOccurrences(of: ".", with: ",") + " s"
        }
        return String(format: "%d:%02d", ms / 60_000, (ms % 60_000) / 1000)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Knoten: Kreis (Diamant bei Übergabe), Connector-Linie nach unten in Akteur-Farbe
            VStack(spacing: 6) {
                if isRunning {
                    WispView(state: .denkt, actor: card.actor ?? .local, size: 18)
                } else if card.kind == .handover {
                    RoundedRectangle(cornerRadius: 2).fill(HuginColor.glut)
                        .frame(width: 12, height: 12).rotationEffect(.degrees(45))
                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(HuginColor.frost, lineWidth: 2))
                } else {
                    Circle().fill(nodeColor).frame(width: 14, height: 14)
                        .overlay(Circle().stroke(nodeColor.opacity(0.8), lineWidth: 2))
                }
                Rectangle().fill(connectorColor).frame(width: 2).frame(maxHeight: .infinity)
            }
            .frame(width: 40)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                monoText(Self.label(for: card.kind), size: 11, color: labelColor)
                    .frame(width: 92, alignment: .leading)
                Text(card.title).font(HuginFont.geist(15)).lineLimit(2)
                Spacer()
                monoText(isRunning ? "läuft" : Self.formatDuration(card.durationMS),
                         size: 11, color: isRunning ? HuginColor.frost : HuginColor.asche)
            }
        }
    }

    private var nodeColor: Color {
        card.kind == .error ? HuginColor.rost : HuginColor.actor(card.actor)
    }
    private var connectorColor: Color { HuginColor.actor(card.actor).opacity(0.42) }
    private var labelColor: Color {
        card.kind == .error ? HuginColor.rost : HuginColor.actor(card.actor)
    }
}
