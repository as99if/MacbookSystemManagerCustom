# AudioVideoMonitor - Comprehensive System Monitoring Suite

Attempt to - A macOS System Extension for comprehensive system monitoring and forensic analysis, built with System Extensions and DriverKit. This tool provides maximum visibility into system processes, file access, network activity, and system calls with no privacy restrictions for security research and system administration.

### System Cleanup and Optimization
- **Smart Process Management**: Intelligently terminate unnecessary background services
- **Memory Optimization**: Comprehensive RAM cleanup and garbage collection
- **Cache Management**: System and user cache cleanup with size analysis
- **Performance Analysis**: Real-time system load and resource usage monitoring
- **Safe Cleanup Modes**: Conservative and aggressive cleanup options
- **SMC Reset Support**: System Management Controller optimization
- **Fresh Boot State**: Restore system to clean boot performance

## 📋 Requirements

- macOS 10.15 (Catalina) or later
- Apple Developer account (for code signing)
- Administrator privileges for installation
- System Integrity Protection (SIP) enabled

## 🛠️ Architecture

```
┌─────────────────┐    XPC    ┌─────────────────────┐
│   CLI Tools     │◄─────────►│  System Extension   │
│  (avcontrol     │           │  (Endpoint Security)│
│  systemmonitor  │           │   & Monitoring)     │
│  systemcleanup) │           │                     │
└─────────────────┘           └─────────────────────┘
         │                              │
         │                              │
         ▼                              ▼
┌─────────────────┐                ┌─────────────────────┐
│   Main App      │                │   macOS Kernel      │
│   (Control &    │                │   (Audio/Video &    │
│    Cleanup)     │                │    System Access)   │
└─────────────────┘                └─────────────────────┘
```

### Components

1. **System Extension**: Endpoint Security-based extension for comprehensive system monitoring
2. **Main Application**: Swift app for system extension management and cleanup operations
3. **CLI Tools**: Command-line interfaces for device control, monitoring, and system cleanup
4. **XPC Service**: Communication layer between components
5. **Configuration Files**: Entitlements, Info.plist, and enterprise profiles
6. **Database**: SQLite database for monitoring data storage

## 🔧 Building from Source

### Prerequisites


```bash
# Install Xcode command line tools
xcode-select --install

# Verify Swift and C++ compilers
swift --version
clang++ --version
```

### Build Process

1. **Clone and navigate to project**:
   ```bash
   git clone <repository-url>
   cd AudioVideoMonitor
   ```

2. **Update configuration**:
   - Edit `build.sh` and replace `YOURTEAMID` with your Apple Developer Team ID
   - Update bundle identifiers in configuration files if needed

3. **Run build script**:
   ```bash
   chmod +x build.sh
   ./build.sh
   ```

4. **Install built package**:
   ```bash
   cd dist
   sudo ./install.sh
   ```

## 🎯 Installation & Setup

### Standard Installation

1. **Build the project**:
   ```bash
   ./build.sh
   ```

2. **Install the package**:
   ```bash
   sudo ./install.sh
   ```

3. **Install system extension**:
   ```bash
   avcontrol install
   ```

4. **Approve in System Settings**:
   - Open System Settings > Privacy & Security
   - Go to Login Items & Extensions
   - Approve "AudioVideoMonitor"

5. **Verify installation**:
   ```bash
   avcontrol status
   ```

## 🗄️ Database Schema

### Events Table
- **event_id**: Unique identifier
- **timestamp**: Event occurrence time
- **event_type**: Type of event (process, file, network, memory, etc.)
- **process_id**: Associated process ID
- **process_name**: Process executable name
- **user_id**: User ID of the process owner
- **event_details**: JSON formatted event-specific data

### Process_Info Table
- **process_id**: Process identifier
- **parent_pid**: Parent process ID
- **executable_path**: Full path to executable
- **arguments**: Command line arguments
- **environment**: Environment variables
- **creation_time**: Process start timestamp
- **memory_usage**: Current memory consumption
- **cpu_usage**: CPU utilization percentage

### File_Access Table
- **access_id**: Unique access identifier
- **process_id**: Accessing process
- **file_path**: Full path to accessed file
- **access_type**: Read/Write/Execute/Delete
- **timestamp**: Access time
- **file_size**: File size at access time
- **permissions**: File permissions

### Network_Connections Table
- **connection_id**: Unique connection identifier
- **process_id**: Process making connection
- **local_address**: Local IP and port
- **remote_address**: Remote IP and port
- **protocol**: TCP/UDP/Other
- **direction**: Incoming/Outgoing
- **bytes_transferred**: Data volume
- **connection_state**: Active/Closed/Listening

### Memory_Maps Table
- **map_id**: Unique mapping identifier
- **process_id**: Process with memory mapping
- **start_address**: Memory region start
- **end_address**: Memory region end
- **protection**: Read/Write/Execute permissions
- **mapping_type**: File-backed/Anonymous/Shared
- **file_path**: Associated file (if file-backed)

### Enterprise Deployment

For organizations, use the included configuration profile:

```bash
# Install configuration profile
sudo profiles install -path Config/Enterprise-Config-Profile.mobileconfig

# Deploy app via MDM or manual installation
# System extension will be pre-approved
```

## 💻 Enhanced Usage

### System Monitoring Commands

```bash
# Real-time System Monitoring
systemmonitor monitor            # Live monitoring with real-time output
systemmonitor processes         # Show comprehensive process history
systemmonitor files            # Display all file access events
systemmonitor network          # Show network activity and connections
systemmonitor stats            # System monitoring statistics

# Advanced Analysis
systemmonitor search <term>    # Search all events for specific terms
systemmonitor analyze <pid>    # Deep analysis of specific process
systemmonitor dump <pid>       # Create memory dump of process
systemmonitor export           # Export all data to CSV files

# Device Control (Original functionality)
avcontrol disable-mic          # Disable microphone system-wide
avcontrol enable-mic           # Enable microphone system-wide
avcontrol disable-cam          # Disable camera system-wide
avcontrol enable-cam           # Enable camera system-wide
avcontrol status               # Show current device status
```

### System Cleanup and Optimization Commands

```bash
# System Performance Analysis
systemcleanup analyze              # Comprehensive system performance analysis
systemcleanup status              # Show current system performance status

# Background Process Management
systemcleanup services            # Terminate unnecessary background services
systemcleanup services --dry-run  # Preview which services would be terminated

# Memory and Cache Cleanup
systemcleanup memory              # Free up RAM and force garbage collection
systemcleanup cache              # Clear system and user caches
systemcleanup logs               # Clean up old log files

# Hardware Reset and Optimization
systemcleanup smc                 # Reset System Management Controller
systemcleanup full               # Perform complete system optimization
systemcleanup full --dry-run     # Preview full cleanup without execution

# Safe Operations
systemcleanup safe-mode          # Conservative cleanup (safest option)
systemcleanup restore            # Restore system to clean boot state

# Integration with Main App
AudioVideoMonitor cleanup analyze     # Via main application
AudioVideoMonitor cleanup full        # Complete cleanup through main app
```

### Database Structure

All monitoring data is stored in SQLite database `/var/log/AudioVideoMonitor.db`:

```sql
-- Process execution and lifecycle events
process_events (timestamp, pid, ppid, executable_path, command_line, 
                bundle_id, uid, gid, event_type, cpu_time, memory_usage)

-- File system access events  
file_access (timestamp, pid, file_path, access_type, was_blocked, reason)

-- Network connection tracking
network_connections (timestamp, pid, protocol, local_address, local_port,
                    remote_address, remote_port, state)

-- System call monitoring
system_calls (timestamp, pid, syscall_name, arguments, return_value)

-- Memory region analysis
process_memory (timestamp, pid, memory_region, permissions, size, file_path)

-- Dynamic library tracking
loaded_libraries (timestamp, pid, library_path, load_address)

-- Environment variable capture
environment_vars (timestamp, pid, var_name, var_value)
```

### Main Application

```bash
# Using the main app directly
./AudioVideoMonitor.app/Contents/MacOS/AudioVideoMonitor install
./AudioVideoMonitor.app/Contents/MacOS/AudioVideoMonitor control disable-mic
./AudioVideoMonitor.app/Contents/MacOS/AudioVideoMonitor status
```

### Forensic Analysis Examples

**Monitor all system activity**:
```bash
# Start comprehensive monitoring
sudo systemmonitor monitor

# Monitor specific process
systemmonitor analyze 1234

# Search for suspicious activity  
systemmonitor search "malware"
systemmonitor search "/tmp/"
systemmonitor search "curl"
```

**Memory and process analysis**:
```bash
# Dump process memory for analysis
systemmonitor dump 1234

# Analyze process behavior
systemmonitor processes | grep chrome
systemmonitor files | grep "/etc/passwd"
systemmonitor network | grep ":443"
```

**Data export for analysis**:
```bash
# Export all data to CSV
systemmonitor export

# Query database directly
sqlite3 /var/log/AudioVideoMonitor.db "SELECT * FROM process_events WHERE pid = 1234"
```

### System Cleanup and Optimization Examples

**System performance analysis**:
```bash
# Comprehensive system analysis
systemcleanup analyze

# Check current system status
systemcleanup status

# Generate cleanup recommendations
AudioVideoMonitor cleanup analyze
```

**Memory and performance optimization**:
```bash
# Free up system memory
systemcleanup memory

# Clean all system caches
systemcleanup cache

# Complete system optimization
systemcleanup full

# Preview cleanup without execution
systemcleanup full --dry-run
```

**Background process management**:
```bash
# Clean unnecessary background services
systemcleanup services

# Preview service cleanup
systemcleanup services --dry-run

# Conservative cleanup only
systemcleanup safe-mode

# Restore to fresh boot state
systemcleanup restore
```

### Code Signing

All components are code signed with Developer ID:

```bash
# Check signatures
codesign -vv AudioVideoMonitor.app
codesign -vv /usr/local/bin/avcontrol
```

## 🐛 Troubleshooting

### Common Issues

**Extension not loading**:
```bash
# Check system extension status
systemextensionsctl list

# Check console for errors
log show --predicate 'subsystem == "com.example.AudioVideoMonitor"' --last 1h
```

**Permission denied errors**:
```bash
# Verify entitlements
codesign -d --entitlements - AudioVideoMonitor.app

# Check TCC database
sudo sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db \
  "SELECT client,auth_value FROM access WHERE service='kTCCServiceMicrophone';"
```

**XPC communication failures**:
```bash
# Check XPC service status
launchctl list | grep com.example.AudioVideoMonitor

# Test direct communication
avcontrol status
```

### Debug Mode

Enable detailed logging:
```bash
# Set debug environment variable
export AVCONTROL_DEBUG=1
avcontrol status

# Check system logs
log stream --predicate 'subsystem == "com.example.AudioVideoMonitor"'
```

## 📁 Project Structure

```
AudioVideoMonitor/
├── SystemExtension/           # C++ Endpoint Security extension
│   ├── AudioVideoController.h # Controller class header
│   ├── AudioVideoController.cpp# Controller implementation
│   ├── DatabaseLogging.cpp   # Database operations
│   ├── ProcessAnalysis.cpp   # Process analysis functionality
│   ├── ProcessMonitoring.cpp # Process monitoring implementation
│   ├── main.cpp              # Extension entry point
│   └── Info.plist            # Extension metadata
├── ControlApp/               # Swift main application
│   ├── SystemExtensionManager.swift # Extension management
│   └── main.swift            # App entry point with cleanup integration
├── CLI/                      # Command-line interface tools
│   ├── avcontrol.swift       # Device control CLI
│   ├── systemmonitor.swift   # System monitoring CLI
│   └── systemcleanup.swift   # System cleanup and optimization CLI
├── Config/                   # Configuration files
│   ├── MainApp.entitlements  # Main app permissions
│   ├── SystemExtension.entitlements # Extension permissions
│   └── Enterprise-Config-Profile.mobileconfig # MDM profile
├── AudioVideoMonitor.app/    # App bundle structure
├── build.sh                  # Enhanced build script
└── README.md                 # This file
```

## 🔄 Development Workflow

### Local Development

1. **Make changes** to source files
2. **Build** with `./build.sh`
3. **Reinstall** with `sudo dist/install.sh`
4. **Test** with `avcontrol status`

### Debugging

```bash
# Build with debug symbols
export DEBUG=1
./build.sh

# Attach debugger to extension
sudo lldb /System/Library/Extensions/com.example.AudioVideoMonitor.SystemExtension
```

### Testing

```bash
# Test CLI functionality
./test-cli.sh

# Test system extension communication
./test-xpc.sh

# Test device control
./test-devices.sh
```

## 🤝 Contributing

DON'T

### Code Style

- objective C
- Swift: Use SwiftLint configuration
- Comments: Document all public APIs


##   Test
[x] build dist
[ ] build
[ ] avcontrol audio
[ ] avcontrol network
[ ] avcontrol cam
[ ]
[ ]

## 🔮 Roadmap

[ ] test
[ ] debug properly
[ ] update unnecessary process list
[ ] update critical process list
[ ] integrate with MyAI

---
