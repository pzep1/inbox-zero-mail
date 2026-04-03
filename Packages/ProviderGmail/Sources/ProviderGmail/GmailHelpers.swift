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
        lines.append("Content-Type: text/plain; charset=utf-8")
        lines.append("")
        lines.append(draft.plainBody)

        let message = lines.joined(separator: "\r\n")
        return Data(message.utf8).base64URLEncodedString()
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
