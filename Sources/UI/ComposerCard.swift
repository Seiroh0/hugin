import SwiftUI

struct ComposerCard: View {
    @Bindable var vm: ChatViewModel
    @Binding var menuOpen: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Auftrag beschreiben …", text: $vm.draft, axis: .vertical)
                .font(HuginFont.geist(22))
                .lineLimit(1...4)
            HStack(spacing: 8) {
                Button { menuOpen.toggle() } label: {
                    HStack(spacing: 10) {
                        WispView(state: .ruhe, actor: vm.mode == .claude ? .claude : .local, size: 12)
                        Text(BotengangMenu.label(for: vm.mode)).font(HuginFont.geist(15, .medium))
                        Image(systemName: "chevron.down").font(.footnote).foregroundStyle(HuginColor.asche)
                    }
                    .padding(.horizontal, 14).frame(minHeight: 44)
                    .background(Capsule().fill(HuginColor.schiefer).stroke(HuginColor.border2))
                }
                .buttonStyle(.plain)
                Label("Alle Freigaben", systemImage: "folder")
                    .font(HuginFont.geist(14)).foregroundStyle(HuginColor.asche)
                    .padding(.horizontal, 14).frame(minHeight: 44)
                    .background(Capsule().stroke(HuginColor.border2))
                Spacer()
                Button { submit() } label: {
                    Image(systemName: "arrow.up").font(.system(size: 20, weight: .bold))
                        .foregroundStyle(HuginColor.basalt)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(HuginColor.knochen))
                }
                .disabled(vm.draft.isEmpty || vm.status == .thinking)
            }
        }
        .padding(18)
        .background(UnevenRoundedRectangle(topLeadingRadius: 26, bottomLeadingRadius: 6,
                                           bottomTrailingRadius: 26, topTrailingRadius: 26, style: .continuous)
            .fill(HuginColor.composer).stroke(HuginColor.border3, lineWidth: 1))
        .overlay(alignment: .bottomLeading) {
            if menuOpen { BotengangMenu(vm: vm) { menuOpen = false } }
        }
    }

    private func submit() {
        let text = vm.draft; vm.draft = ""; vm.run(text)
    }
}
