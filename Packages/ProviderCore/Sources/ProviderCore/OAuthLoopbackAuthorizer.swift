import AppAuth
import AppKit
import Foundation

public struct OAuthLoopbackAuthorizationRequest {
    public var providerDisplayName: String
    public var clientID: String
    public var clientSecret: String?
    public var scopes: [String]
    public var authorizationEndpoint: URL
    public var tokenEndpoint: URL
    public var additionalParameters: [String: String]
    public var presentingWindow: NSWindow

    public init(
        providerDisplayName: String,
        clientID: String,
        clientSecret: String? = nil,
        scopes: [String],
        authorizationEndpoint: URL,
        tokenEndpoint: URL,
        additionalParameters: [String: String] = [:],
        presentingWindow: NSWindow
    ) {
        self.providerDisplayName = providerDisplayName
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.scopes = scopes
        self.authorizationEndpoint = authorizationEndpoint
        self.tokenEndpoint = tokenEndpoint
        self.additionalParameters = additionalParameters
        self.presentingWindow = presentingWindow
    }
}

public struct OAuthLoopbackAuthorizationPayload: Sendable {
    public var accessToken: String
    public var refreshToken: String?
    public var idToken: String?
    public var expirationDate: Date?

    public init(
        accessToken: String,
        refreshToken: String?,
        idToken: String?,
        expirationDate: Date?
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.idToken = idToken
        self.expirationDate = expirationDate
    }
}

@MainActor
public func authorizeWithLoopback(_ request: OAuthLoopbackAuthorizationRequest) async throws -> OAuthLoopbackAuthorizationPayload {
    let serviceConfiguration = OIDServiceConfiguration(
        authorizationEndpoint: request.authorizationEndpoint,
        tokenEndpoint: request.tokenEndpoint
    )

    let httpHandler = OIDRedirectHTTPHandler(successURL: nil)

    // OIDRedirectHTTPHandler.startHTTPListener is annotated nonnull but can
    // return nil on failure (for example missing network.server entitlement).
    // Call via IMP to avoid Swift's forced URL bridging crash.
    typealias StartListenerIMP = @convention(c) (AnyObject, Selector, NSErrorPointer, UInt16) -> NSURL?
    let selector = NSSelectorFromString("startHTTPListener:withPort:")
    let imp = unsafeBitCast(httpHandler.method(for: selector), to: StartListenerIMP.self)
    var listenerError: NSError?
    guard let loopbackRedirectURL = imp(httpHandler, selector, &listenerError, 0) as URL? else {
        throw MailProviderError.transport(
            "Failed to start \(request.providerDisplayName) OAuth loopback listener: \(listenerError?.localizedDescription ?? "unknown error")"
        )
    }

    let authorizationRequest = OIDAuthorizationRequest(
        configuration: serviceConfiguration,
        clientId: request.clientID,
        clientSecret: request.clientSecret,
        scopes: request.scopes,
        redirectURL: loopbackRedirectURL,
        responseType: OIDResponseTypeCode,
        additionalParameters: request.additionalParameters
    )

    defer {
        httpHandler.cancelHTTPListener()
    }

    return try await withCheckedThrowingContinuation { continuation in
        let once = SingleResumeGuard()

        httpHandler.currentAuthorizationFlow = OIDAuthState.authState(
            byPresenting: authorizationRequest,
            presenting: request.presentingWindow
        ) { authState, error in
            guard once.tryAcquire() else { return }

            DispatchQueue.main.async {
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let authState else {
                    continuation.resume(
                        throwing: MailProviderError.transport(
                            "\(request.providerDisplayName) OAuth finished without an auth state."
                        )
                    )
                    return
                }

                let tokenResponse = authState.lastTokenResponse
                continuation.resume(
                    returning: OAuthLoopbackAuthorizationPayload(
                        accessToken: tokenResponse?.accessToken ?? authState.lastAuthorizationResponse.accessToken ?? "",
                        refreshToken: authState.refreshToken,
                        idToken: tokenResponse?.idToken,
                        expirationDate: tokenResponse?.accessTokenExpirationDate
                    )
                )
            }
        }
    }
}
