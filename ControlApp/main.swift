import Foundation
import SystemExtensions
import OSLog

// Main app structure
struct AudioVideoMonitorApp {
    private let log = OSLog(subsystem: "com.example.AudioVideoMonitor", category: "MainApp")
    private let extensionManager = SystemExtensionManager()
    private let communicator = SystemExtensionCommunicator()
    
    func run() {
        let arguments = CommandLine.arguments
        
        if arguments.count < 2 {
            printUsage()
            exit(1)
        }
        
        let command = arguments[1]
        
        switch command {
        case "install":
            installExtension()
        case "uninstall":
            uninstallExtension()
        case "status":
            getSystemStatus()
        case "control":
            if arguments.count < 3 {
                print("Error: control command requires an action")
                printControlUsage()
                exit(1)
            }
            handleControlCommand(arguments[2])
        case "cleanup":
            if arguments.count < 3 {
                print("Error: cleanup command requires an action")
                printCleanupUsage()
                exit(1)
            }
            handleCleanupCommand(Array(arguments[2...]))
        default:
            print("Unknown command: \(command)")
            printUsage()
            exit(1)
        }
    }
    
    private func printUsage() {
        print("""
        AudioVideoMonitor - macOS System Extension for Audio/Video Control
        
        Usage: AudioVideoMonitor <command> [options]
        
        Commands:
          install                Install the system extension
          uninstall              Remove the system extension
          status                 Show extension and device status
          control <action>       Control audio/video devices
          cleanup <action>       System cleanup and optimization
        
        Control Actions:
          disable-mic           Disable microphone access
          enable-mic            Enable microphone access
          disable-cam           Disable camera access
          enable-cam            Enable camera access
          get-status           Get current device status
        
        Cleanup Actions:
          analyze              Analyze system performance
          services             Clean background services
          memory               Free up RAM
          cache                Clear system caches
          full                 Complete system cleanup
          safe-mode            Conservative cleanup
        
        Examples:
          AudioVideoMonitor install
          AudioVideoMonitor control disable-mic
          AudioVideoMonitor control get-status
          AudioVideoMonitor cleanup analyze
          AudioVideoMonitor cleanup full --dry-run
          AudioVideoMonitor status
        """)
    }
    
    private func printControlUsage() {
        print("""
        Control command usage:
          AudioVideoMonitor control disable-mic    # Disable microphone
          AudioVideoMonitor control enable-mic     # Enable microphone
          AudioVideoMonitor control disable-cam    # Disable camera
          AudioVideoMonitor control enable-cam     # Enable camera
          AudioVideoMonitor control get-status     # Get device status
        """)
    }
    
    private func printCleanupUsage() {
        print("""
        System Cleanup command usage:
          AudioVideoMonitor cleanup analyze            # Analyze system performance
          AudioVideoMonitor cleanup services [--dry-run]  # Clean background services
          AudioVideoMonitor cleanup memory             # Free up RAM and memory
          AudioVideoMonitor cleanup cache              # Clear system caches
          AudioVideoMonitor cleanup full [--dry-run]   # Complete system cleanup
          AudioVideoMonitor cleanup safe-mode          # Conservative cleanup only
          
        Options:
          --dry-run    Preview changes without executing them
          
        Note: Some cleanup operations may require administrator privileges.
        """)
    }
    
    private func handleCleanupCommand(_ arguments: [String]) {
        if arguments.isEmpty {
            printCleanupUsage()
            return
        }
        
        let cleanupAction = arguments[0]
        let additionalArgs = Array(arguments[1...])
        
        // Launch systemcleanup CLI tool with the specified arguments
        let task = Process()
        task.launchPath = "/usr/local/bin/systemcleanup"
        task.arguments = [cleanupAction] + additionalArgs
        
        // Set up pipes for output
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        
        do {
            try task.run()
            
            // Read and display output in real-time
            let outputHandle = outputPipe.fileHandleForReading
            let errorHandle = errorPipe.fileHandleForReading
            
            let outputData = outputHandle.readDataToEndOfFile()
            let errorData = errorHandle.readDataToEndOfFile()
            
            if let output = String(data: outputData, encoding: .utf8), !output.isEmpty {
                print(output)
            }
            
            if let errorOutput = String(data: errorData, encoding: .utf8), !errorOutput.isEmpty {
                print("Error: \(errorOutput)")  // Print to stdout instead
            }
            
            task.waitUntilExit()
            
            if task.terminationStatus != 0 {
                print("⚠️  Cleanup command failed with status: \(task.terminationStatus)")
                exit(Int32(task.terminationStatus))
            }
            
        } catch {
            print("❌ Failed to execute cleanup command: \(error)")
            print("💡 Make sure systemcleanup is installed. Run: sudo ./install.sh")
            exit(1)
        }
    }
    
    private func installExtension() {
        print("📦 Installing AudioVideoMonitor System Extension...")
        print("   This may require administrator approval.")
        
        let semaphore = DispatchSemaphore(value: 0)
        var installSuccess = false
        
        extensionManager.activateExtension { success in
            installSuccess = success
            semaphore.signal()
        }
        
        // Wait for completion
        semaphore.wait()
        
        if installSuccess {
            print("✅ System extension installed successfully!")
            print("   You may need to approve it in System Settings if prompted.")
            print("   Path: System Settings > Privacy & Security > Login Items & Extensions")
        } else {
            print("❌ Failed to install system extension.")
            print("   Make sure you have administrator privileges.")
            exit(1)
        }
    }
    
    private func uninstallExtension() {
        print("🗑️  Uninstalling AudioVideoMonitor System Extension...")
        
        let semaphore = DispatchSemaphore(value: 0)
        var uninstallSuccess = false
        
        extensionManager.deactivateExtension { success in
            uninstallSuccess = success
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if uninstallSuccess {
            print("✅ System extension uninstalled successfully!")
        } else {
            print("❌ Failed to uninstall system extension.")
            exit(1)
        }
    }
    
    private func getSystemStatus() {
        print("📊 AudioVideoMonitor System Status")
        print("=" * 40)
        
        // Check if extension is installed
        _ = OSSystemExtensionManager.shared
        print("🔍 Checking system extension status...")
        
        // Get device status from extension
        getDeviceStatusFromExtension()
    }
    
    private func getDeviceStatusFromExtension() {
        let semaphore = DispatchSemaphore(value: 0)
        
        communicator.sendCommand("get_status") { success, data in
            if success, let data = data {
                let micEnabled = data["microphone_enabled"] as? Bool ?? false
                let camEnabled = data["camera_enabled"] as? Bool ?? false
                
                print("🎤 Microphone: \(micEnabled ? "🟢 Enabled" : "🔴 Disabled")")
                print("📹 Camera: \(camEnabled ? "🟢 Enabled" : "🔴 Disabled")")
                print("🔗 Extension: 🟢 Connected")
            } else {
                print("🎤 Microphone: ❓ Unknown")
                print("📹 Camera: ❓ Unknown")
                print("🔗 Extension: 🔴 Not responding")
                print("   The system extension may not be installed or running.")
            }
            semaphore.signal()
        }
        
        semaphore.wait()
    }
    
    private func handleControlCommand(_ action: String) {
        let command: String
        let actionDescription: String
        
        switch action {
        case "disable-mic":
            command = "disable_microphone"
            actionDescription = "Disabling microphone"
        case "enable-mic":
            command = "enable_microphone"
            actionDescription = "Enabling microphone"
        case "disable-cam":
            command = "disable_camera"
            actionDescription = "Disabling camera"
        case "enable-cam":
            command = "enable_camera"
            actionDescription = "Enabling camera"
        case "get-status":
            getDeviceStatusFromExtension()
            return
        default:
            print("❌ Unknown control action: \(action)")
            printControlUsage()
            exit(1)
        }
        
        print("⚙️  \(actionDescription)...")
        
        let semaphore = DispatchSemaphore(value: 0)
        
        communicator.sendCommand(command) { success, data in
            if success {
                print("✅ \(actionDescription) completed successfully!")
            } else {
                print("❌ Failed to \(actionDescription.lowercased())")
                if let error = data?["error"] as? String {
                    print("   Error: \(error)")
                }
                exit(1)
            }
            semaphore.signal()
        }
        
        semaphore.wait()
    }
}

// Helper extension for string repetition
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}

// Main entry point
let app = AudioVideoMonitorApp()
app.run()