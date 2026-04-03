import CryptoKit
import Foundation
import MailCore

enum GmailMailboxRoleMapper {
    static func role(for labelID: String) -> MailboxSystemRole? {
        switch labelID {
        case "INBOX":
            .inbox
        case "UNREAD":
            .unread
        case "STARRED":
            .starred
        case "SENT":
            .sent
        case "DRAFT":
            .draft
        case "TRASH":
            .trash
        case "SPAM":
            .spam
        case "IMPORTANT":
            .important
        default:
            nil
        }
    }
}

enum GmailBodyExtractor {
    static func extract(from payload: GmailMessage.Payload) -> (plain: String?, html: String?) {
        var plain = decodeBody(payload.body?.data)
        var html = payload.mimeType == "text/html" ? decodeBody(payload.body?.data) : nil

        for part in payload.parts ?? [] {
            let extracted = extract(from: part)
            if plain == nil {
                plain = payload.mimeType == "text/plain" ? decodeBody(payload.body?.data) : extracted.plain
            }
            if html == nil {
                html = extracted.html
            }
        }

        if payload.mimeType == "text/plain" {
            plain = plain ?? decodeBody(payload.body?.data)
        }
        if payload.mimeType == "text/html" {
            html = html ?? decodeBody(payload.body?.data)
        }

        return (plain, html)
    }

    private static func decodeBody(_ value: String?) -> String? {
        guard let value, value.isEmpty == false else { return nil }
        return Data(base64URLEncoded: value).flatMap { String(data: $0, encoding: .utf8) }
    }
}

enum GmailAttachmentExtractor {
    static func extract(from payload: GmailMessage.Payload, messageID: MailMessageID) -> [MailAttachment] {
        var attachments: [MailAttachment] = []
        collectAttachments(from: payload, messageID: messageID, into: &attachments)
        return attachments
    }

    private static func collectAttachments(from part: GmailMessage.Payload, messageID: MailMessageID, into attachments: inout [MailAttachment]) {
        // A part is an attachment if it has a filename and an attachmentId
        if let filename = part.filename, !filename.isEmpty,
           let attachmentId = part.body?.attachmentId, !attachmentId.isEmpty {
            attachments.append(MailAttachment(
                id: attachmentId,
                messageID: messageID,
                filename: filename,
                mimeType: part.mimeType ?? "application/octet-stream",
                size: part.body?.size ?? 0
            ))
        }
        for child in part.parts ?? [] {
            collectAttachments(from: child, messageID: messageID, into: &attachments)
        }
    }
}

enum GmailMIMEBuilder {
    static func makeRawMessage(from draft: OutgoingDraft, fromEmail: String) -> String {
        let toLine = draft.toRecipients.map(\.displayName).joined(separator: ", ")
        let ccLine = draft.ccRecipients.map(\.displayName).joined(separator: ", ")
        let bccLine = draft.bccRecipients.map(\.displayName).joined(separator: ", ")
        let boundary = "=_InboxZeroMail_\(UUID().uuidString)"

        var lines: [String] = [
            "From: \(fromEmail)",
            "To: \(toLine)",
        ]

        if draft.ccRecipients.isEmpty == false {
            lines.append("Cc: \(ccLine)")
        }
        if draft.bccRecipients.isEmpty == false {
            lines.append("Bcc: \(bccLine)")
        }

        lines.append("Subject: \(draft.subject)")
        lines.append("MIME-Version: 1.0")
        lines.append("Content-Type: multipart/alternative; boundary=\"\(boundary)\"")
        lines.append("")
        lines.append("--\(boundary)")
        lines.append("Content-Type: text/plain; charset=utf-8")
        lines.append("")
        lines.append(composedPlainBody(for: draft))
        lines.append("")
        lines.append("--\(boundary)")
        lines.append("Content-Type: text/html; charset=utf-8")
        lines.append("")
        lines.append(composedHTMLBody(for: draft))
        lines.append("")
        lines.append("--\(boundary)--")

        let message = lines.joined(separator: "\r\n")
        return Data(message.utf8).base64URLEncodedString()
    }

    private static func composedPlainBody(for draft: OutgoingDraft) -> String {
        joinedSections(
            draft.plainBody,
            quotedPlainBody(for: draft.quotedReply)
        )
    }

    private static func composedHTMLBody(for draft: OutgoingDraft) -> String {
        let editorBody = normalizedHTMLBody(from: draft.htmlBody, fallbackPlainText: draft.plainBody)
        let quotedBody = quotedHTMLBody(for: draft.quotedReply)
        let combined = joinedSections(editorBody, quotedBody)

        return """
        <html>
        <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; font-size: 14px; color: #1a1c24;">
        \(combined)
        </body>
        </html>
        """
    }

    private static func quotedPlainBody(for quote: DraftQuotedReply?) -> String? {
        guard let quote else { return nil }
        let originalText = quote.plainBody?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard originalText.isEmpty == false else { return nil }

        let quoted = originalText
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { "> \($0)" }
            .joined(separator: "\n")

        return "\(quotedHeaderLine(for: quote))\n\(quoted)"
    }

    private static func quotedHTMLBody(for quote: DraftQuotedReply?) -> String? {
        guard let quote else { return nil }
        let body = quote.htmlBody.flatMap(extractBodyHTML(from:)) ?? quote.plainBody.map(htmlEscapedPlainText(_:))
        guard let body, body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return nil }

        return """
        <div style="margin-top: 18px; color: #5b6375; font-size: 13px;">\(htmlEscaped(quotedHeaderLine(for: quote)))</div>
        <blockquote style="margin: 8px 0 0 0; padding-left: 14px; border-left: 2px solid #d6dbe7;">
        \(body)
        </blockquote>
        """
    }

    private static func quotedHeaderLine(for quote: DraftQuotedReply) -> String {
        var header = "On "
        if let sentAt = quote.sentAt {
            header += sentAt.formatted(.dateTime.year().month().day().hour().minute())
        } else {
            header += "an earlier message"
        }
        header += ", \(quote.sender.displayName) <\(quote.sender.emailAddress)> wrote:"
        return header
    }

    private static func normalizedHTMLBody(from html: String?, fallbackPlainText: String) -> String {
        if let html, html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return extractBodyHTML(from: html) ?? html
        }
        return htmlEscapedPlainText(fallbackPlainText)
    }

    private static func extractBodyHTML(from html: String) -> String? {
        let pattern = "(?is)<body\\b[^>]*>(.*)</body>"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              let bodyRange = Range(match.range(at: 1), in: html) else {
            return nil
        }
        return String(html[bodyRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func htmlEscapedPlainText(_ text: String) -> String {
        htmlEscaped(text)
            .replacingOccurrences(of: "\n", with: "<br>")
    }

    private static func htmlEscaped(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func joinedSections(_ sections: String?...) -> String {
        sections
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: "\n\n")
    }
}

enum GmailDraftMapper {
    static func draft(
        from resource: GmailDraftResponse,
        accountID: MailAccountID,
        mailboxLookup: [String: MailboxRef],
        primaryEmail: String,
        preferredID: UUID? = nil
    ) -> OutgoingDraft {
        let threadID = MailThreadID(accountID: accountID, providerThreadID: resource.message.threadId)
        let message = resource.message.asMailMessage(
            accountID: accountID,
            threadID: threadID,
            mailboxLookup: mailboxLookup,
            primaryEmail: primaryEmail
        )

        return OutgoingDraft(
            id: preferredID ?? stableDraftID(accountID: accountID, providerDraftID: resource.id),
            accountID: accountID,
            providerDraftID: resource.id,
            providerMessageID: resource.message.id,
            replyMode: resource.message.threadId.isEmpty ? .new : .reply,
            threadID: resource.message.threadId.isEmpty ? nil : threadID,
            toRecipients: message.toRecipients,
            ccRecipients: message.ccRecipients,
            bccRecipients: message.bccRecipients,
            subject: message.headers.first(where: { $0.name.caseInsensitiveCompare("Subject") == .orderedSame })?.value ?? "",
            plainBody: message.plainBody ?? "",
            htmlBody: message.htmlBody,
            updatedAt: message.receivedAt ?? message.sentAt ?? .now
        )
    }

    private static func stableDraftID(accountID: MailAccountID, providerDraftID: String) -> UUID {
        let digest = SHA256.hash(data: Data("\(accountID.rawValue):\(providerDraftID)".utf8))
        let bytes = Array(digest.prefix(16))
        let raw = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: raw)
    }
}

enum MailDateParser {
    static func messageDate(from value: String?) -> Date? {
        guard let value else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, d MMM yyyy HH:mm:ss Z"
        if let parsed = formatter.date(from: value) {
            return parsed
        }

        formatter.dateFormat = "d MMM yyyy HH:mm:ss Z"
        return formatter.date(from: value)
    }
}

extension Data {
    init?(base64URLEncoded value: String) {
        var normalized = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let padding = 4 - normalized.count % 4
        if padding < 4 {
            normalized += String(repeating: "=", count: padding)
        }

        self.init(base64Encoded: normalized)
    }

    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

extension MailParticipant {
    init(string value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let open = trimmed.firstIndex(of: "<"),
           let close = trimmed.firstIndex(of: ">"),
           open < close {
            let name = String(trimmed[..<open]).trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
            let email = String(trimmed[trimmed.index(after: open)..<close])
            self.init(name: name.isEmpty ? nil : name, emailAddress: email)
            return
        }

        self.init(name: nil, emailAddress: trimmed)
    }

    static func list(from rawValue: String?) -> [MailParticipant] {
        guard let rawValue, rawValue.isEmpty == false else { return [] }
        return rawValue
            .split(separator: ",")
            .map { MailParticipant(string: String($0)) }
    }
}
