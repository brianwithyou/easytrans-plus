import AppKit
import Darwin
import Darwin.Mach
import Foundation

final class SystemMetricsCollector {
    static let shared = SystemMetricsCollector()

    private struct CPULoadSample {
        let user: Int32
        let system: Int32
        let idle: Int32
        let nice: Int32
    }

    private var previousCPULoad: [CPULoadSample] = []
    private var previousProcessCPUTimes: [pid_t: UInt64] = [:]
    private var previousSampleDate: Date?
    private var pendingProcessCPUTimes: [pid_t: UInt64] = [:]
    private var pendingSampleDate: Date?

    private static let machTimebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    private static let protectedProcessNames: Set<String> = [
        "kernel_task",
        "launchd",
        "WindowServer",
        "loginwindow",
        "syslogd",
        "coreaudiod",
        "mds",
        "mdworker",
        "trustd",
        "powerd",
    ]

    private init() {}

    private func machTicksToNanoseconds(_ ticks: UInt64) -> UInt64 {
        UInt64(ticks) * UInt64(Self.machTimebase.numer) / UInt64(Self.machTimebase.denom)
    }

    func sampleSystemCPU() -> Double {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCpuInfo
        )
        guard result == KERN_SUCCESS, let cpuInfo else { return 0 }

        defer {
            let size = vm_size_t(numCpuInfo) * vm_size_t(MemoryLayout<integer_t>.size)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), size)
        }

        let cpuCount = Int(numCPUs)
        var currentLoad: [CPULoadSample] = []
        currentLoad.reserveCapacity(cpuCount)

        for index in 0..<cpuCount {
            let offset = Int(CPU_STATE_MAX) * index
            currentLoad.append(
                CPULoadSample(
                    user: cpuInfo[offset + Int(CPU_STATE_USER)],
                    system: cpuInfo[offset + Int(CPU_STATE_SYSTEM)],
                    idle: cpuInfo[offset + Int(CPU_STATE_IDLE)],
                    nice: cpuInfo[offset + Int(CPU_STATE_NICE)]
                )
            )
        }

        defer { previousCPULoad = currentLoad }

        guard previousCPULoad.count == currentLoad.count, !previousCPULoad.isEmpty else {
            return 0
        }

        var totalUser: Int64 = 0
        var totalSystem: Int64 = 0
        var totalIdle: Int64 = 0
        var totalNice: Int64 = 0

        for index in 0..<currentLoad.count {
            let current = currentLoad[index]
            let previous = previousCPULoad[index]
            totalUser += Int64(current.user - previous.user)
            totalSystem += Int64(current.system - previous.system)
            totalIdle += Int64(current.idle - previous.idle)
            totalNice += Int64(current.nice - previous.nice)
        }

        let total = totalUser + totalSystem + totalIdle + totalNice
        guard total > 0 else { return 0 }
        return Double(totalUser + totalSystem + totalNice) / Double(total) * 100.0
    }

    func sampleSystemMemory() -> (usedBytes: UInt64, totalBytes: UInt64, percent: Double) {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            let total = ProcessInfo.processInfo.physicalMemory
            return (0, total, 0)
        }

        let pageSize = UInt64(vm_page_size)
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let used = active + wired + compressed
        let total = ProcessInfo.processInfo.physicalMemory
        let percent = total > 0 ? Double(used) / Double(total) * 100.0 : 0
        return (used, total, percent)
    }

    func sampleProcessPool() -> [ProcessSnapshot] {
        let now = Date()
        let elapsed = previousSampleDate.map { now.timeIntervalSince($0) } ?? 0
        let hasProcessCPUSample = elapsed >= 0.5

        var pids = [pid_t](repeating: 0, count: 4096)
        let bytes = proc_listpids(
            UInt32(PROC_ALL_PIDS),
            0,
            &pids,
            Int32(MemoryLayout<pid_t>.size * pids.count)
        )
        guard bytes > 0 else { return [] }

        let pidCount = Int(bytes) / MemoryLayout<pid_t>.size
        let ownPID = ProcessInfo.processInfo.processIdentifier

        var bundleByPID: [pid_t: String] = [:]
        var nameByPID: [pid_t: String] = [:]
        for app in NSWorkspace.shared.runningApplications {
            let pid = app.processIdentifier
            bundleByPID[pid] = app.bundleIdentifier
            nameByPID[pid] = app.localizedName
        }

        var snapshots: [ProcessSnapshot] = []
        var stagedProcessCPUTimes: [pid_t: UInt64] = [:]

        for index in 0..<pidCount {
            let pid = pids[index]
            guard pid > 0 else { continue }

            var info = proc_taskinfo()
            let infoSize = proc_pidinfo(
                pid,
                PROC_PIDTASKINFO,
                0,
                &info,
                Int32(MemoryLayout<proc_taskinfo>.size)
            )
            guard infoSize == Int32(MemoryLayout<proc_taskinfo>.size) else { continue }

            let memoryBytes = UInt64(info.pti_resident_size)
            guard memoryBytes > 0 || info.pti_total_user > 0 || info.pti_total_system > 0 else { continue }

            let totalTimeTicks = info.pti_total_user + info.pti_total_system
            let totalTimeNanoseconds = machTicksToNanoseconds(totalTimeTicks)
            stagedProcessCPUTimes[pid] = totalTimeNanoseconds

            var cpuPercent = 0.0
            if hasProcessCPUSample,
               let previousTime = previousProcessCPUTimes[pid],
               totalTimeNanoseconds >= previousTime {
                let delta = totalTimeNanoseconds - previousTime
                let elapsedNanoseconds = elapsed * 1_000_000_000
                // Match Activity Monitor / htop: % of one CPU, can exceed 100%.
                cpuPercent = Double(delta) / elapsedNanoseconds * 100.0
            }

            var procNameBuffer = [CChar](repeating: 0, count: Int(MAXCOMLEN))
            proc_name(pid, &procNameBuffer, UInt32(procNameBuffer.count))
            let procName = String(cString: procNameBuffer)
            let identity = resolveProcessIdentity(
                pid: pid,
                procName: procName,
                nameByPID: nameByPID,
                bundleByPID: bundleByPID
            )
            let displayName = identity.name
            let bundleIdentifier = identity.bundleIdentifier

            var bsdInfo = proc_bsdinfo()
            let bsdSize = proc_pidinfo(
                pid,
                PROC_PIDTBSDINFO,
                0,
                &bsdInfo,
                Int32(MemoryLayout<proc_bsdinfo>.size)
            )
            let userName = bsdSize == Int32(MemoryLayout<proc_bsdinfo>.size)
                ? ProcessSnapshot.username(for: bsdInfo.pbi_uid)
                : ProcessSnapshot.username(for: getuid())
            let threadCount = max(Int(info.pti_threadnum), 0)

            let isProtected = isProcessProtected(
                pid: pid,
                name: displayName,
                procName: procName,
                ownPID: ownPID,
                ownerUID: bsdSize == Int32(MemoryLayout<proc_bsdinfo>.size) ? bsdInfo.pbi_uid : getuid()
            )

            if hasProcessCPUSample, cpuPercent < 0.05, memoryBytes < 4 * 1024 * 1024 { continue }

            snapshots.append(
                ProcessSnapshot(
                    pid: pid,
                    name: displayName,
                    bundleIdentifier: bundleIdentifier,
                    executablePath: identity.executablePath,
                    memoryBytes: memoryBytes,
                    cpuPercent: cpuPercent,
                    cpuTimeNanoseconds: totalTimeNanoseconds,
                    threadCount: threadCount,
                    userName: userName,
                    isProtected: isProtected,
                    pageTitle: nil,
                    pageURL: nil
                )
            )
        }

        pendingProcessCPUTimes = stagedProcessCPUTimes
        pendingSampleDate = now

        return snapshots
    }

    func sampleTopProcesses(limit: Int = 15, sortBy: ProcessSortMetric = .cpu) -> [ProcessSnapshot] {
        sampleProcessPool().sorted(by: sortBy, limit: limit)
    }

    func commitProcessCPUBaselines() {
        if !pendingProcessCPUTimes.isEmpty {
            previousProcessCPUTimes = pendingProcessCPUTimes
        }
        if let pendingSampleDate {
            previousSampleDate = pendingSampleDate
        }
        pendingProcessCPUTimes = [:]
        self.pendingSampleDate = nil
    }

    private func resolveProcessIdentity(
        pid: pid_t,
        procName: String,
        nameByPID: [pid_t: String],
        bundleByPID: [pid_t: String]
    ) -> (name: String, bundleIdentifier: String?, executablePath: String?) {
        if let localizedName = nameByPID[pid], !localizedName.isEmpty {
            return (localizedName, bundleByPID[pid], nil)
        }

        if !procName.isEmpty {
            return (procName, bundleByPID[pid], executablePath(for: pid))
        }

        if let executablePath = executablePath(for: pid) {
            let basename = URL(fileURLWithPath: executablePath).lastPathComponent
            if !basename.isEmpty {
                return (basename, bundleByPID[pid], executablePath)
            }
        }

        if let comm = bsdCommandName(for: pid), !comm.isEmpty {
            return (comm, bundleByPID[pid], executablePath(for: pid))
        }

        return ("PID \(pid)", bundleByPID[pid], executablePath(for: pid))
    }

    private func executablePath(for pid: pid_t) -> String? {
        var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
        guard pathLength > 0 else { return nil }
        return String(cString: pathBuffer)
    }

    private func bsdCommandName(for pid: pid_t) -> String? {
        var bsdInfo = proc_bsdinfo()
        let size = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsdInfo, Int32(MemoryLayout<proc_bsdinfo>.size))
        guard size == Int32(MemoryLayout<proc_bsdinfo>.size) else { return nil }
        return withUnsafePointer(to: bsdInfo.pbi_comm) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: bsdInfo.pbi_comm)) {
                String(cString: $0)
            }
        }
    }

    private func isProcessProtected(
        pid: pid_t,
        name: String,
        procName: String,
        ownPID: pid_t,
        ownerUID: uid_t
    ) -> Bool {
        if pid == ownPID || pid <= 1 {
            return true
        }

        let loweredNames = [name.lowercased(), procName.lowercased()]
        if Self.protectedProcessNames.contains(where: { protected in
            loweredNames.contains { $0.contains(protected.lowercased()) }
        }) {
            return true
        }

        if getuid() != geteuid() {
            return true
        }

        if ownerUID != getuid() {
            return true
        }

        return false
    }
}
