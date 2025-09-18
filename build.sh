#!/bin/bash

# AudioVideoMonitor Build Script
# Modern macOS System Extension for Audio/Video Control

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="AudioVideoMonitor"
TEAM_ID="YOURTEAMID"  # Replace with your Apple Developer Team ID
BUNDLE_ID="com.example.AudioVideoMonitor"
SYSEXT_BUNDLE_ID="com.example.AudioVideoMonitor.SystemExtension"

# Paths
PROJECT_ROOT=$(pwd)
BUILD_DIR="$PROJECT_ROOT/build"
DIST_DIR="$PROJECT_ROOT/dist"
APP_NAME="$PROJECT_NAME.app"
APP_BUNDLE="$BUILD_DIR/$APP_NAME"

echo -e "${BLUE}🔨 Building AudioVideoMonitor System Extension Project${NC}"
echo "======================================================="

# Clean previous builds
echo -e "${YELLOW}🧹 Cleaning previous builds...${NC}"
rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$BUILD_DIR" "$DIST_DIR"

# Check requirements
echo -e "${YELLOW}🔍 Checking build requirements...${NC}"

# Check for Xcode command line tools
if ! xcode-select -p &>/dev/null; then
    echo -e "${RED}❌ Xcode command line tools not found${NC}"
    echo "Install with: xcode-select --install"
    exit 1
fi

# Check for Swift
if ! command -v swift &>/dev/null; then
    echo -e "${RED}❌ Swift compiler not found${NC}"
    exit 1
fi

# Check for clang++
if ! command -v clang++ &>/dev/null; then
    echo -e "${RED}❌ C++ compiler not found${NC}"
    exit 1
fi

echo -e "${GREEN}✅ All requirements met${NC}"

# Build System Extension
echo -e "${YELLOW}🔧 Building Enhanced System Extension...${NC}"
cd SystemExtension

# Create system extension bundle structure
SYSEXT_BUNDLE="$BUILD_DIR/$SYSEXT_BUNDLE_ID.systemextension"
mkdir -p "$SYSEXT_BUNDLE/Contents/MacOS"

# Compile C++ system extension with all source files
clang++ -o "$SYSEXT_BUNDLE/Contents/MacOS/AudioVideoMonitor" \
    *.cpp \
    -framework Foundation \
    -framework EndpointSecurity \
    -framework IOKit \
    -framework CoreFoundation \
    -lsqlite3 \
    -lpthread \
    -lproc \
    -std=c++17 \
    -arch arm64 \
    -arch x86_64 \
    -mmacosx-version-min=10.15 \
    -O2 \
    -DMAX_MONITORING_ENABLED \
    -DFULL_SYSTEM_ACCESS

# Copy Info.plist to system extension
cp Info.plist "$SYSEXT_BUNDLE/Contents/"

echo -e "${GREEN}✅ System Extension built successfully${NC}"

# Build Main Application
echo -e "${YELLOW}🔧 Building Main Application...${NC}"
cd "$PROJECT_ROOT/ControlApp"

# Create app bundle structure  
mkdir -p "$APP_BUNDLE/Contents"/{MacOS,Library/SystemExtensions}

# Compile Swift main app
swiftc -o "$APP_BUNDLE/Contents/MacOS/AudioVideoMonitor" \
    *.swift \
    -framework Foundation \
    -framework SystemExtensions \
    -framework OSLog \
    -target arm64-apple-macos10.15 \
    -target x86_64-apple-macos10.15

# Copy system extension into app bundle
cp -r "$SYSEXT_BUNDLE" "$APP_BUNDLE/Contents/Library/SystemExtensions/"

# Copy main app Info.plist
cp "$PROJECT_ROOT/AudioVideoMonitor.app/Contents/Info.plist" "$APP_BUNDLE/Contents/"

echo -e "${GREEN}✅ Main Application built successfully${NC}"

# Build CLI Tools
echo -e "${YELLOW}🔧 Building Enhanced CLI Tools...${NC}"
cd "$PROJECT_ROOT/CLI"

# Make CLI executables
chmod +x *.swift

# Compile Swift CLI tools
swiftc -o "$BUILD_DIR/avcontrol" \
    avcontrol.swift \
    -framework Foundation \
    -framework SystemExtensions \
    -framework OSLog \
    -target arm64-apple-macos10.15 \
    -target x86_64-apple-macos10.15

# Compile system monitor CLI
swiftc -o "$BUILD_DIR/systemmonitor" \
    systemmonitor.swift \
    -framework Foundation \
    -framework OSLog \
    -lsqlite3 \
    -target arm64-apple-macos10.15 \
    -target x86_64-apple-macos10.15

# Compile system cleanup CLI
swiftc -o "$BUILD_DIR/systemcleanup" \
    systemcleanup.swift \
    -framework Foundation \
    -framework OSLog \
    -lsqlite3 \
    -target arm64-apple-macos10.15 \
    -target x86_64-apple-macos10.15

echo -e "${GREEN}✅ Enhanced CLI Tools built successfully${NC}"

# Code Signing (if team ID is set)
if [ "$TEAM_ID" != "YOURTEAMID" ]; then
    echo -e "${YELLOW}🔐 Code signing applications...${NC}"
    
    # Sign system extension
    codesign --force --sign "Developer ID Application: Your Name ($TEAM_ID)" \
        --entitlements "$PROJECT_ROOT/Config/SystemExtension.entitlements" \
        "$SYSEXT_BUNDLE"
    
    # Sign main app
    codesign --force --sign "Developer ID Application: Your Name ($TEAM_ID)" \
        --entitlements "$PROJECT_ROOT/Config/MainApp.entitlements" \
        "$APP_BUNDLE"
    
    # Sign CLI tool
    codesign --force --sign "Developer ID Application: Your Name ($TEAM_ID)" \
        "$BUILD_DIR/avcontrol"
    
    echo -e "${GREEN}✅ Code signing completed${NC}"
else
    echo -e "${YELLOW}⚠️  Skipping code signing (update TEAM_ID in script)${NC}"
fi

# Create distribution package
echo -e "${YELLOW}📦 Creating distribution package...${NC}"

# Copy built files to dist
cp -r "$APP_BUNDLE" "$DIST_DIR/"
cp "$BUILD_DIR/avcontrol" "$DIST_DIR/"
cp "$BUILD_DIR/systemmonitor" "$DIST_DIR/"
cp "$BUILD_DIR/systemcleanup" "$DIST_DIR/"
cp -r Config "$DIST_DIR/"

# Create monitoring directories
mkdir -p "$DIST_DIR/monitoring_data"
mkdir -p "$DIST_DIR/memory_dumps"
mkdir -p "$DIST_DIR/exports"

# Create installer script
cat > "$DIST_DIR/install.sh" << 'EOF'
#!/bin/bash

echo "📦 AudioVideoMonitor Installer"
echo "=============================="

# Check for admin privileges
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run with sudo for system-wide installation"
    echo "Usage: sudo ./install.sh"
    exit 1
fi

# Install CLI tool to /usr/local/bin
echo "🔧 Installing CLI tools..."
cp avcontrol /usr/local/bin/
cp systemmonitor /usr/local/bin/
cp systemcleanup /usr/local/bin/
chmod +x /usr/local/bin/avcontrol
chmod +x /usr/local/bin/systemmonitor
chmod +x /usr/local/bin/systemcleanup

# Create monitoring directories
mkdir -p /var/log/memory_dumps
mkdir -p /var/log/exports
chmod 755 /var/log/memory_dumps
chmod 755 /var/log/exports

# Copy app to Applications
echo "📱 Installing Application..."
cp -r AudioVideoMonitor.app /Applications/

echo "✅ Installation completed!"
echo ""
echo "Next steps:"
echo "1. Run: avcontrol install"
echo "2. Approve extension in System Settings > Privacy & Security"
echo "3. Use: avcontrol status to verify installation"
echo "4. Monitor with: systemmonitor monitor"
echo "5. View processes: systemmonitor processes"
echo "6. Analyze system: systemmonitor stats"
echo "7. System cleanup: systemcleanup analyze"
echo "8. Full cleanup: systemcleanup full"
echo "9. Safe cleanup: systemcleanup safe-mode"
EOF

chmod +x "$DIST_DIR/install.sh"

# Create README
cat > "$DIST_DIR/README.md" << 'EOF'
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
EOF

# Create ZIP package
echo -e "${YELLOW}🗜️  Creating ZIP package...${NC}"
cd "$DIST_DIR"
zip -r "AudioVideoMonitor-v1.0.zip" . -x "*.DS_Store"

cd "$PROJECT_ROOT"

# Build summary
echo -e "${GREEN}"
echo "🎉 Build completed successfully!"
echo "================================="
echo -e "${NC}"
echo "📁 Built files:"
echo "  • App Bundle:    $APP_BUNDLE"
echo "  • CLI Tool:      $BUILD_DIR/avcontrol"
echo "  • Distribution:  $DIST_DIR/"
echo "  • ZIP Package:   $DIST_DIR/AudioVideoMonitor-v1.0.zip"
echo ""
echo "🚀 Next steps:"
echo "  1. Update TEAM_ID in build script for code signing"
echo "  2. Run: sudo $DIST_DIR/install.sh"
echo "  3. Test with: avcontrol status"
echo ""
echo -e "${BLUE}📖 See README.md in dist/ for complete instructions${NC}"
EOF