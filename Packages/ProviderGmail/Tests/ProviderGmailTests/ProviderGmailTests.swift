import Foundation
import MailCore
import ProviderCore
import Testing
@testable import ProviderGmail

@Test
func base64URLRoundTripPreservesMIMEBodies() {
    let original = "Subject: Demo\r\n\r\nBody"
    let encoded = Data(original.utf8).base64URLEncodedString()
    let decoded = Data(base64URLEncoded: encoded).flatMap { String(data: $0, encoding: .utf8) }

    #expect(decoded == original)
}

@Test
func formURLEncodingEscapesReservedCharacters() {
    let body = formURLEncodedBody([
        "email": "user+tag@gmail.com",
        "code": "abc+123/=&",
        "scope": "openid email",
    ])
    let encoded = String(decoding: body, as: UTF8.self)

    #expect(encoded.contains("email=user%2Btag%40gmail.com"))
    #expect(encoded.contains("code=abc%2B123%2F%3D%26"))
    #expect(encoded.contains("scope=openid+email"))
}

@Test
@MainActor
func liveAuthorizationRequiresAConfiguredClientID() async throws {
    let provider = GmailProvider(
        configuration: .production(
            clientID: "",
            redirectURL: URL(string: "inboxzeromail://oauth/google")!
        )
    )

    do {
        _ = try await provider.authorize()
        Issue.record("Expected live Gmail auth to require a configured client ID.")
    } catch let error as MailProviderError {
        switch error {
        case let .missingConfiguration(message):
            #expect(message.contains("INBOX_ZERO_GMAIL_CLIENT_ID"))
        default:
            Issue.record("Unexpected Gmail provider error: \(error)")
        }
    }
}

@Test
func gmailEmulatorContractCoversSyncMutationsAndSend() async throws {
    guard emulatorTestsEnabled else { return }

    let baseURL = googleBaseURL
    let redirectURL = baseURL.appending(path: "/oauth/google")
    let provider = GmailProvider(
        configuration: GmailProviderConfiguration(
            environment: .emulator(
                apiBaseURL: baseURL,
                authBaseURL: baseURL,
                userInfoURL: baseURL.appending(path: "/oauth2/v2/userinfo")
            ),
            clientID: "inbox-zero-mail-dev",
            redirectURL: redirectURL
        )
    )

    let session = try await googleSession(baseURL: baseURL, redirectURL: redirectURL, email: "alpha.inbox@example.com")
    let accountID = MailAccountID(rawValue: "gmail:alpha.inbox@example.com")

    let mailboxes = try await provider.listMailboxes(session: session, accountID: accountID)
    #expect(mailboxes.contains(where: { $0.providerMailboxID == "Label_ops" && $0.kind == .label }))

    let page = try await provider.syncPage(session: session, accountID: accountID, request: MailSyncRequest(mode: .initial, limit: 10))
    let thread = try #require(page.threadDetails.first(where: { $0.thread.subject == "Release checklist" }))

    #expect(page.profile.emailAddress == "alpha.inbox@example.com")
    #expect(thread.thread.hasUnread == true)
    #expect(thread.thread.isStarred == true)
    #expect(thread.thread.isInInbox == true)

    try await provider.apply(session: session, mutation: .archive(threadID: thread.thread.id))
    let archived = try await provider.fetchThread(session: session, accountID: accountID, providerThreadID: thread.thread.providerThreadID)
    #expect(archived.thread.isInInbox == false)

    try await provider.apply(session: session, mutation: .markRead(threadID: thread.thread.id))
    let readThread = try await provider.fetchThread(session: session, accountID: accountID, providerThreadID: thread.thread.providerThreadID)
    #expect(readThread.thread.hasUnread == false)

    try await provider.apply(session: session, mutation: .unstar(threadID: thread.thread.id))
    let unstarred = try await provider.fetchThread(session: session, accountID: accountID, providerThreadID: thread.thread.providerThreadID)
    #expect(unstarred.thread.isStarred == false)

    let receipt = try await provider.send(
        session: session,
        draft: OutgoingDraft(
            accountID: accountID,
            replyMode: .new,
            toRecipients: [MailParticipant(name: "Ops", emailAddress: "ops@example.com")],
            subject: "Contract test",
            plainBody: "Hello from the Gmail provider contract test."
        )
    )
    #expect(receipt.providerMessageID.isEmpty == false)
}

private var emulatorTestsEnabled: Bool {
    ProcessInfo.processInfo.environment["INBOX_ZERO_RUN_EMULATOR_TESTS"] == "1"
}

private var googleBaseURL: URL {
    URL(string: ProcessInfo.processInfo.environment["INBOX_ZERO_GOOGLE_BASE_URL"] ?? "http://localhost:4402")!
}

private struct GoogleTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let idToken: String?
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case scope
    }
}

private func googleSession(baseURL: URL, redirectURL: URL, email: String) async throws -> ProviderSession {
    var authRequest = URLRequest(url: baseURL.appending(path: "/o/oauth2/v2/auth/callback"))
    authRequest.httpMethod = "POST"
    authRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    authRequest.httpBody = formURLEncodedBody([
        "email": email,
        "redirect_uri": redirectURL.absoluteString,
        "scope": "openid email profile https://www.googleapis.com/auth/gmail.modify https://www.googleapis.com/auth/gmail.send",
        "client_id": "inbox-zero-mail-dev",
        "state": "",
        "code_challenge": "",
        "code_challenge_method": "",
    ])

    let (_, authResponse) = try await URLSession.shared.data(for: authRequest)
    let authURL = try #require(authResponse.url)
    let authComponents = try #require(URLComponents(url: authURL, resolvingAgainstBaseURL: false))
    let code = try #require(authComponents.queryItems?.first(where: { $0.name == "code" })?.value)

    var tokenRequest = URLRequest(url: baseURL.appending(path: "/oauth2/token"))
    tokenRequest.httpMethod = "POST"
    tokenRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    tokenRequest.httpBody = formURLEncodedBody([
        "code": code,
        "client_id": "inbox-zero-mail-dev",
        "client_secret": "inbox-zero-google-secret",
        "grant_type": "authorization_code",
        "redirect_uri": redirectURL.absoluteString,
    ])

    let (tokenData, _) = try await URLSession.shared.data(for: tokenRequest)
    let token = try JSONDecoder().decode(GoogleTokenResponse.self, from: tokenData)

    return ProviderSession(
        providerKind: .gmail,
        providerAccountID: email,
        emailAddress: email,
        displayName: email,
        accessToken: token.accessToken,
        refreshToken: token.refreshToken,
        idToken: token.idToken,
        scopes: token.scope?.split(separator: " ").map(String.init) ?? []
    )
}
