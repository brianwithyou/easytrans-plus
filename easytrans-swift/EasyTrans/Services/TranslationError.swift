import Foundation

enum TranslationError: LocalizedError {
    case notConfigured(TranslationMode)
    case notAuthenticated
    case invalidURL
    case httpError(status: Int, message: String)
    case emptyResponse
    case network(Error)
    case quotaExceeded

    var errorDescription: String? {
        switch self {
        case let .notConfigured(mode):
            return mode.configurationHint
        case .notAuthenticated:
            return "云端登录已失效，请重新登录"
        case .invalidURL:
            return "API 地址无效"
        case let .httpError(status, message):
            return "请求失败 (\(status)): \(message)"
        case .emptyResponse:
            return "模型返回内容为空"
        case let .network(error):
            return "网络错误: \(error.localizedDescription)"
        case .quotaExceeded:
            return "今日翻译额度已用尽，请升级套餐或切换为自备 API Key"
        }
    }
}
