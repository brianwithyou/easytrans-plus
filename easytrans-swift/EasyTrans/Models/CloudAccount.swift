import Foundation

struct CloudAccount: Codable, Equatable, Sendable {
    var email: String
    var planName: String
    var dailyQuota: Int?
    var dailyUsed: Int?
    var planExpiresAt: String?
    var paidPlanActive: Bool?
    var requiresPurchase: Bool?

    var quotaSummary: String? {
        if requiresPurchase == true {
            return "请先购买基础版后使用云端翻译"
        }
        guard let dailyQuota else { return nil }
        let used = dailyUsed ?? 0
        return "今日用量 \(used) / \(dailyQuota) 字符"
    }

    var planExpirySummary: String? {
        if requiresPurchase == true {
            return "未开通基础版"
        }
        guard let planExpiresAt, !planExpiresAt.isEmpty else { return nil }
        if paidPlanActive == true {
            return "有效期至 \(Self.formatPlanExpiry(planExpiresAt))"
        }
        return "已到期，请续费"
    }

    private static func formatPlanExpiry(_ raw: String) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) ?? ISO8601DateFormatter().date(from: raw) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            return formatter.string(from: date)
        }
        return String(raw.prefix(16).replacingOccurrences(of: "T", with: " "))
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
        let planExpiresAt: String?
        let paidPlanActive: Bool?
        let requiresPurchase: Bool?
    }

    func toCloudAccount(fallbackEmail: String) -> CloudAccount {
        CloudAccount(
            email: user?.email ?? fallbackEmail,
            planName: user?.planName ?? "基础版",
            dailyQuota: user?.dailyQuota,
            dailyUsed: user?.dailyUsed,
            planExpiresAt: user?.planExpiresAt,
            paidPlanActive: user?.paidPlanActive,
            requiresPurchase: user?.requiresPurchase
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
    let planExpiresAt: String?
    let paidPlanActive: Bool?
    let requiresPurchase: Bool?

    func toCloudAccount(fallbackEmail: String) -> CloudAccount {
        CloudAccount(
            email: email ?? fallbackEmail,
            planName: planName ?? "基础版",
            dailyQuota: dailyQuota,
            dailyUsed: dailyUsed,
            planExpiresAt: planExpiresAt,
            paidPlanActive: paidPlanActive,
            requiresPurchase: requiresPurchase
        )
    }
}

struct BillingConfigResponse: Decodable, Sendable {
    let enabled: Bool
    let mode: String?
    let products: [BillingProduct]?

    var isPaidMode: Bool {
        mode == "paid" || enabled
    }

    struct BillingProduct: Decodable, Sendable, Identifiable {
        let variantId: String
        let planName: String?
        let dailyQuota: Int?
        let durationDays: Int?
        let label: String?

        var id: String { variantId }

        var displayLabel: String {
            if let label, !label.isEmpty { return label }
            let name = planName ?? "基础版"
            let days = durationDays ?? 30
            return "\(name)（\(days)天）"
        }
    }
}

struct BillingCheckoutResponse: Decodable, Sendable {
    let checkoutUrl: String
    let variantId: String?
    let label: String?
}
