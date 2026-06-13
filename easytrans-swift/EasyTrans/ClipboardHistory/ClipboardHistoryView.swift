import AppKit
import SwiftUI

/// 剪贴板历史浮层内容（列表区域）；搜索框由 `ClipboardHistoryPanelRootView` 以 AppKit 方式承载。
struct ClipboardHistoryView: View {
    @ObservedObject var store: ClipboardHistoryStore
    @ObservedObject private var shortcutSettings = KeyboardShortcutSettings.shared
    var onPaste: (ClipboardHistoryItem) -> Void
    var onDismiss: () -> Void

    private var filteredItems: [ClipboardHistoryItem] {
        let query = store.searchFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.items }
        return store.items.filter {
            $0.text.localizedCaseInsensitiveContains(query)
                || $0.preview.localizedCaseInsensitiveContains(query)
        }
    }

    private var isSearching: Bool {
        !store.searchFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if store.items.isEmpty {
                emptyState
            } else if filteredItems.isEmpty {
                noSearchResults
            } else {
                itemList
            }
            Divider()
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack {
            Label("剪贴板历史", systemImage: "doc.on.clipboard")
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
                .symbolRenderingMode(.hierarchical)
            Text("暂无剪贴板记录")
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
            Text("复制一些文字后会自动出现在这里")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    private var noSearchResults: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
                .symbolRenderingMode(.hierarchical)
            Text("未找到匹配记录")
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
            Text("试试其他关键字")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(filteredItems) { item in
                    ClipboardHistoryRow(item: item) {
                        onPaste(item)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("双击条目粘贴到光标处")
                .font(.caption)
                .foregroundStyle(.secondary)

            if isSearching {
                Text("·")
                    .font(.caption)
                    .foregroundStyle(.quaternary)
                Text("\(filteredItems.count) 条结果")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            KeyboardShortcutLabel(
                shortcut: shortcutSettings.clipboardHistoryShortcut,
                keySpacing: 4
            )
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
}

// MARK: - Row

private struct ClipboardHistoryRow: View {
    let item: ClipboardHistoryItem
    let onDoubleClick: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "text.alignleft")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 16, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.preview)
                    .font(.callout)
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(item.absoluteTimeText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovered ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.04))
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { isHovered = $0 }
        .overlay {
            DoubleClickDetector(onDoubleClick: onDoubleClick)
        }
        .help("双击粘贴")
    }
}

/// 铺满 overlay 并接收鼠标事件，避免零尺寸 NSView 吞不掉双击。
private final class ClipboardHistoryClickView: NSView {
    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }
}

/// AppKit-level double-click detection; SwiftUI `onTapGesture(count: 2)` is unreliable inside ScrollView on macOS.
private struct DoubleClickDetector: NSViewRepresentable {
    let onDoubleClick: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDoubleClick: onDoubleClick)
    }

    func makeNSView(context: Context) -> ClipboardHistoryClickView {
        let view = ClipboardHistoryClickView(frame: .zero)
        view.autoresizingMask = [.width, .height]
        let recognizer = NSClickGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleClick)
        )
        recognizer.numberOfClicksRequired = 2
        view.addGestureRecognizer(recognizer)
        return view
    }

    func updateNSView(_ nsView: ClipboardHistoryClickView, context: Context) {
        context.coordinator.onDoubleClick = onDoubleClick
    }

    final class Coordinator: NSObject {
        var onDoubleClick: () -> Void

        init(onDoubleClick: @escaping () -> Void) {
            self.onDoubleClick = onDoubleClick
        }

        @objc func handleDoubleClick() {
            onDoubleClick()
        }
    }
}
