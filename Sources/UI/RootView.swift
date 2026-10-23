import SwiftUI

struct RootView: View {
    @State private var vm: ChatViewModel?
    @State private var showSettings = false
    @State private var launchDone = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let vm {
                if launchDone || reduceMotion { content(vm) } else {
                    LaunchSequenceView(reduceMotion: reduceMotion) { launchDone = true }
                }
            } else {
                HuginColor.basalt.ignoresSafeArea()
            }
            if let conf = vm?.pendingConfirmation {
                Color.black.opacity(0.7).ignoresSafeArea()
                ConfirmOverwriteDialog(confirmation: conf,
                                       onAllow: { vm?.resolveConfirmation(true) },
                                       onDeny: { vm?.resolveConfirmation(false) })
            }
        }
        .preferredColorScheme(.dark)
        .task {
            if vm == nil { vm = ChatViewModel(store: try? HuginStore()); vm?.load() }
        }
    }

    @ViewBuilder private func content(_ vm: ChatViewModel) -> some View {
        HStack(spacing: 0) {
            SidebarView(vm: vm,
                        onNewOrder: { vm.closeOrder() },
                        onOpenOrder: { vm.open(orderID: $0) },
                        onSettings: { showSettings = true })
            Divider().overlay(HuginColor.seitenleiste)
            if vm.currentOrderID == nil {
                StartView(vm: vm).frame(maxWidth: .infinity)
            } else {
                OrderView(vm: vm, onBack: { vm.closeOrder() })
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView(vm: vm) }
        .background(HuginColor.basalt)
    }
}
