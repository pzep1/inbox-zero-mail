import Foundation
import MailCore

enum OutlookSystemRoleMapper {
    static func role(for wellKnownName: String?) -> MailboxSystemRole? {
        switch wellKnownName?.lowercased() {
        case "inbox":
            .inbox
        case "drafts":
            .draft
        case "sentitems":
            .sent
        case "archive":
            .archive
        case "deleteditems":
            .trash
        default:
            nil
        }
    }
}

enum OutlookMapper {
    static func threadDetail(
        accountID: MailAccountID,
        conversationID: String,
        messages: [OutlookMessage],
        mailboxLookup: [String: MailboxRef],
        primaryEmail: String
    ) -> MailThreadDetail? {
        guard messages.isEmpty == false else { return nil }

        let threadID = MailThreadID(accountID: accountID, providerThreadID: conversationID)
        let mappedMessages = messages.map { message -> MailMessage in
            let categoryRefs = (message.categories ?? []).compactMap { mailboxLookup[$0] }
            let folderRef = message.parentFolderId.flatMap { mailboxLookup[$0] }
            let mailboxes = [folderRef].compactMap { $0 } + categoryRefs
            let headers = (message.internetMessageHeaders ?? []).map { MessageHeader(name: $0.name, value: $0.value) }
            let sender = message.from.map { MailParticipant(name: $0.emailAddress.name, emailAddress: $0.emailAddress.address) } ?? .init(emailAddress: primaryEmail)
            let bodyText = message.body?.contentType.lowercased() == "html" ? nil : message.body?.content
            let bodyHTML = message.body?.contentType.lowercased() == "html" ? message.body?.content : nil
            let receivedAt = message.receivedDateTime ?? message.sentDateTime

            return MailMessage(
                id: MailMessageID(accountID: accountID, providerMessageID: message.id),
                threadID: threadID,
                accountID: accountID,
                providerMessageID: message.id,
                sender: sender,
                toRecipients: mapRecipients(message.toRecipients),
                ccRecipients: mapRecipients(message.ccRecipients),
                bccRecipients: mapRecipients(message.bccRecipients),
                sentAt: message.sentDateTime,
                receivedAt: receivedAt,
                snippet: message.bodyPreview ?? "",
                plainBody: bodyText,
                htmlBody: bodyHTML,
                bodyCacheState: bodyText == nil && bodyHTML == nil ? .missing : .hot,
                headers: headers,
                mailboxRefs: mailboxes,
                isRead: message.isRead ?? true,
                isOutgoing: sender.emailAddress.caseInsensitiveCompare(primaryEmail) == .orderedSame
            )
        }.sorted { ($0.receivedAt ?? .distantPast) < ($1.receivedAt ?? .distantPast) }

        let newestMessage = mappedMessages.last
        let participants = Array(NSOrderedSet(array: mappedMessages.map(\.sender.displayName))) as? [String] ?? []
        let subject = newestMessage?.headers.first(where: { $0.name.caseInsensitiveCompare("Subject") == .orderedSame })?.value ?? messages.last?.subject ?? "(No subject)"
        let mailboxRefs = Array(Set(mappedMessages.flatMap(\.mailboxRefs))).sorted { $0.displayName < $1.displayName }
        let hasUnread = mappedMessages.contains(where: { !$0.isRead })
        let hasFollowUpCategory = mappedMessages.contains(where: { $0.mailboxRefs.contains(where: { $0.kind == .category && $0.displayName.localizedCaseInsensitiveContains("follow") }) })
        let hasFlaggedMessage = messages.contains(where: { $0.flag?.flagStatus?.localizedCaseInsensitiveCompare("flagged") == .orderedSame })
            || mappedMessages.contains(where: { $0.headers.contains(where: { $0.name == "X-Flag-Status" && $0.value == "flagged" }) })
        let isStarred = hasFollowUpCategory || hasFlaggedMessage
        let isInInbox = mappedMessages.contains(where: { $0.mailboxRefs.contains(where: { $0.systemRole == .inbox }) })

        let thread = MailThread(
            id: threadID,
            accountID: accountID,
            providerThreadID: conversationID,
            subject: subject,
            participantSummary: participants.prefix(2).joined(separator: ", "),
            snippet: newestMessage?.snippet ?? "",
            lastActivityAt: newestMessage?.receivedAt ?? newestMessage?.sentAt ?? .distantPast,
            hasUnread: hasUnread,
            isStarred: isStarred,
            isInInbox: isInInbox,
            mailboxRefs: mailboxRefs,
            latestMessageID: newestMessage?.id,
            syncRevision: newestMessage?.id.rawValue ?? conversationID
        )

        return MailThreadDetail(thread: thread, messages: mappedMessages)
    }

    private static func mapRecipients(_ recipients: [OutlookMessage.RecipientList]?) -> [MailParticipant] {
        (recipients ?? []).map { MailParticipant(name: $0.emailAddress.name, emailAddress: $0.emailAddress.address) }
    }
}
