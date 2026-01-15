#!/bin/bash

set -e

echo "=== Configuring Zenith Commander Project ==="
echo ""

# 检查并添加 entitlements 到 Extension target
echo "Checking FinderSync Extension entitlements..."
EXTENSION_ENTITLEMENTS="FinderSyncExtension/FinderSyncExtension.entitlements"

if [ -f "$EXTENSION_ENTITLEMENTS" ]; then
    echo "✅ Extension entitlements file exists"
else
    echo "❌ Extension entitlements file not found!"
    exit 1
fi

# 提示用户需要在 Xcode 中做的配置
echo ""
echo "=== Manual Configuration Required in Xcode ==="
echo ""
echo "1. Open Zenith Commander.xcodeproj in Xcode"
echo ""
echo "2. Configure FinderSync Extension Target:"
echo "   - Select 'FinderSyncExtension' target"
echo "   - Go to 'Signing & Capabilities' tab"
echo "   - Click '+Capability' → Add 'App Groups'"
echo "   - Check 'group.com.lihuu.top.ZenithCommander'"
echo "   - In 'Build Settings', set 'CODE_SIGN_ENTITLEMENTS' to:"
echo "     FinderSyncExtension/FinderSyncExtension.entitlements"
echo ""
echo "3. Configure Main App Target:"
echo "   - Select 'Zenith Commander' target"
echo "   - Go to 'Signing & Capabilities' tab"
echo "   - Verify 'App Groups' capability exists with:"
echo "     group.com.lihuu.top.ZenithCommander"
echo ""
echo "4. Add FinderRequest.swift to both targets:"
echo "   - In Project Navigator, select:"
echo "     Zenith Commander/Shared/FinderRequest.swift"
echo "   - In File Inspector (右侧面板):"
echo "   - Under 'Target Membership', check BOTH:"
echo "     ☑ Zenith Commander"
echo "     ☑ FinderSyncExtension"
echo ""
echo "5. Fix version mismatch:"
echo "   - Select 'FinderSyncExtension' target"
echo "   - In 'Build Settings', search for 'MARKETING_VERSION'"
echo "   - Change from '1.4.1' to '1.4.1' (should match main app)"
echo "   - Search for 'CURRENT_PROJECT_VERSION'"
echo "   - Change from '1' to '1.4.1' (to match main app)"
echo ""
echo "=== Verification Steps ==="
echo ""
echo "After configuration, build the project:"
echo "  xcodebuild -scheme \"Zenith Commander\" -configuration Release build"
echo ""
echo "If build succeeds, test the integration:"
echo "  1. Run the app from Xcode"
echo "  2. Enable FinderSync Extension in System Settings"
echo "  3. Right-click files in Finder → '复制完整路径'"
echo "  4. Check Console.app for logs with 'FinderRequestStore'"
echo ""

