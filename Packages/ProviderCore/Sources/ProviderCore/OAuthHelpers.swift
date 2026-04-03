import Foundation

public func formURLEncodedBody(_ values: [String: String]) -> Data {
    let body = values
        .sorted { $0.key < $1.key }
        .map { key, value in
            "\(formURLEncodedComponent(key))=\(formURLEncodedComponent(value))"
        }
        .joined(separator: "&")
    return Data(body.utf8)
}

public func formURLEncodedComponent(_ value: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
    return value
        .addingPercentEncoding(withAllowedCharacters: allowed)?
        .replacingOccurrences(of: "%20", with: "+")
        ?? value
}

/// Thread-safe one-shot guard for OAuth callbacks that may fire more than once.
public final class SingleResumeGuard: @unchecked Sendable {
    private var acquired = false
    private let lock = NSLock()

    public init() {}

    public func tryAcquire() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard acquired == false else { return false }
        acquired = true
        return true
    }
}
