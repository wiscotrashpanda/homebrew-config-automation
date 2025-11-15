#!/bin/bash

# Create app wrapper for brew-config.sh
# This allows the script to show with a proper name in System Settings

APP_NAME="Homebrew Config Automation"
APP_DIR="$HOME/Applications/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
ICON_NAME="AppIcon"

# Get the actual script path
SCRIPT_PATH="$HOME/bin/brew-config.sh"

echo "Creating app wrapper: ${APP_DIR}"

# Create directory structure
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Create the wrapper executable
cat > "${MACOS_DIR}/${APP_NAME}" << 'EOF'
#!/bin/bash
# Wrapper script that calls the actual brew-config.sh
exec "$HOME/bin/brew-config.sh" "$@"
EOF

chmod +x "${MACOS_DIR}/${APP_NAME}"

# Copy ICNS file to app bundle
ICON_SOURCE="$(pwd)/AppIcon.icns"
if [[ -f "${ICON_SOURCE}" ]]; then
    echo "Copying AppIcon.icns to app bundle..."
    
    cp "${ICON_SOURCE}" "${RESOURCES_DIR}/${ICON_NAME}.icns"
    
    if [[ $? -eq 0 ]]; then
        echo "✓ Icon added to app bundle"
    else
        echo "⚠ Warning: Failed to copy icon file"
    fi
else
    echo "⚠ Warning: AppIcon.icns not found in current directory, skipping icon"
fi

# Create Info.plist
cat > "${CONTENTS_DIR}/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.emkaytec.homebrewconfig</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>${ICON_NAME}</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSBackgroundOnly</key>
    <true/>
</dict>
</plist>
EOF

echo "✓ App wrapper created successfully"
echo ""
echo "App location: ${APP_DIR}"
echo ""
echo "Now update your launchd plist to use the app wrapper:"
echo "  ${MACOS_DIR}/${APP_NAME}"
