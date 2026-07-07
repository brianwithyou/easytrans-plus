import AppKit
import SwiftUI

struct ContentView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var session = TranslationSession.shared
    @ObservedObject private var cloudAuth = CloudAuthService.shared
    @ObservedObject private var shortcutSettings = KeyboardShortcutSettings.shared

    @State private var translationTask: Task<Void, Never>?

    private var sourceText: Binding<String> {
        Binding(get: { session.sourceText }, set: { session.sourceText = $0 })
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            languageBar
            Divider()
            editorArea
            Divider()
            footer
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            session.registerOpenWindowHandler {
                openWindow(id: "main")
            }
            NotificationCenter.default.post(name: .mainWindowContentDidLoad, object: nil)
        }
        .alert("翻译失败", isPresented: .init(
            get: { session.errorMessage != nil },
            set: { if !$0 { session.errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(session.errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "character.bubble")
                .font(.title2)
                .foregroundStyle(.blue)
            Text("EasyTrans Plus")
                .font(.title2.weight(.semibold))
            Spacer()
            if settings.translationMode == .cloud && !cloudAuth.isLoggedIn {
                HStack(spacing: 8) {
                    Button("登录") {
                        cloudAuth.presentLogin()
                    }
                    Button("注册") {
                        cloudAuth.presentRegister()
                    }
                }
                .controlSize(.small)
            } else if settings.translationMode == .byok && !settings.isConfigured {
                Label(settings.configurationHint, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var languageBar: some View {
        HStack(spacing: 12) {
            fixedLanguagePicker(language: .english)

            Image(systemName: "arrow.left.arrow.right")
                .font(.caption)
                .foregroundStyle(.tertiary)

            targetLanguagePicker(selection: $settings.targetLanguage)

            Spacer()

            Button("清空") {
                cancelTranslation()
                session.sourceText = ""
                session.translatedText = ""
            }
            .disabled(session.sourceText.isEmpty && session.translatedText.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func fixedLanguagePicker(language: Language) -> some View {
        Picker("源语言", selection: .constant(language)) {
            Text(language.displayName).tag(language)
        }
        .labelsHidden()
        .frame(width: 120)
        .disabled(true)
    }

    private func targetLanguagePicker(selection: Binding<Language>) -> some View {
        Picker("目标语言", selection: selection) {
            ForEach(Language.selectableTargets) { language in
                Text(language.displayName).tag(language)
            }
        }
        .labelsHidden()
        .frame(width: 120)
    }

    private var editorArea: some View {
        HStack(spacing: 0) {
            textPanel(
                title: "原文",
                text: sourceText,
                placeholder: "输入要翻译的文本…",
                isEditable: true
            )

            Divider()

            textPanel(
                title: "译文",
                text: .constant(session.translatedText),
                placeholder: session.isTranslating ? "翻译中…" : "翻译结果将显示在这里",
                isEditable: false
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func textPanel(title: String, text: Binding<String>, placeholder: String, isEditable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if title == "译文", !session.translatedText.isEmpty {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(
                            TranslationFormatting.plainTextForCopy(session.translatedText),
                            forType: .string
                        )
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                    .help("复制译文")
                }
            }

            Group {
                if isEditable {
                    PlaceholderTextEditor(text: text, placeholder: placeholder)
                } else {
                    ScrollView {
                        translationResultText(text.wrappedValue, placeholder: placeholder)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(4)
                    }
                }
            }
            .padding(10)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            if session.isTranslating {
                ProgressView()
                    .controlSize(.small)
                Text("正在翻译…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                KeyboardShortcutLabel(shortcut: shortcutSettings.translateShortcut)
                Text("翻译选中文字")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Spacer()

            Button("翻译") {
                startTranslation()
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(session.isTranslating || session.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !settings.isConfigured)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func translationResultText(_ content: String, placeholder: String) -> some View {
        if content.isEmpty {
            Text(placeholder)
                .font(.body)
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
        } else if let attributed = try? AttributedString(
            markdown: content,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attributed)
                .font(.body)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        } else {
            Text(content)
                .font(.body)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
    }

    private func cancelTranslation() {
        translationTask?.cancel()
        translationTask = nil
        session.isTranslating = false
    }

    private func startTranslation() {
        cancelTranslation()
        session.translatedText = ""
        session.isTranslating = true
        session.errorMessage = nil

        let text = session.sourceText
        let preferredTarget = settings.targetLanguage
        let languages = TextClassifier.resolveTranslationLanguages(
            text: text,
            preferredTarget: preferredTarget
        )
        let style = TextClassifier.resolveTranslationStyle(
            text: text,
            source: languages.source,
            target: languages.target,
            preferredTarget: preferredTarget
        )
        let service = TranslationService()

        translationTask = Task {
            do {
                _ = try await service.translate(
                    text: text,
                    sourceLanguage: languages.source,
                    targetLanguage: languages.target,
                    style: style
                ) { chunk in
                    Task { @MainActor in
                        session.translatedText += chunk
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    session.errorMessage = error.localizedDescription
                }
            }

            await MainActor.run {
                session.isTranslating = false
                translationTask = nil
            }
        }
    }
}

/// 使用 NSTextView 自绘占位符，与正文共用同一套排版，避免与光标错位。
private struct PlaceholderTextEditor: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String

    private static let textInset = NSSize(width: 4, height: 6)

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = PlaceholderNSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = Self.textInset
        textView.placeholder = placeholder
        textView.string = text

        scrollView.documentView = textView
        context.coordinator.textView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? PlaceholderNSTextView else { return }
        if textView.placeholder != placeholder {
            textView.placeholder = placeholder
        }
        guard !context.coordinator.isUpdatingFromTextView else { return }
        if textView.string != text {
            context.coordinator.isUpdatingFromBinding = true
            textView.string = text
            context.coordinator.isUpdatingFromBinding = false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        weak var textView: PlaceholderNSTextView?
        var isUpdatingFromBinding = false
        var isUpdatingFromTextView = false

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? PlaceholderNSTextView else { return }
            guard !isUpdatingFromBinding else { return }
            isUpdatingFromTextView = true
            text = textView.string
            isUpdatingFromTextView = false
            textView.needsDisplay = true
        }
    }
}

private final class PlaceholderNSTextView: NSTextView {
    var placeholder = "" {
        didSet { needsDisplay = true }
    }

    override var string: String {
        didSet { needsDisplay = true }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard allowsUndo, event.modifierFlags.contains(.command),
              let key = event.charactersIgnoringModifiers?.lowercased() else {
            return super.performKeyEquivalent(with: event)
        }

        switch key {
        case "z":
            if event.modifierFlags.contains(.shift) {
                if undoManager?.canRedo == true {
                    undoManager?.redo()
                    return true
                }
            } else if undoManager?.canUndo == true {
                undoManager?.undo()
                return true
            }
        default:
            break
        }

        return super.performKeyEquivalent(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !placeholder.isEmpty else { return }

        let font = self.font ?? .systemFont(ofSize: NSFont.systemFontSize)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.placeholderTextColor
        ]
        let inset = textContainerInset
        let padding = textContainer?.lineFragmentPadding ?? 0
        let rect = NSRect(
            x: inset.width + padding,
            y: inset.height,
            width: bounds.width - (inset.width + padding) * 2,
            height: bounds.height - inset.height * 2
        )
        placeholder.draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs
        )
    }
}
