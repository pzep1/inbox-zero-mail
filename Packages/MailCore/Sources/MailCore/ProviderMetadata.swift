import Foundation

public extension ProviderKind {
    var displayName: String {
        switch self {
        case .gmail:
            "Gmail"
        case .microsoft:
            "Outlook"
        }
    }

    var systemImageName: String {
        switch self {
        case .gmail:
            "envelope.badge"
        case .microsoft:
            "briefcase"
        }
    }

    var mailboxTagSingular: String {
        switch self {
        case .gmail:
            "Label"
        case .microsoft:
            "Category"
        }
    }

    var mailboxTagPlural: String {
        switch self {
        case .gmail:
            "Labels"
        case .microsoft:
            "Categories"
        }
    }
}

public extension MailAccountCapabilities {
    var supportsTagging: Bool {
        supportsLabels || supportsCategories
    }
}
