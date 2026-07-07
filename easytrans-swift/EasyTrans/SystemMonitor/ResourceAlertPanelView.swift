import AppKit
import SwiftUI

final class ResourceAlertPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

struct ResourceAlertPanelView: View {
    @ObservedObject var service: SystemMonitorService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            metricsRow
            processTable
            if let statusMessage = service.panelStatusMessage, !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            actionButtons
        }
        .padding(16)
        .frame(width: 980, height: 480)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("系统资源占用较高")
                    .font(.headline)
                Text("勾选后可结束进程；可在 CPU / 内存视角间切换排序。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                service.closePanelFromUI()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("关闭")
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 16) {
            metricBadge(
                title: "CPU",
                value: service.systemCPUPercent,
                isHigh: service.systemCPUPercent >= SystemMonitorSettings.defaultCPUThreshold
            )
            metricBadge(
                title: "内存",
                value: service.systemMemoryPercent,
                isHigh: service.systemMemoryPercent >= SystemMonitorSettings.defaultMemoryThreshold
            )

            Spacer()

            Picker("视角", selection: sortMetricBinding) {
                ForEach(ProcessSortMetric.allCases) { metric in
                    Text(metric.label).tag(metric)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 148)
            .labelsHidden()
        }
    }

    private var sortMetricBinding: Binding<ProcessSortMetric> {
        Binding(
            get: { service.panelSortMetric },
            set: { service.setPanelSortMetric($0) }
        )
    }

    private func metricBadge(title: String, value: Double, isHigh: Bool) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(String(format: "%.0f%%", value))
                .font(.title3.weight(.semibold))
                .foregroundStyle(isHigh ? Color.orange : Color.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var processTable: some View {
        Group {
            if service.panelSortMetric == .memory {
                memoryProcessTable
            } else {
                cpuProcessTable
            }
        }
    }

    private var cpuProcessTable: some View {
        Table(service.topProcesses) {
            TableColumn("") { process in
                ProcessSelectionCell(
                    process: process,
                    isTerminating: service.isTerminating,
                    selection: selectionBinding(for: process)
                )
            }
            .width(28)

            TableColumn(columnTitle("% CPU", active: true)) { process in
                ProcessCPUPercentCell(process: process)
            }
            .width(72)

            TableColumn("CPU 时间") { process in
                ProcessCPUTimeCell(process: process)
            }
            .width(min: 96, ideal: 110)

            TableColumn("进程名称") { process in
                ProcessNameCell(process: process)
            }
            .width(min: 160, ideal: 200)

            TableColumn("线程") { process in
                ProcessThreadCell(process: process)
            }
            .width(52)

            TableColumn(columnTitle("内存", active: false)) { process in
                ProcessMemoryCell(process: process)
            }
            .width(80)

            TableColumn("PID") { process in
                ProcessPIDCell(process: process)
            }
            .width(64)

            TableColumn("用户") { process in
                ProcessUserCell(process: process)
            }
            .width(min: 88, ideal: 120)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
    }

    private var memoryProcessTable: some View {
        Table(service.topProcesses) {
            TableColumn("") { process in
                ProcessSelectionCell(
                    process: process,
                    isTerminating: service.isTerminating,
                    selection: selectionBinding(for: process)
                )
            }
            .width(28)

            TableColumn(columnTitle("% CPU", active: false)) { process in
                ProcessCPUPercentCell(process: process)
            }
            .width(72)

            TableColumn("CPU 时间") { process in
                ProcessCPUTimeCell(process: process)
            }
            .width(min: 96, ideal: 110)

            TableColumn("进程名称") { process in
                ProcessNameCell(process: process)
            }
            .width(min: 160, ideal: 200)

            TableColumn("详细信息") { process in
                ProcessDetailsCell(process: process)
            }
            .width(min: 180, ideal: 260)

            TableColumn("线程") { process in
                ProcessThreadCell(process: process)
            }
            .width(52)

            TableColumn(columnTitle("内存", active: true)) { process in
                ProcessMemoryCell(process: process)
            }
            .width(80)

            TableColumn("PID") { process in
                ProcessPIDCell(process: process)
            }
            .width(64)

            TableColumn("用户") { process in
                ProcessUserCell(process: process)
            }
            .width(min: 88, ideal: 120)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
    }

    private func columnTitle(_ title: String, active: Bool) -> String {
        active ? "▼ \(title)" : title
    }

    private var actionButtons: some View {
        HStack {
            Button("结束选中进程", role: .destructive) {
                Task { @MainActor in
                    await service.terminateSelectedProcesses()
                }
            }
            .disabled(service.selectedPIDs.isEmpty || service.isTerminating)

            Button("稍后提醒") {
                service.snoozeAlertFromUI()
            }
            .disabled(service.isTerminating)

            Spacer()

            Button("关闭") {
                service.closePanelFromUI()
            }
        }
    }

    private func selectionBinding(for process: ProcessSnapshot) -> Binding<Bool> {
        Binding(
            get: { service.selectedPIDs.contains(process.pid) },
            set: { isSelected in
                service.setProcessSelected(process.pid, isSelected: isSelected, isProtected: process.isProtected)
            }
        )
    }
}

private struct ProcessSelectionCell: View {
    let process: ProcessSnapshot
    let isTerminating: Bool
    @Binding var selection: Bool

    var body: some View {
        Toggle(isOn: $selection) { EmptyView() }
            .toggleStyle(.checkbox)
            .labelsHidden()
            .disabled(process.isProtected || isTerminating)
    }
}

private struct ProcessCPUPercentCell: View {
    let process: ProcessSnapshot

    var body: some View {
        Text(process.activityMonitorCPUDisplay)
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct ProcessCPUTimeCell: View {
    let process: ProcessSnapshot

    var body: some View {
        Text(process.cpuTimeDisplay)
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct ProcessNameCell: View {
    let process: ProcessSnapshot

    var body: some View {
        HStack(spacing: 8) {
            if let icon = process.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 18, height: 18)
            }
            Text(process.name)
                .lineLimit(1)
                .truncationMode(.tail)
            if process.isProtected {
                Text("受保护")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ProcessDetailsCell: View {
    let process: ProcessSnapshot

    var body: some View {
        if process.hasPageContext {
            VStack(alignment: .leading, spacing: 2) {
                Text(process.pageTitle ?? "")
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let pageURL = process.pageURL, !pageURL.isEmpty {
                    Text(pageURL)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        } else {
            Text("—")
                .foregroundStyle(.tertiary)
        }
    }
}

private struct ProcessThreadCell: View {
    let process: ProcessSnapshot

    var body: some View {
        Text("\(process.threadCount)")
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct ProcessMemoryCell: View {
    let process: ProcessSnapshot

    var body: some View {
        Text(process.memoryDisplay)
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct ProcessPIDCell: View {
    let process: ProcessSnapshot

    var body: some View {
        Text("\(process.pid)")
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct ProcessUserCell: View {
    let process: ProcessSnapshot

    var body: some View {
        Text(process.userName)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}
