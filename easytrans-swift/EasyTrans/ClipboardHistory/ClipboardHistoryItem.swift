import Foundation

/// 单条剪贴板历史记录，对应 JSON 数组中的一个元素。
/// `preview`、`absoluteTimeText` 为 UI 计算属性，不参与 `Codable` 编解码。
struct ClipboardHistoryItem: Identifiable, Equatable, Hashable, Codable {
    /// 唯一标识，加载持久化文件时保留原 id。
    let id: UUID
    /// 剪贴板纯文本内容。
    let text: String
    /// 复制发生时间（ISO8601 落盘）。
    let copiedAt: Date

    init(id: UUID = UUID(), text: String, copiedAt: Date = Date()) {
        self.id = id
        self.text = text
        self.copiedAt = copiedAt
    }

    /// 列表中展示的文本摘要（单行、最多 120 字符）。
    var preview: String {
        let singleLine = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if singleLine.count <= 120 {
            return singleLine
        }
        return String(singleLine.prefix(117)) + "..."
    }

    /// UI 使用的绝对时间字符串，例如 `2025-06-08 14:30:25`。
    var absoluteTimeText: String {
        Self.absoluteTimeFormatter.string(from: copiedAt)
    }

    private static let absoluteTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
}
