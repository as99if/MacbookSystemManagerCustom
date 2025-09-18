// Comprehensive process monitoring implementation
#include "AudioVideoController.h"

void AudioVideoController::handleESEvent(es_client_t* client, const es_message_t* message) {
    AudioVideoController* controller = AudioVideoController::getInstance();
    
    // Log all events for maximum visibility
    uint64_t timestamp = mach_absolute_time();
    pid_t pid = audit_token_to_pid(message->process->audit_token);
    
    switch (message->event_type) {
        case ES_EVENT_TYPE_NOTIFY_EXEC:
            controller->handleProcessExec(message);
            break;
            
        case ES_EVENT_TYPE_NOTIFY_EXIT:
            controller->handleProcessExit(message);
            break;
            
        case ES_EVENT_TYPE_NOTIFY_FORK:
            controller->handleFork(message);
            break;
            
        case ES_EVENT_TYPE_AUTH_OPEN:
        case ES_EVENT_TYPE_NOTIFY_OPEN:
            controller->handleFileOpen(message);
            break;
            
        case ES_EVENT_TYPE_NOTIFY_WRITE:
            controller->handleFileWrite(message);
            break;
            
        case ES_EVENT_TYPE_AUTH_UNLINK:
        case ES_EVENT_TYPE_NOTIFY_UNLINK:
            controller->handleFileDelete(message);
            break;
            
        case ES_EVENT_TYPE_NOTIFY_MMAP:
            controller->handleMmap(message);
            break;
            
        case ES_EVENT_TYPE_NOTIFY_SIGNAL:
            controller->handleSignal(message);
            break;
            
        case ES_EVENT_TYPE_NOTIFY_SETUID:
            controller->handleSetuid(message);
            break;
            
        default:
            // Log unknown events
            syslog(LOG_DEBUG, "Unknown ES event type: %d from PID: %d", 
                   message->event_type, pid);
            break;
    }
    
    // Always allow events to proceed unless specifically blocking
    if (message->action_type == ES_ACTION_TYPE_AUTH) {
        es_respond_auth_result(client, message, ES_AUTH_RESULT_ALLOW, false);
    }
}

void AudioVideoController::handleProcessExec(const es_message_t* message) {
    pid_t pid = audit_token_to_pid(message->process->audit_token);
    ProcessInfo processInfo = analyzeProcess(pid);
    
    // Comprehensive process analysis
    processInfo.pid = pid;
    processInfo.ppid = message->process->ppid;
    processInfo.executablePath = std::string(message->process->executable->path.data, 
                                           message->process->executable->path.length);
    processInfo.uid = audit_token_to_uid(message->process->audit_token);
    processInfo.gid = audit_token_to_gid(message->process->audit_token);
    processInfo.startTime = mach_absolute_time();
    
    // Get comprehensive process details
    processInfo.commandLine = getProcessCommandLine(pid);
    processInfo.openFiles = getProcessOpenFiles(pid);
    processInfo.networkConnections = getProcessNetworkConnections(pid);
    processInfo.loadedLibraries = getProcessLoadedLibraries(pid);
    processInfo.environmentVariables = getProcessEnvironment(pid);
    processInfo.memoryUsage = getProcessMemoryUsage(pid);
    processInfo.cpuTime = getProcessCPUTime(pid);
    processInfo.isSystemProcess = isSystemCriticalProcess(pid);
    
    // Check for audio/video access capabilities
    processInfo.hasAudioAccess = false;
    processInfo.hasVideoAccess = false;
    processInfo.hasNetworkAccess = false;
    processInfo.hasFileSystemAccess = true;
    
    // Analyze loaded libraries for capabilities
    for (const auto& lib : processInfo.loadedLibraries) {
        if (lib.find("AVFoundation") != std::string::npos ||
            lib.find("CoreAudio") != std::string::npos ||
            lib.find("AudioUnit") != std::string::npos) {
            processInfo.hasAudioAccess = true;
        }
        if (lib.find("AVCapture") != std::string::npos ||
            lib.find("CoreMediaIO") != std::string::npos) {
            processInfo.hasVideoAccess = true;
        }
        if (lib.find("Network") != std::string::npos ||
            lib.find("CFNetwork") != std::string::npos) {
            processInfo.hasNetworkAccess = true;
        }
    }
    
    // Store process information
    runningProcesses[pid] = processInfo;
    
    // Log to database
    logProcessEvent(processInfo, "EXEC");
    
    syslog(LOG_INFO, "Process EXEC: PID=%d, Path=%s, PPID=%d, UID=%d", 
           pid, processInfo.executablePath.c_str(), processInfo.ppid, processInfo.uid);
}

void AudioVideoController::handleProcessExit(const es_message_t* message) {
    pid_t pid = audit_token_to_pid(message->process->audit_token);
    
    // Log exit event
    if (runningProcesses.find(pid) != runningProcesses.end()) {
        ProcessInfo& processInfo = runningProcesses[pid];
        logProcessEvent(processInfo, "EXIT");
        
        syslog(LOG_INFO, "Process EXIT: PID=%d, Path=%s", 
               pid, processInfo.executablePath.c_str());
               
        runningProcesses.erase(pid);
    }
}

void AudioVideoController::handleFileOpen(const es_message_t* message) {
    pid_t pid = audit_token_to_pid(message->process->audit_token);
    
    if (message->event.open.file.path.data) {
        std::string filePath(message->event.open.file.path.data, 
                           message->event.open.file.path.length);
        
        FileAccess access;
        access.pid = pid;
        access.filePath = filePath;
        access.accessType = "OPEN";
        access.timestamp = mach_absolute_time();
        access.wasBlocked = false;
        
        // Check for sensitive file access
        bool isAudioDevice = (filePath.find("/dev/audio") != std::string::npos ||
                             filePath.find("coreaudio") != std::string::npos);
        bool isVideoDevice = (filePath.find("/dev/video") != std::string::npos ||
                             filePath.find("AVCapture") != std::string::npos);
        
        if (isAudioDevice && !microphoneEnabled) {
            access.wasBlocked = true;
            access.reason = "Microphone disabled by system extension";
        } else if (isVideoDevice && !cameraEnabled) {
            access.wasBlocked = true;
            access.reason = "Camera disabled by system extension";
        }
        
        logFileAccess(access);
        recentFileAccess.push_back(access);
        
        // Keep only last 10000 file accesses in memory
        if (recentFileAccess.size() > 10000) {
            recentFileAccess.erase(recentFileAccess.begin(), 
                                 recentFileAccess.begin() + 1000);
        }
        
        syslog(LOG_DEBUG, "File OPEN: PID=%d, Path=%s, Blocked=%s", 
               pid, filePath.c_str(), access.wasBlocked ? "YES" : "NO");
    }
}

void AudioVideoController::handleFileWrite(const es_message_t* message) {
    pid_t pid = audit_token_to_pid(message->process->audit_token);
    
    if (message->event.write.target.path.data) {
        std::string filePath(message->event.write.target.path.data,
                           message->event.write.target.path.length);
        
        FileAccess access;
        access.pid = pid;
        access.filePath = filePath;
        access.accessType = "WRITE";
        access.timestamp = mach_absolute_time();
        access.wasBlocked = false;
        
        logFileAccess(access);
        
        syslog(LOG_DEBUG, "File WRITE: PID=%d, Path=%s", pid, filePath.c_str());
    }
}

void AudioVideoController::handleFileDelete(const es_message_t* message) {
    pid_t pid = audit_token_to_pid(message->process->audit_token);
    
    if (message->event.unlink.target.path.data) {
        std::string filePath(message->event.unlink.target.path.data,
                           message->event.unlink.target.path.length);
        
        FileAccess access;
        access.pid = pid;
        access.filePath = filePath;
        access.accessType = "DELETE";
        access.timestamp = mach_absolute_time();
        access.wasBlocked = false;
        
        logFileAccess(access);
        
        syslog(LOG_INFO, "File DELETE: PID=%d, Path=%s", pid, filePath.c_str());
    }
}

void AudioVideoController::handleMmap(const es_message_t* message) {
    pid_t pid = audit_token_to_pid(message->process->audit_token);
    
    // Log memory mapping for comprehensive analysis
    logSystemCall(pid, "mmap", "Memory mapping event");
    
    syslog(LOG_DEBUG, "Memory MMAP: PID=%d", pid);
}

void AudioVideoController::handleSignal(const es_message_t* message) {
    pid_t pid = audit_token_to_pid(message->process->audit_token);
    pid_t targetPid = audit_token_to_pid(message->event.signal.target->audit_token);
    int sig = message->event.signal.sig;
    
    char args[256];
    snprintf(args, sizeof(args), "signal=%d target_pid=%d", sig, targetPid);
    logSystemCall(pid, "kill", args);
    
    syslog(LOG_INFO, "Signal SEND: PID=%d sent signal %d to PID=%d", 
           pid, sig, targetPid);
}

void AudioVideoController::handleFork(const es_message_t* message) {
    pid_t parentPid = audit_token_to_pid(message->process->audit_token);
    pid_t childPid = message->event.fork.child->pid;
    
    logSystemCall(parentPid, "fork", "Process forked");
    
    syslog(LOG_INFO, "Process FORK: Parent PID=%d, Child PID=%d", 
           parentPid, childPid);
}

void AudioVideoController::handleSetuid(const es_message_t* message) {
    pid_t pid = audit_token_to_pid(message->process->audit_token);
    uid_t uid = message->event.setuid.uid;
    
    char args[256];
    snprintf(args, sizeof(args), "new_uid=%d", uid);
    logSystemCall(pid, "setuid", args);
    
    syslog(LOG_WARNING, "SETUID: PID=%d changed to UID=%d", pid, uid);
}