import Foundation

#if APP_STORE
@MainActor
final class AppUpdateController: ObservableObject {
    @Published private(set) var canCheckForUpdates = false

    let isConfigured = false
    let configurationIssue = "App Store builds use App Store updates."

    init(bundle: Bundle = .main, isEnabled: Bool = true) {}

    func checkForUpdates() {}
}
#endif

