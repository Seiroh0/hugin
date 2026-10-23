import SwiftUI

struct SettingsView: View {
    @Bindable var vm: ChatViewModel
    @State private var keyInput = ""
    @State private var showPicker = false

    var body: some View {
        Form {
            Section("Botengang") {
                Picker("Modus", selection: $vm.mode) {
                    Text("Im Haus").tag(ChatViewModel.Mode.onDevice)
                    Text("Nach Bedarf").tag(ChatViewModel.Mode.auto)
                    Text("Zu Claude").tag(ChatViewModel.Mode.claude)
                }
            }
            Section("Freigegebene Ordner") {
                ForEach(vm.grants) { Text($0.name).font(HuginFont.geist(15)) }
                Button("Ordner freigeben…") { showPicker = true }
            }
            Section("Claude API-Key") {
                SecureField("sk-ant-…", text: $keyInput)
                Button("Speichern") { vm.saveKey(keyInput) }
                Text("Der Key bleibt nur im iPad-Schlüsselbund (Keychain).")
                    .font(HuginFont.geist(12)).foregroundStyle(HuginColor.asche)
            }
            Section {
                Text("Kostenloser Apple-Account: App läuft 7 Tage, dann neu per Sideloadly installieren.")
                    .font(HuginFont.geist(12)).foregroundStyle(HuginColor.asche)
            }
        }
        .scrollContentBackground(.hidden)
        .background(HuginColor.basalt)
        .navigationTitle("Einstellungen")
        .sheet(isPresented: $showPicker) {
            FolderPicker { vm.addGrant(url: $0) }
        }
    }
}
