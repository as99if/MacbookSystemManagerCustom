import Foundation
import SystemExtensions
import os.log

class SystemExtensionManager: NSObject, OSSystemExtensionRequestDelegate {
    private let logger = Logger(subsystem: "com.example.AudioVideoMonitor", category: "SystemExtensionManager")
    private let extensionBundleID = "com.example.AudioVideoMonitor.SystemExtension"
    
    private var completionHandler: ((Bool) -> Void)?
    
    func activateExtension(completion: @escaping (Bool) -> Void) {
        completionHandler = completion
        
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: extensionBundleID,
            queue: .main
        )
        request.delegate = self
        
        logger.info("Submitting system extension activation request")
        OSSystemExtensionManager.shared.submitRequest(request)
    }
    
    func deactivateExtension(completion: @escaping (Bool) -> Void) {
        completionHandler = completion
        
        let request = OSSystemExtensionRequest.deactivationRequest(
            forExtensionWithIdentifier: extensionBundleID,
            queue: .main
        )
        request.delegate = self
        
        logger.info("Submitting system extension deactivation request")
        OSSystemExtensionManager.shared.submitRequest(request)
    }
    
    // MARK: - OSSystemExtensionRequestDelegate
    
    func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties, withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        logger.info("Replacing existing system extension")
        return .replace
    }
    
    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        logger.info("System extension needs user approval - check System Settings > Privacy & Security > Login Items & Extensions")
        print("⚠️  System extension requires user approval")
        print("   Please go to: System Settings > Privacy & Security > Login Items & Extensions")
        print("   and approve the AudioVideoMonitor extension")
    }
    
    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        logger.info("System extension request finished with result: \(result.rawValue)")
        
        switch result {
        case .completed:
            logger.info("System extension activation completed successfully")
            completionHandler?(true)
        case .willCompleteAfterReboot:
            logger.info("System extension will complete after reboot")
            print("ℹ️  Extension will be active after system reboot")
            completionHandler?(true)
        @unknown default:
            logger.error("Unknown system extension result: \(result.rawValue)")
            completionHandler?(false)
        }
        
        completionHandler = nil
    }
    
    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        logger.error("System extension request failed: \(error.localizedDescription)")
        print("❌ Extension request failed: \(error.localizedDescription)")
        completionHandler?(false)
        completionHandler = nil
    }
}

// XPC Communication with System Extension
class SystemExtensionCommunicator {
    private let logger = Logger(subsystem: "com.example.AudioVideoMonitor", category: "Communicator")
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
            logger.error("Failed to create XPC connection")
            return
        }
        
        xpc_connection_set_event_handler(connection) { [weak self] event in
            let type = xpc_get_type(event)
            if type == XPC_TYPE_ERROR {
                let description = String(cString: xpc_dictionary_get_string(event, XPC_ERROR_KEY_DESCRIPTION))
                self?.logger.error("XPC connection error: \(description)")
            }
        }
        
        xpc_connection_resume(connection)
        logger.info("XPC connection established")
    }
    
    func sendCommand(_ command: String, completion: @escaping (Bool, [String: Any]?) -> Void) {
        guard let connection = connection else {
            logger.error("No XPC connection available")
            completion(false, nil)
            return
        }
        
        let message = xpc_dictionary_create(nil, nil, 0)
        xpc_dictionary_set_string(message, "command", command)
        
        logger.info("Sending XPC command: \(command)")
        
        xpc_connection_send_message_with_reply(connection, message, DispatchQueue.main) { [weak self] reply in
            let type = xpc_get_type(reply)
            
            if type == XPC_TYPE_ERROR {
                let description = String(cString: xpc_dictionary_get_string(reply, XPC_ERROR_KEY_DESCRIPTION))
                self?.logger.error("XPC reply error: \(description)")
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
                self?.logger.error("Unexpected XPC reply type")
                completion(false, nil)
            }
        }
    }
}