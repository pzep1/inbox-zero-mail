import DesignSystem
import MailCore
import MailFeatures
import SwiftUI

struct FullscreenComposeView: View {
    @Bindable var model: WindowModel
    let draft: OutgoingDraft

    @State private var showCC = false
    @State private var showBCC = false
    @FocusState private var isBodyFocused: Bool

    private var adapter: ComposeDraftAdapter { ComposeDraftAdapter(model: model, fallbackDraft: draft) }
    private var currentDraft: OutgoingDraft { adapter.draft }

    private var title: String {
        switch currentDraft.replyMode {
        case .new: return "Compose"
        case .reply, .replyAll: return "Reply"
        case .forward: return "Forward"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(MailDesignTokens.textPrimary)

                Spacer()

                Button {
                    model.minimizeCompose()
                } label: {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 12))
                        .foregroundStyle(MailDesignTokens.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Minimize")

                Button {
                    model.dismissCompose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundStyle(MailDesignTokens.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(MailDesignTokens.surface)

            Divider()

            // Header fields
            VStack(spacing: 0) {
                // From
                FullscreenComposeFieldRow(label: "From") {
                    Picker("", selection: adapter.binding(\.accountID)) {
                        ForEach(model.accounts) { account in
                            Text(account.primaryEmail).tag(account.id)
                        }
                    }
                    .labelsHidden()
                }

                Divider().padding(.leading, 60)

                // To
                FullscreenComposeFieldRow(label: "To") {
                    HStack {
                        TextField("Recipients", text: adapter.recipientBinding(\.toRecipients))
                            .textFieldStyle(.plain)
                            .foregroundStyle(MailDesignTokens.textPrimary)
                            .accessibilityIdentifier("compose-to")
                        if !showCC || !showBCC {
                            Button {
                                if !showCC { showCC = true }
                                else { showBCC = true }
                            } label: {
                                Text(showCC ? "Bcc" : "Cc/Bcc")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(MailDesignTokens.accent)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if showCC {
                    Divider().padding(.leading, 60)
                    FullscreenComposeFieldRow(label: "Cc") {
                        TextField("Cc recipients", text: adapter.recipientBinding(\.ccRecipients))
                            .textFieldStyle(.plain)
                            .foregroundStyle(MailDesignTokens.textPrimary)
                    }
                }

                if showBCC {
                    Divider().padding(.leading, 60)
                    FullscreenComposeFieldRow(label: "Bcc") {
                        TextField("Bcc recipients", text: adapter.recipientBinding(\.bccRecipients))
                            .textFieldStyle(.plain)
                            .foregroundStyle(MailDesignTokens.textPrimary)
                    }
                }

                Divider()

                ZStack(alignment: .leading) {
                    if currentDraft.subject.isEmpty {
                        Text("Subject")
                            .foregroundStyle(MailDesignTokens.textTertiary)
                            .allowsHitTesting(false)
                    }
                    TextField("", text: adapter.binding(\.subject))
                        .textFieldStyle(.plain)
                        .foregroundStyle(MailDesignTokens.textPrimary)
                        .accessibilityIdentifier("compose-subject")
                }
                .padding(.vertical, 8)
            }
            .padding(.horizontal, 16)

            Divider()

            // Body
            TextEditor(text: adapter.binding(\.plainBody))
                .font(.system(size: 13))
                .foregroundStyle(MailDesignTokens.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .focused($isBodyFocused)
                .accessibilityIdentifier("compose-body")

            Divider()

            // Bottom toolbar
            HStack(spacing: 16) {
                Button {
                    model.sendCompose()
                } label: {
                    HStack(spacing: 4) {
                        Text("Send")
                            .font(.system(size: 13, weight: .semibold))
                        Text("⌘↵")
                            .font(.system(size: 11))
                            .foregroundStyle(MailDesignTokens.textTertiary)
                    }
                    .foregroundStyle(MailDesignTokens.textPrimary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("compose-send")
                .keyboardShortcut(.return, modifiers: [.command])

                Spacer()

                Button {
                    model.dismissCompose()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(MailDesignTokens.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("compose-cancel")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .background(MailDesignTokens.background)
        .onAppear {
            if !currentDraft.ccRecipients.isEmpty { showCC = true }
            if !currentDraft.bccRecipients.isEmpty { showBCC = true }
            isBodyFocused = true
        }
    }
}

// Local field row helper (will be deduplicated in Task 6 when ContentView's version becomes non-private)
private struct FullscreenComposeFieldRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(MailDesignTokens.textTertiary)
                .frame(width: 48, alignment: .trailing)
            content
        }
        .padding(.vertical, 8)
    }
}
