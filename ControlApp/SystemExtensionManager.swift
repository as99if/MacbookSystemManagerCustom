import Foundation
import SystemExtensions
import OSLog

class SystemExtensionManager: NSObject, OSSystemExtensionRequestDelegate {
    private let log = OSLog(subsystem: "com.example.AudioVideoMonitor", category: "SystemExtensionManager")
    private let extensionBundleID = "com.example.AudioVideoMonitor.SystemExtension"
    
    private var completionHandler: ((Bool) -> Void)?
    
    func activateExtension(completion: @escaping (Bool) -> Void) {
        completionHandler = completion
        
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: extensionBundleID,
            queue: .main
        )
        request.delegate = self
        
        os_log("Submitting system extension activation request", log: log, type: .info)
        OSSystemExtensionManager.shared.submitRequest(request)
    }
    
    func deactivateExtension(completion: @escaping (Bool) -> Void) {
        completionHandler = completion
        
        let request = OSSystemExtensionRequest.deactivationRequest(
            forExtensionWithIdentifier: extensionBundleID,
            queue: .main
        )
        request.delegate = self
        
        os_log("Submitting system extension deactivation request", log: log, type: .info)
        OSSystemExtensionManager.shared.submitRequest(request)
    }
    
    // MARK: - OSSystemExtensionRequestDelegate
    
    func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties, withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        os_log("Replacing existing system extension", log: log, type: .info)
        return .replace
    }
    
    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        os_log("System extension needs user approval - check System Settings > Privacy & Security > Login Items & Extensions", log: log, type: .info)
        print("⚠️  System extension requires user approval")
        print("   Please go to: System Settings > Privacy & Security > Login Items & Extensions")
        print("   and approve the AudioVideoMonitor extension")
    }
    
    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        os_log("System extension request finished with result: %d", log: log, type: .info, result.rawValue)
        
        switch result {
        case .completed:
            os_log("System extension activation completed successfully", log: log, type: .info)
            completionHandler?(true)
        case .willCompleteAfterReboot:
            os_log("System extension will complete after reboot", log: log, type: .info)
            print("ℹ️  Extension will be active after system reboot")
            completionHandler?(true)
        @unknown default:
            os_log("Unknown system extension result: %d", log: log, type: .error, result.rawValue)
            completionHandler?(false)
        }
        
        completionHandler = nil
    }
    
    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        os_log("System extension request failed: %@", log: log, type: .error, error.localizedDescription)
        print("❌ Extension request failed: \(error.localizedDescription)")
        completionHandler?(false)
        completionHandler = nil
    }
}

// XPC Communication with System Extension
class SystemExtensionCommunicator {
    private let log = OSLog(subsystem: "com.example.AudioVideoMonitor", category: "Communicator")
    private var connection: xpc_connection_t?
    private let serviceName = "com.example.AudioVideoMonitor.SystemExtension"
    
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
            os_log("Failed to create XPC connection", log: log, type: .error)
            return
        }
        
        xpc_connection_set_event_handler(connection) { [weak self] event in
            let type = xpc_get_type(event)
            if type == XPC_TYPE_ERROR {
                if let errorString = xpc_dictionary_get_string(event, XPC_ERROR_KEY_DESCRIPTION) {
                    let description = String(cString: errorString)
                    os_log("XPC connection error: %@", log: self?.log ?? OSLog.default, type: .error, description)
                }
            }
        }
        
        xpc_connection_resume(connection)
        os_log("XPC connection established", log: log, type: .info)
    }
    
    func sendCommand(_ command: String, completion: @escaping (Bool, [String: Any]?) -> Void) {
        guard let connection = connection else {
            os_log("No XPC connection available", log: log, type: .error)
            completion(false, nil)
            return
        }
        
        let message = xpc_dictionary_create(nil, nil, 0)
        xpc_dictionary_set_string(message, "command", command)
        
        os_log("Sending XPC command: %@", log: log, type: .info, command)
        
        xpc_connection_send_message_with_reply(connection, message, DispatchQueue.main) { [weak self] reply in
            let type = xpc_get_type(reply)
            
            if type == XPC_TYPE_ERROR {
                if let errorString = xpc_dictionary_get_string(reply, XPC_ERROR_KEY_DESCRIPTION) {
                    let description = String(cString: errorString)
                    os_log("XPC reply error: %@", log: self?.log ?? OSLog.default, type: .error, description)
                }
                completion(false, nil)
                return
            }
            
            if type == XPC_TYPE_DICTIONARY {
                let success = xpc_dictionary_get_bool(reply, "success")
                var resultDict: [String: Any] = ["success": success]
                
                // Extract additional data based on command
                if command == "get_status" {
                    resultDict["microphone_enabled"] = xpc_dictionary_get_bool(reply, "microphone_enabled")
                    resultDict["camera_enabled"] = xpc_dictionary_get_bool(reply, "camera_enabled")
                }
                
                if let errorString = xpc_dictionary_get_string(reply, "error") {
                    resultDict["error"] = String(cString: errorString)
                }
                
                completion(success, resultDict)
            } else {
                os_log("Unexpected XPC reply type", log: self?.log ?? OSLog.default, type: .error)
                completion(false, nil)
            }
        }
    }
}