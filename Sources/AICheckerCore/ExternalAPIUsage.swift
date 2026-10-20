import Foundation

/// These are billing/analytics reports. They are NEVER consumer-chat quotas.
public enum ExternalAPIKind: String, CaseIterable, Sendable {
    case openaiAPI = "openai-api"
    case cursorTeam = "cursor-team"
    case xaiAPI = "xai-api"

    public var name: String {
        switch self {
        case .openaiAPI: return "OpenAI API"
        case .cursorTeam: return "Cursor Team"
        case .xaiAPI: return "xAI API (Grok)"
        }
    }
    public var scope: String {
        switch self {
        case .openaiAPI: return "OpenAI組織のAPI請求額（当月、USD）"
        case .cursorTeam: return "Cursorチーム全体のAgentリクエスト（当月）"
        case .xaiAPI: return "xAIチームのAPI課金額（当月、USD）"
        }
    }
    public var requiresTeamID: Bool { self == .xaiAPI }
}

public enum ExternalAPIError: Error, Equatable {
    case malformed, incomplete, invalidValue, invalidTeamID
}

public struct ExternalAPIReport: Equatable, Sendable {
    public let kind: ExternalAPIKind
    public let value: Double
    public let observedAt: Date
    public let periodStart: Date
    public let label: String
    public let unit: String
    public init(kind: ExternalAPIKind, value: Double, observedAt: Date,
                periodStart: Date, label: String, unit: String) {
        self.kind = kind; self.value = value; self.observedAt = observedAt
        self.periodStart = periodStart; self.label = label; self.unit = unit
    }
}

public enum ExternalAPIUsage {
    public static func validTeamID(_ id: String) -> Bool {
        // Avoid malicious or unintended URL-path interpolation; UUIDs are the documented team ID.
        UUID(uuidString: id) != nil
    }

    public static func startOfUTCMonth(_ now: Date) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let parts = cal.dateComponents([.year, .month], from: now)
        return cal.date(from: DateComponents(year: parts.year, month: parts.month, day: 1))!
    }

    public static func decode(_ data: Data, kind: ExternalAPIKind,
                              observedAt: Date, periodStart: Date) throws -> ExternalAPIReport {
        guard data.count <= 2_000_000,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ExternalAPIError.malformed
        }
        let value: Double
        let label: String
        let unit: String
        switch kind {
        case .openaiAPI:
            // GET /v1/organization/costs; the endpoint may paginate. Partial totals forbidden.
            guard let hasMore = root["has_more"] as? Bool, !hasMore,
                  let buckets = root["data"] as? [[String: Any]] else {
                throw ExternalAPIError.incomplete
            }
            var total = 0.0
            for bucket in buckets {
                guard let results = bucket["results"] as? [[String: Any]] else {
                    throw ExternalAPIError.malformed
                }
                for result in results {
                    guard let amount = result["amount"] as? [String: Any],
                          amount["currency"] as? String == "usd",
                          let number = amount["value"] as? NSNumber,
                          number.doubleValue.isFinite, number.doubleValue >= 0 else {
                        throw ExternalAPIError.invalidValue
                    }
                    total += number.doubleValue
                }
            }
            value = total; label = "組織API請求額"; unit = "USD"
        case .cursorTeam:
            // POST /teams/daily-usage-data: only agentRequests, not subscriptions or quota.
            guard let days = root["data"] as? [[String: Any]] else {
                throw ExternalAPIError.malformed
            }
            var total = 0.0
            for day in days {
                guard let number = day["agentRequests"] as? NSNumber,
                      number.doubleValue.isFinite, number.doubleValue >= 0,
                      number.doubleValue.rounded() == number.doubleValue else {
                    throw ExternalAPIError.invalidValue
                }
                total += number.doubleValue
            }
            value = total; label = "チームAgent実行数"; unit = "requests"
        case .xaiAPI:
            // POST /v1/billing/teams/{team_id}/usage. No partial `limitReached` result.
            guard let partial = root["limitReached"] as? Bool, !partial,
                  let series = root["timeSeries"] as? [[String: Any]] else {
                throw ExternalAPIError.incomplete
            }
            var total = 0.0
            for item in series {
                guard let points = item["dataPoints"] as? [[String: Any]] else {
                    throw ExternalAPIError.malformed
                }
                for point in points {
                    guard let values = point["values"] as? [NSNumber], values.count == 1,
                          values[0].doubleValue.isFinite, values[0].doubleValue >= 0 else {
                        throw ExternalAPIError.invalidValue
                    }
                    total += values[0].doubleValue
                }
            }
            value = total; label = "チームAPI課金額"; unit = "USD"
        }
        guard value.isFinite && value >= 0 else { throw ExternalAPIError.invalidValue }
        return ExternalAPIReport(kind: kind, value: value, observedAt: observedAt,
                                 periodStart: periodStart, label: label, unit: unit)
    }
}
