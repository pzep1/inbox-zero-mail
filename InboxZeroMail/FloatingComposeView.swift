import DesignSystem
import MailCore
import MailFeatures
import SwiftUI

struct ComposeDraftAdapter {
    let model: WindowModel
    let fallbackDraft: OutgoingDraft

    var draft: OutgoingDraft {
        model.composeDraft ?? fallbackDraft
    }

    func binding<T>(_ keyPath: WritableKeyPath<OutgoingDraft, T>) -> Binding<T> {
        Binding(
            get: { draft[keyPath: keyPath] },
            set: { value in
                guard var updated = model.composeDraft else { return }
                updated[keyPath: keyPath] = value
                model.updateCompose(updated)
            }
        )
    }

    func recipientBinding(_ keyPath: WritableKeyPath<OutgoingDraft, [MailParticipant]>) -> Binding<String> {
        Binding(
            get: { draft[keyPath: keyPath].map(\.emailAddress).joined(separator: ", ") },
            set: { value in
                guard var updated = model.composeDraft else { return }
                updated[keyPath: keyPath] = Self.participants(from: value)
                model.updateCompose(updated)
            }
        )
    }

    private static func participants(from value: String) -> [MailParticipant] {
        value
            .split(separator: ",")
            .map { MailParticipant(emailAddress: String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
    }
}

struct FloatingComposeView: View {
    @Bindable var model: WindowModel
    let draft: OutgoingDraft

    @State private var showCC = false
    @State private var showBCC = false
    @FocusState private var focusedField: ComposeField?

    private enum ComposeField: Hashable {
        case to, cc, bcc, subject, body
    }

    private var adapter: ComposeDraftAdapter { ComposeDraftAdapter(model: model, fallbackDraft: draft) }
    private var currentDraft: OutgoingDraft { adapter.draft }

    private var title: String {
        switch currentDraft.replyMode {
        case .new: return "New Message"
        case .reply, .replyAll: return "Reply"
        case .forward: return "Forward"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MailDesignTokens.textPrimary)
                    .lineLimit(1)

                Spacer()

                Button {
                    model.expandCompose()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11))
                        .foregroundStyle(MailDesignTokens.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Fullscreen")

                Button {
                    model.dismissCompose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11))
                        .foregroundStyle(MailDesignTokens.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(MailDesignTokens.surfaceMuted)

            Divider()

            // Compose fields
            VStack(spacing: 0) {
                // To
                HStack(spacing: 8) {
                    Text("To")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(MailDesignTokens.textTertiary)
                        .frame(width: 40, alignment: .trailing)
                    TextField("Recipients", text: adapter.recipientBinding(\.toRecipients))
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(MailDesignTokens.textPrimary)
                        .focused($focusedField, equals: .to)
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
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                if showCC {
                    Divider().padding(.leading, 60)
                    HStack(spacing: 8) {
                        Text("Cc")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(MailDesignTokens.textTertiary)
                            .frame(width: 40, alignment: .trailing)
                        TextField("Cc", text: adapter.recipientBinding(\.ccRecipients))
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .foregroundStyle(MailDesignTokens.textPrimary)
                            .focused($focusedField, equals: .cc)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }

                if showBCC {
                    Divider().padding(.leading, 60)
                    HStack(spacing: 8) {
                        Text("Bcc")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(MailDesignTokens.textTertiary)
                            .frame(width: 40, alignment: .trailing)
                        TextField("Bcc", text: adapter.recipientBinding(\.bccRecipients))
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .foregroundStyle(MailDesignTokens.textPrimary)
                            .focused($focusedField, equals: .bcc)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }

                Divider()

                // Subject
                ZStack(alignment: .leading) {
                    if currentDraft.subject.isEmpty {
                        Text("Subject")
                            .font(.system(size: 13))
                            .foregroundStyle(MailDesignTokens.textTertiary)
                            .allowsHitTesting(false)
                    }
                    TextField("", text: adapter.binding(\.subject))
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(MailDesignTokens.textPrimary)
                        .focused($focusedField, equals: .subject)
                        .accessibilityIdentifier("compose-subject")
                }
                    .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            Divider()

            // Body
            TextEditor(text: adapter.binding(\.plainBody))
                .font(.system(size: 13))
                .foregroundStyle(MailDesignTokens.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .focused($focusedField, equals: .body)
                .accessibilityIdentifier("compose-body")

            Divider()

            // Bottom toolbar
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
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 480)
        .frame(minHeight: 360)
        .background(MailDesignTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(MailDesignTokens.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
        .onAppear {
            if !currentDraft.ccRecipients.isEmpty { showCC = true }
            if !currentDraft.bccRecipients.isEmpty { showBCC = true }
            // Focus the appropriate field
            if currentDraft.toRecipients.isEmpty {
                focusedField = .to
            } else {
                focusedField = .body
            }
        }
    }
}
