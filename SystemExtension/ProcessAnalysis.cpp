// Process analysis and monitoring thread implementations
#include "AudioVideoController.h"

ProcessInfo AudioVideoController::analyzeProcess(pid_t pid) {
    ProcessInfo info;
    info.pid = pid;
    
    // Get process information using libproc
    struct proc_taskallinfo taskInfo;
    if (proc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, &taskInfo, sizeof(taskInfo)) > 0) {
        info.ppid = taskInfo.pbsd.pbi_ppid;
        info.uid = taskInfo.pbsd.pbi_uid;
        info.gid = taskInfo.pbsd.pbi_gid;
        info.startTime = taskInfo.pbsd.pbi_start_tvsec;
        
        // Get memory usage
        info.memoryUsage = taskInfo.ptinfo.pti_resident_size;
        
        // Get CPU time
        info.cpuTime = taskInfo.ptinfo.pti_total_user + taskInfo.ptinfo.pti_total_system;
    }
    
    // Get executable path
    char pathBuffer[PROC_PIDPATHINFO_MAXSIZE];
    if (proc_pidpath(pid, pathBuffer, sizeof(pathBuffer)) > 0) {
        info.executablePath = std::string(pathBuffer);
    }
    
    // Get command line arguments
    info.commandLine = getProcessCommandLine(pid);
    
    // Get open files
    info.openFiles = getProcessOpenFiles(pid);
    
    // Get network connections
    info.networkConnections = getProcessNetworkConnections(pid);
    
    // Get loaded libraries
    info.loadedLibraries = getProcessLoadedLibraries(pid);
    
    // Get environment variables
    info.environmentVariables = getProcessEnvironment(pid);
    
    // Determine if system process
    info.isSystemProcess = isSystemCriticalProcess(pid);
    
    return info;
}

std::string AudioVideoController::getProcessCommandLine(pid_t pid) {
    char pathBuffer[4096];
    size_t size = sizeof(pathBuffer);
    
    int mib[3] = {CTL_KERN, KERN_PROCARGS2, pid};
    
    if (sysctl(mib, 3, pathBuffer, &size, NULL, 0) == 0) {
        // Skip argc
        char* args = pathBuffer + sizeof(int);
        
        // Skip to first argument
        while (*args && args < pathBuffer + size) args++;
        args++;
        
        std::string cmdline;
        while (args < pathBuffer + size && *args) {
            if (!cmdline.empty()) cmdline += " ";
            cmdline += args;
            while (*args && args < pathBuffer + size) args++;
            args++;
        }
        return cmdline;
    }
    
    return "";
}

std::vector<std::string> AudioVideoController::getProcessOpenFiles(pid_t pid) {
    std::vector<std::string> openFiles;
    
    struct proc_fdinfo *fdInfos = nullptr;
    int numFds = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nullptr, 0);
    
    if (numFds > 0) {
        fdInfos = (struct proc_fdinfo*)malloc(numFds);
        numFds = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, fdInfos, numFds);
        
        int actualFds = numFds / sizeof(struct proc_fdinfo);
        
        for (int i = 0; i < actualFds; i++) {
            if (fdInfos[i].proc_fdtype == PROX_FDTYPE_VNODE) {
                struct vnode_fdinfowithpath vnodeInfo;
                if (proc_pidfdinfo(pid, fdInfos[i].proc_fd, PROC_PIDFDVNODEPATHINFO, 
                                 &vnodeInfo, sizeof(vnodeInfo)) > 0) {
                    openFiles.push_back(std::string(vnodeInfo.pvip.vip_path));
                }
            }
        }
        
        free(fdInfos);
    }
    
    return openFiles;
}

std::vector<std::string> AudioVideoController::getProcessNetworkConnections(pid_t pid) {
    std::vector<std::string> connections;
    
    // Get network socket information
    struct proc_fdinfo *fdInfos = nullptr;
    int numFds = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nullptr, 0);
    
    if (numFds > 0) {
        fdInfos = (struct proc_fdinfo*)malloc(numFds);
        numFds = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, fdInfos, numFds);
        
        int actualFds = numFds / sizeof(struct proc_fdinfo);
        
        for (int i = 0; i < actualFds; i++) {
            if (fdInfos[i].proc_fdtype == PROX_FDTYPE_SOCKET) {
                struct socket_fdinfo socketInfo;
                if (proc_pidfdinfo(pid, fdInfos[i].proc_fd, PROC_PIDFDSOCKETINFO,
                                 &socketInfo, sizeof(socketInfo)) > 0) {
                    
                    char connStr[256];
                    if (socketInfo.psi.soi_family == AF_INET) {
                        struct sockaddr_in *local = (struct sockaddr_in*)&socketInfo.psi.soi_proto.pri_tcp.tcpsi_ini.insi_laddr;
                        struct sockaddr_in *remote = (struct sockaddr_in*)&socketInfo.psi.soi_proto.pri_tcp.tcpsi_ini.insi_faddr;
                        
                        snprintf(connStr, sizeof(connStr), "TCP %s:%d -> %s:%d",
                                inet_ntoa(local->sin_addr), ntohs(local->sin_port),
                                inet_ntoa(remote->sin_addr), ntohs(remote->sin_port));
                        connections.push_back(std::string(connStr));
                    }
                }
            }
        }
        
        free(fdInfos);
    }
    
    return connections;
}

std::vector<std::string> AudioVideoController::getProcessLoadedLibraries(pid_t pid) {
    std::vector<std::string> libraries;
    
    task_t task;
    if (task_for_pid(mach_task_self(), pid, &task) != KERN_SUCCESS) {
        return libraries;
    }
    
    struct task_dyld_info dyld_info;
    mach_msg_type_number_t count = TASK_DYLD_INFO_COUNT;
    
    if (task_info(task, TASK_DYLD_INFO, (task_info_t)&dyld_info, &count) == KERN_SUCCESS) {
        mach_vm_size_t size;
        vm_offset_t data;
        
        if (mach_vm_read(task, dyld_info.all_image_info_addr, 
                        dyld_info.all_image_info_size, &data, &size) == KERN_SUCCESS) {
            
            struct dyld_all_image_infos *infos = (struct dyld_all_image_infos *)data;
            
            for (uint32_t i = 0; i < infos->infoArrayCount; i++) {
                mach_vm_size_t pathSize;
                vm_offset_t pathData;
                
                if (mach_vm_read(task, (mach_vm_address_t)infos->infoArray[i].imageFilePath,
                               256, &pathData, &pathSize) == KERN_SUCCESS) {
                    char *path = (char *)pathData;
                    libraries.push_back(std::string(path));
                    vm_deallocate(mach_task_self(), pathData, pathSize);
                }
            }
            
            vm_deallocate(mach_task_self(), data, size);
        }
    }
    
    mach_port_deallocate(mach_task_self(), task);
    return libraries;
}

std::map<std::string, std::string> AudioVideoController::getProcessEnvironment(pid_t pid) {
    std::map<std::string, std::string> env;
    
    char *buffer = nullptr;
    size_t size = 0;
    int mib[3] = {CTL_KERN, KERN_PROCARGS2, pid};
    
    // Get buffer size
    if (sysctl(mib, 3, nullptr, &size, nullptr, 0) == 0) {
        buffer = (char*)malloc(size);
        
        if (sysctl(mib, 3, buffer, &size, nullptr, 0) == 0) {
            // Skip argc and arguments to get to environment
            char *ptr = buffer + sizeof(int);
            
            // Skip executable path
            while (ptr < buffer + size && *ptr) ptr++;
            ptr++;
            
            // Skip arguments
            while (ptr < buffer + size && *ptr) {
                while (ptr < buffer + size && *ptr) ptr++;
                ptr++;
            }
            
            // Now we're at environment variables
            while (ptr < buffer + size && *ptr) {
                std::string envVar(ptr);
                size_t equals = envVar.find('=');
                
                if (equals != std::string::npos) {
                    std::string key = envVar.substr(0, equals);
                    std::string value = envVar.substr(equals + 1);
                    env[key] = value;
                }
                
                while (ptr < buffer + size && *ptr) ptr++;
                ptr++;
            }
        }
        
        free(buffer);
    }
    
    return env;
}

uint64_t AudioVideoController::getProcessMemoryUsage(pid_t pid) {
    struct proc_taskinfo taskInfo;
    if (proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, sizeof(taskInfo)) > 0) {
        return taskInfo.pti_resident_size;
    }
    return 0;
}

uint64_t AudioVideoController::getProcessCPUTime(pid_t pid) {
    struct proc_taskinfo taskInfo;
    if (proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, sizeof(taskInfo)) > 0) {
        return taskInfo.pti_total_user + taskInfo.pti_total_system;
    }
    return 0;
}

bool AudioVideoController::isSystemCriticalProcess(pid_t pid) {
    char pathBuffer[PROC_PIDPATHINFO_MAXSIZE];
    if (proc_pidpath(pid, pathBuffer, sizeof(pathBuffer)) > 0) {
        std::string path(pathBuffer);
        
        // Check for system paths
        if (path.find("/System/") == 0 || 
            path.find("/usr/") == 0 ||
            path.find("/sbin/") == 0 ||
            path.find("/bin/") == 0) {
            return true;
        }
        
        // Check for known system processes
        std::vector<std::string> systemProcesses = {
            "kernel_task", "launchd", "kextd", "UserEventAgent",
            "loginwindow", "WindowServer", "Dock", "Finder",
            "SystemUIServer", "coreaudiod", "VDCAssistant"
        };
        
        for (const auto& sysProc : systemProcesses) {
            if (path.find(sysProc) != std::string::npos) {
                return true;
            }
        }
    }
    
    return false;
}

bool AudioVideoController::hasElevatedPrivileges(pid_t pid) {
    struct proc_bsdinfo bsdInfo;
    if (proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsdInfo, sizeof(bsdInfo)) > 0) {
        return (bsdInfo.pbi_uid == 0 || bsdInfo.pbi_gid == 0);
    }
    return false;
}

// Monitoring thread implementations
void AudioVideoController::startProcessMonitoring() {
    monitoringEnabled = true;
    pthread_create(&processMonitorThread, nullptr, processMonitoringThread, this);
}

void AudioVideoController::startNetworkMonitoring() {
    pthread_create(&networkMonitorThread, nullptr, networkMonitoringThread, this);
}

void AudioVideoController::startFileSystemMonitoring() {
    pthread_create(&fileSystemMonitorThread, nullptr, fileSystemMonitoringThread, this);
}

void* AudioVideoController::processMonitoringThread(void* arg) {
    AudioVideoController* controller = (AudioVideoController*)arg;
    
    while (controller->monitoringEnabled) {
        controller->scanRunningProcesses();
        sleep(5); // Scan every 5 seconds
    }
    
    return nullptr;
}

void* AudioVideoController::networkMonitoringThread(void* arg) {
    AudioVideoController* controller = (AudioVideoController*)arg;
    
    while (controller->monitoringEnabled) {
        controller->scanNetworkConnections();
        sleep(10); // Scan every 10 seconds
    }
    
    return nullptr;
}

void* AudioVideoController::fileSystemMonitoringThread(void* arg) {
    AudioVideoController* controller = (AudioVideoController*)arg;
    
    while (controller->monitoringEnabled) {
        controller->monitorFileSystemEvents();
        sleep(1); // Monitor frequently
    }
    
    return nullptr;
}

void AudioVideoController::scanRunningProcesses() {
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
    struct kinfo_proc *procs = nullptr;
    size_t size;
    
    if (sysctl(mib, 4, nullptr, &size, nullptr, 0) == 0) {
        procs = (struct kinfo_proc*)malloc(size);
        
        if (sysctl(mib, 4, procs, &size, nullptr, 0) == 0) {
            int numProcs = size / sizeof(struct kinfo_proc);
            
            for (int i = 0; i < numProcs; i++) {
                pid_t pid = procs[i].kp_proc.p_pid;
                
                // Skip if we already know about this process
                if (runningProcesses.find(pid) != runningProcesses.end()) {
                    continue;
                }
                
                // Analyze new process
                ProcessInfo info = analyzeProcess(pid);
                runningProcesses[pid] = info;
                
                logProcessEvent(info, "DISCOVERED");
            }
        }
        
        free(procs);
    }
}

void AudioVideoController::scanNetworkConnections() {
    // Implementation for network connection scanning
    std::vector<NetworkConnection> connections = parseNetstat();
    
    for (const auto& conn : connections) {
        logNetworkEvent(conn);
    }
}

std::vector<NetworkConnection> AudioVideoController::parseNetstat() {
    std::vector<NetworkConnection> connections;
    
    // Parse network connections using system calls
    // This is a simplified implementation
    
    return connections;
}

void AudioVideoController::monitorFileSystemEvents() {
    // File system monitoring implementation
    // This would integrate with FSEvents or similar
}

std::vector<ProcessInfo> AudioVideoController::getAllProcesses() {
    std::vector<ProcessInfo> processes;
    
    for (const auto& pair : runningProcesses) {
        processes.push_back(pair.second);
    }
    
    return processes;
}

ProcessInfo AudioVideoController::getProcessInfo(pid_t pid) {
    auto it = runningProcesses.find(pid);
    if (it != runningProcesses.end()) {
        return it->second;
    }
    
    // If not in cache, analyze now
    return analyzeProcess(pid);
}