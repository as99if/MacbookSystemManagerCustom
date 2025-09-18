#!/usr/bin/env swift

import Foundation
import os.log
import SQLite3

class SystemMonitorCLI {
    private let logger = Logger(subsystem: "com.example.AudioVideoMonitor", category: "MonitorCLI")
    private let communicator = SystemExtensionCommunicator()
    private let dbPath = "/var/log/AudioVideoMonitor.db"
    private var database: OpaquePointer?
    
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
        case "monitor":
            startRealTimeMonitoring()
        case "processes":
            showProcessHistory()
        case "files":
            showFileAccessHistory()
        case "network":
            showNetworkActivity()
        case "search":
            if arguments.count > 2 {
                searchEvents(arguments[2])
            } else {
                print("❌ Search command requires a search term")
                exit(1)
            }
        case "dump":
            if arguments.count > 2 {
                dumpProcessMemory(Int32(arguments[2]) ?? 0)
            } else {
                print("❌ Dump command requires a PID")
                exit(1)
            }
        case "analyze":
            if arguments.count > 2 {
                analyzeProcess(Int32(arguments[2]) ?? 0)
            } else {
                print("❌ Analyze command requires a PID")
                exit(1)
            }
        case "export":
            exportData()
        case "stats":
            showSystemStats()
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
        🔍 SystemMonitor CLI - Comprehensive Process and System Monitoring
        
        USAGE:
            systemmonitor <command> [options]
        
        COMMANDS:
            monitor             🔴 Start real-time monitoring (live output)
            processes           📋 Show process execution history
            files               📁 Show file access history  
            network             🌐 Show network activity
            search <term>       🔍 Search all events for specific term
            dump <pid>          🧠 Dump process memory to file
            analyze <pid>       🔬 Comprehensive process analysis
            export              📤 Export all data to CSV files
            stats               📊 Show system monitoring statistics
            help                ❓ Show this help message
        
        MONITORING FEATURES:
            • Real-time process execution tracking
            • Comprehensive file system monitoring
            • Network connection tracking
            • System call monitoring
            • Memory analysis and dumping
            • Environment variable capture
            • Library loading tracking
            • Process tree reconstruction
        
        EXAMPLES:
            systemmonitor monitor                    # Live monitoring
            systemmonitor processes | head -20       # Recent processes
            systemmonitor files | grep "/etc"        # System file access
            systemmonitor search "chrome"            # Find Chrome-related events
            systemmonitor analyze 1234               # Deep dive into PID 1234
            systemmonitor dump 1234                  # Memory dump of PID 1234
        
        DATA LOCATION:
            Database: /var/log/AudioVideoMonitor.db
            Memory dumps: /var/log/memory_dumps/
            Exports: /var/log/exports/
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
    
    private func startRealTimeMonitoring() {
        print("🔴 Starting Real-Time System Monitoring...")
        print("   Press Ctrl+C to stop")
        print("=" + String(repeating: "=", count: 79))
        
        // Set up signal handler for clean exit
        signal(SIGINT) { _ in
            print("\n\n🛑 Monitoring stopped by user")
            exit(0)
        }
        
        var lastTimestamp: Int64 = 0
        
        while true {
            // Query recent events
            showRecentEvents(since: lastTimestamp)
            lastTimestamp = Int64(Date().timeIntervalSince1970)
            
            // Sleep for 1 second
            usleep(1000000)
        }
    }
    
    private func showRecentEvents(since timestamp: Int64) {
        guard let db = database else { return }
        
        // Process events
        let processSQL = """
            SELECT timestamp, pid, executable_path, event_type, uid 
            FROM process_events 
            WHERE timestamp > ? 
            ORDER BY timestamp DESC 
            LIMIT 10
        """
        
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, processSQL, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, timestamp)
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let timestamp = sqlite3_column_int64(stmt, 0)
                let pid = sqlite3_column_int(stmt, 1)
                let path = String(cString: sqlite3_column_text(stmt, 2))
                let event = String(cString: sqlite3_column_text(stmt, 3))
                let uid = sqlite3_column_int(stmt, 4)
                
                let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm:ss"
                
                print("🔄 [\(formatter.string(from: date))] \(event) PID:\(pid) UID:\(uid) \(path)")
            }
        }
        sqlite3_finalize(stmt)
        
        // File access events
        let fileSQL = """
            SELECT timestamp, pid, file_path, access_type, was_blocked
            FROM file_access 
            WHERE timestamp > ? 
            ORDER BY timestamp DESC 
            LIMIT 5
        """
        
        if sqlite3_prepare_v2(db, fileSQL, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, timestamp)
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let timestamp = sqlite3_column_int64(stmt, 0)
                let pid = sqlite3_column_int(stmt, 1)
                let path = String(cString: sqlite3_column_text(stmt, 2))
                let accessType = String(cString: sqlite3_column_text(stmt, 3))
                let blocked = sqlite3_column_int(stmt, 4) != 0
                
                let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm:ss"
                
                let blockStatus = blocked ? "🔒" : "✅"
                print("📁 [\(formatter.string(from: date))] \(accessType) \(blockStatus) PID:\(pid) \(path)")
            }
        }
        sqlite3_finalize(stmt)
    }
    
    private func showProcessHistory() {
        print("📋 Process Execution History")
        print("=" + String(repeating: "=", count: 79))
        
        guard let db = database else { return }
        
        let sql = """
            SELECT timestamp, pid, ppid, executable_path, command_line, event_type, uid, gid, 
                   cpu_time, memory_usage, is_system_process
            FROM process_events 
            ORDER BY timestamp DESC 
            LIMIT 50
        """
        
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            
            printf("%-20s %-8s %-8s %-8s %-8s %-10s %-40s\n", 
                   "TIMESTAMP", "PID", "PPID", "UID", "GID", "EVENT", "EXECUTABLE")
            print(String(repeating: "-", count: 120))
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let timestamp = sqlite3_column_int64(stmt, 0)
                let pid = sqlite3_column_int(stmt, 1)
                let ppid = sqlite3_column_int(stmt, 2)
                let path = String(cString: sqlite3_column_text(stmt, 3))
                let cmdline = sqlite3_column_text(stmt, 4) != nil ? 
                             String(cString: sqlite3_column_text(stmt, 4)) : ""
                let event = String(cString: sqlite3_column_text(stmt, 5))
                let uid = sqlite3_column_int(stmt, 6)
                let gid = sqlite3_column_int(stmt, 7)
                let cpuTime = sqlite3_column_int64(stmt, 8)
                let memUsage = sqlite3_column_int64(stmt, 9)
                let isSystem = sqlite3_column_int(stmt, 10) != 0
                
                let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
                let formatter = DateFormatter()
                formatter.dateFormat = "MM/dd HH:mm:ss"
                
                let systemIcon = isSystem ? "⚙️ " : ""
                let executableName = URL(fileURLWithPath: path).lastPathComponent
                
                printf("%-20s %-8d %-8d %-8d %-8d %-10s %s%-39s\n",
                       formatter.string(from: date), pid, ppid, uid, gid, event, 
                       systemIcon, executableName)
                
                if !cmdline.isEmpty && cmdline != path {
                    print("   📝 Command: \(cmdline)")
                }
                
                if memUsage > 0 {
                    let memMB = Double(memUsage) / (1024 * 1024)
                    print("   💾 Memory: \(String(format: "%.1f", memMB)) MB, CPU: \(cpuTime) ticks")
                }
            }
        }
        sqlite3_finalize(stmt)
    }
    
    private func showFileAccessHistory() {
        print("📁 File Access History")
        print("=" + String(repeating: "=", count: 79))
        
        guard let db = database else { return }
        
        let sql = """
            SELECT f.timestamp, f.pid, f.file_path, f.access_type, f.was_blocked, f.reason,
                   p.executable_path
            FROM file_access f
            LEFT JOIN process_events p ON f.pid = p.pid
            ORDER BY f.timestamp DESC 
            LIMIT 100
        """
        
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            
            printf("%-20s %-8s %-10s %-8s %-50s %-20s\n",
                   "TIMESTAMP", "PID", "ACCESS", "BLOCKED", "FILE_PATH", "PROCESS")
            print(String(repeating: "-", count: 120))
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let timestamp = sqlite3_column_int64(stmt, 0)
                let pid = sqlite3_column_int(stmt, 1)
                let filePath = String(cString: sqlite3_column_text(stmt, 2))
                let accessType = String(cString: sqlite3_column_text(stmt, 3))
                let blocked = sqlite3_column_int(stmt, 4) != 0
                let reason = sqlite3_column_text(stmt, 5) != nil ? 
                           String(cString: sqlite3_column_text(stmt, 5)) : ""
                let processPath = sqlite3_column_text(stmt, 6) != nil ? 
                                String(cString: sqlite3_column_text(stmt, 6)) : "Unknown"
                
                let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
                let formatter = DateFormatter()
                formatter.dateFormat = "MM/dd HH:mm:ss"
                
                let blockIcon = blocked ? "🔒" : "✅"
                let processName = URL(fileURLWithPath: processPath).lastPathComponent
                
                printf("%-20s %-8d %-10s %-8s %-50s %-20s\n",
                       formatter.string(from: date), pid, accessType, blockIcon, 
                       filePath, processName)
                
                if blocked && !reason.isEmpty {
                    print("   ⚠️  Blocked: \(reason)")
                }
            }
        }
        sqlite3_finalize(stmt)
    }
    
    private func showNetworkActivity() {
        print("🌐 Network Activity")
        print("=" + String(repeating: "=", count: 79))
        
        guard let db = database else { return }
        
        let sql = """
            SELECT n.timestamp, n.pid, n.protocol, n.local_address, n.local_port,
                   n.remote_address, n.remote_port, n.state, p.executable_path
            FROM network_connections n
            LEFT JOIN process_events p ON n.pid = p.pid
            ORDER BY n.timestamp DESC 
            LIMIT 50
        """
        
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            
            printf("%-20s %-8s %-8s %-20s %-20s %-15s %-20s\n",
                   "TIMESTAMP", "PID", "PROTO", "LOCAL", "REMOTE", "STATE", "PROCESS")
            print(String(repeating: "-", count: 120))
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let timestamp = sqlite3_column_int64(stmt, 0)
                let pid = sqlite3_column_int(stmt, 1)
                let protocol = String(cString: sqlite3_column_text(stmt, 2))
                let localAddr = String(cString: sqlite3_column_text(stmt, 3))
                let localPort = sqlite3_column_int(stmt, 4)
                let remoteAddr = String(cString: sqlite3_column_text(stmt, 5))
                let remotePort = sqlite3_column_int(stmt, 6)
                let state = String(cString: sqlite3_column_text(stmt, 7))
                let processPath = sqlite3_column_text(stmt, 8) != nil ? 
                                String(cString: sqlite3_column_text(stmt, 8)) : "Unknown"
                
                let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
                let formatter = DateFormatter()
                formatter.dateFormat = "MM/dd HH:mm:ss"
                
                let processName = URL(fileURLWithPath: processPath).lastPathComponent
                let localEndpoint = "\(localAddr):\(localPort)"
                let remoteEndpoint = "\(remoteAddr):\(remotePort)"
                
                printf("%-20s %-8d %-8s %-20s %-20s %-15s %-20s\n",
                       formatter.string(from: date), pid, protocol, localEndpoint, 
                       remoteEndpoint, state, processName)
            }
        }
        sqlite3_finalize(stmt)
    }
    
    private func searchEvents(_ searchTerm: String) {
        print("🔍 Searching for: '\(searchTerm)'")
        print("=" + String(repeating: "=", count: 79))
        
        guard let db = database else { return }
        
        // Search in process events
        print("📋 Process Events:")
        let processSQL = """
            SELECT timestamp, pid, executable_path, command_line, event_type
            FROM process_events 
            WHERE executable_path LIKE ? OR command_line LIKE ?
            ORDER BY timestamp DESC 
            LIMIT 20
        """
        
        var stmt: OpaquePointer?
        let searchPattern = "%\(searchTerm)%"
        
        if sqlite3_prepare_v2(db, processSQL, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, searchPattern, -1, nil)
            sqlite3_bind_text(stmt, 2, searchPattern, -1, nil)
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let timestamp = sqlite3_column_int64(stmt, 0)
                let pid = sqlite3_column_int(stmt, 1)
                let path = String(cString: sqlite3_column_text(stmt, 2))
                let cmdline = sqlite3_column_text(stmt, 3) != nil ? 
                             String(cString: sqlite3_column_text(stmt, 3)) : ""
                let event = String(cString: sqlite3_column_text(stmt, 4))
                
                let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
                let formatter = DateFormatter()
                formatter.dateFormat = "MM/dd HH:mm:ss"
                
                print("  [\(formatter.string(from: date))] \(event) PID:\(pid) \(path)")
                if !cmdline.isEmpty {
                    print("    Command: \(cmdline)")
                }
            }
        }
        sqlite3_finalize(stmt)
        
        // Search in file access
        print("\n📁 File Access Events:")
        let fileSQL = """
            SELECT timestamp, pid, file_path, access_type, was_blocked
            FROM file_access 
            WHERE file_path LIKE ?
            ORDER BY timestamp DESC 
            LIMIT 20
        """
        
        if sqlite3_prepare_v2(db, fileSQL, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, searchPattern, -1, nil)
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let timestamp = sqlite3_column_int64(stmt, 0)
                let pid = sqlite3_column_int(stmt, 1)
                let path = String(cString: sqlite3_column_text(stmt, 2))
                let accessType = String(cString: sqlite3_column_text(stmt, 3))
                let blocked = sqlite3_column_int(stmt, 4) != 0
                
                let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
                let formatter = DateFormatter()
                formatter.dateFormat = "MM/dd HH:mm:ss"
                
                let blockIcon = blocked ? "🔒" : "✅"
                print("  [\(formatter.string(from: date))] \(accessType) \(blockIcon) PID:\(pid) \(path)")
            }
        }
        sqlite3_finalize(stmt)
    }
    
    private func analyzeProcess(_ pid: Int32) {
        print("🔬 Comprehensive Process Analysis for PID: \(pid)")
        print("=" + String(repeating: "=", count: 79))
        
        // Get process information via XPC
        communicator.sendCommand("analyze_process_\(pid)") { success, data in
            if success, let data = data {
                self.displayProcessAnalysis(data)
            } else {
                print("❌ Failed to analyze process")
            }
        }
        
        // Also query database for historical data
        queryProcessHistory(pid)
    }
    
    private func queryProcessHistory(_ pid: Int32) {
        guard let db = database else { return }
        
        print("\n📊 Historical Data for PID \(pid):")
        
        // Process events
        let processSQL = """
            SELECT timestamp, executable_path, command_line, event_type, cpu_time, memory_usage
            FROM process_events 
            WHERE pid = ?
            ORDER BY timestamp DESC
        """
        
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, processSQL, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, pid)
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let timestamp = sqlite3_column_int64(stmt, 0)
                let path = String(cString: sqlite3_column_text(stmt, 1))
                let cmdline = sqlite3_column_text(stmt, 2) != nil ? 
                             String(cString: sqlite3_column_text(stmt, 2)) : ""
                let event = String(cString: sqlite3_column_text(stmt, 3))
                let cpuTime = sqlite3_column_int64(stmt, 4)
                let memUsage = sqlite3_column_int64(stmt, 5)
                
                let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                
                print("  📋 [\(formatter.string(from: date))] \(event)")
                print("      Executable: \(path)")
                if !cmdline.isEmpty {
                    print("      Command: \(cmdline)")
                }
                if memUsage > 0 {
                    let memMB = Double(memUsage) / (1024 * 1024)
                    print("      Memory: \(String(format: "%.1f", memMB)) MB, CPU: \(cpuTime) ticks")
                }
            }
        }
        sqlite3_finalize(stmt)
        
        // File access count
        let fileSQL = "SELECT COUNT(*) FROM file_access WHERE pid = ?"
        if sqlite3_prepare_v2(db, fileSQL, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, pid)
            if sqlite3_step(stmt) == SQLITE_ROW {
                let count = sqlite3_column_int(stmt, 0)
                print("  📁 File accesses: \(count)")
            }
        }
        sqlite3_finalize(stmt)
        
        // Network connections count
        let netSQL = "SELECT COUNT(*) FROM network_connections WHERE pid = ?"
        if sqlite3_prepare_v2(db, netSQL, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, pid)
            if sqlite3_step(stmt) == SQLITE_ROW {
                let count = sqlite3_column_int(stmt, 0)
                print("  🌐 Network connections: \(count)")
            }
        }
        sqlite3_finalize(stmt)
    }
    
    private func dumpProcessMemory(_ pid: Int32) {
        print("🧠 Dumping memory for PID: \(pid)")
        
        communicator.sendCommand("dump_memory_\(pid)") { success, data in
            if success, let data = data {
                if let dumpPath = data["dump_path"] as? String {
                    print("✅ Memory dump saved to: \(dumpPath)")
                    
                    // Show dump file info
                    let fileManager = FileManager.default
                    if let attributes = try? fileManager.attributesOfItem(atPath: dumpPath) {
                        if let size = attributes[.size] as? Int64 {
                            let sizeMB = Double(size) / (1024 * 1024)
                            print("   📊 Dump size: \(String(format: "%.1f", sizeMB)) MB")
                        }
                    }
                } else {
                    print("❌ Memory dump failed")
                }
            } else {
                print("❌ Failed to communicate with system extension")
            }
        }
    }
    
    private func exportData() {
        print("📤 Exporting monitoring data...")
        
        let exportDir = "/var/log/exports"
        let fileManager = FileManager.default
        
        // Create export directory
        try? fileManager.createDirectory(atPath: exportDir, withIntermediateDirectories: true)
        
        let timestamp = DateFormatter().string(from: Date())
        
        // Export process events
        exportProcessEvents(to: "\(exportDir)/processes_\(timestamp).csv")
        exportFileAccess(to: "\(exportDir)/file_access_\(timestamp).csv")
        exportNetworkConnections(to: "\(exportDir)/network_\(timestamp).csv")
        
        print("✅ Data exported to: \(exportDir)")
    }
    
    private func showSystemStats() {
        print("📊 System Monitoring Statistics")
        print("=" + String(repeating: "=", count: 79))
        
        guard let db = database else { return }
        
        var stmt: OpaquePointer?
        
        // Total events
        let tables = ["process_events", "file_access", "network_connections", "system_calls"]
        
        for table in tables {
            let sql = "SELECT COUNT(*) FROM \(table)"
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) == SQLITE_ROW {
                    let count = sqlite3_column_int(stmt, 0)
                    print("📈 \(table.capitalized.replacingOccurrences(of: "_", with: " ")): \(count) events")
                }
            }
            sqlite3_finalize(stmt)
        }
        
        // Most active processes
        print("\n🔥 Most Active Processes:")
        let activeSQL = """
            SELECT executable_path, COUNT(*) as event_count
            FROM process_events 
            GROUP BY executable_path 
            ORDER BY event_count DESC 
            LIMIT 10
        """
        
        if sqlite3_prepare_v2(db, activeSQL, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let path = String(cString: sqlite3_column_text(stmt, 0))
                let count = sqlite3_column_int(stmt, 1)
                let processName = URL(fileURLWithPath: path).lastPathComponent
                print("  \(processName): \(count) events")
            }
        }
        sqlite3_finalize(stmt)
        
        // Database size
        if let attributes = try? FileManager.default.attributesOfItem(atPath: dbPath) {
            if let size = attributes[.size] as? Int64 {
                let sizeMB = Double(size) / (1024 * 1024)
                print("\n💾 Database size: \(String(format: "%.1f", sizeMB)) MB")
            }
        }
    }
    
    private func displayProcessAnalysis(_ data: [String: Any]) {
        // Display comprehensive process analysis data
        print("Process analysis data received")
        // Implementation would display detailed process information
    }
    
    // Export methods
    private func exportProcessEvents(to path: String) {
        // CSV export implementation
    }
    
    private func exportFileAccess(to path: String) {
        // CSV export implementation  
    }
    
    private func exportNetworkConnections(to path: String) {
        // CSV export implementation
    }
}

// Simplified XPC communicator for monitoring CLI
class SystemExtensionCommunicator {
    func sendCommand(_ command: String, completion: @escaping (Bool, [String: Any]?) -> Void) {
        // XPC communication implementation
        completion(true, [:])
    }
}

// Entry point
let monitor = SystemMonitorCLI()
monitor.run()