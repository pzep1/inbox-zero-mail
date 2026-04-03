import DesignSystem
import MailCore
import MailFeatures
import SwiftUI

struct InlineComposeView: View {
    @Bindable var model: WindowModel
    let draft: OutgoingDraft

    @FocusState private var isBodyFocused: Bool

    private var adapter: ComposeDraftAdapter { ComposeDraftAdapter(model: model, fallbackDraft: draft) }
    private var currentDraft: OutgoingDraft { adapter.draft }

    private var recipientSummary: String {
        let names = currentDraft.toRecipients.map(\.displayName)
        if names.isEmpty { return "..." }
        return names.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 0) {
                // Header: "Draft to [recipients]"
                HStack {
                    HStack(spacing: 6) {
                        Text("Draft")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(red: 0.3, green: 0.7, blue: 0.4))
                        Text("to \(recipientSummary)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(MailDesignTokens.textPrimary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Pop-out button
                    Button {
                        model.popOutCompose()
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 11))
                            .foregroundStyle(MailDesignTokens.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Pop out (⌘⇧P)")

                    // Close button
                    Button {
                        model.dismissCompose()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11))
                            .foregroundStyle(MailDesignTokens.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Discard")
                }
                .padding(.bottom, 8)

                // Body editor
                TextEditor(text: adapter.binding(\.plainBody))
                    .font(.system(size: 13))
                    .foregroundStyle(MailDesignTokens.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120, maxHeight: 300)
                    .focused($isBodyFocused)
                    .accessibilityIdentifier("compose-body")

                Divider()
                    .padding(.vertical, 8)

                // Toolbar
                HStack(spacing: 16) {
                    Button {
                        model.sendCompose()
                    } label: {
                        Text("Send")
                            .font(.system(size: 13, weight: .semibold))
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
                            .font(.system(size: 12))
                            .foregroundStyle(MailDesignTokens.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("compose-cancel")
                    .help("Discard draft")
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(MailDesignTokens.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(MailDesignTokens.border, lineWidth: 1)
            )
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .onAppear {
            isBodyFocused = true
        }
    }
}
