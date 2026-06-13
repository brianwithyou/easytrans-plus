import Foundation

struct CloudAccount: Codable, Equatable, Sendable {
    var email: String
    var planName: String
    var dailyQuota: Int?
    var dailyUsed: Int?

    var quotaSummary: String? {
        guard let dailyQuota else { return nil }
        let used = dailyUsed ?? 0
        return "今日用量 \(used) / \(dailyQuota) 字符"
    }
}

struct AuthResponse: Decodable, Sendable {
    let token: String
    let refreshToken: String?
    let user: AuthUserPayload?

    struct AuthUserPayload: Decodable, Sendable {
        let email: String?
        let planName: String?
        let dailyQuota: Int?
        let dailyUsed: Int?
    }

    func toCloudAccount(fallbackEmail: String) -> CloudAccount {
        CloudAccount(
            email: user?.email ?? fallbackEmail,
            planName: user?.planName ?? "标准版",
            dailyQuota: user?.dailyQuota,
            dailyUsed: user?.dailyUsed
        )
    }
}

struct SendCodeResponse: Decodable, Sendable {
    let success: Bool?
}

struct MeResponse: Decodable, Sendable {
    let email: String?
    let planName: String?
    let dailyQuota: Int?
    let dailyUsed: Int?

    func toCloudAccount(fallbackEmail: String) -> CloudAccount {
        CloudAccount(
            email: email ?? fallbackEmail,
            planName: planName ?? "标准版",
            dailyQuota: dailyQuota,
            dailyUsed: dailyUsed
        )
    }
}
