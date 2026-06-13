import AppKit
import Carbon.HIToolbox
import Foundation
import SwiftUI

struct KeyboardShortcut: Codable, Equatable, Hashable, Sendable {
    var keyCode: UInt16
    var command: Bool
    var shift: Bool
    var option: Bool
    var control: Bool

    static let translateDefault = KeyboardShortcut(
        keyCode: UInt16(kVK_ANSI_D),
        command: true,
        shift: true,
        option: false,
        control: false
    )

    static let clipboardHistoryDefault = KeyboardShortcut(
        keyCode: UInt16(kVK_ANSI_V),
        command: true,
        shift: true,
        option: false,
        control: false
    )

    /// 系统设置窗口（⌘ ,）
    static let openSettings = KeyboardShortcut(
        keyCode: UInt16(kVK_ANSI_Comma),
        command: true,
        shift: false,
        option: false,
        control: false
    )

    var hasModifier: Bool {
        command || shift || option || control
    }

    var carbonModifierFlags: UInt32 {
        var flags: UInt32 = 0
        if command { flags |= UInt32(cmdKey) }
        if shift { flags |= UInt32(shiftKey) }
        if option { flags |= UInt32(optionKey) }
        if control { flags |= UInt32(controlKey) }
        return flags
    }

    var displayParts: [String] {
        var parts: [String] = []
        if control { parts.append("⌃") }
        if option { parts.append("⌥") }
        if shift { parts.append("⇧") }
        if command { parts.append("⌘") }
        parts.append(keyDisplayName)
        return parts
    }

    var displayString: String {
        displayParts.joined(separator: " ")
    }

    var swiftUIKeyEquivalent: KeyEquivalent {
        switch Int(keyCode) {
        case kVK_Return: return .return
        case kVK_Tab: return .tab
        case kVK_Space: return .space
        case kVK_Escape: return .escape
        case kVK_Delete: return .delete
        case kVK_ForwardDelete: return .deleteForward
        case kVK_LeftArrow: return .leftArrow
        case kVK_RightArrow: return .rightArrow
        case kVK_UpArrow: return .upArrow
        case kVK_DownArrow: return .downArrow
        case kVK_ANSI_Comma: return KeyEquivalent(",")
        default:
            let name = keyDisplayName
            if name.count == 1, let char = name.first {
                return KeyEquivalent(char)
            }
            return KeyEquivalent(" ")
        }
    }

    var swiftUIModifiers: SwiftUI.EventModifiers {
        var modifiers: SwiftUI.EventModifiers = []
        if command { modifiers.insert(.command) }
        if shift { modifiers.insert(.shift) }
        if option { modifiers.insert(.option) }
        if control { modifiers.insert(.control) }
        return modifiers
    }

    func matches(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard event.keyCode == keyCode else { return false }
        return flags.contains(.command) == command
            && flags.contains(.shift) == shift
            && flags.contains(.option) == option
            && flags.contains(.control) == control
    }

    func matches(_ event: CGEvent) -> Bool {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        guard keyCode == self.keyCode else { return false }
        let flags = event.flags
        return flags.contains(.maskCommand) == command
            && flags.contains(.maskShift) == shift
            && flags.contains(.maskAlternate) == option
            && flags.contains(.maskControl) == control
    }

    func validationError(conflictingWith other: KeyboardShortcut?) -> String? {
        if keyCode == 0 || !hasModifier {
            return "请至少按下一个修饰键和主键"
        }
        if let other, self == other {
            return "与另一快捷键冲突"
        }
        return nil
    }

    static func from(event: NSEvent) -> KeyboardShortcut {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return KeyboardShortcut(
            keyCode: event.keyCode,
            command: flags.contains(.command),
            shift: flags.contains(.shift),
            option: flags.contains(.option),
            control: flags.contains(.control)
        )
    }

    private var keyDisplayName: String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_ANSI_Comma: return ","
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Escape: return "Esc"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default:
            if let scalar = keyCodeToUnicodeScalar(keyCode) {
                return String(scalar).uppercased()
            }
            return "Key\(keyCode)"
        }
    }

    private func keyCodeToUnicodeScalar(_ code: UInt16) -> UnicodeScalar? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let data = unsafeBitCast(layoutData, to: CFData.self) as Data
        guard data.count >= 256 else { return nil }

        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        let error = UCKeyTranslate(
            data.withUnsafeBytes { $0.baseAddress!.assumingMemoryBound(to: UCKeyboardLayout.self) },
            UInt16(code),
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            4,
            &length,
            &chars
        )
        guard error == noErr, length > 0, let scalar = UnicodeScalar(chars[0]) else {
            return nil
        }
        return scalar
    }
}

extension Notification.Name {
    static let keyboardShortcutsDidChange = Notification.Name("keyboardShortcutsDidChange")
}

enum KeyboardShortcutPersistence {
    private enum Keys {
        static let translate = "hotkey.translate"
        static let clipboardHistory = "hotkey.clipboardHistory"
    }

    static func translateShortcut() -> KeyboardShortcut {
        load(key: Keys.translate) ?? .translateDefault
    }

    static func clipboardHistoryShortcut() -> KeyboardShortcut {
        load(key: Keys.clipboardHistory) ?? .clipboardHistoryDefault
    }

    static func saveTranslate(_ shortcut: KeyboardShortcut) {
        save(key: Keys.translate, shortcut: shortcut)
        postChange()
    }

    static func saveClipboardHistory(_ shortcut: KeyboardShortcut) {
        save(key: Keys.clipboardHistory, shortcut: shortcut)
        postChange()
    }

    private static func load(key: String) -> KeyboardShortcut? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(KeyboardShortcut.self, from: data)
    }

    private static func save(key: String, shortcut: KeyboardShortcut) {
        guard let data = try? JSONEncoder().encode(shortcut) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func postChange() {
        NotificationCenter.default.post(name: .keyboardShortcutsDidChange, object: nil)
    }
}

@MainActor
final class KeyboardShortcutSettings: ObservableObject {
    static let shared = KeyboardShortcutSettings()

    @Published var translateShortcut: KeyboardShortcut {
        didSet {
            guard translateShortcut != oldValue else { return }
            KeyboardShortcutPersistence.saveTranslate(translateShortcut)
        }
    }

    @Published var clipboardHistoryShortcut: KeyboardShortcut {
        didSet {
            guard clipboardHistoryShortcut != oldValue else { return }
            KeyboardShortcutPersistence.saveClipboardHistory(clipboardHistoryShortcut)
        }
    }

    private init() {
        translateShortcut = KeyboardShortcutPersistence.translateShortcut()
        clipboardHistoryShortcut = KeyboardShortcutPersistence.clipboardHistoryShortcut()
    }

    func resetTranslateShortcut() {
        translateShortcut = .translateDefault
    }

    func resetClipboardHistoryShortcut() {
        clipboardHistoryShortcut = .clipboardHistoryDefault
    }
}
