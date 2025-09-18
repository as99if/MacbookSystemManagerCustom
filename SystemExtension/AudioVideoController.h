#ifndef AudioVideoController_h
#define AudioVideoController_h

#include <EndpointSecurity/EndpointSecurity.h>
// #include <Foundation/Foundation.h>
#include <IOKit/IOKitLib.h>
#include <CoreFoundation/CoreFoundation.h>
#include <sys/sysctl.h>
#include <sys/proc.h>
#include <libproc.h>
#include <pthread.h>
#include <unistd.h>
#include <mach/mach.h>
#include <mach/task.h>
#include <mach/vm_map.h>
#include <mach/mach_vm.h>
#include <mach/mach_time.h>
#include <bsm/audit.h>
#include <bsm/audit_kevents.h>
#include <bsm/libbsm.h>
#include <sqlite3.h>
#include <fstream>
#include <vector>
#include <map>
#include <string>
#include <syslog.h>

// Comprehensive process information structure
struct ProcessInfo {
    pid_t pid;
    pid_t ppid;
    std::string executablePath;
    std::string commandLine;
    std::string bundleIdentifier;
    uid_t uid;
    gid_t gid;
    uint64_t startTime;
    uint64_t cpuTime;
    uint64_t memoryUsage;
    std::vector<std::string> openFiles;
    std::vector<std::string> networkConnections;
    std::vector<std::string> loadedLibraries;
    std::map<std::string, std::string> environmentVariables;
    bool isSystemProcess;
    bool hasAudioAccess;
    bool hasVideoAccess;
    bool hasNetworkAccess;
    bool hasFileSystemAccess;
};

// Network connection information
struct NetworkConnection {
    std::string protocol;
    std::string localAddress;
    int localPort;
    std::string remoteAddress;
    int remotePort;
    std::string state;
    pid_t pid;
    uint64_t timestamp;
};

// File access information
struct FileAccess {
    pid_t pid;
    std::string filePath;
    std::string accessType;
    uint64_t timestamp;
    bool wasBlocked;
    std::string reason;
};

class AudioVideoController {
public:
    AudioVideoController();
    ~AudioVideoController();
    
    bool initialize();
    void cleanup();
    
    // Control methods
    bool disableMicrophone();
    bool enableMicrophone();
    bool disableCamera();
    bool enableCamera();
    
    // Status methods
    bool isMicrophoneEnabled() const { return microphoneEnabled; }
    bool isCameraEnabled() const { return cameraEnabled; }
    
    // Event monitoring
    void startMonitoring();
    void stopMonitoring();
    
    // Comprehensive monitoring methods
    void startProcessMonitoring();
    void startNetworkMonitoring();
    void startFileSystemMonitoring();
    void startMemoryMonitoring();
    void startSystemCallMonitoring();
    
    // Data collection methods
    std::vector<ProcessInfo> getAllProcesses();
    ProcessInfo getProcessInfo(pid_t pid);
    std::vector<NetworkConnection> getNetworkConnections();
    std::vector<FileAccess> getFileAccessHistory();
    
    // Logging and database methods
    bool initializeDatabase();
    void logProcessEvent(const ProcessInfo& process, const std::string& event);
    void logNetworkEvent(const NetworkConnection& connection);
    void logFileAccess(const FileAccess& access);
    void logSystemCall(pid_t pid, const std::string& syscall, const std::string& args);
    
    // Singleton access
    static AudioVideoController* getInstance();
    
private:
    es_client_t* esClient;
    bool microphoneEnabled;
    bool cameraEnabled;
    sqlite3* database;
    pthread_mutex_t databaseMutex;
    bool monitoringEnabled;
    
    // Monitoring threads
    pthread_t processMonitorThread;
    pthread_t networkMonitorThread;
    pthread_t fileSystemMonitorThread;
    
    // Callback for ES events
    static void handleESEvent(es_client_t* client, const es_message_t* message);
    
    // Enhanced event handlers
    void handleProcessExec(const es_message_t* message);
    void handleProcessExit(const es_message_t* message);
    void handleFileOpen(const es_message_t* message);
    void handleFileWrite(const es_message_t* message);
    void handleFileDelete(const es_message_t* message);
    void handleNetworkConnect(const es_message_t* message);
    void handleMmap(const es_message_t* message);
    void handleSignal(const es_message_t* message);
    void handleFork(const es_message_t* message);
    void handleSetuid(const es_message_t* message);
    void handleAudioAccess(const es_message_t* message);
    void handleVideoAccess(const es_message_t* message);
    
    // Device control helpers
    bool controlAudioDevices(bool enable);
    bool controlVideoDevices(bool enable);
    
    // Process analysis methods
    ProcessInfo analyzeProcess(pid_t pid);
    std::vector<std::string> getProcessOpenFiles(pid_t pid);
    std::vector<std::string> getProcessNetworkConnections(pid_t pid);
    std::vector<std::string> getProcessLoadedLibraries(pid_t pid);
    std::map<std::string, std::string> getProcessEnvironment(pid_t pid);
    std::string getProcessCommandLine(pid_t pid);
    uint64_t getProcessMemoryUsage(pid_t pid);
    uint64_t getProcessCPUTime(pid_t pid);
    
    // Network monitoring methods
    static void* networkMonitoringThread(void* arg);
    void scanNetworkConnections();
    std::vector<NetworkConnection> parseNetstat();
    
    // File system monitoring methods
    static void* fileSystemMonitoringThread(void* arg);
    void monitorFileSystemEvents();
    
    // Process monitoring methods
    static void* processMonitoringThread(void* arg);
    void scanRunningProcesses();
    void detectProcessChanges();
    
    // Memory analysis methods
    bool analyzeProcessMemory(pid_t pid);
    std::vector<std::string> getProcessMemoryMaps(pid_t pid);
    bool dumpProcessMemory(pid_t pid, const std::string& outputPath);
    
    // Database operations
    void createDatabaseTables();
    void insertProcessEvent(const ProcessInfo& process, const std::string& event);
    void insertNetworkEvent(const NetworkConnection& connection);
    void insertFileEvent(const FileAccess& access);
    void insertSystemCallEvent(pid_t pid, const std::string& syscall, const std::string& args);
    
    // Process monitoring
    bool shouldBlockProcess(const es_process_t* process);
    void logAccessAttempt(const es_process_t* process, const char* deviceType);
    bool isSystemCriticalProcess(pid_t pid);
    bool hasElevatedPrivileges(pid_t pid);
    
    // Data structures for tracking
    std::map<pid_t, ProcessInfo> runningProcesses;
    std::vector<NetworkConnection> activeConnections;
    std::vector<FileAccess> recentFileAccess;
    
    // Singleton instance
    static AudioVideoController* instance;
};

#endif