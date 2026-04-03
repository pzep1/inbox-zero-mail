import Foundation

public protocol MailIdentifier: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible where RawValue == String {
    init(rawValue: String)
}

extension MailIdentifier {
    public var description: String { rawValue }
}

public struct MailAccountID: MailIdentifier, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
}

public struct MailThreadID: MailIdentifier, ExpressibleByStringLiteral {
    public static let separator = "::thread::"

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public init(accountID: MailAccountID, providerThreadID: String) {
        self.init(rawValue: accountID.rawValue + Self.separator + providerThreadID)
    }

    public var accountID: MailAccountID {
        guard let prefix = rawValue.components(separatedBy: Self.separator).first else {
            return MailAccountID(rawValue: rawValue)
        }
        return MailAccountID(rawValue: prefix)
    }

    public var providerThreadID: String {
        let components = rawValue.components(separatedBy: Self.separator)
        guard components.count >= 2 else { return rawValue }
        return components.dropFirst().joined(separator: Self.separator)
    }
}

public struct MailMessageID: MailIdentifier, ExpressibleByStringLiteral {
    public static let separator = "::message::"

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public init(accountID: MailAccountID, providerMessageID: String) {
        self.init(rawValue: accountID.rawValue + Self.separator + providerMessageID)
    }

    public var accountID: MailAccountID {
        guard let prefix = rawValue.components(separatedBy: Self.separator).first else {
            return MailAccountID(rawValue: rawValue)
        }
        return MailAccountID(rawValue: prefix)
    }

    public var providerMessageID: String {
        let components = rawValue.components(separatedBy: Self.separator)
        guard components.count >= 2 else { return rawValue }
        return components.dropFirst().joined(separator: Self.separator)
    }
}

public struct MailboxID: MailIdentifier, ExpressibleByStringLiteral {
    public static let separator = "::mailbox::"

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public init(accountID: MailAccountID, providerMailboxID: String) {
        self.init(rawValue: accountID.rawValue + Self.separator + providerMailboxID)
    }

    public var accountID: MailAccountID {
        guard let prefix = rawValue.components(separatedBy: Self.separator).first else {
            return MailAccountID(rawValue: rawValue)
        }
        return MailAccountID(rawValue: prefix)
    }

    public var providerMailboxID: String {
        let components = rawValue.components(separatedBy: Self.separator)
        guard components.count >= 2 else { return rawValue }
        return components.dropFirst().joined(separator: Self.separator)
    }
}
