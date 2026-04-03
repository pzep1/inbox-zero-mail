import Combine
import Foundation
import OSLog
import Sparkle

@MainActor
public final class AppUpdateController: ObservableObject {
    @Published public private(set) var canCheckForUpdates = false

    public let isConfigured: Bool
    public let configurationIssue: String?

    private let updaterController: SPUStandardUpdaterController?
    private let logger = Logger(subsystem: "com.getinboxzero.InboxZeroMail", category: "updates")
    private var canCheckObservation: NSKeyValueObservation?

    public init(bundle: Bundle = .main, isEnabled: Bool = true) {
        guard isEnabled else {
            self.isConfigured = false
            self.configurationIssue = "Direct updates are disabled during UI testing."
            self.updaterController = nil
            return
        }

        let configuration = UpdateConfiguration(bundle: bundle)
        self.isConfigured = configuration.isConfigured
        self.configurationIssue = configuration.configurationIssue
        let updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.updaterController = updaterController

        canCheckObservation = updaterController.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            DispatchQueue.main.async {
                self?.canCheckForUpdates = updater.canCheckForUpdates
            }
        }

        guard configuration.isConfigured else {
            logger.notice("Direct updates are disabled: \(configuration.configurationIssue ?? "missing Sparkle configuration", privacy: .public)")
            return
        }

        do {
            try updaterController.startUpdater()
        } catch {
            logger.error("Failed to start Sparkle updater: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func checkForUpdates() {
        guard isConfigured, let updaterController else { return }
        updaterController.checkForUpdates(nil)
    }
}

private struct UpdateConfiguration {
    let appcastURL: URL?
    let publicEDKey: String?

    init(bundle: Bundle) {
        self.appcastURL = Self.resolvedURL(for: "SUFeedURL", bundle: bundle)
        self.publicEDKey = Self.resolvedValue(for: "SUPublicEDKey", bundle: bundle)
    }

    var isConfigured: Bool {
        configurationIssue == nil
    }

    var configurationIssue: String? {
        if appcastURL == nil {
            return "SUFeedURL is missing. Set SPARKLE_APPCAST_URL for direct releases."
        }
        if publicEDKey == nil {
            return "SUPublicEDKey is missing. Set SPARKLE_PUBLIC_ED_KEY for direct releases."
        }
        return nil
    }

    private static func resolvedURL(for key: String, bundle: Bundle) -> URL? {
        guard let rawValue = resolvedValue(for: key, bundle: bundle) else { return nil }
        return URL(string: rawValue)
    }

    private static func resolvedValue(for key: String, bundle: Bundle) -> String? {
        guard let rawValue = bundle.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false, trimmed.hasPrefix("$(") == false else {
            return nil
        }

        return trimmed
    }
}
