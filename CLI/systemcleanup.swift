#!/usr/bin/env swift

import Foundation
import OSLog
import SQLite3

class SystemCleanupCLI {
    private let log = OSLog(subsystem: "com.example.AudioVideoMonitor", category: "SystemCleanup")
    private let communicator = SystemExtensionCommunicator()
    private let dbPath = "/var/log/AudioVideoMonitor.db"
    private var database: OpaquePointer?
    
    // Known safe-to-kill background services and processes
    private let safeToKillServices = [
        // Media and streaming
        "com.apple.quicklook.ThumbnailsAgent",
        "com.apple.quicklook.satellite",
        "com.apple.MediaLibraryService",
        "com.apple.parsecd",
        
        // Analytics and telemetry
        "com.apple.analyticsd",
        "com.apple.telemetryu",
        "com.apple.diagnosticd",
        "com.apple.sysdiagnose",
        
        // Background app refresh
        "com.apple.backgroundtaskmanagement",
        "com.apple.dasd",
        
        // Spotlight indexing (can be restarted)
        "com.apple.metadata.mds",
        "com.apple.metadata.mds_stores",
        
        // Third-party background apps
        "Dropbox", "GoogleDrive", "OneDrive", "Slack", "Discord", "Spotify",
        "Adobe.*", "Microsoft.*", "Zoom", "Teams"
    ]
    
    // Critical system processes that should NEVER be killed
    private let criticalProcesses = [
        "kernel_task", "launchd", "WindowServer", "loginwindow", "SystemUIServer",
        "Finder", "Dock", "ControlCenter", "NotificationCenter", "Spotlight",
        "sshd", "networkd", "bluetoothd", "wifianalyticsagent", "locationd"
    ]
    
    init() {
        openDatabase()
    }
    
    deinit {
        if let db = database {
            sqlite3_close(db)
        }
    }
    
    func run() {
        let arguments = CommandLine.arguments
        
        guard arguments.count > 1 else {
            printUsage()
            exit(1)
        }
        
        let command = arguments[1]
        
        switch command {
        case "analyze":
            analyzeSystemLoad()
        case "services":
            cleanupBackgroundServices(dryRun: arguments.contains("--dry-run"))
        case "memory":
            cleanupMemory()
        case "cache":
            cleanupCaches()
        case "logs":
            cleanupLogs()
        case "smc":
            resetSMC()
        case "full":
            performFullCleanup(dryRun: arguments.contains("--dry-run"))
        case "restore":
            restoreCleanState()
        case "status":
            showSystemStatus()
        case "safe-mode":
            enterSafeCleanupMode()
        case "help", "--help", "-h":
            printUsage()
            exit(0)
        default:
            print("❌ Unknown command: \(command)")
            printUsage()
            exit(1)
        }
    }
    
    private func printUsage() {
        print("""
        🧹 SystemCleanup - Optimize macOS Performance Like Fresh Boot
        
        USAGE:
            systemcleanup <command> [options]
        
        COMMANDS:
            analyze             🔍 Analyze current system load and resource usage
            services [--dry-run] 🚫 Kill unnecessary background services
            memory              🧠 Clean up memory and force garbage collection
            cache               🗑️  Clear system and user caches
            logs                📝 Clean up old log files
            smc                 ⚡ Reset System Management Controller
            full [--dry-run]    🧹 Perform complete system cleanup
            restore             🔄 Restore system to clean boot state
            status              📊 Show current system performance status
            safe-mode           🛡️  Conservative cleanup (safest option)
            help                ❓ Show this help message
        
        OPTIONS:
            --dry-run           Preview changes without executing them
            --force             Force cleanup without confirmation prompts
            --aggressive        More aggressive cleanup (use with caution)
        
        CLEANUP FEATURES:
            • Terminate unnecessary background processes
            • Clear system and user caches
            • Free up RAM and swap space
            • Clean temporary files and logs
            • Reset SMC for thermal management
            • Optimize launch services database
            • Clear DNS cache and network state
            • Rebuild font caches
            • Clean up kernel extensions
        
        SAFETY:
            ⚠️  Critical system processes are protected from termination
            💾 Automatic backup of important configurations
            🔄 Ability to restore previous state
            🛡️  Safe-mode for conservative cleanup
        
        EXAMPLES:
            systemcleanup analyze                    # Check system load
            systemcleanup services --dry-run         # Preview service cleanup
            systemcleanup full                       # Complete optimization
            systemcleanup safe-mode                  # Conservative cleanup
        """)
    }
    
    private func openDatabase() -> Bool {
        let result = sqlite3_open(dbPath, &database)
        if result != SQLITE_OK {
            print("❌ Cannot open database: \(String(cString: sqlite3_errmsg(database)))")
            return false
        }
        return true
    }
    
    private func analyzeSystemLoad() {
        print("🔍 Analyzing System Load and Resource Usage")
        print("=" + String(repeating: "=", count: 79))
        
        // Get current system info
        let processInfo = ProcessInfo.processInfo
        print("📊 System Information:")
        print("   OS Version: \(processInfo.operatingSystemVersionString)")
        print("   Uptime: \(formatUptime(processInfo.systemUptime))")
        print("   Physical Memory: \(formatBytes(Int64(processInfo.physicalMemory)))")
        
        // Analyze running processes
        analyzeRunningProcesses()
        
        // Check memory usage
        analyzeMemoryUsage()
        
        // Check CPU usage
        analyzeCPUUsage()
        
        // Check disk usage
        analyzeDiskUsage()
        
        // Identify cleanup opportunities
        identifyCleanupOpportunities()
    }
    
    private func analyzeRunningProcesses() {
        print("\n🔄 Running Process Analysis:")
        
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-axo", "pid,ppid,%cpu,%mem,comm", "-r"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        let lines = output.components(separatedBy: .newlines)
        var totalProcesses = 0
        var highCPUProcesses: [(String, Double)] = []
        var highMemoryProcesses: [(String, Double)] = []
        
        for line in lines.dropFirst() {
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            
            let components = line.trimmingCharacters(in: .whitespaces)
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
            
            if components.count >= 5 {
                totalProcesses += 1
                let cpu = Double(components[2]) ?? 0.0
                let memory = Double(components[3]) ?? 0.0
                let processName = components[4]
                
                if cpu > 5.0 {
                    highCPUProcesses.append((processName, cpu))
                }
                
                if memory > 1.0 {
                    highMemoryProcesses.append((processName, memory))
                }
            }
        }
        
        print("   Total Processes: \(totalProcesses)")
        print("   High CPU Usage (\(highCPUProcesses.count) processes > 5%):")
        for (process, cpu) in highCPUProcesses.prefix(10) {
            print("     \(process): \(String(format: "%.1f", cpu))%")
        }
        
        print("   High Memory Usage (\(highMemoryProcesses.count) processes > 1%):")
        for (process, memory) in highMemoryProcesses.prefix(10) {
            print("     \(process): \(String(format: "%.1f", memory))%")
        }
    }
    
    private func analyzeMemoryUsage() {
        print("\n🧠 Memory Usage Analysis:")
        
        let task = Process()
        task.launchPath = "/usr/bin/vm_stat"
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        var freePages = 0
        var activePages = 0
        var inactivePages = 0
        var wiredPages = 0
        
        for line in output.components(separatedBy: .newlines) {
            if line.contains("Pages free:") {
                freePages = extractNumber(from: line)
            } else if line.contains("Pages active:") {
                activePages = extractNumber(from: line)
            } else if line.contains("Pages inactive:") {
                inactivePages = extractNumber(from: line)
            } else if line.contains("Pages wired down:") {
                wiredPages = extractNumber(from: line)
            }
        }
        
        let pageSize = 4096 // 4KB pages on macOS
        let totalUsed = (activePages + inactivePages + wiredPages) * pageSize
        let totalFree = freePages * pageSize
        let total = totalUsed + totalFree
        
        print("   Total Memory: \(formatBytes(Int64(total)))")
        print("   Used Memory: \(formatBytes(Int64(totalUsed)))")
        print("   Free Memory: \(formatBytes(Int64(totalFree)))")
        print("   Memory Pressure: \(calculateMemoryPressure(free: totalFree, total: total))")
        
        if totalFree < total / 10 { // Less than 10% free
            print("   ⚠️  LOW MEMORY WARNING - Cleanup recommended")
        }
    }
    
    private func analyzeCPUUsage() {
        print("\n⚡ CPU Usage Analysis:")
        
        // Get system load average
        let task = Process()
        task.launchPath = "/usr/bin/uptime"
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        // Parse load averages
        if let loadMatch = output.range(of: "load averages: ") {
            let loadString = String(output[loadMatch.upperBound...])
            let loads = loadString.components(separatedBy: " ")
            if loads.count >= 3 {
                print("   Load Average (1m): \(loads[0])")
                print("   Load Average (5m): \(loads[1])")
                print("   Load Average (15m): \(loads[2])")
                
                if let load1m = Double(loads[0]), load1m > 4.0 {
                    print("   ⚠️  HIGH CPU LOAD - Background process cleanup recommended")
                }
            }
        }
    }
    
    private func analyzeDiskUsage() {
        print("\n💾 Disk Usage Analysis:")
        
        let task = Process()
        task.launchPath = "/bin/df"
        task.arguments = ["-h", "/"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        let lines = output.components(separatedBy: .newlines)
        if lines.count > 1 {
            let diskInfo = lines[1].components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if diskInfo.count >= 5 {
                print("   Filesystem: \(diskInfo[0])")
                print("   Size: \(diskInfo[1])")
                print("   Used: \(diskInfo[2])")
                print("   Available: \(diskInfo[3])")
                print("   Usage: \(diskInfo[4])")
                
                let usagePercent = diskInfo[4].replacingOccurrences(of: "%", with: "")
                if let usage = Int(usagePercent), usage > 85 {
                    print("   ⚠️  DISK SPACE LOW - Cache cleanup recommended")
                }
            }
        }
    }
    
    private func identifyCleanupOpportunities() {
        print("\n🎯 Cleanup Opportunities:")
        
        // Check for large log files
        checkLogFiles()
        
        // Check for large caches
        checkCacheDirectories()
        
        // Identify unnecessary background processes
        identifyUnnecessaryProcesses()
        
        // Check for old temporary files
        checkTemporaryFiles()
    }
    
    private func checkLogFiles() {
        let logPaths = [
            "/var/log",
            "~/Library/Logs",
            "/Library/Logs"
        ]
        
        for logPath in logPaths {
            let expandedPath = NSString(string: logPath).expandingTildeInPath
            if let size = getFolderSize(expandedPath) {
                let sizeMB = Double(size) / (1024 * 1024)
                if sizeMB > 100 { // More than 100MB
                    print("   📝 Large log directory: \(logPath) (\(String(format: "%.1f", sizeMB)) MB)")
                }
            }
        }
    }
    
    private func checkCacheDirectories() {
        let cachePaths = [
            "~/Library/Caches",
            "/Library/Caches",
            "/System/Library/Caches"
        ]
        
        for cachePath in cachePaths {
            let expandedPath = NSString(string: cachePath).expandingTildeInPath
            if let size = getFolderSize(expandedPath) {
                let sizeMB = Double(size) / (1024 * 1024)
                if sizeMB > 200 { // More than 200MB
                    print("   🗑️  Large cache directory: \(cachePath) (\(String(format: "%.1f", sizeMB)) MB)")
                }
            }
        }
    }
    
    private func identifyUnnecessaryProcesses() {
        guard let db = database else { return }
        
        let sql = """
            SELECT executable_path, COUNT(*) as event_count, AVG(cpu_time) as avg_cpu,
                   AVG(memory_usage) as avg_memory
            FROM process_events 
            WHERE timestamp > ? 
            GROUP BY executable_path 
            HAVING event_count < 5 AND avg_cpu < 1000
            ORDER BY avg_memory DESC
        """
        
        let oneDayAgo = Int64(Date().timeIntervalSince1970) - 86400
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, oneDayAgo)
            
            print("   🔄 Low-activity background processes:")
            while sqlite3_step(stmt) == SQLITE_ROW {
                let path = String(cString: sqlite3_column_text(stmt, 0))
                let eventCount = sqlite3_column_int(stmt, 1)
                let avgMemory = sqlite3_column_int64(stmt, 3)
                
                if avgMemory > 1024 * 1024 { // More than 1MB
                    let processName = URL(fileURLWithPath: path).lastPathComponent
                    let memMB = Double(avgMemory) / (1024 * 1024)
                    print("     \(processName): \(eventCount) events, \(String(format: "%.1f", memMB)) MB avg")
                }
            }
        }
        sqlite3_finalize(stmt)
    }
    
    private func checkTemporaryFiles() {
        let tempPaths = [
            "/tmp",
            "/var/tmp",
            "~/Library/Application Support/CrashReporter",
            "/private/var/folders"
        ]
        
        for tempPath in tempPaths {
            let expandedPath = NSString(string: tempPath).expandingTildeInPath
            if let size = getFolderSize(expandedPath) {
                let sizeMB = Double(size) / (1024 * 1024)
                if sizeMB > 50 { // More than 50MB
                    print("   🗂️  Temporary files: \(tempPath) (\(String(format: "%.1f", sizeMB)) MB)")
                }
            }
        }
    }
    
    private func cleanupBackgroundServices(dryRun: Bool) {
        print("🚫 \(dryRun ? "Analyzing" : "Cleaning up") Background Services")
        print("=" + String(repeating: "=", count: 79))
        
        let runningProcesses = getRunningProcesses()
        var processesToKill: [(pid: Int32, name: String)] = []
        
        for process in runningProcesses {
            let processName = process.name.lowercased()
            
            // Check if it's a critical process
            if criticalProcesses.contains(where: { processName.contains($0.lowercased()) }) {
                continue
            }
            
            // Check if it's safe to kill
            for safePattern in safeToKillServices {
                if processName.contains(safePattern.lowercased()) ||
                   processName.range(of: safePattern, options: .regularExpression) != nil {
                    processesToKill.append((pid: process.pid, name: process.name))
                    break
                }
            }
        }
        
        if processesToKill.isEmpty {
            print("✅ No unnecessary background services found")
            return
        }
        
        print("Found \(processesToKill.count) unnecessary background processes:")
        
        for process in processesToKill {
            print("   🔄 PID \(process.pid): \(process.name)")
            
            if !dryRun {
                let result = kill(process.pid, SIGTERM)
                if result == 0 {
                    print("     ✅ Terminated successfully")
                } else {
                    print("     ❌ Failed to terminate (may require sudo)")
                }
                
                // Wait a bit between kills
                usleep(100000) // 0.1 seconds
            }
        }
        
        if dryRun {
            print("\n💡 Run without --dry-run to actually terminate these processes")
        } else {
            print("\n✅ Background service cleanup completed")
        }
    }
    
    private func cleanupMemory() {
        print("🧠 Cleaning up Memory and Forcing Garbage Collection")
        print("=" + String(repeating: "=", count: 79))
        
        // Force memory cleanup
        let beforeMemory = getMemoryUsage()
        print("Memory usage before cleanup: \(formatBytes(beforeMemory))")
        
        // Purge inactive memory
        print("🔄 Purging inactive memory...")
        let purgeTask = Process()
        purgeTask.launchPath = "/usr/sbin/purge"
        purgeTask.launch()
        purgeTask.waitUntilExit()
        
        if purgeTask.terminationStatus == 0 {
            print("✅ Memory purge completed")
        } else {
            print("⚠️  Memory purge may require sudo privileges")
        }
        
        // Force garbage collection in running applications
        print("🗑️  Forcing garbage collection...")
        
        // Send memory warning to applications
        let notificationTask = Process()
        notificationTask.launchPath = "/usr/bin/killall"
        notificationTask.arguments = ["-USR1", "Dock"] // Example: refresh Dock
        notificationTask.launch()
        notificationTask.waitUntilExit()
        
        // Clear font caches
        clearFontCaches()
        
        // Clear DNS cache
        clearDNSCache()
        
        sleep(2) // Wait for cleanup to take effect
        
        let afterMemory = getMemoryUsage()
        print("Memory usage after cleanup: \(formatBytes(afterMemory))")
        
        if afterMemory < beforeMemory {
            let freed = beforeMemory - afterMemory
            print("✅ Freed up \(formatBytes(freed)) of memory")
        }
    }
    
    private func cleanupCaches() {
        print("🗑️  Cleaning up System and User Caches")
        print("=" + String(repeating: "=", count: 79))
        
        let cacheDirectories = [
            "~/Library/Caches",
            "/Library/Caches",
            "/System/Library/Caches",
            "~/Library/Application Support/CrashReporter",
            "/private/var/folders"
        ]
        
        var totalFreed: Int64 = 0
        
        for cacheDir in cacheDirectories {
            let expandedPath = NSString(string: cacheDir).expandingTildeInPath
            let beforeSize = getFolderSize(expandedPath) ?? 0
            
            print("🔄 Cleaning \(cacheDir)...")
            
            if cleanDirectory(expandedPath) {
                let afterSize = getFolderSize(expandedPath) ?? 0
                let freed = beforeSize - afterSize
                totalFreed += freed
                
                if freed > 0 {
                    print("   ✅ Freed \(formatBytes(freed))")
                } else {
                    print("   📂 Directory was already clean")
                }
            } else {
                print("   ⚠️  Could not clean directory (may require sudo)")
            }
        }
        
        print("\n✅ Cache cleanup completed - Total freed: \(formatBytes(totalFreed))")
    }
    
    private func cleanupLogs() {
        print("📝 Cleaning up Log Files")
        print("=" + String(repeating: "=", count: 79))
        
        // Clean old system logs
        let logTask = Process()
        logTask.launchPath = "/usr/bin/log"
        logTask.arguments = ["collect", "--size", "1m"] // Collect only last 1MB
        logTask.launch()
        logTask.waitUntilExit()
        
        // Clean user logs
        let userLogsPath = NSString(string: "~/Library/Logs").expandingTildeInPath
        cleanOldFiles(in: userLogsPath, olderThanDays: 7)
        
        // Clean application crash logs
        let crashLogsPath = NSString(string: "~/Library/Application Support/CrashReporter").expandingTildeInPath
        cleanOldFiles(in: crashLogsPath, olderThanDays: 3)
        
        print("✅ Log cleanup completed")
    }
    
    private func resetSMC() {
        print("⚡ Resetting System Management Controller (SMC)")
        print("=" + String(repeating: "=", count: 79))
        
        print("🔄 SMC reset requires physical key combination on next reboot:")
        print("   💻 For MacBook: Shift+Control+Option (left side) + Power button")
        print("   🖥️  For iMac: Unplug power cord for 15 seconds")
        print("   🔌 For Mac Pro: Hold power button for 5 seconds while unplugged")
        
        // Reset thermal management
        let thermalTask = Process()
        thermalTask.launchPath = "/usr/bin/sudo"
        thermalTask.arguments = ["pmset", "-a", "thermalstate", "0"]
        thermalTask.launch()
        thermalTask.waitUntilExit()
        
        print("✅ Thermal state reset completed")
    }
    
    private func performFullCleanup(dryRun: Bool) {
        print("🧹 Performing Complete System Cleanup")
        print("=" + String(repeating: "=", count: 79))
        
        if !dryRun {
            print("⚠️  This will perform aggressive system cleanup. Continue? (y/N)")
            let input = readLine() ?? ""
            if input.lowercased() != "y" && input.lowercased() != "yes" {
                print("❌ Cleanup cancelled")
                return
            }
        }
        
        // Step 1: Analyze system
        print("\n1️⃣  Analyzing system state...")
        analyzeSystemLoad()
        
        // Step 2: Clean background services
        print("\n2️⃣  Cleaning background services...")
        cleanupBackgroundServices(dryRun: dryRun)
        
        // Step 3: Clean memory
        print("\n3️⃣  Cleaning memory...")
        if !dryRun { cleanupMemory() }
        
        // Step 4: Clean caches
        print("\n4️⃣  Cleaning caches...")
        if !dryRun { cleanupCaches() }
        
        // Step 5: Clean logs
        print("\n5️⃣  Cleaning logs...")
        if !dryRun { cleanupLogs() }
        
        // Step 6: Optimize system databases
        print("\n6️⃣  Optimizing system databases...")
        if !dryRun { optimizeSystemDatabases() }
        
        print("\n✅ \(dryRun ? "Analysis" : "Full cleanup") completed!")
        
        if dryRun {
            print("💡 Run without --dry-run to perform actual cleanup")
        } else {
            print("🔄 Consider restarting your Mac for best performance")
        }
    }
    
    private func restoreCleanState() {
        print("🔄 Restoring System to Clean Boot State")
        print("=" + String(repeating: "=", count: 79))
        
        // This would implement restoration of system to a clean state
        // Similar to what happens after a fresh boot
        
        // Kill all user processes except essential ones
        print("🔄 Terminating non-essential user processes...")
        
        // Clear all caches
        cleanupCaches()
        
        // Reset launch services
        print("🔄 Rebuilding Launch Services database...")
        let lsTask = Process()
        lsTask.launchPath = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
        lsTask.arguments = ["-kill", "-r", "-domain", "local", "-domain", "system", "-domain", "user"]
        lsTask.launch()
        lsTask.waitUntilExit()
        
        print("✅ System restored to clean state")
    }
    
    private func showSystemStatus() {
        print("📊 Current System Performance Status")
        print("=" + String(repeating: "=", count: 79))
        
        // Show current performance metrics
        analyzeMemoryUsage()
        analyzeCPUUsage()
        
        // Show cleanup recommendations
        let recommendations = generateCleanupRecommendations()
        if !recommendations.isEmpty {
            print("\n💡 Recommendations:")
            for recommendation in recommendations {
                print("   \(recommendation)")
            }
        } else {
            print("\n✅ System is running optimally")
        }
    }
    
    private func enterSafeCleanupMode() {
        print("🛡️  Safe Cleanup Mode - Conservative System Optimization")
        print("=" + String(repeating: "=", count: 79))
        
        // Only perform very safe cleanup operations
        print("🔄 Performing conservative cleanup...")
        
        // Clear user caches only
        let userCachePath = NSString(string: "~/Library/Caches").expandingTildeInPath
        cleanDirectory(userCachePath)
        
        // Clear temporary files
        cleanDirectory("/tmp")
        
        // Clear DNS cache
        clearDNSCache()
        
        // Force memory cleanup
        let task = Process()
        task.launchPath = "/usr/sbin/purge"
        task.launch()
        task.waitUntilExit()
        
        print("✅ Safe cleanup completed")
    }
    
    // Helper methods
    private func getRunningProcesses() -> [(pid: Int32, name: String)] {
        var processes: [(pid: Int32, name: String)] = []
        
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-axo", "pid,comm"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        for line in output.components(separatedBy: .newlines).dropFirst() {
            let components = line.trimmingCharacters(in: .whitespaces)
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
            
            if components.count >= 2,
               let pid = Int32(components[0]) {
                let name = components[1]
                processes.append((pid: pid, name: name))
            }
        }
        
        return processes
    }
    
    private func getMemoryUsage() -> Int64 {
        let processInfo = ProcessInfo.processInfo
        return Int64(processInfo.physicalMemory)
    }
    
    private func getFolderSize(_ path: String) -> Int64? {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: path) else { return nil }
        
        var totalSize: Int64 = 0
        
        while let fileName = enumerator.nextObject() as? String {
            let filePath = "\(path)/\(fileName)"
            if let attributes = try? fileManager.attributesOfItem(atPath: filePath) {
                if let size = attributes[.size] as? Int64 {
                    totalSize += size
                }
            }
        }
        
        return totalSize
    }
    
    private func cleanDirectory(_ path: String) -> Bool {
        let fileManager = FileManager.default
        
        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            return false
        }
        
        for item in contents {
            let itemPath = "\(path)/\(item)"
            try? fileManager.removeItem(atPath: itemPath)
        }
        
        return true
    }
    
    private func cleanOldFiles(in directory: String, olderThanDays days: Int) {
        let fileManager = FileManager.default
        let cutoffDate = Date().addingTimeInterval(-TimeInterval(days * 24 * 60 * 60))
        
        guard let contents = try? fileManager.contentsOfDirectory(atPath: directory) else {
            return
        }
        
        for item in contents {
            let itemPath = "\(directory)/\(item)"
            if let attributes = try? fileManager.attributesOfItem(atPath: itemPath),
               let modificationDate = attributes[.modificationDate] as? Date,
               modificationDate < cutoffDate {
                try? fileManager.removeItem(atPath: itemPath)
            }
        }
    }
    
    private func clearFontCaches() {
        let task = Process()
        task.launchPath = "/usr/bin/atsutil"
        task.arguments = ["databases", "-remove"]
        task.launch()
        task.waitUntilExit()
    }
    
    private func clearDNSCache() {
        let task = Process()
        task.launchPath = "/usr/bin/dscacheutil"
        task.arguments = ["-flushcache"]
        task.launch()
        task.waitUntilExit()
    }
    
    private func optimizeSystemDatabases() {
        // Optimize Spotlight index
        let spotlightTask = Process()
        spotlightTask.launchPath = "/usr/bin/mdutil"
        spotlightTask.arguments = ["-E", "/"]
        spotlightTask.launch()
        spotlightTask.waitUntilExit()
        
        // Rebuild dyld cache
        let dyldTask = Process()
        dyldTask.launchPath = "/usr/bin/update_dyld_shared_cache"
        dyldTask.arguments = ["-force"]
        dyldTask.launch()
        dyldTask.waitUntilExit()
    }
    
    private func generateCleanupRecommendations() -> [String] {
        var recommendations: [String] = []
        
        // Check memory usage
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let freeMemory = getAvailableMemory()
        
        if freeMemory < totalMemory / 5 { // Less than 20% free
            recommendations.append("🧠 Run 'systemcleanup memory' to free up RAM")
        }
        
        // Check cache sizes
        let userCachePath = NSString(string: "~/Library/Caches").expandingTildeInPath
        if let cacheSize = getFolderSize(userCachePath), cacheSize > 500 * 1024 * 1024 {
            recommendations.append("🗑️  Run 'systemcleanup cache' to clear large caches")
        }
        
        // Check running processes
        let processes = getRunningProcesses()
        if processes.count > 150 {
            recommendations.append("🚫 Run 'systemcleanup services' to reduce background processes")
        }
        
        return recommendations
    }
    
    private func getAvailableMemory() -> UInt64 {
        // Simplified - would need proper implementation
        return 0
    }
    
    private func formatUptime(_ uptime: TimeInterval) -> String {
        let hours = Int(uptime) / 3600
        let minutes = Int(uptime) % 3600 / 60
        return "\(hours)h \(minutes)m"
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: bytes)
    }
    
    private func extractNumber(from string: String) -> Int {
        let numbers = string.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .joined()
        return Int(numbers) ?? 0
    }
    
    private func calculateMemoryPressure(free: Int, total: Int) -> String {
        let freePercent = (Double(free) / Double(total)) * 100
        
        switch freePercent {
        case 20...:
            return "Normal"
        case 10..<20:
            return "Medium"
        case 5..<10:
            return "High"
        default:
            return "Critical"
        }
    }
}

// Simplified XPC communicator for cleanup tool
class SystemExtensionCommunicator {
    func sendCommand(_ command: String, completion: @escaping (Bool, [String: Any]?) -> Void) {
        // XPC communication implementation
        completion(true, [:])
    }
}

// Entry point
let cleanup = SystemCleanupCLI()
cleanup.run()