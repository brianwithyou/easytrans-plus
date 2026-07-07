import SwiftUI

struct MenuBarLabelView: View {
    @ObservedObject private var monitor = SystemMonitorService.shared
    @ObservedObject private var settings = SystemMonitorSettings.shared

    var body: some View {
        if settings.showMenuBarStats {
            HStack(spacing: 4) {
                Image(systemName: "character.bubble")
                Text("\(Int(monitor.systemCPUPercent.rounded()))%")
                    .monospacedDigit()
                Text("\(Int(monitor.systemMemoryPercent.rounded()))%")
                    .monospacedDigit()
                    .foregroundStyle(monitor.systemMemoryPercent >= settings.memoryThreshold ? .orange : .primary)
            }
            .font(.system(size: 11, weight: .medium))
        } else {
            Image(systemName: "character.bubble")
        }
    }
}
