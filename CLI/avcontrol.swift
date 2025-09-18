#!/usr/bin/env swift

import Foundation
import os.log
import XPC

class AudioVideoControlCLI {
    private let logger = Logger(subsystem: "com.example.AudioVideoControl", category: "CLI")
    private let communicator = SystemExtensionCommunicator()
    
    func run() {
        let arguments = CommandLine.arguments
        
        guard arguments.count > 1 else {
            printUsage()
            exit(1)
        }
        
        let command = arguments[1]
        
        switch command {
        case "disable-mic":
            disableMicrophone()
        case "enable-mic":
            enableMicrophone()
        case "disable-cam":
            disableCamera()
        case "enable-cam":
            enableCamera()
        case "status":
            getStatus()
        case "install":
            installExtension()
        case "uninstall":
            uninstallExtension()
        case "help", "--help", "-h":
            printUsage()
            exit(0)
        case "version", "--version", "-v":
            printVersion()
            exit(0)
        default:
            print("❌ Unknown command: \(command)")
            printUsage()
            exit(1)
        }
    }
    
    private func printUsage() {
        print("""
        🎛️  AudioVideoControl CLI - macOS Audio/Video Device Controller
        
        USAGE:
            avcontrol <command>
        
        COMMANDS:
            install        📦 Install system extension
            uninstall      🗑️  Uninstall system extension
            disable-mic    🔇 Disable microphone access
            enable-mic     🎤 Enable microphone access
            disable-cam    📵 Disable camera access
            enable-cam     📹 Enable camera access
            status         📊 Show current device status
            help           ❓ Show this help message
            version        ℹ️  Show version information
        
        EXAMPLES:
            avcontrol install           # Install the system extension
            avcontrol disable-mic       # Disable microphone system-wide
            avcontrol enable-cam        # Enable camera system-wide
            avcontrol status            # Check current status
        
        NOTE:
            This tool requires the AudioVideoMonitor System Extension to be
            installed and approved in System Settings > Privacy & Security.
        """)
    }
    
    private func printVersion() {
        print("AudioVideoControl CLI v1.0")
        print("Built for macOS System Extensions and DriverKit")
        print("© 2024 - Modern replacement for kernel extensions")
    }
    
    private func installExtension() {
        print("📦 Installing AudioVideoMonitor System Extension...")
        print("   This operation requires administrator privileges.")
        
        let manager = SystemExtensionManager()
        let semaphore = DispatchSemaphore(value: 0)
        var success = false
        
        manager.activateExtension { result in
            success = result
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if success {
            print("✅ System extension installed successfully!")
            print("📋 Next steps:")
            print("   1. Go to System Settings > Privacy & Security")
            print("   2. Navigate to Login Items & Extensions")
            print("   3. Approve the AudioVideoMonitor extension")
            print("   4. Run 'avcontrol status' to verify installation")
        } else {
            print("❌ Failed to install system extension")
            print("💡 Troubleshooting:")
            print("   • Make sure you have administrator privileges")
            print("   • Check Console.app for error messages")
            print("   • Ensure macOS version supports System Extensions")
            exit(1)
        }
    }
    
    private func uninstallExtension() {
        print("🗑️  Uninstalling AudioVideoMonitor System Extension...")
        
        let manager = SystemExtensionManager()
        let semaphore = DispatchSemaphore(value: 0)
        var success = false
        
        manager.deactivateExtension { result in
            success = result
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if success {
            print("✅ System extension uninstalled successfully!")
            print("🔄 All audio/video controls have been restored to system defaults.")
        } else {
            print("❌ Failed to uninstall system extension")
            print("💡 You may need to remove it manually from System Settings")
            exit(1)
        }
    }
    
    private func disableMicrophone() {
        print("🔇 Disabling microphone access...")
        executeCommand("disable_microphone") { success in
            if success {
                print("✅ Microphone disabled system-wide")
                print("🔒 Applications will no longer have access to microphone input")
            } else {
                print("❌ Failed to disable microphone")
                self.printTroubleshooting()
                exit(1)
            }
        }
    }
    
    private func enableMicrophone() {
        print("🎤 Enabling microphone access...")
        executeCommand("enable_microphone") { success in
            if success {
                print("✅ Microphone enabled system-wide")
                print("🔓 Applications can now access microphone input (subject to permissions)")
            } else {
                print("❌ Failed to enable microphone")
                self.printTroubleshooting()
                exit(1)
            }
        }
    }
    
    private func disableCamera() {
        print("📵 Disabling camera access...")
        executeCommand("disable_camera") { success in
            if success {
                print("✅ Camera disabled system-wide")
                print("🔒 Applications will no longer have access to camera input")
            } else {
                print("❌ Failed to disable camera")
                self.printTroubleshooting()
                exit(1)
            }
        }
    }
    
    private func enableCamera() {
        print("📹 Enabling camera access...")
        executeCommand("enable_camera") { success in
            if success {
                print("✅ Camera enabled system-wide")
                print("🔓 Applications can now access camera input (subject to permissions)")
            } else {
                print("❌ Failed to enable camera")
                self.printTroubleshooting()
                exit(1)
            }
        }
    }
    
    private func getStatus() {
        print("📊 AudioVideoMonitor Device Status")
        print("=" + String(repeating: "=", count: 39))
        
        executeCommand("get_status") { success, data in
            if success, let data = data {
                let micEnabled = data["microphone_enabled"] as? Bool ?? false
                let camEnabled = data["camera_enabled"] as? Bool ?? false
                
                print("🎤 Microphone: \(micEnabled ? "🟢 Enabled" : "🔴 Disabled")")
                print("📹 Camera:     \(camEnabled ? "🟢 Enabled" : "🔴 Disabled")")
                print("🔗 Extension:  🟢 Active and responding")
                
                print("\n📋 System Information:")
                print("   • Extension Bundle: com.example.AudioVideoMonitor.SystemExtension")
                print("   • Communication: XPC Service")
                print("   • Framework: Endpoint Security")
                
                if !micEnabled || !camEnabled {
                    print("\n⚠️  Warning: Some devices are disabled")
                    print("   Use 'avcontrol enable-mic' or 'avcontrol enable-cam' to enable them")
                }
            } else {
                print("🎤 Microphone: ❓ Unknown")
                print("📹 Camera:     ❓ Unknown") 
                print("🔗 Extension:  🔴 Not responding")
                
                print("\n❌ Cannot communicate with system extension")
                print("💡 Troubleshooting:")
                print("   • Run 'avcontrol install' to install the extension")
                print("   • Check System Settings > Privacy & Security > Login Items & Extensions")
                print("   • Restart the system extension or reboot if needed")
                exit(1)
            }
        }
    }
    
    private func printTroubleshooting() {
        print("💡 Troubleshooting:")
        print("   • Ensure the system extension is installed: 'avcontrol install'")
        print("   • Check that it's approved in System Settings")
        print("   • Verify you have the necessary permissions")
        print("   • Check Console.app for detailed error messages")
        print("   • Try running 'avcontrol status' to check extension connectivity")
    }
    
    private func executeCommand(_ command: String, completion: @escaping (Bool, [String: Any]?) -> Void) {
        let semaphore = DispatchSemaphore(value: 0)
        
        communicator.sendCommand(command) { success, data in
            completion(success, data)
            semaphore.signal()
        }
        
        semaphore.wait()
    }
}

// Simplified XPC communicator for CLI
class SystemExtensionCommunicator {
    private let serviceName = "com.example.AudioVideoMonitor.SystemExtension"
    private var connection: xpc_connection_t?
    
    init() {
        setupConnection()
    }
    
    deinit {
        if let connection = connection {
            xpc_connection_cancel(connection)
        }
    }
    
    private func setupConnection() {
        connection = xpc_connection_create_mach_service(
            serviceName,
            DispatchQueue.main,
            UInt64(0)
        )
        
        guard let connection = connection else {
            return
        }
        
        xpc_connection_set_event_handler(connection) { event in
            // Handle connection events
            let type = xpc_get_type(event)
            if type == XPC_TYPE_ERROR {
                // Connection error - extension may not be running
            }
        }
        
        xpc_connection_resume(connection)
    }
    
    func sendCommand(_ command: String, completion: @escaping (Bool, [String: Any]?) -> Void) {
        guard let connection = connection else {
            completion(false, nil)
            return
        }
        
        let message = xpc_dictionary_create(nil, nil, 0)
        xpc_dictionary_set_string(message, "command", command)
        
        xpc_connection_send_message_with_reply(connection, message, DispatchQueue.main) { reply in
            let type = xpc_get_type(reply)
            
            if type == XPC_TYPE_ERROR {
                completion(false, nil)
                return
            }
            
            if type == XPC_TYPE_DICTIONARY {
                let success = xpc_dictionary_get_bool(reply, "success")
                var resultDict: [String: Any] = ["success": success]
                
                if command == "get_status" {
                    resultDict["microphone_enabled"] = xpc_dictionary_get_bool(reply, "microphone_enabled")
                    resultDict["camera_enabled"] = xpc_dictionary_get_bool(reply, "camera_enabled")
                }
                
                completion(success, resultDict)
            } else {
                completion(false, nil)
            }
        }
    }
}

// System Extension Manager for CLI
class SystemExtensionManager: NSObject, OSSystemExtensionRequestDelegate {
    private let extensionBundleID = "com.example.AudioVideoMonitor.SystemExtension"
    private var completionHandler: ((Bool) -> Void)?
    
    func activateExtension(completion: @escaping (Bool) -> Void) {
        completionHandler = completion
        
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: extensionBundleID,
            queue: .main
        )
        request.delegate = self
        
        OSSystemExtensionManager.shared.submitRequest(request)
    }
    
    func deactivateExtension(completion: @escaping (Bool) -> Void) {
        completionHandler = completion
        
        let request = OSSystemExtensionRequest.deactivationRequest(
            forExtensionWithIdentifier: extensionBundleID,
            queue: .main
        )
        request.delegate = self
        
        OSSystemExtensionManager.shared.submitRequest(request)
    }
    
    // MARK: - OSSystemExtensionRequestDelegate
    
    func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties, withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        return .replace
    }
    
    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        print("⚠️  User approval required in System Settings")
    }
    
    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        switch result {
        case .completed:
            completionHandler?(true)
        case .willCompleteAfterReboot:
            completionHandler?(true)
        @unknown default:
            completionHandler?(false)
        }
        completionHandler = nil
    }
    
    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        completionHandler?(false)
        completionHandler = nil
    }
}

// Entry point
let cli = AudioVideoControlCLI()
cli.run()