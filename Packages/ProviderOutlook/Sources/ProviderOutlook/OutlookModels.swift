import Foundation
import MailCore

struct OutlookProfileResponse: Decodable, Sendable {
    let id: String
    let displayName: String
    let mail: String?
    let userPrincipalName: String
}

struct OutlookFolderListResponse: Decodable, Sendable {
    let value: [OutlookFolder]
}

struct OutlookFolder: Decodable, Sendable {
    let id: String
    let displayName: String
    let wellKnownName: String?

    func asMailbox(accountID: MailAccountID) -> MailboxRef {
        MailboxRef(
            id: MailboxID(accountID: accountID, providerMailboxID: id),
            accountID: accountID,
            providerMailboxID: id,
            displayName: displayName,
            kind: .folder,
            systemRole: OutlookSystemRoleMapper.role(for: wellKnownName)
        )
    }
}

struct OutlookCategoryListResponse: Decodable, Sendable {
    let value: [OutlookCategory]
}

struct OutlookCategory: Decodable, Sendable {
    let id: String?
    let displayName: String
    let color: String?

    func asMailbox(accountID: MailAccountID) -> MailboxRef {
        let providerMailboxID = id ?? displayName
        return MailboxRef(
            id: MailboxID(accountID: accountID, providerMailboxID: providerMailboxID),
            accountID: accountID,
            providerMailboxID: providerMailboxID,
            displayName: displayName,
            kind: .category,
            colorHex: sanitizedColorHex(from: color)
        )
    }

    private func sanitizedColorHex(from rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        let hexDigits = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        guard candidate.count == 6, candidate.unicodeScalars.allSatisfy(hexDigits.contains) else {
            return nil
        }
        return candidate
    }
}

struct OutlookMessageListResponse: Decodable, Sendable {
    let value: [OutlookMessage]
    let nextLink: String?

    enum CodingKeys: String, CodingKey {
        case value
        case nextLink = "@odata.nextLink"
    }
}

struct OutlookMessage: Decodable, Sendable {
    struct RecipientList: Decodable, Sendable {
        let emailAddress: EmailAddress
    }

    struct EmailAddress: Decodable, Sendable {
        let address: String
        let name: String?
    }

    struct Body: Decodable, Sendable {
        let contentType: String
        let content: String
    }

    struct Flag: Decodable, Sendable {
        let flagStatus: String?
    }

    let id: String
    let conversationId: String
    let subject: String?
    let bodyPreview: String?
    let body: Body?
    let from: RecipientList?
    let toRecipients: [RecipientList]?
    let ccRecipients: [RecipientList]?
    let bccRecipients: [RecipientList]?
    let internetMessageHeaders: [OutlookHeader]?
    let categories: [String]?
    let parentFolderId: String?
    let receivedDateTime: Date?
    let sentDateTime: Date?
    let isRead: Bool?
    let flag: Flag?
}

struct OutlookHeader: Decodable, Sendable {
    let name: String
    let value: String
}
