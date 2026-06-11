import AppKit
import ApplicationServices

enum AccessibilityHelper {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    static var executablePath: String {
        Bundle.main.executablePath ?? Bundle.main.bundlePath
    }

    static var bundlePath: String {
        Bundle.main.bundlePath
    }

    /// Xcode 默认 DerivedData 路径，每次编译后授权容易失效。
    static var isRunningFromDerivedData: Bool {
        bundlePath.contains("/DerivedData/")
    }

    /// 项目内固定构建输出路径（build/Debug），授权可长期保留。
    static var isStableProjectBuild: Bool {
        bundlePath.contains("/build/Debug/") || bundlePath.contains("/build/Release/")
    }

    static func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: bundlePath)])
    }

    @discardableResult
    static func requestPermission() -> Bool {
        if AXIsProcessTrusted() { return true }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 通过辅助功能 API 读取指定应用中焦点控件的选中文字
    static func selectedText(processID: pid_t) -> String? {
        let appElement = AXUIElementCreateApplication(processID)
        AXUIElementSetMessagingTimeout(appElement, 0.5)

        if let text = selectedTextFromFocusedElement(in: appElement) {
            return text
        }

        if let windows = elementArrayAttribute(appElement, kAXWindowsAttribute) {
            for window in windows {
                if let text = selectedText(inElementTree: window, maxDepth: 12) {
                    return text
                }
            }
        }

        return nil
    }

    /// 读取当前前台应用（非 EasyTrans）的选中文字
    static func selectedTextFromFrontmostOtherApp() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return nil
        }
        return selectedText(processID: app.processIdentifier)
    }

    private static func selectedTextFromFocusedElement(in appElement: AXUIElement) -> String? {
        guard let focusedElement = uiElementAttribute(appElement, kAXFocusedUIElementAttribute) else {
            return nil
        }

        if let text = selectedText(on: focusedElement) {
            return text
        }

        var current: AXUIElement? = focusedElement
        for _ in 0..<8 {
            guard let element = current else { break }
            if let text = selectedText(on: element) {
                return text
            }
            current = uiElementAttribute(element, kAXParentAttribute)
        }

        if let window = uiElementAttribute(focusedElement, kAXWindowAttribute) {
            return selectedText(inElementTree: window, maxDepth: 10)
        }

        return nil
    }

    private static func selectedText(on element: AXUIElement) -> String? {
        if let text = trimmedStringAttribute(element, kAXSelectedTextAttribute) {
            return text
        }
        return selectedTextFromRange(in: element)
    }

    private static func selectedTextFromRange(in element: AXUIElement) -> String? {
        guard let value = stringAttribute(element, kAXValueAttribute), !value.isEmpty else {
            return nil
        }

        guard let rangeValue = copyAttributeValue(element, kAXSelectedTextRangeAttribute),
              CFGetTypeID(rangeValue) == AXValueGetTypeID() else {
            return nil
        }

        var range = CFRange()
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &range), range.length > 0 else {
            return nil
        }

        let nsValue = value as NSString
        guard range.location >= 0, range.location + range.length <= nsValue.length else {
            return nil
        }

        let text = nsValue
            .substring(with: NSRange(location: range.location, length: range.length))
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private static func selectedText(inElementTree root: AXUIElement, maxDepth: Int, depth: Int = 0) -> String? {
        if depth > maxDepth { return nil }

        if let text = selectedText(on: root) {
            return text
        }

        guard let children = elementArrayAttribute(root, kAXChildrenAttribute) else {
            return nil
        }

        for child in children {
            if let text = selectedText(inElementTree: child, maxDepth: maxDepth, depth: depth + 1) {
                return text
            }
        }

        return nil
    }

    private static func trimmedStringAttribute(_ element: AXUIElement, _ name: String) -> String? {
        guard let text = stringAttribute(element, name)?
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
              !text.isEmpty else {
            return nil
        }
        return text
    }

    private static func stringAttribute(_ element: AXUIElement, _ name: String) -> String? {
        copyAttributeValue(element, name) as? String
    }

    private static func uiElementAttribute(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        guard let value = copyAttributeValue(element, name) else { return nil }
        return axUIElement(from: value)
    }

    private static func elementArrayAttribute(_ element: AXUIElement, _ name: String) -> [AXUIElement]? {
        guard let value = copyAttributeValue(element, name) else { return nil }
        let elements = axUIElements(from: value)
        return elements.isEmpty ? nil : elements
    }

    private static func copyAttributeValue(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    /// 新版 SDK 中 `AXUIElement` 是独立结构体，需从底层 `CFTypeRef` 转换。
    private static func axUIElement(from value: CFTypeRef) -> AXUIElement {
        unsafeBitCast(value, to: AXUIElement.self)
    }

    private static func axUIElements(from value: CFTypeRef) -> [AXUIElement] {
        guard let objects = value as? [AnyObject] else {
            return []
        }
        return objects.map { unsafeBitCast($0, to: AXUIElement.self) }
    }
}
