import Foundation

public enum MailMutation: Hashable, Sendable {
    case archive(threadID: MailThreadID)
    case unarchive(threadID: MailThreadID)
    case markRead(threadID: MailThreadID)
    case markUnread(threadID: MailThreadID)
    case star(threadID: MailThreadID)
    case unstar(threadID: MailThreadID)
    case trash(threadID: MailThreadID)
    case untrash(threadID: MailThreadID)
    case snooze(threadID: MailThreadID, until: Date)
    case unsnooze(threadID: MailThreadID)
    case applyMailbox(threadID: MailThreadID, mailboxID: MailboxID)
    case removeMailbox(threadID: MailThreadID, mailboxID: MailboxID)
    case send(draft: OutgoingDraft)

    public var accountID: MailAccountID {
        switch self {
        case let .archive(threadID),
            let .unarchive(threadID),
            let .markRead(threadID),
            let .markUnread(threadID),
            let .star(threadID),
            let .unstar(threadID),
            let .trash(threadID),
            let .untrash(threadID),
            let .snooze(threadID, _),
            let .unsnooze(threadID),
            let .applyMailbox(threadID, _),
            let .removeMailbox(threadID, _):
            return threadID.accountID
        case let .send(draft):
            return draft.accountID
        }
    }

    public var rollbackMutation: MailMutation? {
        switch self {
        case let .archive(threadID):
            .unarchive(threadID: threadID)
        case let .unarchive(threadID):
            .archive(threadID: threadID)
        case let .markRead(threadID):
            .markUnread(threadID: threadID)
        case let .markUnread(threadID):
            .markRead(threadID: threadID)
        case let .star(threadID):
            .unstar(threadID: threadID)
        case let .unstar(threadID):
            .star(threadID: threadID)
        case let .trash(threadID):
            .untrash(threadID: threadID)
        case let .untrash(threadID):
            .trash(threadID: threadID)
        case let .snooze(threadID, _):
            .unsnooze(threadID: threadID)
        case .unsnooze, .send:
            nil
        case let .applyMailbox(threadID, mailboxID):
            .removeMailbox(threadID: threadID, mailboxID: mailboxID)
        case let .removeMailbox(threadID, mailboxID):
            .applyMailbox(threadID: threadID, mailboxID: mailboxID)
        }
    }
}

extension MailMutation: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case threadID
        case mailboxID
        case snoozeUntil
        case draft
    }

    private enum Kind: String, Codable {
        case archive
        case unarchive
        case markRead
        case markUnread
        case star
        case unstar
        case trash
        case untrash
        case snooze
        case unsnooze
        case applyMailbox
        case removeMailbox
        case send
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        switch kind {
        case .archive:
            self = .archive(threadID: try container.decode(MailThreadID.self, forKey: .threadID))
        case .unarchive:
            self = .unarchive(threadID: try container.decode(MailThreadID.self, forKey: .threadID))
        case .markRead:
            self = .markRead(threadID: try container.decode(MailThreadID.self, forKey: .threadID))
        case .markUnread:
            self = .markUnread(threadID: try container.decode(MailThreadID.self, forKey: .threadID))
        case .star:
            self = .star(threadID: try container.decode(MailThreadID.self, forKey: .threadID))
        case .unstar:
            self = .unstar(threadID: try container.decode(MailThreadID.self, forKey: .threadID))
        case .trash:
            self = .trash(threadID: try container.decode(MailThreadID.self, forKey: .threadID))
        case .untrash:
            self = .untrash(threadID: try container.decode(MailThreadID.self, forKey: .threadID))
        case .snooze:
            self = .snooze(
                threadID: try container.decode(MailThreadID.self, forKey: .threadID),
                until: try container.decode(Date.self, forKey: .snoozeUntil)
            )
        case .unsnooze:
            self = .unsnooze(threadID: try container.decode(MailThreadID.self, forKey: .threadID))
        case .applyMailbox:
            self = .applyMailbox(
                threadID: try container.decode(MailThreadID.self, forKey: .threadID),
                mailboxID: try container.decode(MailboxID.self, forKey: .mailboxID)
            )
        case .removeMailbox:
            self = .removeMailbox(
                threadID: try container.decode(MailThreadID.self, forKey: .threadID),
                mailboxID: try container.decode(MailboxID.self, forKey: .mailboxID)
            )
        case .send:
            self = .send(draft: try container.decode(OutgoingDraft.self, forKey: .draft))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .archive(threadID):
            try container.encode(Kind.archive, forKey: .kind)
            try container.encode(threadID, forKey: .threadID)
        case let .unarchive(threadID):
            try container.encode(Kind.unarchive, forKey: .kind)
            try container.encode(threadID, forKey: .threadID)
        case let .markRead(threadID):
            try container.encode(Kind.markRead, forKey: .kind)
            try container.encode(threadID, forKey: .threadID)
        case let .markUnread(threadID):
            try container.encode(Kind.markUnread, forKey: .kind)
            try container.encode(threadID, forKey: .threadID)
        case let .star(threadID):
            try container.encode(Kind.star, forKey: .kind)
            try container.encode(threadID, forKey: .threadID)
        case let .unstar(threadID):
            try container.encode(Kind.unstar, forKey: .kind)
            try container.encode(threadID, forKey: .threadID)
        case let .trash(threadID):
            try container.encode(Kind.trash, forKey: .kind)
            try container.encode(threadID, forKey: .threadID)
        case let .untrash(threadID):
            try container.encode(Kind.untrash, forKey: .kind)
            try container.encode(threadID, forKey: .threadID)
        case let .snooze(threadID, until):
            try container.encode(Kind.snooze, forKey: .kind)
            try container.encode(threadID, forKey: .threadID)
            try container.encode(until, forKey: .snoozeUntil)
        case let .unsnooze(threadID):
            try container.encode(Kind.unsnooze, forKey: .kind)
            try container.encode(threadID, forKey: .threadID)
        case let .applyMailbox(threadID, mailboxID):
            try container.encode(Kind.applyMailbox, forKey: .kind)
            try container.encode(threadID, forKey: .threadID)
            try container.encode(mailboxID, forKey: .mailboxID)
        case let .removeMailbox(threadID, mailboxID):
            try container.encode(Kind.removeMailbox, forKey: .kind)
            try container.encode(threadID, forKey: .threadID)
            try container.encode(mailboxID, forKey: .mailboxID)
        case let .send(draft):
            try container.encode(Kind.send, forKey: .kind)
            try container.encode(draft, forKey: .draft)
        }
    }
}
