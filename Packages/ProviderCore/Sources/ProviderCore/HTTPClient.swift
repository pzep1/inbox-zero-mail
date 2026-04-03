import Foundation

public struct HTTPClient: Sendable {
    public var session: URLSession
    public var decoder: JSONDecoder
    public var encoder: JSONEncoder

    public init(
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder.providerDefault,
        encoder: JSONEncoder = JSONEncoder.providerDefault
    ) {
        self.session = session
        self.decoder = decoder
        self.encoder = encoder
    }

    public func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw MailProviderError.transport("The provider returned a non-HTTP response.")
        }

        guard (200 ..< 300).contains(response.statusCode) else {
            if response.statusCode == 401 {
                throw MailProviderError.unauthorized
            }
            let body = String(data: data, encoding: .utf8) ?? "<empty>"
            if isRateLimitResponse(statusCode: response.statusCode, body: body) {
                throw MailProviderError.rateLimited(
                    message: "The provider is temporarily rate-limited. We'll retry shortly.",
                    retryAfter: retryAfter(from: response)
                )
            }
            throw MailProviderError.transport("Provider request failed with status \(response.statusCode): \(body)")
        }

        return data
    }

    public func decode<T: Decodable>(_ type: T.Type, from request: URLRequest) async throws -> T {
        let data = try await data(for: request)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw MailProviderError.decoding("Failed to decode \(type): \(error)")
        }
    }
}

private extension HTTPClient {
    func isRateLimitResponse(statusCode: Int, body: String) -> Bool {
        if statusCode == 429 {
            return true
        }

        let normalized = body.lowercased()
        return statusCode == 403 && (
            normalized.contains("ratelimitexceeded") ||
            normalized.contains("rate_limit_exceeded") ||
            normalized.contains("quota exceeded") ||
            normalized.contains("userratelimitexceeded")
        )
    }

    func retryAfter(from response: HTTPURLResponse) -> TimeInterval? {
        guard let rawValue = response.value(forHTTPHeaderField: "Retry-After")?.trimmingCharacters(in: .whitespacesAndNewlines),
              rawValue.isEmpty == false else {
            return nil
        }

        if let seconds = TimeInterval(rawValue) {
            return seconds
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss z"
        guard let retryDate = formatter.date(from: rawValue) else { return nil }
        return max(0, retryDate.timeIntervalSinceNow)
    }
}

extension JSONDecoder {
    public static var providerDefault: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let fractionalSecondsFormatter = ISO8601DateFormatter()
            fractionalSecondsFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let basicFormatter = ISO8601DateFormatter()
            basicFormatter.formatOptions = [.withInternetDateTime]

            if let date = fractionalSecondsFormatter.date(from: value)
                ?? basicFormatter.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected date string to be ISO8601-formatted."
            )
        }
        return decoder
    }
}

extension JSONEncoder {
    public static var providerDefault: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
