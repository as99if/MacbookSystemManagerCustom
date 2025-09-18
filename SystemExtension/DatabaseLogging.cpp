// Database logging implementation
#include "AudioVideoController.h"

void AudioVideoController::logProcessEvent(const ProcessInfo& process, const std::string& event) {
    pthread_mutex_lock(&databaseMutex);
    
    const char* sql = "INSERT INTO process_events ("
                     "timestamp, pid, ppid, executable_path, command_line, bundle_id, "
                     "uid, gid, event_type, cpu_time, memory_usage, is_system_process"
                     ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
    
    sqlite3_stmt* stmt;
    if (sqlite3_prepare_v2(database, sql, -1, &stmt, nullptr) == SQLITE_OK) {
        sqlite3_bind_int64(stmt, 1, process.startTime);
        sqlite3_bind_int(stmt, 2, process.pid);
        sqlite3_bind_int(stmt, 3, process.ppid);
        sqlite3_bind_text(stmt, 4, process.executablePath.c_str(), -1, SQLITE_STATIC);
        sqlite3_bind_text(stmt, 5, process.commandLine.c_str(), -1, SQLITE_STATIC);
        sqlite3_bind_text(stmt, 6, process.bundleIdentifier.c_str(), -1, SQLITE_STATIC);
        sqlite3_bind_int(stmt, 7, process.uid);
        sqlite3_bind_int(stmt, 8, process.gid);
        sqlite3_bind_text(stmt, 9, event.c_str(), -1, SQLITE_STATIC);
        sqlite3_bind_int64(stmt, 10, process.cpuTime);
        sqlite3_bind_int64(stmt, 11, process.memoryUsage);
        sqlite3_bind_int(stmt, 12, process.isSystemProcess ? 1 : 0);
        
        sqlite3_step(stmt);
        sqlite3_finalize(stmt);
        
        // Log open files
        for (const auto& file : process.openFiles) {
            logFileAccess({process.pid, file, "OPEN_FILE", process.startTime, false, ""});
        }
        
        // Log loaded libraries
        for (const auto& lib : process.loadedLibraries) {
            const char* libSql = "INSERT INTO loaded_libraries (timestamp, pid, library_path, load_address) "
                                "VALUES (?, ?, ?, ?)";
            sqlite3_stmt* libStmt;
            if (sqlite3_prepare_v2(database, libSql, -1, &libStmt, nullptr) == SQLITE_OK) {
                sqlite3_bind_int64(libStmt, 1, process.startTime);
                sqlite3_bind_int(libStmt, 2, process.pid);
                sqlite3_bind_text(libStmt, 3, lib.c_str(), -1, SQLITE_STATIC);
                sqlite3_bind_text(libStmt, 4, "0x0", -1, SQLITE_STATIC);
                sqlite3_step(libStmt);
                sqlite3_finalize(libStmt);
            }
        }
        
        // Log environment variables
        for (const auto& env : process.environmentVariables) {
            const char* envSql = "INSERT INTO environment_vars (timestamp, pid, var_name, var_value) "
                                "VALUES (?, ?, ?, ?)";
            sqlite3_stmt* envStmt;
            if (sqlite3_prepare_v2(database, envSql, -1, &envStmt, nullptr) == SQLITE_OK) {
                sqlite3_bind_int64(envStmt, 1, process.startTime);
                sqlite3_bind_int(envStmt, 2, process.pid);
                sqlite3_bind_text(envStmt, 3, env.first.c_str(), -1, SQLITE_STATIC);
                sqlite3_bind_text(envStmt, 4, env.second.c_str(), -1, SQLITE_STATIC);
                sqlite3_step(envStmt);
                sqlite3_finalize(envStmt);
            }
        }
    }
    
    pthread_mutex_unlock(&databaseMutex);
}

void AudioVideoController::logNetworkEvent(const NetworkConnection& connection) {
    pthread_mutex_lock(&databaseMutex);
    
    const char* sql = "INSERT INTO network_connections ("
                     "timestamp, pid, protocol, local_address, local_port, "
                     "remote_address, remote_port, state"
                     ") VALUES (?, ?, ?, ?, ?, ?, ?, ?)";
    
    sqlite3_stmt* stmt;
    if (sqlite3_prepare_v2(database, sql, -1, &stmt, nullptr) == SQLITE_OK) {
        sqlite3_bind_int64(stmt, 1, connection.timestamp);
        sqlite3_bind_int(stmt, 2, connection.pid);
        sqlite3_bind_text(stmt, 3, connection.protocol.c_str(), -1, SQLITE_STATIC);
        sqlite3_bind_text(stmt, 4, connection.localAddress.c_str(), -1, SQLITE_STATIC);
        sqlite3_bind_int(stmt, 5, connection.localPort);
        sqlite3_bind_text(stmt, 6, connection.remoteAddress.c_str(), -1, SQLITE_STATIC);
        sqlite3_bind_int(stmt, 7, connection.remotePort);
        sqlite3_bind_text(stmt, 8, connection.state.c_str(), -1, SQLITE_STATIC);
        
        sqlite3_step(stmt);
        sqlite3_finalize(stmt);
    }
    
    pthread_mutex_unlock(&databaseMutex);
}

void AudioVideoController::logFileAccess(const FileAccess& access) {
    pthread_mutex_lock(&databaseMutex);
    
    const char* sql = "INSERT INTO file_access ("
                     "timestamp, pid, file_path, access_type, was_blocked, reason"
                     ") VALUES (?, ?, ?, ?, ?, ?)";
    
    sqlite3_stmt* stmt;
    if (sqlite3_prepare_v2(database, sql, -1, &stmt, nullptr) == SQLITE_OK) {
        sqlite3_bind_int64(stmt, 1, access.timestamp);
        sqlite3_bind_int(stmt, 2, access.pid);
        sqlite3_bind_text(stmt, 3, access.filePath.c_str(), -1, SQLITE_STATIC);
        sqlite3_bind_text(stmt, 4, access.accessType.c_str(), -1, SQLITE_STATIC);
        sqlite3_bind_int(stmt, 5, access.wasBlocked ? 1 : 0);
        sqlite3_bind_text(stmt, 6, access.reason.c_str(), -1, SQLITE_STATIC);
        
        sqlite3_step(stmt);
        sqlite3_finalize(stmt);
    }
    
    pthread_mutex_unlock(&databaseMutex);
}

void AudioVideoController::logSystemCall(pid_t pid, const std::string& syscall, const std::string& args) {
    pthread_mutex_lock(&databaseMutex);
    
    const char* sql = "INSERT INTO system_calls ("
                     "timestamp, pid, syscall_name, arguments, return_value"
                     ") VALUES (?, ?, ?, ?, ?)";
    
    sqlite3_stmt* stmt;
    if (sqlite3_prepare_v2(database, sql, -1, &stmt, nullptr) == SQLITE_OK) {
        sqlite3_bind_int64(stmt, 1, mach_absolute_time());
        sqlite3_bind_int(stmt, 2, pid);
        sqlite3_bind_text(stmt, 3, syscall.c_str(), -1, SQLITE_STATIC);
        sqlite3_bind_text(stmt, 4, args.c_str(), -1, SQLITE_STATIC);
        sqlite3_bind_text(stmt, 5, "0", -1, SQLITE_STATIC);
        
        sqlite3_step(stmt);
        sqlite3_finalize(stmt);
    }
    
    pthread_mutex_unlock(&databaseMutex);
}

std::vector<NetworkConnection> AudioVideoController::getNetworkConnections() {
    std::vector<NetworkConnection> connections;
    pthread_mutex_lock(&databaseMutex);
    
    const char* sql = "SELECT * FROM network_connections ORDER BY timestamp DESC LIMIT 1000";
    sqlite3_stmt* stmt;
    
    if (sqlite3_prepare_v2(database, sql, -1, &stmt, nullptr) == SQLITE_OK) {
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            NetworkConnection conn;
            conn.timestamp = sqlite3_column_int64(stmt, 1);
            conn.pid = sqlite3_column_int(stmt, 2);
            
            const char* protocol = (const char*)sqlite3_column_text(stmt, 3);
            if (protocol) conn.protocol = protocol;
            
            const char* localAddr = (const char*)sqlite3_column_text(stmt, 4);
            if (localAddr) conn.localAddress = localAddr;
            
            conn.localPort = sqlite3_column_int(stmt, 5);
            
            const char* remoteAddr = (const char*)sqlite3_column_text(stmt, 6);
            if (remoteAddr) conn.remoteAddress = remoteAddr;
            
            conn.remotePort = sqlite3_column_int(stmt, 7);
            
            const char* state = (const char*)sqlite3_column_text(stmt, 8);
            if (state) conn.state = state;
            
            connections.push_back(conn);
        }
        sqlite3_finalize(stmt);
    }
    
    pthread_mutex_unlock(&databaseMutex);
    return connections;
}

std::vector<FileAccess> AudioVideoController::getFileAccessHistory() {
    std::vector<FileAccess> accesses;
    pthread_mutex_lock(&databaseMutex);
    
    const char* sql = "SELECT * FROM file_access ORDER BY timestamp DESC LIMIT 5000";
    sqlite3_stmt* stmt;
    
    if (sqlite3_prepare_v2(database, sql, -1, &stmt, nullptr) == SQLITE_OK) {
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            FileAccess access;
            access.timestamp = sqlite3_column_int64(stmt, 1);
            access.pid = sqlite3_column_int(stmt, 2);
            
            const char* filePath = (const char*)sqlite3_column_text(stmt, 3);
            if (filePath) access.filePath = filePath;
            
            const char* accessType = (const char*)sqlite3_column_text(stmt, 4);
            if (accessType) access.accessType = accessType;
            
            access.wasBlocked = sqlite3_column_int(stmt, 5) != 0;
            
            const char* reason = (const char*)sqlite3_column_text(stmt, 6);
            if (reason) access.reason = reason;
            
            accesses.push_back(access);
        }
        sqlite3_finalize(stmt);
    }
    
    pthread_mutex_unlock(&databaseMutex);
    return accesses;
}

// Memory analysis methods
bool AudioVideoController::analyzeProcessMemory(pid_t pid) {
    task_t task;
    if (task_for_pid(mach_task_self(), pid, &task) != KERN_SUCCESS) {
        return false;
    }
    
    vm_region_basic_info_data_64_t info;
    mach_vm_size_t size;
    mach_vm_address_t address = 0;
    mach_port_t object_name;
    mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
    
    while (mach_vm_region(task, &address, &size, VM_REGION_BASIC_INFO_64,
                         (vm_region_info_t)&info, &count, &object_name) == KERN_SUCCESS) {
        
        // Log memory region information
        char memInfo[512];
        snprintf(memInfo, sizeof(memInfo), 
                "addr=0x%llx size=0x%llx prot=%d maxprot=%d inheritance=%d shared=%d reserved=%d",
                address, size, info.protection, info.max_protection, 
                info.inheritance, info.shared, info.reserved);
        
        logSystemCall(pid, "vm_region", memInfo);
        
        address += size;
    }
    
    mach_port_deallocate(mach_task_self(), task);
    return true;
}

std::vector<std::string> AudioVideoController::getProcessMemoryMaps(pid_t pid) {
    std::vector<std::string> memoryMaps;
    
    task_t task;
    if (task_for_pid(mach_task_self(), pid, &task) != KERN_SUCCESS) {
        return memoryMaps;
    }
    
    vm_region_basic_info_data_64_t info;
    mach_vm_size_t size;
    mach_vm_address_t address = 0;
    mach_port_t object_name;
    mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
    
    while (mach_vm_region(task, &address, &size, VM_REGION_BASIC_INFO_64,
                         (vm_region_info_t)&info, &count, &object_name) == KERN_SUCCESS) {
        
        char mapStr[256];
        snprintf(mapStr, sizeof(mapStr), "0x%llx-0x%llx %c%c%c",
                address, address + size,
                (info.protection & VM_PROT_READ) ? 'r' : '-',
                (info.protection & VM_PROT_WRITE) ? 'w' : '-',
                (info.protection & VM_PROT_EXECUTE) ? 'x' : '-');
        
        memoryMaps.push_back(std::string(mapStr));
        address += size;
    }
    
    mach_port_deallocate(mach_task_self(), task);
    return memoryMaps;
}

bool AudioVideoController::dumpProcessMemory(pid_t pid, const std::string& outputPath) {
    task_t task;
    if (task_for_pid(mach_task_self(), pid, &task) != KERN_SUCCESS) {
        return false;
    }
    
    std::ofstream dumpFile(outputPath, std::ios::binary);
    if (!dumpFile.is_open()) {
        mach_port_deallocate(mach_task_self(), task);
        return false;
    }
    
    vm_region_basic_info_data_64_t info;
    mach_vm_size_t size;
    mach_vm_address_t address = 0;
    mach_port_t object_name;
    mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
    
    while (mach_vm_region(task, &address, &size, VM_REGION_BASIC_INFO_64,
                         (vm_region_info_t)&info, &count, &object_name) == KERN_SUCCESS) {
        
        if (info.protection & VM_PROT_READ) {
            vm_offset_t data;
            mach_msg_type_number_t dataSize;
            
            if (mach_vm_read(task, address, size, &data, &dataSize) == KERN_SUCCESS) {
                dumpFile.write((const char*)data, dataSize);
                vm_deallocate(mach_task_self(), data, dataSize);
            }
        }
        
        address += size;
    }
    
    dumpFile.close();
    mach_port_deallocate(mach_task_self(), task);
    
    syslog(LOG_INFO, "Memory dump completed for PID %d: %s", pid, outputPath.c_str());
    return true;
}