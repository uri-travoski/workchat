#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-1.1.0}"
VERSION="${VERSION#v}"
ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BUNDLE_DIR="$ROOT_DIR/app/build/linux/x64/release/bundle"
DIST_DIR="$ROOT_DIR/dist"

mkdir -p "$DIST_DIR"

echo "=== Building Linux Packages for WorkChat v$VERSION ==="

if [ ! -d "$BUNDLE_DIR" ]; then
  echo "Error: Bundle directory $BUNDLE_DIR does not exist. Run 'flutter build linux --release' first."
  exit 1
fi

# 1. Build .deb package
echo "--> Creating .deb package..."
DEB_DIR=$(mktemp -d)/workchat-deb
mkdir -p "$DEB_DIR/usr/lib/workchat" "$DEB_DIR/usr/bin" "$DEB_DIR/usr/share/applications" "$DEB_DIR/usr/share/icons/hicolor/512x512/apps" "$DEB_DIR/DEBIAN"

cp -r "$BUNDLE_DIR/"* "$DEB_DIR/usr/lib/workchat/"
ln -sf "/usr/lib/workchat/workchat" "$DEB_DIR/usr/bin/workchat"
cp "$ROOT_DIR/packaging/linux/workchat.desktop" "$DEB_DIR/usr/share/applications/"
cp "$ROOT_DIR/assets/icon/workchat-512.png" "$DEB_DIR/usr/share/icons/hicolor/512x512/apps/workchat.png"

cat << EOF > "$DEB_DIR/DEBIAN/control"
Package: workchat
Version: $VERSION
Section: net
Priority: optional
Architecture: amd64
Maintainer: Uri Travoski <uri-travoski@users.noreply.github.com>
Description: WorkChat - Lightweight, private self-hosted messaging platform
 A lightweight messaging platform supporting up to 100 users, engineered for minimal CPU and RAM consumption.
EOF

dpkg-deb --build --root-owner-group "$DEB_DIR" "$DIST_DIR/WorkChat-$VERSION-linux-amd64.deb"
rm -rf "$DEB_DIR"
echo "✓ Created $DIST_DIR/WorkChat-$VERSION-linux-amd64.deb"

# 2. Build .rpm package using alien
echo "--> Creating .rpm package..."
if command -v alien >/dev/null 2>&1; then
  TMP_RPM_DIR=$(mktemp -d)
  (cd "$TMP_RPM_DIR" && alien -r --nodeps "$DIST_DIR/WorkChat-$VERSION-linux-amd64.deb")
  RPM_FILE=$(find "$TMP_RPM_DIR" -name "*.rpm" | head -n 1)
  if [ -n "$RPM_FILE" ]; then
    cp "$RPM_FILE" "$DIST_DIR/WorkChat-$VERSION-linux-x86_64.rpm"
    echo "✓ Created $DIST_DIR/WorkChat-$VERSION-linux-x86_64.rpm"
  fi
  rm -rf "$TMP_RPM_DIR"
else
  echo "alien not found, skipping .rpm build locally (will be run in CI)"
fi

# 3. Build .AppImage package
echo "--> Creating .AppImage package..."
APPDIR=$(mktemp -d)/WorkChat.AppDir
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/lib" "$APPDIR/usr/share/applications" "$APPDIR/usr/share/icons/hicolor/512x512/apps"

cp -r "$BUNDLE_DIR/"* "$APPDIR/usr/bin/"
cp "$ROOT_DIR/packaging/linux/workchat.desktop" "$APPDIR/workchat.desktop"
cp "$ROOT_DIR/packaging/linux/workchat.desktop" "$APPDIR/usr/share/applications/workchat.desktop"
cp "$ROOT_DIR/assets/icon/workchat-512.png" "$APPDIR/workchat.png"
cp "$ROOT_DIR/assets/icon/workchat-512.png" "$APPDIR/usr/share/icons/hicolor/512x512/apps/workchat.png"

# AppRun launcher script
cat << 'EOF' > "$APPDIR/AppRun"
#!/bin/sh
SELF=$(readlink -f "$0")
HERE=${SELF%/*}
export PATH="${HERE}/usr/bin:${PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${HERE}/usr/bin/lib:${LD_LIBRARY_PATH}"
exec "${HERE}/usr/bin/workchat" "$@"
EOF
chmod +x "$APPDIR/AppRun"

TOOLS_DIR="$ROOT_DIR/packaging/.tools"
mkdir -p "$TOOLS_DIR"
if ! command -v appimagetool >/dev/null 2>&1 && [ ! -x "$TOOLS_DIR/appimagetool" ]; then
  curl -fsSL -o "$TOOLS_DIR/appimagetool" https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage || true
  chmod +x "$TOOLS_DIR/appimagetool" 2>/dev/null || true
fi

AT=$(command -v appimagetool || echo "$TOOLS_DIR/appimagetool")
if [ -x "$AT" ]; then
  ARCH=x86_64 "$AT" --appimage-extract-and-run "$APPDIR" "$DIST_DIR/WorkChat-$VERSION-linux-x86_64.AppImage" || true
  echo "✓ Created $DIST_DIR/WorkChat-$VERSION-linux-x86_64.AppImage"
else
  echo "appimagetool not available locally, will build in CI"
fi
rm -rf "$APPDIR"

# 4. Build .flatpak single-file bundle
echo "--> Creating .flatpak package..."
if command -v flatpak-builder >/dev/null 2>&1; then
  TMP_FP_BUILD=$(mktemp -d)
  TMP_FP_REPO=$(mktemp -d)
  flatpak-builder --force-clean --repo="$TMP_FP_REPO" "$TMP_FP_BUILD" "$ROOT_DIR/packaging/flatpak/com.workchat.WorkChat.yml"
  flatpak build-bundle "$TMP_FP_REPO" "$DIST_DIR/WorkChat-$VERSION-linux-x86_64.flatpak" com.workchat.WorkChat
  rm -rf "$TMP_FP_BUILD" "$TMP_FP_REPO"
  echo "✓ Created $DIST_DIR/WorkChat-$VERSION-linux-x86_64.flatpak"
else
  echo "flatpak-builder not available locally, will build in CI"
fi

echo "=== Linux packaging completed! ==="
ls -la "$DIST_DIR" || true
