import Foundation
import MailCore

enum DemoDataFactory {
    static func makeAccounts() -> [MailAccount] {
        [
            MailAccount(
                id: MailAccountID(rawValue: "gmail:alpha@example.com"),
                providerKind: .gmail,
                providerAccountID: "alpha@example.com",
                primaryEmail: "alpha@example.com",
                displayName: "Alpha",
                capabilities: .init(supportsArchive: true, supportsLabels: true, supportsCompose: true)
            ),
            MailAccount(
                id: MailAccountID(rawValue: "gmail:beta@example.com"),
                providerKind: .gmail,
                providerAccountID: "beta@example.com",
                primaryEmail: "beta@example.com",
                displayName: "Beta",
                capabilities: .init(supportsArchive: true, supportsLabels: true, supportsCompose: true)
            ),
        ]
    }

    static func makeMailboxes(for accounts: [MailAccount]) -> [MailboxRef] {
        accounts.flatMap { account in
            [
                MailboxRef(id: MailboxID(accountID: account.id, providerMailboxID: "INBOX"), accountID: account.id, providerMailboxID: "INBOX", displayName: "Inbox", kind: .system, systemRole: .inbox),
                MailboxRef(id: MailboxID(accountID: account.id, providerMailboxID: "STARRED"), accountID: account.id, providerMailboxID: "STARRED", displayName: "Starred", kind: .system, systemRole: .starred),
                MailboxRef(id: MailboxID(accountID: account.id, providerMailboxID: "Label_ops"), accountID: account.id, providerMailboxID: "Label_ops", displayName: "Ops", kind: .label),
            ]
        }
    }

    static func makeThreads(for accounts: [MailAccount], now: Date) -> [MailThreadDetail] {
        let accountMailboxes = Dictionary(uniqueKeysWithValues: makeMailboxes(for: accounts).map { ($0.id.rawValue, $0) })

        return accounts.enumerated().map { index, account in
            let inbox = accountMailboxes[MailboxID(accountID: account.id, providerMailboxID: "INBOX").rawValue]!
            let starred = accountMailboxes[MailboxID(accountID: account.id, providerMailboxID: "STARRED").rawValue]!
            let ops = accountMailboxes[MailboxID(accountID: account.id, providerMailboxID: "Label_ops").rawValue]!

            let threadID = MailThreadID(accountID: account.id, providerThreadID: "demo-thread-\(index)")
            let messageID = MailMessageID(accountID: account.id, providerMessageID: "demo-message-\(index)")
            let message = MailMessage(
                id: messageID,
                threadID: threadID,
                accountID: account.id,
                providerMessageID: "demo-message-\(index)",
                sender: MailParticipant(name: "Ops Desk", emailAddress: "ops@example.com"),
                toRecipients: [MailParticipant(name: account.displayName, emailAddress: account.primaryEmail)],
                sentAt: now.addingTimeInterval(Double(index) * -1800),
                receivedAt: now.addingTimeInterval(Double(index) * -1800),
                snippet: index == 0 ? "Action needed on the release checklist." : "Tomorrow's customer follow-up is ready.",
                plainBody: index == 0 ? "Archive, star, and reply actions are wired up." : "This inbox is unified across both demo accounts.",
                bodyCacheState: .hot,
                headers: [MessageHeader(name: "Subject", value: index == 0 ? "Release checklist" : "Customer follow-up")],
                mailboxRefs: index == 0 ? [inbox, starred, ops] : [inbox],
                isRead: index != 0,
                isOutgoing: false
            )

            let thread = MailThread(
                id: threadID,
                accountID: account.id,
                providerThreadID: "demo-thread-\(index)",
                subject: index == 0 ? "Release checklist" : "Customer follow-up",
                participantSummary: "Ops Desk",
                snippet: message.snippet,
                lastActivityAt: message.receivedAt ?? now,
                hasUnread: index == 0,
                isStarred: index == 0,
                isInInbox: true,
                mailboxRefs: message.mailboxRefs,
                latestMessageID: message.id,
                syncRevision: "demo-\(index)"
            )

            return MailThreadDetail(thread: thread, messages: [message])
        }
    }
}
