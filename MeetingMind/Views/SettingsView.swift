import SwiftUI

struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var showAPIKey = false
    @State private var isSaved = false

    @AppStorage("audioQuality") private var audioQuality = "high"
    @AppStorage("autoAnalyze") private var autoAnalyze = false

    @AppStorage("slackWebhookURL") private var slackWebhookURL = ""
    @AppStorage("teamsWebhookURL") private var teamsWebhookURL = ""
    @State private var slackTestResult: String?
    @State private var teamsTestResult: String?
    @State private var isTestingSlack = false
    @State private var isTestingTeams = false

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

            Section {
                TextField("Webhook URL", text: $slackWebhookURL)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Button {
                    testSlackConnection()
                } label: {
                    HStack {
                        Text("Test Connection")
                        if isTestingSlack {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(slackWebhookURL.isEmpty || isTestingSlack)

                if let result = slackTestResult {
                    Text(result)
                        .font(Theme.captionFont)
                        .foregroundStyle(result.contains("Success") ? Theme.successCheck : Theme.statusFailed)
                }
            } header: {
                Label("Slack", systemImage: "number")
            } footer: {
                Text("Paste your Slack Incoming Webhook URL to share meeting summaries to a channel.")
            }

            Section {
                TextField("Webhook URL", text: $teamsWebhookURL)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Button {
                    testTeamsConnection()
                } label: {
                    HStack {
                        Text("Test Connection")
                        if isTestingTeams {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(teamsWebhookURL.isEmpty || isTestingTeams)

                if let result = teamsTestResult {
                    Text(result)
                        .font(Theme.captionFont)
                        .foregroundStyle(result.contains("Success") ? Theme.successCheck : Theme.statusFailed)
                }
            } header: {
                Label("Microsoft Teams", systemImage: "person.3")
            } footer: {
                Text("Paste your Teams Incoming Webhook URL to share meeting summaries to a channel.")
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

    private func testSlackConnection() {
        isTestingSlack = true
        slackTestResult = nil
        Task { @MainActor in
            defer { isTestingSlack = false }
            do {
                let service = SlackService()
                try await service.testConnection()
                slackTestResult = "Success! Test message sent."
            } catch {
                slackTestResult = error.localizedDescription
            }
        }
    }

    private func testTeamsConnection() {
        isTestingTeams = true
        teamsTestResult = nil
        Task { @MainActor in
            defer { isTestingTeams = false }
            do {
                let service = TeamsService()
                try await service.testConnection()
                teamsTestResult = "Success! Test message sent."
            } catch {
                teamsTestResult = error.localizedDescription
            }
        }
    }
}
