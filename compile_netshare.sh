#!/bin/zsh

# Usage: curl -sL https://raw.githubusercontent.com/khaleel77/Net-Share-App/refs/heads/master/compile_netshare.sh

swift_file="${1:-custom_window.swift}"

if [[ ! -f "${swift_file}" ]]; then
        curl -s https://raw.githubusercontent.com/khaleel77/Net-Share-App/refs/heads/master/netshare.swift -o iNetShare.swift && echo "Downloaded swift file" || exit 1
fi

#remove the previous one
launchctl unload ~/Library/LaunchAgents/kha.prog.iNetShare.plist
rm -f ~/Library/LaunchAgents/kha.prog.iNetShare.plist
rm -rf /Applications/iNetShare.app
killall iNetShare

app_name="iNetShare"


if [[ ! -f "$swift_file" ]]; then
    echo "❌ Error: Swift file '$swift_file' not found."
    exit 1
fi

app_path="/Applications/${app_name}.app"
plist_label="kha.prog.${app_name:l}"
agent_plist="$HOME/Library/LaunchAgents/${plist_label}.plist"

echo "🔨 Compiling $swift_file with static entry point..."
# Compiling with the main entry designated
if ! swiftc "$swift_file" -o "$app_name"; then
    echo "❌ Compilation failed."
    exit 1
fi



echo "📦 Building ${app_name}.app..."
mkdir -p "${app_name}.app/Contents/MacOS"
mkdir -p "${app_name}.app/Contents/Resources"

mv "$app_name" "${app_name}.app/Contents/MacOS/"


if [[ -f "AppIcon.icns" ]]; then
    cp "AppIcon.icns" "${app_name}.app/Contents/Resources/"
    echo "🎨 App icon bundled successfully."
else
    echo "⚠️ Warning: AppIcon.icns not found in current directory. App will have a default blank icon."
fi

# Create Info.plist
cat <<EOF > "${app_name}.app/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$app_name</string>
    <key>CFBundleIdentifier</key>
    <string>$plist_label</string>
    <key>CFBundleName</key>
    <string>$app_name</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string> 
    <key>NSServices</key>
    <array>
        <dict>
            <key>NSMenuItem</key>
            <dict>
                <key>default</key>
                <string>Process with CustomApp</string>
            </dict>
            <key>NSMessage</key>
            <string>handleService</string>
            <key>NSSendTypes</key>
            <array>
                <string>NSStringPboardType</string>
                <string>NSURLPboardType</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
EOF

echo "🚚 Moving to Applications folder..."
[ -d "$app_path" ] && rm -rf "$app_path"
mv "${app_name}.app" /Applications/

echo "⏰ Setting up Auto-Launch Agent..."
cat <<EOF > "$agent_plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$plist_label</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/open</string>
        <string>$app_path</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

/System/Library/CoreServices/pbs -update

launchctl load "$agent_plist" 2>/dev/null
open "$app_path"

echo "🚀 Success! ${app_name}.app is installed and running."
