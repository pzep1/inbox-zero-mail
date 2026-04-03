import Foundation

public struct ProviderEnvironment: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Hashable, Sendable {
        case production
        case emulator
    }

    public var kind: Kind
    public var authBaseURL: URL?
    public var apiBaseURL: URL
    public var userInfoURL: URL?

    public init(
        kind: Kind = .production,
        authBaseURL: URL? = nil,
        apiBaseURL: URL,
        userInfoURL: URL? = nil
    ) {
        self.kind = kind
        self.authBaseURL = authBaseURL
        self.apiBaseURL = apiBaseURL
        self.userInfoURL = userInfoURL
    }

    public static func production(apiBaseURL: URL, authBaseURL: URL? = nil, userInfoURL: URL? = nil) -> Self {
        .init(kind: .production, authBaseURL: authBaseURL, apiBaseURL: apiBaseURL, userInfoURL: userInfoURL)
    }

    public static func emulator(apiBaseURL: URL, authBaseURL: URL? = nil, userInfoURL: URL? = nil) -> Self {
        .init(kind: .emulator, authBaseURL: authBaseURL, apiBaseURL: apiBaseURL, userInfoURL: userInfoURL)
    }
}
