import SwiftUI

struct ConfirmOverwriteDialog: View {
    let confirmation: ChatViewModel.Confirmation
    let onAllow: () -> Void
    let onDeny: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                WispView(state: .wartet, actor: .local, size: 12)
                monoLabel("WARTET AUF DICH", color: HuginColor.knochen)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("„\(fileName)“ überschreiben?").font(HuginFont.geist(28, .semibold))
                Text("Die Datei gibt es schon. Hugin möchte sie durch die neue Fassung ersetzen.")
                    .font(HuginFont.geist(15)).foregroundStyle(HuginColor.asche)
            }
            DiffView(old: confirmation.request.oldContent, new: confirmation.request.newContent)
                .frame(maxHeight: 220)

            HStack(spacing: 12) {
                Image(systemName: "archivebox").foregroundStyle(HuginColor.glut)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Vorher wird eine Sicherung angelegt").font(HuginFont.geist(14, .medium))
                    monoText("Sicherungen/\(backupStamp)/\(fileName)", size: 11, color: HuginColor.asche)
                }
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(HuginColor.schiefer))

            HStack(spacing: 12) {
                Button("Abbrechen", action: onDeny)
                    .buttonStyle(.plain).frame(minHeight: 60)
                    .padding(.horizontal, 24)
                    .background(Capsule().stroke(HuginColor.border3))
                HoldToConfirmButton(onConfirmed: onAllow)
            }
        }
        .padding(30)
        .frame(width: 620, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 28).fill(HuginColor.dialog).stroke(HuginColor.border2))
        .shadow(color: .black.opacity(0.6), radius: 60)
    }

    private var fileName: String {
        confirmation.request.path.split(separator: "/").last.map(String.init) ?? confirmation.request.path
    }
    private var backupStamp: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HHmm"
        return f.string(from: Date())
    }
}

// Hinweis: der angezeigte Sicherungs-Pfad ist illustrativ; der echte Backup-Pfad
// stammt aus der Sicherungs-Karte des Runners.
