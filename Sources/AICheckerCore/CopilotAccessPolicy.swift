import Foundation

/// The user's declared Copilot billing context. It is NOT inferred from HTTP errors,
/// GitHub login, the presence of a token, or a successful GitHub connection.
/// v1.6.3 defaults to undetermined, including upgrades with saved v1.6 tokens.
public enum CopilotAccessMode: String, Codable, CaseIterable, Sendable {
    case undetermined
    case freeOrNotSubscribed
    case personallyBilled
    case organizationBilled

    public var permitsPersonalBillingAPI: Bool { self == .personallyBilled }

    public var menuLabel: String {
        switch self {
        case .undetermined: return "未確認（API停止）"
        case .freeOrNotSubscribed: return "Copilot Free／個人課金なし（API停止）"
        case .personallyBilled: return "個人購入プラン（個人請求API）"
        case .organizationBilled: return "組織・学校管理（個人請求API停止）"
        }
    }

    public var informationalStatus: String {
        switch self {
        case .undetermined: return "利用区分が未設定です。個人向け請求APIは停止しています"
        case .freeOrNotSubscribed: return "無料／個人課金なしとして設定済み。請求APIは使用しません"
        case .personallyBilled: return "個人請求APIの取得を許可済み（契約の有無は未検証）"
        case .organizationBilled: return "組織・学校管理のため個人請求APIは使用しません"
        }
    }

    public static func restored(_ raw: String?) -> Self {
        guard let raw = raw else { return .undetermined }
        return Self(rawValue: raw) ?? .undetermined
    }
}
