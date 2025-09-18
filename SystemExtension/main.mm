#include <Foundation/Foundation.h>
#include "AudioVideoController.h"
#include <xpc/xpc.h>
#include <dispatch/dispatch.h>
#include <syslog.h>

// XPC service for communication with main app
static xpc_connection_t create_listener() {
    xpc_connection_t listener = xpc_connection_create_mach_service(
        "com.example.AudioVideoMonitor.SystemExtension",
        dispatch_get_main_queue(),
        XPC_CONNECTION_MACH_SERVICE_LISTENER);
    
    xpc_connection_set_event_handler(listener, ^(xpc_object_t event) {
        if (xpc_get_type(event) == XPC_TYPE_CONNECTION) {
            xpc_connection_t connection = (xpc_connection_t)event;
            
            xpc_connection_set_event_handler(connection, ^(xpc_object_t message) {
                if (xpc_get_type(message) == XPC_TYPE_DICTIONARY) {
                    const char* command = xpc_dictionary_get_string(message, "command");
                    
                    if (!command) {
                        syslog(LOG_ERR, "Received XPC message without command");
                        return;
                    }
                    
                    AudioVideoController* controller = AudioVideoController::getInstance();
                    xpc_object_t reply = xpc_dictionary_create_reply(message);
                    
                    syslog(LOG_INFO, "Processing XPC command: %s", command);
                    
                    if (strcmp(command, "disable_microphone") == 0) {
                        bool success = controller->disableMicrophone();
                        xpc_dictionary_set_bool(reply, "success", success);
                        syslog(LOG_INFO, "Disable microphone result: %s", success ? "success" : "failed");
                    }
                    else if (strcmp(command, "enable_microphone") == 0) {
                        bool success = controller->enableMicrophone();
                        xpc_dictionary_set_bool(reply, "success", success);
                        syslog(LOG_INFO, "Enable microphone result: %s", success ? "success" : "failed");
                    }
                    else if (strcmp(command, "disable_camera") == 0) {
                        bool success = controller->disableCamera();
                        xpc_dictionary_set_bool(reply, "success", success);
                        syslog(LOG_INFO, "Disable camera result: %s", success ? "success" : "failed");
                    }
                    else if (strcmp(command, "enable_camera") == 0) {
                        bool success = controller->enableCamera();
                        xpc_dictionary_set_bool(reply, "success", success);
                        syslog(LOG_INFO, "Enable camera result: %s", success ? "success" : "failed");
                    }
                    else if (strcmp(command, "get_status") == 0) {
                        xpc_dictionary_set_bool(reply, "microphone_enabled", 
                                              controller->isMicrophoneEnabled());
                        xpc_dictionary_set_bool(reply, "camera_enabled", 
                                              controller->isCameraEnabled());
                        xpc_dictionary_set_bool(reply, "success", true);
                        syslog(LOG_INFO, "Status requested - Mic: %s, Camera: %s", 
                               controller->isMicrophoneEnabled() ? "enabled" : "disabled",
                               controller->isCameraEnabled() ? "enabled" : "disabled");
                    }
                    else {
                        syslog(LOG_ERR, "Unknown command received: %s", command);
                        xpc_dictionary_set_bool(reply, "success", false);
                        xpc_dictionary_set_string(reply, "error", "Unknown command");
                    }
                    
                    xpc_connection_send_message(connection, reply);
                    xpc_release(reply);
                }
            });
            
            xpc_connection_resume(connection);
        }
    });
    
    return listener;
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        syslog(LOG_INFO, "AudioVideoMonitor System Extension starting...");
        NSLog(@"AudioVideoMonitor System Extension starting...");
        
        // Initialize controller
        AudioVideoController* controller = AudioVideoController::getInstance();
        if (!controller->initialize()) {
            syslog(LOG_ERR, "Failed to initialize AudioVideoController");
            NSLog(@"Failed to initialize AudioVideoController");
            return 1;
        }
        
        // Start monitoring
        controller->startMonitoring();
        
        // Create XPC listener
        xpc_connection_t listener = create_listener();
        if (!listener) {
            syslog(LOG_ERR, "Failed to create XPC listener");
            NSLog(@"Failed to create XPC listener");
            return 1;
        }
        
        xpc_connection_resume(listener);
        
        syslog(LOG_INFO, "AudioVideoMonitor System Extension ready and listening");
        NSLog(@"AudioVideoMonitor System Extension ready and listening");
        
        // Keep the extension running
        dispatch_main();
    }
    return 0;
}