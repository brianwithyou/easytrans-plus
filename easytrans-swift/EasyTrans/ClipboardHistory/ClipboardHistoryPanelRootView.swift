import AppKit
import Carbon.HIToolbox

/// 可成为 key 窗口的浮层，用于承载搜索框键盘输入。
final class ClipboardHistoryPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// 不让 SwiftUI 宿主视图参与焦点环，避免抢走搜索框光标。
private final class ClipboardHistoryHostingContainer: NSView {
    override var acceptsFirstResponder: Bool { false }
}

/// 剪贴板历史 panel 根视图：搜索框作为 AppKit 原生子视图，避免 SwiftUI 嵌套导致无法显示插入光标。
@MainActor
final class ClipboardHistoryPanelRootView: NSView, NSSearchFieldDelegate {
    static let searchBarHeight: CGFloat = 52

    let searchField = ClipboardHistorySearchField()
    private let hostingContainer = ClipboardHistoryHostingContainer()

    var onPrepareForInput: (() -> Void)?

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        searchField.placeholderString = "搜索剪贴板历史…"
        searchField.sendsSearchStringImmediately = true
        searchField.focusRingType = .default
        searchField.isBordered = true
        searchField.isBezeled = true
        searchField.isEditable = true
        searchField.isSelectable = true
        searchField.delegate = self
        searchField.onPrepareForInput = { [weak self] in
            self?.onPrepareForInput?()
        }
        addSubview(searchField)

        addSubview(hostingContainer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func installHostingView(_ view: NSView) {
        view.frame = hostingContainer.bounds
        view.autoresizingMask = [.width, .height]
        hostingContainer.addSubview(view)
        needsLayout = true
    }

    func setSearchVisible(_ visible: Bool) {
        searchField.isHidden = !visible
        needsLayout = true
    }

    override func layout() {
        super.layout()

        let searchAreaHeight = searchField.isHidden ? 0 : Self.searchBarHeight
        if searchAreaHeight > 0 {
            searchField.frame = NSRect(
                x: 16,
                y: 12,
                width: max(0, bounds.width - 32),
                height: 28
            )
        }

        hostingContainer.frame = NSRect(
            x: 0,
            y: searchAreaHeight,
            width: bounds.width,
            height: max(0, bounds.height - searchAreaHeight)
        )

        searchField.nextKeyView = hostingContainer
        hostingContainer.nextKeyView = searchField
    }

    func syncSearchFieldFromStore() {
        let query = ClipboardHistoryStore.shared.searchFilter
        guard searchField.stringValue != query else { return }
        searchField.stringValue = query
        searchField.placeInsertionCaretAtEnd()
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSSearchField else { return }
        ClipboardHistoryStore.shared.searchFilter = field.stringValue
    }
}

@MainActor
final class ClipboardHistorySearchField: NSSearchField {
    var onPrepareForInput: (() -> Void)?
    var onEscape: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        onPrepareForInput?()
        window?.makeKey()
        super.mouseDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            onEscape?()
            return
        }
        super.keyDown(with: event)
    }

    override var acceptsFirstResponder: Bool { true }

    func placeInsertionCaretAtEnd() {
        let length = (stringValue as NSString).length
        if let editor = currentEditor() {
            editor.selectedRange = NSRange(location: length, length: 0)
        }
    }
}
