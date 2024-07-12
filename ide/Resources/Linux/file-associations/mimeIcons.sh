#!/bin/bash

# Define paths and filenames
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ICON_DIR="$SCRIPT_DIR"
APPLICATION_ICON="oxtlite-app.png"
DOCUMENT_ICON="oxtlite-doc.png"
DOCUMENT_ICON_SCALE="oxtlite-doc.svg"
APPLICATION_PATH="/opt/openxtalk/openxtalk_x86_64/openxtalk.x86_64"
MIME_TYPE="application/x-oxtstack"
DESKTOP_ENTRY="$HOME/.local/share/applications/openxtalk.desktop"
APP_ICON_PATH="$HOME/.local/share/icons/hicolor/48x48/apps"
DOC_ICON_PATH="$HOME/.local/share/icons/hicolor/48x48/mimetypes"
DOC_ICON_PATH_SCALE="$HOME/.local/share/icons/hicolor/scaleable"
LOCK_FILE="$HOME/.local/share/applications/openxtalk.lock"

# Check if another instance is already running
if [ -f "$LOCK_FILE" ]; then
    echo "Another instance of OpenXTalk is already running."
    exit 1
fi

# Create a lock file
touch "$LOCK_FILE"

# Function to remove the lock file on exit
cleanup() {
    rm -f "$LOCK_FILE"
}
trap cleanup EXIT

# Create necessary directories in user's home
mkdir -p "$APP_ICON_PATH"
mkdir -p "$DOC_ICON_PATH"
mkdir -p "$HOME/.local/share/applications"
mkdir -p "$HOME/.local/share/mime/packages"

# Copy icons to user's icon directory
cp "$ICON_DIR/$APPLICATION_ICON" "$APP_ICON_PATH/"
cp "$ICON_DIR/$DOCUMENT_ICON" "$DOC_ICON_PATH/"
cp "$ICON_DIR/$DOCUMENT_ICON_SCALE" "$DOC_ICON_PATH_SCALE/"

# Create MIME XML file for oxtstack filetype
tee "$HOME/.local/share/mime/packages/oxtstack.xml" > /dev/null << EOF
<?xml version="1.0"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
    <mime-type type="$MIME_TYPE">
        <comment>OxtStack File</comment>
        <glob pattern="*.oxtstack"/>
    </mime-type>
</mime-info>
EOF

# Update the user's mime database
update-mime-database "$HOME/.local/share/mime"

# Create desktop entry for launching application
tee "$DESKTOP_ENTRY" > /dev/null << EOF
[Desktop Entry]
Version=1.0
Name=OpenXTalk Lite
Comment=Launch OpenXTalk Lite
Exec="$APPLICATION_PATH" %U
Icon=$APP_ICON_PATH/$APPLICATION_ICON
Terminal=false
Type=Application
MimeType=$MIME_TYPE;
Categories=Development;
EOF

# Ensure correct permissions for the icon files
chmod 644 "$APP_ICON_PATH/$APPLICATION_ICON"
chmod 644 "$DOC_ICON_PATH/$DOCUMENT_ICON"
chmod 644 "$DOC_ICON_PATH_SCALE/$DOCUMENT_ICON_SCALE"

# Force update the icon cache
gtk-update-icon-cache -f "$APP_ICON_PATH"

# Print success message
echo "OpenXTalk Lite desktop entry configured successfully."

