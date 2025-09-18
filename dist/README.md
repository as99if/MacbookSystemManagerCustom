# AudioVideoMonitor

Modern macOS System Extension for controlling microphone and camera access.

## Installation

1. Run the installer:
   ```bash
   sudo ./install.sh
   ```

2. Install the system extension:
   ```bash
   avcontrol install
   ```

3. Approve the extension in System Settings:
   - Go to System Settings > Privacy & Security
   - Navigate to Login Items & Extensions
   - Approve AudioVideoMonitor

## Usage

```bash
# Control devices
avcontrol disable-mic    # Disable microphone
avcontrol enable-mic     # Enable microphone
avcontrol disable-cam    # Disable camera
avcontrol enable-cam     # Enable camera

# Check status
avcontrol status         # Show current status

# Manage extension
avcontrol install        # Install extension
avcontrol uninstall      # Remove extension
```

## Enterprise Deployment

Use the included configuration profile (`Config/Enterprise-Config-Profile.mobileconfig`) to pre-approve the system extension for enterprise deployment.

## Requirements

- macOS 10.15 or later
- Administrator privileges for installation
- Apple Developer account for code signing (optional)

## Architecture

- **System Extension**: Endpoint Security framework for device monitoring
- **XPC Service**: Communication between app and extension
- **CLI Tool**: Command-line interface for device control
- **Configuration Profiles**: Enterprise deployment support
