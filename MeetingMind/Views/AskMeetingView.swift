import SwiftUI

struct AskMeetingView: View {
    @Bindable var meeting: Meeting
    let claudeService: ClaudeAPIService?

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""

    private let suggestedQuestions = [
        "What were the key decisions?",
        "Summarize the action items",
        "What topics were discussed?",
        "Draft a follow-up email"
    ]

    var body: some View {
        VStack(spacing: 0) {
            messageList
            chatInputBar
        }
        .onAppear {
            messages = meeting.chatHistory
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Theme.spacing12) {
                    if messages.isEmpty {
                        emptyState
                    }

                    ForEach(messages) { message in
                        if message.isUser {
                            UserMessageBubble(text: message.content)
                        } else {
                            AIMessageBubble(text: message.content)
                        }
                    }

                    if isLoading {
                        typingIndicator
                    }

                    if !messages.isEmpty {
                        suggestedFollowUps
                    }

                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) {
                withAnimation {
                    proxy.scrollTo("bottom")
                }
            }
            .onChange(of: isLoading) {
                if isLoading {
                    withAnimation {
                        proxy.scrollTo("bottom")
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Theme.spacing16) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(Theme.teal500)

            Text("Ask about this meeting")
                .font(Theme.headlineFont)

            Text("Get answers, summaries, or draft follow-ups based on the transcript.")
                .font(Theme.captionFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            SuggestedQuestionsView(questions: suggestedQuestions) { question in
                sendMessage(question)
            }
        }
        .padding(.vertical, Theme.spacing40)
    }

    // MARK: - Suggested Follow-ups

    private var suggestedFollowUps: some View {
        SuggestedQuestionsView(
            questions: ["Tell me more", "What else was discussed?", "Any concerns raised?"]
        ) { question in
            sendMessage(question)
        }
        .padding(.top, Theme.spacing8)
    }

    // MARK: - Typing Indicator

    private var typingIndicator: some View {
        HStack {
            HStack(spacing: Theme.spacing4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Theme.teal500)
                        .frame(width: 6, height: 6)
                        .opacity(0.6)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: isLoading
                        )
                }
            }
            .padding(.horizontal, Theme.spacing16)
            .padding(.vertical, Theme.spacing12)
            .background(Theme.surfaceTeal, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))

            Spacer()
        }
    }

    // MARK: - Chat Input Bar

    private var chatInputBar: some View {
        HStack(spacing: Theme.spacing8) {
            TextField("Ask about this meeting...", text: $inputText)
                .font(Theme.bodyFont)
                .textFieldStyle(.plain)
                .padding(.horizontal, Theme.spacing12)
                .padding(.vertical, Theme.spacing8)
                .background(Color(UIColor.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 20))
                .onSubmit { sendCurrentMessage() }

            Button(action: sendCurrentMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Theme.inactiveControl : Theme.teal600)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.horizontal)
        .padding(.vertical, Theme.spacing8)
        .background(.bar)
    }

    // MARK: - Actions

    private func sendCurrentMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        sendMessage(text)
    }

    private func sendMessage(_ text: String) {
        let userMessage = ChatMessage(role: "user", content: text)
        messages.append(userMessage)
        meeting.chatHistory = messages

        guard let claudeService else {
            let errorMsg = ChatMessage(role: "assistant", content: "AI service is not available. Please try again later.")
            messages.append(errorMsg)
            meeting.chatHistory = messages
            return
        }

        isLoading = true

        Task {
            do {
                let response = try await claudeService.chatWithMeeting(
                    transcript: meeting.transcriptText,
                    history: Array(messages.dropLast()),
                    userMessage: text
                )

                let assistantMessage = ChatMessage(role: "assistant", content: response)
                messages.append(assistantMessage)
                meeting.chatHistory = messages
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }
}

// MARK: - Message Bubbles

struct UserMessageBubble: View {
    let text: String

    var body: some View {
        HStack {
            Spacer(minLength: 60)
            Text(text)
                .font(Theme.bodyFont)
                .foregroundStyle(.white)
                .padding(.horizontal, Theme.spacing16)
                .padding(.vertical, Theme.spacing12)
                .background(Theme.teal600, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
        }
        .accessibilityLabel("You said: \(text)")
    }
}

struct AIMessageBubble: View {
    let text: String

    var body: some View {
        HStack {
            Text(text)
                .font(Theme.bodyFont)
                .foregroundStyle(.primary)
                .padding(.horizontal, Theme.spacing16)
                .padding(.vertical, Theme.spacing12)
                .background(Theme.surfaceTeal, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
            Spacer(minLength: 60)
        }
        .accessibilityLabel("MeetingMind said: \(text)")
    }
}

// MARK: - Suggested Questions

struct SuggestedQuestionsView: View {
    let questions: [String]
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.spacing8) {
                ForEach(questions, id: \.self) { question in
                    Button {
                        onSelect(question)
                    } label: {
                        Text(question)
                            .font(Theme.captionBoldFont)
                            .foregroundStyle(Theme.teal600)
                            .padding(.horizontal, Theme.pillPaddingH)
                            .padding(.vertical, Theme.pillPaddingV)
                            .background(Theme.surfaceTeal, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
