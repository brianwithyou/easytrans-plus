import SwiftUI

struct StickyNoteView: View {
    @Binding var text: String
    @Binding var isPinned: Bool
    var onClose: () -> Void
    var onPinToggle: () -> Void

    @FocusState private var isEditorFocused: Bool

    private let noteInk = Color(red: 0.24, green: 0.20, blue: 0.14)
    private let adhesive = Color(red: 0.94, green: 0.86, blue: 0.52)
    private let paperTop = Color(red: 1.0, green: 0.99, blue: 0.88)
    private let paperBottom = Color(red: 0.99, green: 0.93, blue: 0.68)

    var body: some View {
        VStack(spacing: 0) {
            adhesiveStrip
            header
            editorArea
            footerHint
        }
        .background(paperBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color(red: 0.78, green: 0.68, blue: 0.36).opacity(0.35),
                            Color(red: 0.62, green: 0.52, blue: 0.24).opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: Color(red: 0.45, green: 0.34, blue: 0.08).opacity(0.18), radius: 1, y: 1)
        .shadow(color: Color(red: 0.35, green: 0.26, blue: 0.05).opacity(0.22), radius: 16, y: 8)
        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        .onAppear {
            isEditorFocused = true
        }
        .onExitCommand {
            onClose()
        }
    }

    private var adhesiveStrip: some View {
        ZStack {
            adhesive
            LinearGradient(
                colors: [
                    .white.opacity(0.28),
                    .clear,
                    .black.opacity(0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(height: 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: 0.5)
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "note.text")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(noteInk.opacity(0.45))
                .symbolRenderingMode(.hierarchical)

            Text("便签")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(noteInk.opacity(0.72))

            if isPinned {
                Text("已固定")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.orange.opacity(0.85))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.12), in: Capsule())
                    .transition(.scale.combined(with: .opacity))
            }

            Spacer(minLength: 0)

            if !isPinned {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(noteInk.opacity(0.22))
                    .help("拖动标题栏移动便签")
            }

            StickyNoteToolbarButton(
                systemName: isPinned ? "pin.fill" : "pin",
                tint: isPinned ? .orange : noteInk.opacity(0.55),
                isActive: isPinned,
                help: isPinned ? "取消固定" : "固定到屏幕位置"
            ) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                    onPinToggle()
                }
            }

            StickyNoteToolbarButton(
                systemName: "xmark",
                tint: noteInk.opacity(0.45),
                hoverTint: .red.opacity(0.85),
                help: "关闭便签"
            ) {
                onClose()
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isPinned)
    }

    private var editorArea: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("写点什么…")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(noteInk.opacity(0.28))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(noteInk)
                .scrollContentBackground(.hidden)
                .focused($isEditorFocused)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.22),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
        )
    }

    private var footerHint: some View {
        HStack {
            Spacer()
            Text("Esc 关闭")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(noteInk.opacity(0.28))
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .padding(.top, 2)
    }

    private var paperBackground: some View {
        LinearGradient(
            colors: [paperTop, paperBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct StickyNoteToolbarButton: View {
    let systemName: String
    let tint: Color
    var hoverTint: Color?
    var isActive: Bool = false
    let help: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isHovered ? (hoverTint ?? tint) : tint)
                .frame(width: 24, height: 24)
                .background {
                    Circle()
                        .fill(backgroundFill)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { isHovered = $0 }
    }

    private var backgroundFill: Color {
        if isActive {
            return Color.orange.opacity(isHovered ? 0.22 : 0.14)
        }
        if isHovered {
            return Color.black.opacity(0.08)
        }
        return Color.black.opacity(0.04)
    }
}
