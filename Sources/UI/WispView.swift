import SwiftUI

enum WispState { case ruhe, denkt, fliegt, uebergabe, wartet, stockt, fertig }

struct WispView: View {
    let state: WispState
    let actor: Actor
    var size: CGFloat = 12
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static func color(for state: WispState, actor: Actor) -> Color {
        switch state {
        case .wartet: return HuginColor.knochen
        case .stockt: return HuginColor.rost
        case .uebergabe: return HuginColor.frost
        default: return actor == .claude ? HuginColor.frost : HuginColor.glut
        }
    }

    var body: some View {
        let core = Self.color(for: state, actor: actor)
        ZStack {
            Circle().fill(core).frame(width: size, height: size)
            Circle().fill(core.opacity(0.42)).frame(width: size * 3, height: size * 3)
                .blur(radius: size * 0.5)
            switch state {
            case .denkt: sparkOrbit
            case .wartet: ripples
            default: EmptyView()
            }
        }
        .modifier(WispMotion(state: state, reduce: reduceMotion))
        .accessibilityHidden(true)
    }

    @ViewBuilder private var sparkOrbit: some View {
        if !reduceMotion { SparkOrbit(size: size) }
    }

    @ViewBuilder private var ripples: some View {
        if !reduceMotion {
            Ripple(size: size, delay: 0)
            Ripple(size: size, delay: 0.8)
        }
    }
}

/// Umlauf-Funke (denkt): kleiner Kreis auf rotierendem Container – linear 1,4 s ∞ (Design §3)
private struct SparkOrbit: View {
    let size: CGFloat
    @State private var angle: Double = 0

    var body: some View {
        Circle().fill(HuginColor.knochen)
            .frame(width: size * 0.45, height: size * 0.45)
            .offset(y: -size * 1.2)                          // Umlaufradius 1,2 × size
            .frame(width: size * 2.4, height: size * 2.4)     // Orbit-Container, im ZStack zentriert
            .rotationEffect(.degrees(angle))
            .animation(.linear(duration: 1.4).repeatForever(autoreverses: false), value: angle)
            .onAppear { angle = 360 }
    }
}

/// Ripple-Ring (wartet): Knochen-Stroke 0,7, Skalierung 0,6 → 3,4, 1,6 s easeOut ∞,
/// zweiter Ring um 0,8 s versetzt (Design §3)
private struct Ripple: View {
    let size: CGFloat
    let delay: Double
    @State private var expand = false

    var body: some View {
        Circle().stroke(HuginColor.knochen.opacity(0.7), lineWidth: 1.5)
            .frame(width: size, height: size)
            .scaleEffect(expand ? 3.4 : 0.6)
            .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false).delay(delay), value: expand)
            .onAppear { expand = true }
    }
}

private struct WispMotion: ViewModifier {
    let state: WispState
    let reduce: Bool
    @State private var pulse = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(pulse ? 1.06 : 0.88)   // Atmen: 0,88–1,06 (Design §3)
            .animation(breathing, value: pulse)
            .onAppear { pulse.toggle() }         // startet den Atem-Zyklus
    }

    private var breathing: Animation? {
        guard !reduce else { return nil }        // ReduceMotion: nur Farb-Blend, keine Bewegung
        switch state {
        case .ruhe, .wartet: return HuginMotion.atmen                       // 4,2 s ∞
        case .denkt: return .easeInOut(duration: 1.1).repeatForever(autoreverses: true)
        case .stockt: return .linear(duration: 2.2).repeatForever(autoreverses: true)
        case .fertig: return HuginMotion.einsinken                          // 700 ms, einmalig
        default: return nil    // fliegt/uebergabe: Bewegung sitzt in Stage-Logik/Übergang
        }
    }
}
