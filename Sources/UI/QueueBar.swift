import SwiftUI

struct QueueBar: View {
    let vm: ChatViewModel
    @State private var queued = ""

    var body: some View {
        HStack(spacing: 14) {
            WispView(state: .ruhe, actor: vm.running?.actor ?? .local, size: 10)
            TextField("Nächsten Auftrag schon vormerken …", text: $queued)
                .font(HuginFont.geist(19))
                .onSubmit { vm.queueDraft(queued); queued = "" }
            Button {
                vm.queueDraft(queued); queued = ""
            } label: {
                Image(systemName: "arrow.up").foregroundStyle(HuginColor.basalt)
                    .frame(width: 44, height: 44).background(Circle().fill(HuginColor.knochen))
            }
            .disabled(queued.isEmpty)
        }
        .padding(.horizontal, 20)
        .frame(minHeight: 60)
        .background(RoundedRectangle(cornerRadius: 20).fill(HuginColor.composer).stroke(HuginColor.border2))
    }
}
