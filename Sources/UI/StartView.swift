import SwiftUI

struct StartView: View {
    let vm: ChatViewModel
    @State private var menuOpen = false

    static let vorschlaege = [
        "Fasse meine Notizen dieser Woche zusammen",
        "Finde alle PDFs ohne Datum im Dateinamen",
        "Erstelle eine Literaturliste aus meinen Freigaben"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WispView(state: .ruhe, actor: .local, size: 26)
                .padding(.bottom, 34).padding(.leading, 8)
            heading()
            monoText("Ich arbeite nur in deinen Freigaben. Gelöscht wird nichts.", size: 13,
                     color: HuginColor.asche)
                .padding(.leading, 14)
                .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 1)
                    .fill(HuginColor.glut).frame(width: 2) }
                .padding(.vertical, 18)

            ComposerCard(vm: vm, menuOpen: $menuOpen)

            VStack(alignment: .leading, spacing: 6) {
                monoLabel("Vorschläge", color: HuginColor.glut)
                ForEach(Self.vorschlaege, id: \.self) { v in
                    Button { vm.run(v) } label: {
                        HStack { Image(systemName: "arrow.right").foregroundStyle(HuginColor.glut); Text(v) }
                            .font(HuginFont.geist(19))
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: 48, alignment: .leading)
                }
                Divider().overlay(HuginColor.border2).frame(height: 1)
            }
            .padding(.top, 34)
            Spacer()
        }
        .padding(36)
        .frame(maxWidth: 640, alignment: .leading)
        .overlay(alignment: .topLeading) { Flugkurve() }   // gepunktete SVG-Flugkurve (Design §5.2)
    }

    @ViewBuilder private func heading() -> some View {
        (Text("Was soll ich für dich ")
         + Text("erledigen").foregroundColor(HuginColor.glutHighlight)
         + Text("?"))
            .font(HuginFont.geist(56))
    }
}

/// Gepunktete Flugkurve über dem Start (Design §5.2) mit Funken-Endpunkt
struct Flugkurve: View {
    var body: some View {
        Canvas { ctx, size in
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
        .frame(width: 260, height: 70)
        .allowsHitTesting(false)
    }
}
