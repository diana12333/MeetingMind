import SwiftUI

struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var showAPIKey = false
    @State private var isSaved = false

    @AppStorage("audioQuality") private var audioQuality = "high"
    @AppStorage("autoAnalyze") private var autoAnalyze = false

    var body: some View {
        Form {
            Section("Claude API Key") {
                HStack {
                    if showAPIKey {
                        TextField("sk-ant-...", text: $apiKey)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                    } else {
                        SecureField("sk-ant-...", text: $apiKey)
                    }

                    Button {
                        showAPIKey.toggle()
                    } label: {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                    }
                }

                Button("Save API Key") {
                    if KeychainService.saveAPIKey(apiKey) {
                        isSaved = true
                    }
                }
                .disabled(apiKey.isEmpty)

                if isSaved {
                    Text("API key saved securely in Keychain")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.successCheck)
                }
            }

            Section("Recording") {
                Picker("Audio Quality", selection: $audioQuality) {
                    Text("Standard").tag("standard")
                    Text("High").tag("high")
                }
            }

            Section("AI Analysis") {
                Toggle("Auto-analyze after transcription", isOn: $autoAnalyze)
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("AI Provider")
                    Spacer()
                    Text("Claude (Anthropic)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            apiKey = KeychainService.getAPIKey() ?? ""
        }
    }
}
