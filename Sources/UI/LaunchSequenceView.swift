import SwiftUI

/// Start-Sequenz (Design §6 „Bewegung und Timing"): Funke → Stäbe → Lichtspur →
/// Aufflammen → UI-Blende, insgesamt 1,4 s, dann `onFinished()`.
/// Der Canvas-Body rendert nur die aktuelle Phase; die Phasen-Funktion ist static und testbar.
struct LaunchSequenceView: View {
    var reduceMotion: Bool
    var onFinished: () -> Void

    enum LaunchPhase { case funke, staebe, spur, aufflammen, ui }

    @State private var startedAt: Date?

    /// 0–<0,12 Funke · 0,12–<0,42 Stäbe · 0,42–<0,82 Spur · 0,82–<1,0 Aufflammen · ≥1,0 UI.
    /// Grenzen gehören der späteren Phase an (>=). ReduceMotion → immer `.ui`.
    static func phase(at elapsed: Double, reduceMotion: Bool = false) -> LaunchPhase {
        if reduceMotion { return .ui }
        switch elapsed {
        case ..<0.12: return .funke
        case 0.12..<0.42: return .staebe
        case 0.42..<0.82: return .spur
        case 0.82..<1.0: return .aufflammen
        default: return .ui
        }
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                guard !reduceMotion else { return }   // ReduceMotion: sofort .ui, nichts animieren
                let start = startedAt ?? timeline.date
                render(elapsed: timeline.date.timeIntervalSince(start), ctx: ctx, size: size)
            }
        }
        .background(HuginColor.basalt.ignoresSafeArea())
        .onAppear { if startedAt == nil { startedAt = Date() } }
        .task {
            if reduceMotion {
                onFinished()   // ReduceMotion: sofort Phase .ui
            } else {
                try? await Task.sleep(for: .seconds(1.4))   // Design: „1,4 s Sequenz, dann UI"
                if !Task.isCancelled { onFinished() }
            }
        }
    }

    // MARK: - Zeichnen (Design-Koordinatenraum 1024², zentriert eingepasst)

    private func render(elapsed: Double, ctx: GraphicsContext, size: CGSize) {
        let s = min(size.width, size.height) / 1024
        let origin = CGPoint(x: (size.width - 1024 * s) / 2, y: (size.height - 1024 * s) / 2)
        func pt(_ x: Double, _ y: Double) -> CGPoint {
            .init(x: origin.x + x * s, y: origin.y + y * s)
        }
        func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect {
            .init(x: origin.x + x * s, y: origin.y + y * s, width: w * s, height: h * s)
        }

        let phase = Self.phase(at: elapsed)
        let p = progress(of: phase, at: elapsed)

        // UI-Blende via opacity: alles sinkt in der UI-Phase auf transparent,
        // RootView blendet zur normalen UI (onFinished nach 1,4 s).
        let groupOpacity = phase == .ui ? 1 - p : 1
        guard groupOpacity > 0 else { return }
        ctx.opacity = groupOpacity

        // 1. Stäbe: scaleY wachsen von unten im Stäbe-Fenster, linker Stab führt (Design-Frames)
        if phase != .funke {
            let (left, right) = phase == .staebe
                ? (min(1, p * 1.5), max(0, min(1, p * 1.5 - 0.5)))
                : (1.0, 1.0)
            drawBar(at: rect(318, 788 - 552 * left, 72, 552 * left), scale: s, in: ctx)
            drawBar(at: rect(634, 788 - 552 * right, 72, 552 * right), scale: s, in: ctx)
        }

        // 2. Lichtspur: Path.trim 0→1 im Spur-Fenster (danach voll, blendet mit der Gruppe aus)
        if phase != .funke && phase != .staebe {
            var trail = Path()
            trail.move(to: pt(354, 650))
            trail.addLine(to: pt(670, 380))
            let trimmed = trail.trim(from: 0, to: phase == .spur ? p : 1)
            ctx.stroke(trimmed,
                       with: .linearGradient(trailGradient,
                                             startPoint: pt(354, 650), endPoint: pt(670, 380)),
                       style: StrokeStyle(lineWidth: 40 * s, lineCap: .round))
        }

        // 3. Wisp-Kreis + Glow mit Radius je Phase (90 → 110 → 260 → 140, Design-Frames 1–5)
        let w = wisp(phase: phase, p: p)
        drawWisp(at: pt(w.x, w.y), glow: w.glow * s, core: w.core * s, in: ctx)
    }

    /// Fortschritt 0…1 innerhalb des aktuellen Phasen-Fensters.
    private func progress(of phase: LaunchPhase, at elapsed: Double) -> Double {
        let (start, end): (Double, Double)
        switch phase {
        case .funke: (start, end) = (0, 0.12)
        case .staebe: (start, end) = (0.12, 0.42)
        case .spur: (start, end) = (0.42, 0.82)
        case .aufflammen: (start, end) = (0.82, 1.0)
        case .ui: (start, end) = (1.0, 1.4)
        }
        return min(1, max(0, (elapsed - start) / (end - start)))
    }

    /// Position/Glow/Kern des Wisp je Phase (Design-Board „Start-Sequenz"):
    /// Funke am Spur-Start, gleitet in der Spur-Phase zum Stab-Ende, flammt dort auf
    /// (260), gleitet in der UI-Phase ins Eingabefeld (unten Mitte).
    private func wisp(phase: LaunchPhase, p: Double) -> (x: Double, y: Double, glow: Double, core: Double) {
        switch phase {
        case .funke, .staebe: return (354, 650, 90, 12)
        case .spur: return (354 + 316 * p, 650 - 270 * p, 90 + 20 * p, 12 + 4 * p)
        case .aufflammen: return (670, 380, 260, 30)
        case .ui: return (670 - 158 * p, 380 + 520 * p, 260 - 120 * p, 30 - 12 * p)
        }
    }

    private func drawBar(at r: CGRect, scale: CGFloat, in ctx: GraphicsContext) {
        guard r.height > 0.5 else { return }
        ctx.fill(Path(roundedRect: r, cornerRadius: min(36 * scale, r.height / 2)),
                 with: .color(Color(hex: 0x2B2D33)))
    }

    private var trailGradient: Gradient {
        Gradient(stops: [
            .init(color: HuginColor.glut.opacity(0.1), location: 0),
            .init(color: HuginColor.glut.opacity(0.85), location: 0.6),
            .init(color: Color(hex: 0xFFD9A0), location: 1)
        ])
    }

    private func drawWisp(at center: CGPoint, glow: CGFloat, core: CGFloat, in ctx: GraphicsContext) {
        if glow > 0 {
            let gradient = Gradient(stops: [
                .init(color: Color(hex: 0xFFF8EC), location: 0),
                .init(color: Color(hex: 0xFFD08A), location: 0.2),
                .init(color: HuginColor.glut.opacity(0.55), location: 0.45),
                .init(color: HuginColor.glut.opacity(0), location: 1)
            ])
            ctx.fill(Path(ellipseIn: CGRect(x: center.x - glow, y: center.y - glow,
                                            width: glow * 2, height: glow * 2)),
                     with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: glow))
        }
        if core > 0 {
            ctx.fill(Path(ellipseIn: CGRect(x: center.x - core, y: center.y - core,
                                            width: core * 2, height: core * 2)),
                     with: .color(Color(hex: 0xFFF8EC)))
        }
    }
}
