import AppKit
import Carbon.HIToolbox
import SwiftUI

struct ShortcutRecorderView: View {
    @Binding var shortcut: KeyboardShortcut
    let defaultShortcut: KeyboardShortcut
    var conflictChecker: ((KeyboardShortcut) -> String?)?

    @State private var isRecording = false
    @State private var errorMessage: String?
    @State private var eventMonitor: Any?

    var body: some View {
        HStack(spacing: 8) {
            if isRecording {
                Text("按下新快捷键…")
                    .font(.body.monospaced())
                    .frame(minWidth: 72, alignment: .leading)
            } else {
                KeyboardShortcutLabel(shortcut: shortcut, font: .body)
                    .frame(minWidth: 72, alignment: .leading)
            }

            Button(isRecording ? "取消" : "修改") {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }

            if shortcut != defaultShortcut {
                Button("默认") {
                    shortcut = defaultShortcut
                    errorMessage = nil
                }
            }
        }
        .onDisappear {
            stopRecording()
        }
        .overlay(alignment: .bottomLeading) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .offset(y: 18)
            }
        }
    }

    private func startRecording() {
        errorMessage = nil
        isRecording = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                stopRecording()
                return nil
            }

            let captured = KeyboardShortcut.from(event: event)
            if let conflict = conflictChecker?(captured) ?? captured.validationError(conflictingWith: nil) {
                errorMessage = conflict
                return nil
            }

            shortcut = captured
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }
}

struct KeyboardShortcutLabel: View {
    let shortcut: KeyboardShortcut
    var font: Font = .caption
    var keySpacing: CGFloat = 5

    var body: some View {
        HStack(spacing: keySpacing) {
            ForEach(Array(shortcut.displayParts.enumerated()), id: \.offset) { _, part in
                Text(part)
            }
        }
        .font(font.monospaced())
    }
}

extension View {
    func keyboardShortcut(_ shortcut: KeyboardShortcut) -> some View {
        keyboardShortcut(shortcut.swiftUIKeyEquivalent, modifiers: shortcut.swiftUIModifiers)
    }
}
