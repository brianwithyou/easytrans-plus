import Foundation
import NaturalLanguage

enum Language: String, CaseIterable, Identifiable, Sendable {
    case auto = "auto"
    case chinese = "zh"
    case english = "en"
    case japanese = "ja"
    case korean = "ko"
    case french = "fr"
    case german = "de"
    case spanish = "es"
    case russian = "ru"
    case arabic = "ar"
    case vietnamese = "vi"

    var id: String { rawValue }

    /// 用户可选的目标语言（不含自动检测与英语）。
    static var selectableTargets: [Language] {
        allCases.filter { $0 != .auto && $0 != .english }
    }

    var nlLanguage: NLLanguage? {
        switch self {
        case .auto: return nil
        case .chinese: return .simplifiedChinese
        case .english: return .english
        case .japanese: return .japanese
        case .korean: return .korean
        case .french: return .french
        case .german: return .german
        case .spanish: return .spanish
        case .russian: return .russian
        case .arabic: return .arabic
        case .vietnamese: return .vietnamese
        }
    }

    var displayName: String {
        switch self {
        case .auto: return "自动检测"
        case .chinese: return "中文"
        case .english: return "英语"
        case .japanese: return "日语"
        case .korean: return "韩语"
        case .french: return "法语"
        case .german: return "德语"
        case .spanish: return "西班牙语"
        case .russian: return "俄语"
        case .arabic: return "阿拉伯语"
        case .vietnamese: return "越南语"
        }
    }

    var promptName: String {
        switch self {
        case .auto: return "目标语言"
        case .chinese: return "中文"
        case .english: return "英语"
        case .japanese: return "日语"
        case .korean: return "韩语"
        case .french: return "法语"
        case .german: return "德语"
        case .spanish: return "西班牙语"
        case .russian: return "俄语"
        case .arabic: return "阿拉伯语"
        case .vietnamese: return "越南语"
        }
    }
}
