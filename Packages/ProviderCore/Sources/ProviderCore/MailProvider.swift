import Foundation
import MailCore

public struct ProviderAccountProfile: Codable, Hashable, Sendable {
    public var providerAccountID: String
    public var emailAddress: String
    public var displayName: String

    public init(providerAccountID: String, emailAddress: String, displayName: String) {
        self.providerAccountID = providerAccountID
        self.emailAddress = emailAddress
        self.displayName = displayName
    }
}

public struct ProviderSession: Codable, Hashable, Sendable {
    public var providerKind: ProviderKind
    public var providerAccountID: String
    public var emailAddress: String
    public var displayName: String
    public var accessToken: String
    public var refreshToken: String?
    public var idToken: String?
    public var expirationDate: Date?
    public var scopes: [String]

    public init(
        providerKind: ProviderKind,
        providerAccountID: String,
        emailAddress: String,
        displayName: String,
        accessToken: String,
        refreshToken: String? = nil,
        idToken: String? = nil,
        expirationDate: Date? = nil,
        scopes: [String] = []
    ) {
        self.providerKind = providerKind
        self.providerAccountID = providerAccountID
        self.emailAddress = emailAddress
        self.displayName = displayName
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.idToken = idToken
        self.expirationDate = expirationDate
        self.scopes = scopes
    }
}

public enum MailSyncMode: Hashable, Sendable {
    case initial
    case delta(checkpointPayload: String, pageToken: String?)
    case backfill(pageToken: String?)
}

public struct MailSyncRequest: Hashable, Sendable {
    public var mode: MailSyncMode
    public var limit: Int

    public init(mode: MailSyncMode, limit: Int = 50) {
        self.mode = mode
        self.limit = limit
    }
}

public struct MailSyncPage: Hashable, Sendable {
    public var profile: ProviderAccountProfile
    public var mailboxes: [MailboxRef]
    public var threadDetails: [MailThreadDetail]
    public var checkpointPayload: String?
    public var nextPageToken: String?
    public var isBackfillComplete: Bool

    public init(
        profile: ProviderAccountProfile,
        mailboxes: [MailboxRef],
        threadDetails: [MailThreadDetail],
        checkpointPayload: String?,
        nextPageToken: String?,
        isBackfillComplete: Bool
    ) {
        self.profile = profile
        self.mailboxes = mailboxes
        self.threadDetails = threadDetails
        self.checkpointPayload = checkpointPayload
        self.nextPageToken = nextPageToken
        self.isBackfillComplete = isBackfillComplete
    }
}

public struct SentDraftReceipt: Codable, Hashable, Sendable {
    public var providerMessageID: String
    public var providerThreadID: String?

    public init(providerMessageID: String, providerThreadID: String? = nil) {
        self.providerMessageID = providerMessageID
        self.providerThreadID = providerThreadID
    }
}

public enum MailProviderError: Error, LocalizedError, Sendable {
    case unauthorized
    case rateLimited(message: String, retryAfter: TimeInterval?)
    case invalidCheckpoint
    case unsupported(String)
    case transport(String)
    case decoding(String)
    case missingConfiguration(String)

    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            "The provider session is unauthorized."
        case let .rateLimited(message, _):
            message
        case .invalidCheckpoint:
            "The sync checkpoint is no longer valid and must be rebuilt."
        case let .unsupported(message),
            let .transport(message),
            let .decoding(message),
            let .missingConfiguration(message):
            message
        }
    }
}

public protocol MailProvider: AnyObject, Sendable {
    var kind: ProviderKind { get }
    var environment: ProviderEnvironment { get }

    @MainActor
    func authorize() async throws -> ProviderSession

    @MainActor
    func handleRedirectURL(_ url: URL) -> Bool

    func restoreSession(_ session: ProviderSession) async throws -> ProviderSession
    func listMailboxes(session: ProviderSession, accountID: MailAccountID) async throws -> [MailboxRef]
    func syncPage(session: ProviderSession, accountID: MailAccountID, request: MailSyncRequest) async throws -> MailSyncPage
    func fetchThread(session: ProviderSession, accountID: MailAccountID, providerThreadID: String) async throws -> MailThreadDetail
    func apply(session: ProviderSession, mutation: MailMutation) async throws
    func send(session: ProviderSession, draft: OutgoingDraft) async throws -> SentDraftReceipt
    func saveDraft(session: ProviderSession, draft: OutgoingDraft) async throws -> OutgoingDraft
    func listDrafts(session: ProviderSession, accountID: MailAccountID) async throws -> [OutgoingDraft]
    func deleteDraft(session: ProviderSession, providerDraftID: String) async throws
    func updateMailboxVisibility(session: ProviderSession, providerMailboxID: String, hidden: Bool) async throws
    func fetchLabelVisibility(session: ProviderSession, accountID: MailAccountID) async throws -> [MailboxRef]
    func fetchAttachment(session: ProviderSession, accountID: MailAccountID, attachment: MailAttachment) async throws -> Data
}

public extension MailProvider {
    func saveDraft(session: ProviderSession, draft: OutgoingDraft) async throws -> OutgoingDraft {
        throw MailProviderError.unsupported("Remote drafts are not supported for this provider.")
    }

    func listDrafts(session: ProviderSession, accountID: MailAccountID) async throws -> [OutgoingDraft] { [] }

    func deleteDraft(session: ProviderSession, providerDraftID: String) async throws {}

    func updateMailboxVisibility(session: ProviderSession, providerMailboxID: String, hidden: Bool) async throws {}
    func fetchLabelVisibility(session: ProviderSession, accountID: MailAccountID) async throws -> [MailboxRef] { [] }

    func fetchAttachment(session: ProviderSession, accountID: MailAccountID, attachment: MailAttachment) async throws -> Data {
        throw MailProviderError.unsupported("Attachment download is not supported for this provider.")
    }
}
