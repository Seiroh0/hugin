import SwiftUI

struct HoldToConfirmButton: View {
    let onConfirmed: () -> Void
    static let holdSeconds: Double = 1.2
    @State private var progress: Double = 0
    @State private var done = false
    @State private var holdTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(HuginColor.glut)
                .frame(width: progressFraction * totalWidth)   // Fortschrittsfüllung
            HStack(spacing: 14) {
                ProgressRing(progress: progress)
                Text(label).font(HuginFont.geist(16, .semibold)).foregroundStyle(done ? HuginColor.glut : HuginColor.basalt)
                Spacer()
                monoText(done ? "✓" : "1,2 s", size: 12, color: HuginColor.basalt.opacity(0.6))
            }
            .padding(.leading, 10).padding(.trailing, 22)
        }
        .frame(height: 60)
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in startHold() }
            .onEnded { _ in endHold() })
    }

    private var progressFraction: Double { done ? 1 : progress }
    private var totalWidth: CGFloat { 400 }   // Implementer: GeometryReader für echte Breite
    private var label: String {
        done ? "Überschrieben · Sicherung angelegt"
             : (progress > 0 ? "Weiter halten …" : "Zum Überschreiben halten")
    }

    private func startHold() {
        guard !done, holdTask == nil else { return }
        holdTask = Task { @MainActor in
            let t0 = Date()
            while !Task.isCancelled {
                progress = min(1, Date().timeIntervalSince(t0) / Self.holdSeconds)
                if progress >= 1 { done = true; onConfirmed(); holdTask = nil; return }
                try? await Task.sleep(for: .milliseconds(30))
            }
        }
    }
    private func endHold() {
        holdTask?.cancel(); holdTask = nil
        if !done { withAnimation(.easeOut(duration: 0.24)) { progress = 0 } }
    }
}

/// Fortschrittsring 42 px (dasharray 106.81 ≈ 2π · 17)
struct ProgressRing: View {
    let progress: Double
    var body: some View {
        ZStack {
            Circle().trim(from: 0, to: progress)
                .stroke(HuginColor.basalt, style: StrokeStyle(lineWidth: 3))
                .frame(width: 42, height: 42)
            WispView(state: .wartet, actor: .local, size: 12)
        }
    }
}
