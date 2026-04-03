import Foundation
import MailCore

public enum MailControlError: LocalizedError {
    case windowNotFound(String)
    case noWindows
    case splitInboxNotFound(String)
    case invalidThreadID(String)
    case invalidVisibleIndex(Int)
    case noThreadSelected
    case noDraftOpen

    public var errorDescription: String? {
        switch self {
        case .windowNotFound(let windowID):
            return "No window matches '\(windowID)'."
        case .noWindows:
            return "The app has no open windows."
        case .splitInboxNotFound(let value):
            return "No split inbox matches '\(value)'."
        case .invalidThreadID(let value):
            return "Invalid thread id '\(value)'."
        case .invalidVisibleIndex(let index):
            return "No visible thread matches index \(index)."
        case .noThreadSelected:
            return "No thread is selected in the target window."
        case .noDraftOpen:
            return "No compose draft is open in the target window."
        }
    }
}

public struct MailControlWindowSnapshot: Codable, Sendable, Equatable {
    public var windowID: String
    public var isActive: Bool
    public var selectedTab: String
    public var selectedSplitInboxID: String
    public var selectedSplitInboxTitle: String
    public var searchText: String
    public var selectedThreadID: String?
    public var selectedThreadSubject: String?
    public var composeMode: String?
    public var threadCount: Int

    public init(
        windowID: String,
        isActive: Bool,
        selectedTab: String,
        selectedSplitInboxID: String,
        selectedSplitInboxTitle: String,
        searchText: String,
        selectedThreadID: String?,
        selectedThreadSubject: String?,
        composeMode: String?,
        threadCount: Int
    ) {
        self.windowID = windowID
        self.isActive = isActive
        self.selectedTab = selectedTab
        self.selectedSplitInboxID = selectedSplitInboxID
        self.selectedSplitInboxTitle = selectedSplitInboxTitle
        self.searchText = searchText
        self.selectedThreadID = selectedThreadID
        self.selectedThreadSubject = selectedThreadSubject
        self.composeMode = composeMode
        self.threadCount = threadCount
    }
}

public struct MailControlMessageSnapshot: Codable, Sendable, Equatable {
    public var id: String
    public var sender: String
    public var sentAt: Date?
    public var snippet: String
    public var plainBody: String?

    public init(
        id: String,
        sender: String,
        sentAt: Date?,
        snippet: String,
        plainBody: String?
    ) {
        self.id = id
        self.sender = sender
        self.sentAt = sentAt
        self.snippet = snippet
        self.plainBody = plainBody
    }
}

public struct MailControlThreadSnapshot: Codable, Sendable, Equatable {
    public var threadID: String
    public var subject: String
    public var participantSummary: String
    public var snippet: String
    public var messageCount: Int
    public var messages: [MailControlMessageSnapshot]

    public init(
        threadID: String,
        subject: String,
        participantSummary: String,
        snippet: String,
        messageCount: Int,
        messages: [MailControlMessageSnapshot]
    ) {
        self.threadID = threadID
        self.subject = subject
        self.participantSummary = participantSummary
        self.snippet = snippet
        self.messageCount = messageCount
        self.messages = messages
    }
}

public struct MailControlThreadListItem: Codable, Sendable, Equatable {
    public var threadID: String
    public var accountID: String
    public var subject: String
    public var participantSummary: String
    public var snippet: String
    public var hasUnread: Bool
    public var isSelected: Bool
    public var isStarred: Bool
    public var attachmentCount: Int
    public var lastActivityAt: Date?

    public init(
        threadID: String,
        accountID: String,
        subject: String,
        participantSummary: String,
        snippet: String,
        hasUnread: Bool,
        isSelected: Bool,
        isStarred: Bool,
        attachmentCount: Int,
        lastActivityAt: Date?
    ) {
        self.threadID = threadID
        self.accountID = accountID
        self.subject = subject
        self.participantSummary = participantSummary
        self.snippet = snippet
        self.hasUnread = hasUnread
        self.isSelected = isSelected
        self.isStarred = isStarred
        self.attachmentCount = attachmentCount
        self.lastActivityAt = lastActivityAt
    }
}

public struct MailControlDraftSnapshot: Codable, Sendable, Equatable {
    public var draftID: UUID
    public var replyMode: String
    public var subject: String
    public var toRecipients: [String]
    public var body: String
    public var composeMode: String?

    public init(
        draftID: UUID,
        replyMode: String,
        subject: String,
        toRecipients: [String],
        body: String,
        composeMode: String?
    ) {
        self.draftID = draftID
        self.replyMode = replyMode
        self.subject = subject
        self.toRecipients = toRecipients
        self.body = body
        self.composeMode = composeMode
    }
}

public struct MailControlWindowStateSnapshot: Codable, Sendable, Equatable {
    public var window: MailControlWindowSnapshot
    public var visibleThreads: [MailControlThreadListItem]
    public var selectedThread: MailControlThreadSnapshot?
    public var draft: MailControlDraftSnapshot?

    public init(
        window: MailControlWindowSnapshot,
        visibleThreads: [MailControlThreadListItem],
        selectedThread: MailControlThreadSnapshot?,
        draft: MailControlDraftSnapshot?
    ) {
        self.window = window
        self.visibleThreads = visibleThreads
        self.selectedThread = selectedThread
        self.draft = draft
    }
}

@MainActor
public final class MailAppControlService {
    private let store: MailAppStore

    public init(store: MailAppStore) {
        self.store = store
    }

    public func listWindows() -> [MailControlWindowSnapshot] {
        store
            .allWindowModels()
            .map { snapshot(for: $0) }
    }

    public func showTab(windowID: String?, tab: UnifiedTab) async throws -> MailControlWindowSnapshot {
        let model = try resolveWindow(windowID)
        model.select(tab: tab)
        await model.reloadThreads()
        return snapshot(for: model)
    }

    public func showSplitInbox(windowID: String?, value: String) async throws -> MailControlWindowSnapshot {
        let model = try resolveWindow(windowID)
        guard let item = resolveSplitInboxItem(in: model, value: value) else {
            throw MailControlError.splitInboxNotFound(value)
        }
        model.select(splitInboxItem: item)
        await model.reloadThreads()
        return snapshot(for: model)
    }

    public func search(windowID: String?, query: String) async throws -> MailControlWindowSnapshot {
        let model = try resolveWindow(windowID)
        model.searchText = query.trimmingCharacters(in: .whitespacesAndNewlines)
        await model.reloadThreads()
        return snapshot(for: model)
    }

    public func currentThread(windowID: String?) async throws -> MailControlThreadSnapshot {
        let model = try resolveWindow(windowID)
        let threadID = model.selectedThreadID ?? model.hoveredThreadID
        guard let threadID else {
            throw MailControlError.noThreadSelected
        }
        guard let detail = try await model.resolveThreadDetail(threadID: threadID) else {
            throw MailControlError.noThreadSelected
        }
        return snapshot(for: detail)
    }

    public func listThreads(windowID: String?) throws -> [MailControlThreadListItem] {
        let model = try resolveWindow(windowID)
        return threadListItems(for: model)
    }

    public func openThread(windowID: String?, threadIDValue: String) async throws -> MailControlThreadSnapshot {
        let model = try resolveWindow(windowID)
        let trimmed = threadIDValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            throw MailControlError.invalidThreadID(threadIDValue)
        }
        let threadID = MailThreadID(rawValue: trimmed)
        try await model.openThreadForControl(threadID)
        guard let detail = try await model.resolveThreadDetail(threadID: threadID) else {
            throw MailControlError.invalidThreadID(threadIDValue)
        }
        return snapshot(for: detail)
    }

    public func openVisibleThread(windowID: String?, index: Int) async throws -> MailControlThreadSnapshot {
        let model = try resolveWindow(windowID)
        let thread = try resolveVisibleThread(in: model, index: index)
        try await model.openThreadForControl(thread.id)
        guard let detail = try await model.resolveThreadDetail(threadID: thread.id) else {
            throw MailControlError.invalidThreadID(thread.id.rawValue)
        }
        return snapshot(for: detail)
    }

    public func readVisibleThread(windowID: String?, index: Int) async throws -> MailControlThreadSnapshot {
        let model = try resolveWindow(windowID)
        let thread = try resolveVisibleThread(in: model, index: index)
        guard let detail = try await model.resolveThreadDetail(threadID: thread.id) else {
            throw MailControlError.invalidThreadID(thread.id.rawValue)
        }
        return snapshot(for: detail)
    }

    public func windowSnapshot(windowID: String?) async throws -> MailControlWindowStateSnapshot {
        let model = try resolveWindow(windowID)
        let selectedThread = try await selectedThreadSnapshot(in: model)
        let draft = model.composeDraft.map { snapshot(for: $0, composeMode: model.composeMode) }
        return MailControlWindowStateSnapshot(
            window: snapshot(for: model),
            visibleThreads: threadListItems(for: model),
            selectedThread: selectedThread,
            draft: draft
        )
    }

    public func openReplyDraft(
        windowID: String?,
        replyMode: ReplyMode,
        threadIDValue: String? = nil,
        visibleIndex: Int? = nil
    ) async throws -> MailControlDraftSnapshot {
        let model = try resolveWindow(windowID)
        if replyMode != .new {
            let threadID = try resolveReplyTargetThreadID(
                in: model,
                threadIDValue: threadIDValue,
                visibleIndex: visibleIndex
            )
            guard let threadID else {
                throw MailControlError.noThreadSelected
            }
            try await model.openThreadForControl(threadID)
            _ = try await model.resolveThreadDetail(threadID: threadID)
        }
        model.openCompose(replyMode: replyMode)
        guard let draft = model.composeDraft else {
            throw MailControlError.noDraftOpen
        }
        return snapshot(for: draft, composeMode: model.composeMode)
    }

    public func currentDraft(windowID: String?) throws -> MailControlDraftSnapshot {
        let model = try resolveWindow(windowID)
        guard let draft = model.composeDraft else {
            throw MailControlError.noDraftOpen
        }
        return snapshot(for: draft, composeMode: model.composeMode)
    }

    public func updateDraftBody(windowID: String?, body: String) throws -> MailControlDraftSnapshot {
        let model = try resolveWindow(windowID)
        guard var draft = model.composeDraft else {
            throw MailControlError.noDraftOpen
        }
        draft.plainBody = body
        model.updateCompose(draft)
        return snapshot(for: draft, composeMode: model.composeMode)
    }

    public func updateDraftSubject(windowID: String?, subject: String) throws -> MailControlDraftSnapshot {
        let model = try resolveWindow(windowID)
        guard var draft = model.composeDraft else {
            throw MailControlError.noDraftOpen
        }
        draft.subject = subject
        model.updateCompose(draft)
        return snapshot(for: draft, composeMode: model.composeMode)
    }

    private func resolveWindow(_ windowID: String?) throws -> WindowModel {
        guard let model = store.windowModel(windowID: windowID) else {
            if let windowID {
                throw MailControlError.windowNotFound(windowID)
            }
            throw MailControlError.noWindows
        }
        return model
    }

    private func resolveVisibleThread(in model: WindowModel, index: Int) throws -> MailThread {
        guard index > 0, model.threads.indices.contains(index - 1) else {
            throw MailControlError.invalidVisibleIndex(index)
        }
        return model.threads[index - 1]
    }

    private func resolveReplyTargetThreadID(
        in model: WindowModel,
        threadIDValue: String?,
        visibleIndex: Int?
    ) throws -> MailThreadID? {
        if let threadIDValue {
            let trimmed = threadIDValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else {
                throw MailControlError.invalidThreadID(threadIDValue)
            }
            return MailThreadID(rawValue: trimmed)
        }

        if let visibleIndex {
            return try resolveVisibleThread(in: model, index: visibleIndex).id
        }

        return model.selectedThreadID ?? model.hoveredThreadID
    }

    private func resolveSplitInboxItem(in model: WindowModel, value: String) -> SplitInboxItem? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.isEmpty == false else { return nil }

        if let tab = UnifiedTab(rawValue: normalized) {
            return SplitInboxItem.builtIn(tab)
        }

        return model.splitInboxItems.first { item in
            item.id.lowercased() == normalized
                || item.normalizedTitle.lowercased() == normalized
                || (item.isBuiltIn && item.tab.rawValue == normalized)
        }
    }

    private func snapshot(for model: WindowModel) -> MailControlWindowSnapshot {
        MailControlWindowSnapshot(
            windowID: model.windowID,
            isActive: store.activeWindowID == model.windowID,
            selectedTab: model.selectedTab.rawValue,
            selectedSplitInboxID: model.selectedSplitInboxItem.id,
            selectedSplitInboxTitle: model.selectedSplitInboxItem.normalizedTitle,
            searchText: model.searchText,
            selectedThreadID: model.selectedThreadID?.rawValue,
            selectedThreadSubject: model.selectedThread?.subject,
            composeMode: model.composeMode.map(composeModeLabel(for:)),
            threadCount: model.threads.count
        )
    }

    private func threadListItems(for model: WindowModel) -> [MailControlThreadListItem] {
        model.threads.map { thread in
            MailControlThreadListItem(
                threadID: thread.id.rawValue,
                accountID: thread.accountID.rawValue,
                subject: thread.subject,
                participantSummary: thread.participantSummary,
                snippet: thread.snippet,
                hasUnread: thread.hasUnread,
                isSelected: model.selectedThreadID == thread.id,
                isStarred: thread.isStarred,
                attachmentCount: thread.attachmentCount,
                lastActivityAt: thread.lastActivityAt
            )
        }
    }

    private func selectedThreadSnapshot(in model: WindowModel) async throws -> MailControlThreadSnapshot? {
        guard let threadID = model.selectedThreadID ?? model.hoveredThreadID else {
            return nil
        }
        guard let detail = try await model.resolveThreadDetail(threadID: threadID) else {
            return nil
        }
        return snapshot(for: detail)
    }

    private func snapshot(for detail: MailThreadDetail) -> MailControlThreadSnapshot {
        MailControlThreadSnapshot(
            threadID: detail.thread.id.rawValue,
            subject: detail.thread.subject,
            participantSummary: detail.thread.participantSummary,
            snippet: detail.thread.snippet,
            messageCount: detail.messages.count,
            messages: detail.messages.map { message in
                MailControlMessageSnapshot(
                    id: message.id.rawValue,
                    sender: message.sender.displayName,
                    sentAt: message.sentAt ?? message.receivedAt,
                    snippet: message.snippet,
                    plainBody: message.plainBody
                )
            }
        )
    }

    private func snapshot(for draft: OutgoingDraft, composeMode: ComposeMode?) -> MailControlDraftSnapshot {
        MailControlDraftSnapshot(
            draftID: draft.id,
            replyMode: draft.replyMode.rawValue,
            subject: draft.subject,
            toRecipients: draft.toRecipients.map(\.emailAddress),
            body: draft.plainBody,
            composeMode: composeMode.map(composeModeLabel(for:))
        )
    }

    private func composeModeLabel(for mode: ComposeMode) -> String {
        switch mode {
        case .inline:
            return "inline"
        case .floating:
            return "floating"
        case .fullscreen:
            return "fullscreen"
        }
    }
}
