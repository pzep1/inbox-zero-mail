import Foundation
import Network

let defaultControlPort: UInt16 = 61432

struct ControlPlaneInfo: Decodable {
    var pid: Int32
    var port: UInt16
    var token: String
}

struct ControlRequest: Encodable {
    var authToken: String
    var action: String
    var windowID: String?
    var value: String?
    var index: Int?
    var text: String?
}

struct ControlResponse: Decodable, Encodable {
    var ok: Bool
    var message: String?
    var windows: [WindowSnapshot]?
    var window: WindowSnapshot?
    var snapshot: WindowStateSnapshot?
    var threadItems: [ThreadListItem]?
    var thread: ThreadSnapshot?
    var draft: DraftSnapshot?
}

struct WindowSnapshot: Codable {
    var windowID: String
    var isActive: Bool
    var selectedTab: String
    var selectedSplitInboxID: String
    var selectedSplitInboxTitle: String
    var searchText: String
    var selectedThreadID: String?
    var selectedThreadSubject: String?
    var composeMode: String?
    var threadCount: Int
}

struct ThreadSnapshot: Codable {
    var threadID: String
    var subject: String
    var participantSummary: String
    var snippet: String
    var messageCount: Int
    var messages: [MessageSnapshot]
}

struct ThreadListItem: Codable {
    var threadID: String
    var accountID: String
    var subject: String
    var participantSummary: String
    var snippet: String
    var hasUnread: Bool
    var isSelected: Bool
    var isStarred: Bool
    var attachmentCount: Int
    var lastActivityAt: Date?
}

struct MessageSnapshot: Codable {
    var id: String
    var sender: String
    var sentAt: Date?
    var snippet: String
    var plainBody: String?
}

struct DraftSnapshot: Codable {
    var draftID: UUID
    var replyMode: String
    var subject: String
    var toRecipients: [String]
    var body: String
    var composeMode: String?
}

struct WindowStateSnapshot: Codable {
    var window: WindowSnapshot
    var visibleThreads: [ThreadListItem]
    var selectedThread: ThreadSnapshot?
    var draft: DraftSnapshot?
}

enum CLIError: LocalizedError {
    case usage(String)
    case invalidPort(UInt16)
    case requestFailed(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .usage(let message):
            return message
        case .invalidPort(let port):
            return "Invalid control plane port \(port)."
        case .requestFailed(let message):
            return message
        case .transport(let message):
            return message
        }
    }
}

@main
struct InboxControlCLI {
    static func main() async {
        do {
            let invocation = try parseInvocation(arguments: Array(CommandLine.arguments.dropFirst()))
            let response = try await ControlClient().send(invocation.request)
            if invocation.json {
                try printJSON(response)
            } else {
                print(render(response: response))
            }
            Foundation.exit(response.ok ? 0 : 1)
        } catch {
            fputs("error: \(error.localizedDescription)\n", stderr)
            if case CLIError.usage = error {
                fputs("\(usage)\n", stderr)
            }
            Foundation.exit(1)
        }
    }

    static let usage = """
    Usage:
      inboxctl windows list [--json]
      inboxctl window snapshot [--window <id>] [--json]
      inboxctl view tab <all|unread|starred|snoozed> [--window <id>] [--json]
      inboxctl view split-inbox <item> [--window <id>] [--json]
      inboxctl search <query> [--window <id>] [--json]
      inboxctl thread list [--window <id>] [--json]
      inboxctl thread current [--window <id>] [--json]
      inboxctl thread open <thread-id> [--window <id>] [--json]
      inboxctl thread open-visible <index> [--window <id>] [--json]
      inboxctl thread read --visible <index> [--window <id>] [--json]
      inboxctl draft reply [--mode <reply|replyAll|forward|new>] [--window <id>] [--json]
      inboxctl draft reply [--thread <id> | --visible <index>] [--mode <reply|replyAll|forward|new>] [--window <id>] [--json]
      inboxctl draft show [--window <id>] [--json]
      inboxctl draft set-body <text> [--window <id>] [--json]
      inboxctl draft set-subject <text> [--window <id>] [--json]
    """

    struct Invocation {
        var request: ControlRequest
        var json: Bool
    }

    static func parseInvocation(arguments: [String]) throws -> Invocation {
        var json = false
        var windowID: String? = nil
        var remaining: [String] = []
        var index = 0

        while index < arguments.count {
            let arg = arguments[index]
            if arg == "--json" {
                json = true
                index += 1
                continue
            }
            if arg == "--window" {
                let nextIndex = index + 1
                guard arguments.indices.contains(nextIndex) else {
                    throw CLIError.usage("Missing value for --window.")
                }
                windowID = arguments[nextIndex]
                index += 2
                continue
            }
            remaining.append(arg)
            index += 1
        }

        guard let command = remaining.first else {
            throw CLIError.usage("Missing command.")
        }

        let request: ControlRequest

        switch command {
        case "windows":
            guard remaining.dropFirst().first == "list" else {
                throw CLIError.usage("Expected 'windows list'.")
            }
            request = ControlRequest(authToken: "", action: "list-windows", windowID: windowID, value: nil, index: nil, text: nil)

        case "window":
            guard remaining.dropFirst().first == "snapshot" else {
                throw CLIError.usage("Expected 'window snapshot'.")
            }
            request = ControlRequest(authToken: "", action: "window-snapshot", windowID: windowID, value: nil, index: nil, text: nil)

        case "view":
            guard remaining.count >= 3 else {
                throw CLIError.usage("Expected 'view tab <tab>' or 'view split-inbox <item>'.")
            }
            let mode = remaining[1]
            let value = remaining[2...].joined(separator: " ")
            switch mode {
            case "tab":
                request = ControlRequest(authToken: "", action: "show-tab", windowID: windowID, value: value, index: nil, text: nil)
            case "split-inbox":
                request = ControlRequest(authToken: "", action: "show-split-inbox", windowID: windowID, value: value, index: nil, text: nil)
            default:
                throw CLIError.usage("Unknown view mode '\(mode)'.")
            }

        case "search":
            guard remaining.count >= 2 else {
                throw CLIError.usage("Expected 'search <query>'.")
            }
            request = ControlRequest(authToken: "", action: "search", windowID: windowID, value: nil, index: nil, text: remaining.dropFirst().joined(separator: " "))

        case "thread":
            guard remaining.count >= 2 else {
                throw CLIError.usage("Expected 'thread list', 'thread current', 'thread open <id>', 'thread open-visible <index>', or 'thread read --visible <index>'.")
            }
            switch remaining[1] {
            case "list":
                request = ControlRequest(authToken: "", action: "list-threads", windowID: windowID, value: nil, index: nil, text: nil)
            case "current":
                request = ControlRequest(authToken: "", action: "current-thread", windowID: windowID, value: nil, index: nil, text: nil)
            case "open":
                guard remaining.count >= 3 else {
                    throw CLIError.usage("Expected 'thread open <id>'.")
                }
                request = ControlRequest(authToken: "", action: "open-thread", windowID: windowID, value: remaining[2], index: nil, text: nil)
            case "open-visible":
                guard remaining.count >= 3, let index = Int(remaining[2]), index > 0 else {
                    throw CLIError.usage("Expected 'thread open-visible <positive-index>'.")
                }
                request = ControlRequest(authToken: "", action: "open-visible-thread", windowID: windowID, value: nil, index: index, text: nil)
            case "read":
                let visibleValue = try parseOption(named: "--visible", in: remaining)
                guard let visibleValue, let index = Int(visibleValue), index > 0 else {
                    throw CLIError.usage("Expected 'thread read --visible <positive-index>'.")
                }
                request = ControlRequest(authToken: "", action: "read-visible-thread", windowID: windowID, value: nil, index: index, text: nil)
            default:
                throw CLIError.usage("Unknown thread subcommand '\(remaining[1])'.")
            }

        case "draft":
            guard remaining.count >= 2 else {
                throw CLIError.usage("Expected a draft subcommand.")
            }
            switch remaining[1] {
            case "reply":
                let mode = try parseOption(named: "--mode", in: remaining) ?? "reply"
                let threadID = try parseOption(named: "--thread", in: remaining)
                let visibleValue = try parseOption(named: "--visible", in: remaining)
                let visibleIndex = visibleValue.flatMap(Int.init)
                if visibleValue != nil, visibleIndex == nil {
                    throw CLIError.usage("Expected '--visible <positive-index>'.")
                }
                if let visibleIndex, visibleIndex <= 0 {
                    throw CLIError.usage("Expected '--visible <positive-index>'.")
                }
                if threadID != nil, visibleIndex != nil {
                    throw CLIError.usage("Use only one of '--thread <id>' or '--visible <index>'.")
                }
                request = ControlRequest(authToken: "", action: "open-draft", windowID: windowID, value: mode, index: visibleIndex, text: threadID)
            case "show":
                request = ControlRequest(authToken: "", action: "current-draft", windowID: windowID, value: nil, index: nil, text: nil)
            case "set-body":
                guard remaining.count >= 3 else {
                    throw CLIError.usage("Expected 'draft set-body <text>'.")
                }
                request = ControlRequest(authToken: "", action: "set-draft-body", windowID: windowID, value: nil, index: nil, text: remaining.dropFirst(2).joined(separator: " "))
            case "set-subject":
                guard remaining.count >= 3 else {
                    throw CLIError.usage("Expected 'draft set-subject <text>'.")
                }
                request = ControlRequest(authToken: "", action: "set-draft-subject", windowID: windowID, value: nil, index: nil, text: remaining.dropFirst(2).joined(separator: " "))
            default:
                throw CLIError.usage("Unknown draft subcommand '\(remaining[1])'.")
            }

        default:
            throw CLIError.usage("Unknown command '\(command)'.")
        }

        return Invocation(request: request, json: json)
    }

    static func parseOption(named name: String, in arguments: [String]) throws -> String? {
        guard let index = arguments.firstIndex(of: name) else { return nil }
        let nextIndex = index + 1
        guard arguments.indices.contains(nextIndex) else {
            throw CLIError.usage("Missing value for \(name).")
        }
        return arguments[nextIndex]
    }

    static func printJSON<T: Encodable>(_ value: T) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        if let string = String(data: data, encoding: .utf8) {
            print(string)
        }
    }

    static func render(response: ControlResponse) -> String {
        if response.ok == false {
            return response.message ?? "Request failed."
        }

        if let windows = response.windows {
            if windows.isEmpty {
                return "No windows."
            }
            return windows.map { window in
                let marker = window.isActive ? "*" : " "
                let subject = window.selectedThreadSubject ?? "no thread selected"
                let searchSuffix = window.searchText.isEmpty ? "" : " search='\(window.searchText)'"
                return "\(marker) \(window.windowID) tab=\(window.selectedTab) split='\(window.selectedSplitInboxTitle)' threads=\(window.threadCount) subject='\(subject)'\(searchSuffix)"
            }.joined(separator: "\n")
        }

        if let snapshot = response.snapshot {
            var sections: [String] = []
            sections.append(renderWindow(snapshot.window))
            if let selectedThread = snapshot.selectedThread {
                sections.append(renderThread(selectedThread))
            }
            if let draft = snapshot.draft {
                sections.append(renderDraft(draft))
            }
            if snapshot.visibleThreads.isEmpty {
                sections.append("visible threads: none")
            } else {
                sections.append("visible threads:")
                sections.append(renderThreadItems(snapshot.visibleThreads))
            }
            return sections.joined(separator: "\n")
        }

        if let window = response.window {
            return renderWindow(window)
        }

        if let threadItems = response.threadItems {
            if threadItems.isEmpty {
                return "No visible threads."
            }
            return renderThreadItems(threadItems)
        }

        if let thread = response.thread {
            return renderThread(thread)
        }

        if let draft = response.draft {
            return renderDraft(draft)
        }

        return response.message ?? "ok"
    }

    static func renderWindow(_ window: WindowSnapshot) -> String {
        let subject = window.selectedThreadSubject ?? "no thread selected"
        let searchSuffix = window.searchText.isEmpty ? "" : " search='\(window.searchText)'"
        return "window \(window.windowID) tab=\(window.selectedTab) split='\(window.selectedSplitInboxTitle)' threads=\(window.threadCount) subject='\(subject)'\(searchSuffix)"
    }

    static func renderThreadItems(_ threadItems: [ThreadListItem]) -> String {
        threadItems.enumerated().map { index, item in
            let unreadMarker = item.hasUnread ? "*" : " "
            let selectedMarker = item.isSelected ? ">" : " "
            let starMarker = item.isStarred ? "★" : ""
            let attachmentSuffix = item.attachmentCount > 0 ? " att=\(item.attachmentCount)" : ""
            let timeSuffix: String
            if let lastActivityAt = item.lastActivityAt {
                timeSuffix = " \(lastActivityAt.formatted(date: .numeric, time: .shortened))"
            } else {
                timeSuffix = ""
            }
            return "\(index + 1).\(selectedMarker)\(unreadMarker)\(starMarker) \(item.threadID) \(item.subject)\(attachmentSuffix)\(timeSuffix) — \(item.snippet)"
        }.joined(separator: "\n")
    }

    static func renderThread(_ thread: ThreadSnapshot) -> String {
        let latestBody = thread.messages.last?.plainBody ?? thread.messages.last?.snippet ?? ""
        return """
        thread \(thread.threadID)
        subject: \(thread.subject)
        participants: \(thread.participantSummary)
        messages: \(thread.messageCount)
        body:
        \(latestBody)
        """
    }

    static func renderDraft(_ draft: DraftSnapshot) -> String {
        let recipients = draft.toRecipients.joined(separator: ", ")
        return """
        draft \(draft.draftID.uuidString)
        mode: \(draft.replyMode)
        to: \(recipients)
        subject: \(draft.subject)
        body:
        \(draft.body)
        """
    }

}

final class ControlClient {
    func send(_ request: ControlRequest) async throws -> ControlResponse {
        let portNumber = try resolvePort()
        guard let port = NWEndpoint.Port(rawValue: portNumber) else {
            throw CLIError.invalidPort(portNumber)
        }

        var authenticatedRequest = request
        authenticatedRequest.authToken = ""

        let connection = NWConnection(host: "127.0.0.1", port: port, using: .tcp)
        let encoder = JSONEncoder()
        let data = try encoder.encode(authenticatedRequest)

        return try await withCheckedThrowingContinuation { continuation in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: data, contentContext: .defaultMessage, isComplete: true, completion: .contentProcessed { error in
                        if let error {
                            continuation.resume(throwing: CLIError.transport(error.localizedDescription))
                            connection.cancel()
                            return
                        }
                    })
                    Self.receive(on: connection, buffer: Data(), continuation: continuation)
                case .failed(let error):
                    continuation.resume(throwing: CLIError.transport(error.localizedDescription))
                    connection.cancel()
                default:
                    break
                }
            }
            connection.start(queue: .global(qos: .userInitiated))
        }
    }

    private static func receive(
        on connection: NWConnection,
        buffer: Data,
        continuation: CheckedContinuation<ControlResponse, Error>
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, isComplete, error in
            if let error {
                continuation.resume(throwing: CLIError.transport(error.localizedDescription))
                connection.cancel()
                return
            }

            var accumulated = buffer
            if let data {
                accumulated.append(data)
            }

            if accumulated.isEmpty == false {
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let response = try decoder.decode(ControlResponse.self, from: accumulated)
                    if response.ok == false {
                        continuation.resume(throwing: CLIError.requestFailed(response.message ?? "Request failed."))
                    } else {
                        continuation.resume(returning: response)
                    }
                } catch {
                    continuation.resume(throwing: CLIError.transport("Could not decode response: \(error.localizedDescription)"))
                }
                connection.cancel()
            } else if isComplete {
                continuation.resume(throwing: CLIError.transport("Received an empty response from the app."))
                connection.cancel()
            } else {
                receive(on: connection, buffer: accumulated, continuation: continuation)
            }
        }
    }

    private func resolvePort() throws -> UInt16 {
        if let value = ProcessInfo.processInfo.environment["INBOX_ZERO_CONTROL_PORT"],
           let port = UInt16(value) {
            return port
        }
        return defaultControlPort
    }
}
