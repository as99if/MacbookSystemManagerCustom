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
