import SwiftUI

struct BotengangMenu: View {
    let vm: ChatViewModel
    var onClose: () -> Void

    static func label(for mode: ChatViewModel.Mode) -> String {
        switch mode { case .onDevice: "Im Haus"; case .auto: "Nach Bedarf"; case .claude: "Zu Claude" }
    }
    static func sub(for mode: ChatViewModel.Mode) -> String {
        switch mode { case .onDevice: "nur iPad"; case .auto: "lokal, sonst Claude"; case .claude: "Cloud" }
    }
    static func desc(for mode: ChatViewModel.Mode) -> String {
        switch mode {
        case .onDevice: return "Hugin bleibt bei dir: offline, privat, schnell. Keine Datei verlässt das iPad."
        case .auto: return "Hugin startet lokal und holt Claude nur dazu, wenn ein Auftrag zu schwer wird. Jede Übergabe siehst du in der Flugbahn."
        case .claude: return "Hugin trägt den Auftrag direkt zu Claude. Für schwere Aufträge; nur die nötigen Dateien verlassen das iPad."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            monoLabel("Botengang", color: HuginColor.glut, size: 11)
            Text("Wie weit soll Hugin fliegen?").font(HuginFont.geist(18, .semibold))
            FlugbahnGrafik(mode: vm.mode)
            ForEach([ChatViewModel.Mode.onDevice, .auto, .claude], id: \.rawValue) { m in
                Button { vm.mode = m; onClose() } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Self.label(for: m)).font(HuginFont.geist(15, .semibold))
                        monoText(Self.sub(for: m), size: 11, color: HuginColor.asche)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14)
                        .fill(vm.mode == m ? Color(hex: 0x22211F) : HuginColor.karte)
                        .stroke(vm.mode == m ? HuginColor.glut : HuginColor.border2))
                }
                .buttonStyle(.plain)
            }
            monoText(Self.desc(for: vm.mode), size: 12, color: HuginColor.asche)
                .padding(.top, 12)
                .overlay(alignment: .top) { Divider().overlay(HuginColor.border2) }
        }
        .padding(16)
        .frame(width: 384)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color(hex: 0x131418))
            .stroke(HuginColor.border3))
        .shadow(color: .black.opacity(0.55), radius: 30)
    }
}

/// Flugbahn iPad → Claude (Design §5.2): gepunkteter Bogen, Wisp wandert je Modus
struct FlugbahnGrafik: View {
    let mode: ChatViewModel.Mode
    var body: some View {
        Canvas { ctx, size in
            // Bogen: M36,66 Q176,-14 316,66 skaliert; gestrichelt Asche; durchgezogener
            // Teil Glut (links) → Frost (rechts) je Modus; iPad-Rechteck links, Claude-Kreis rechts;
            // Wisp-Knoten bei (58,54)=Im Haus / (176,26)=Nach Bedarf / (294,54)=Zu Claude
            // (Task-16-Brief konkretisiert: gepunkteter Glut-Bogen + Funken-Endpunkt wie Flugkurve;
            //  iPad-Rechteck/Claude-Kreis/Wisp-Wanderung bleiben als Marken dokumentiert)
            var path = Path()
            path.move(to: CGPoint(x: 2, y: size.height * 0.43))
            path.addCurve(to: CGPoint(x: size.width - 4, y: size.height * 0.49),
                          control1: CGPoint(x: size.width * 0.23, y: -size.height * 0.11),
                          control2: CGPoint(x: size.width * 0.46, y: size.height * 0.89))
            ctx.stroke(path, with: .color(HuginColor.glut.opacity(0.55)),
                       style: StrokeStyle(lineWidth: 1.5, dash: [2, 7], lineCap: .round))
            ctx.fill(Path(ellipseIn: CGRect(x: size.width - 8, y: size.height * 0.49 - 2.5,
                                           width: 5, height: 5)),
                     with: .color(HuginColor.glut.opacity(0.7)))
        }
        .frame(height: 96)
    }
}
