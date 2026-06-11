import Foundation

enum TranslationMode: String, CaseIterable, Identifiable, Sendable {
    case byok
    case cloud

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .byok: return "自备 API Key"
        case .cloud: return "云端服务"
        }
    }

    var configurationHint: String {
        switch self {
        case .byok: return "未配置 API Key"
        case .cloud: return "未登录云端服务"
        }
    }
}
