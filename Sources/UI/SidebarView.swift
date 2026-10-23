import SwiftUI

struct SidebarView: View {
    let vm: ChatViewModel
    var onNewOrder: () -> Void
    var onOpenOrder: (UUID) -> Void
    var onSettings: () -> Void
    @State private var showPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            Wortmarke()
            Button(action: onNewOrder) {
                Label("Neuer Auftrag", systemImage: "plus")
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            .padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 12).stroke(HuginColor.border3))

            VStack(alignment: .leading, spacing: 4) {
                monoLabel("Freigaben")
                ForEach(vm.grants) { grant in
                    GrantRow(name: grant.name)   // Ordner-Icon + Name; Zahl folgt in Phase 2 (Dateizahl-Ermittlung ist IO)
                }
                Button {
                    showPicker = true
                } label: {
                    Label("Ordner freigeben", systemImage: "plus")
                        .foregroundStyle(HuginColor.asche)
                }
                .buttonStyle(.plain).frame(minHeight: 44)
            }

            VStack(alignment: .leading, spacing: 4) {
                monoLabel("Munin · Erinnerung")
                ForEach(vm.munin) { order in
                    Button { onOpenOrder(order.id) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(order.title).lineLimit(1)
                            monoText("\(order.actor)", size: 11, color: HuginColor.asche)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10)
                        .fill(order.id == vm.currentOrderID ? HuginColor.schiefer : .clear))
                }
            }
            Spacer()
            Button(action: onSettings) {
                Label("Einstellungen", systemImage: "slider.horizontal.3")
                    .foregroundStyle(HuginColor.asche)
            }
            .buttonStyle(.plain).frame(minHeight: 44)
        }
        .padding(28).padding(.horizontal, -8)   // optisch 20 px wie Design
        .frame(width: 260, alignment: .leading)
        .background(HuginColor.seitenleiste)
        .sheet(isPresented: $showPicker) { FolderPicker { vm.addGrant(url: $0) } }
    }

    struct Wortmarke: View {
        var body: some View {
            HStack(alignment: .top, spacing: 0) {
                Text("hug").font(HuginFont.geist(30, .semibold))
                ZStack {
                    Text("ı").font(HuginFont.geist(30, .semibold))   // punktloses i
                    WispView(state: .ruhe, actor: .local, size: 5).offset(y: 4)
                }
                Text("n").font(HuginFont.geist(30, .semibold))
            }
            .foregroundStyle(HuginColor.knochen)
            .accessibilityLabel("hugin")
        }
    }
}

struct GrantRow: View {
    let name: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder").foregroundStyle(HuginColor.asche)
            Text(name).font(HuginFont.geist(15))
        }
        .frame(minHeight: 44, alignment: .leading)
    }
}
