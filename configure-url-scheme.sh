#!/bin/bash

set -e

PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PLIST_FILE="Zenith Commander/Info.plist"

echo "Configuring URL Scheme for Zenith Commander..."

# 检查是否已存在 Info.plist
if [ ! -f "$PLIST_FILE" ]; then
    echo "Creating Info.plist..."
    cat > "$PLIST_FILE" << 'PLIST_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"\>
<plist version="1.0">
<dict>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>com.lihuu.top.Zenith-Commander</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>zenith-commander</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
PLIST_EOF
else
    echo "Info.plist already exists, checking for URL Types..."
    
    # 检查是否已经配置了 URL Types
    if /usr/libexec/PlistBuddy -c "Print :CFBundleURLTypes" "$PLIST_FILE" &>/dev/null; then
        echo "CFBundleURLTypes already exists"
    else
        echo "Adding CFBundleURLTypes..."
        /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes array" "$PLIST_FILE"
        /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0 dict" "$PLIST_FILE"
        /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLName string com.lihuu.top.Zenith-Commander" "$PLIST_FILE"
        /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$PLIST_FILE"
        /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string zenith-commander" "$PLIST_FILE"
    fi
fi

echo "✅ URL Scheme configured successfully!"
echo ""
echo "URL Scheme: zenith-commander://"
echo "Example: zenith-commander://batch-rename?files=path1,path2,path3"
echo ""
echo "Next steps:"
echo "1. Rebuild the project in Xcode"
echo "2. Test with: open 'zenith-commander://batch-rename?files=/tmp/test.txt'"
