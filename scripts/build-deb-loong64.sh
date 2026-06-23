#!/bin/bash
# Build a deb package for Clash Verge Rev on LoongArch64
#
# This script manually creates a deb package since @tauri-apps/cli has no
# loong64 native binding and cannot run "tauri build" for bundling.
#
# Prerequisites:
#   - cargo build --release completed in src-tauri/
#   - Real mihomo binary placed at target/release/verge-mihomo

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

VERSION=$(grep '^version' "$PROJECT_DIR/src-tauri/Cargo.toml" | sed 's/.*"\(.*\)"/\1/')
ARCH=loong64
DEB_NAME="clash-verge_${VERSION}_${ARCH}"
BUILD_DIR="/tmp/clash-verge-deb/$DEB_NAME"

echo "Building $DEB_NAME.deb ..."

# Clean and create directory structure
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/DEBIAN"
mkdir -p "$BUILD_DIR/usr/bin"
mkdir -p "$BUILD_DIR/usr/share/applications"
mkdir -p "$BUILD_DIR/usr/share/icons/hicolor/32x32/apps"
mkdir -p "$BUILD_DIR/usr/share/icons/hicolor/128x128/apps"
mkdir -p "$BUILD_DIR/usr/share/icons/hicolor/256x256@2/apps"

# Copy binaries
cp "$PROJECT_DIR/target/release/clash-verge" "$BUILD_DIR/usr/bin/"
cp "$PROJECT_DIR/target/release/verge-mihomo" "$BUILD_DIR/usr/bin/"
cp "$PROJECT_DIR/target/release/verge-mihomo-alpha" "$BUILD_DIR/usr/bin/"
cp "$PROJECT_DIR/target/release/clash-verge-service" "$BUILD_DIR/usr/bin/"
cp "$PROJECT_DIR/target/release/clash-verge-service-install" "$BUILD_DIR/usr/bin/"
cp "$PROJECT_DIR/target/release/clash-verge-service-uninstall" "$BUILD_DIR/usr/bin/"

# Copy icons
cp "$PROJECT_DIR/src-tauri/icons/32x32.png" \
   "$BUILD_DIR/usr/share/icons/hicolor/32x32/apps/clash-verge.png"
cp "$PROJECT_DIR/src-tauri/icons/128x128.png" \
   "$BUILD_DIR/usr/share/icons/hicolor/128x128/apps/clash-verge.png"
cp "$PROJECT_DIR/src-tauri/icons/128x128@2x.png" \
   "$BUILD_DIR/usr/share/icons/hicolor/256x256@2/apps/clash-verge.png"

# DEBIAN control
cat > "$BUILD_DIR/DEBIAN/control" << EOF
Package: clash-verge
Version: $VERSION
Architecture: $ARCH
Maintainer: Clash Verge Rev <https://github.com/clash-verge-rev/clash-verge-rev>
Depends: openssl, libayatana-appindicator3-1
Provides: clash-verge
Conflicts: clash-verge
Replaces: clash-verge
Section: net
Priority: optional
Description: A Clash Meta GUI based on Tauri
 Clash Verge Rev is a modern GUI proxy client built with Tauri,
 supporting Clash Meta (mihomo) as the backend core.
 Homepage: https://github.com/clash-verge-rev/clash-verge-rev
EOF

# postinst
cat > "$BUILD_DIR/DEBIAN/postinst" << 'SCRIPT'
#!/bin/bash
chmod +x /usr/bin/clash-verge-service-install
chmod +x /usr/bin/clash-verge-service-uninstall
chmod +x /usr/bin/clash-verge-service
SCRIPT
chmod 755 "$BUILD_DIR/DEBIAN/postinst"

# prerm
cat > "$BUILD_DIR/DEBIAN/prerm" << 'SCRIPT'
#!/bin/bash
/usr/bin/clash-verge-service-uninstall 2>/dev/null || true
SCRIPT
chmod 755 "$BUILD_DIR/DEBIAN/prerm"

# Desktop file
cat > "$BUILD_DIR/usr/share/applications/clash-verge.desktop" << EOF
[Desktop Entry]
Categories=Network
Comment=A Clash Meta GUI based on Tauri
Exec=/usr/bin/clash-verge %u
StartupWMClass=clash-verge
Icon=clash-verge
Name=Clash Verge
Terminal=false
Type=Application
MimeType=x-scheme-handler/clash;
EOF

# Build deb
dpkg-deb --build "$BUILD_DIR"

# Copy to project dir
cp "/tmp/clash-verge-deb/$DEB_NAME.deb" "$PROJECT_DIR/"

echo "Done: $PROJECT_DIR/$DEB_NAME.deb"
