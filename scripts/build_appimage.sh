#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_DIR="${ROOT_DIR}/app"
DIST_DIR="${ROOT_DIR}/dist"
APPDIR="${DIST_DIR}/WorkChat.AppDir"
VERSION="1.2.4"

echo "=== Building WorkChat Linux AppImage (v${VERSION}) ==="

# 1. Ensure Linux release bundle is built
BUNDLE_DIR="${APP_DIR}/build/linux/x64/release/bundle"
if [ ! -f "${BUNDLE_DIR}/workchat" ]; then
  echo "Building Flutter Linux release bundle..."
  (cd "${APP_DIR}" && flutter build linux --release)
fi

# 2. Prepare AppDir
echo "Preparing AppDir structure at ${APPDIR}..."
rm -rf "${APPDIR}"
mkdir -p "${APPDIR}/usr/bin"
mkdir -p "${APPDIR}/usr/share/applications"
mkdir -p "${APPDIR}/usr/share/icons/hicolor/512x512/apps"

# Copy bundle files
cp -r "${BUNDLE_DIR}/"* "${APPDIR}/"

# Copy icon
ICON_SRC="${ROOT_DIR}/app-icon-512.png"
if [ ! -f "${ICON_SRC}" ]; then
  ICON_SRC="${APP_DIR}/assets/icons/app-icon.png"
fi
cp "${ICON_SRC}" "${APPDIR}/workchat.png"
cp "${ICON_SRC}" "${APPDIR}/usr/share/icons/hicolor/512x512/apps/workchat.png"

# Create .desktop file
cat << 'EOF' > "${APPDIR}/workchat.desktop"
[Desktop Entry]
Name=WorkChat
GenericName=Team Messenger
Comment=Secure, modern team messaging and collaboration
Exec=workchat %u
Icon=workchat
Terminal=false
Type=Application
Categories=Network;InstantMessaging;Chat;
StartupWMClass=workchat
MimeType=x-scheme-handler/workchat;
Keywords=chat;work;team;messaging;slack;teams;
EOF
cp "${APPDIR}/workchat.desktop" "${APPDIR}/usr/share/applications/workchat.desktop"

# Symlink binary in usr/bin
ln -sf "../../workchat" "${APPDIR}/usr/bin/workchat"

# Create AppRun
cat << 'EOF' > "${APPDIR}/AppRun"
#!/usr/bin/env bash
set -e

# Determine the directory where this script is located
HERE="$(dirname "$(readlink -f "${0}")")"

export APPDIR="${HERE}"
export PATH="${HERE}:${HERE}/usr/bin:${PATH}"
export LD_LIBRARY_PATH="${HERE}/lib:${HERE}/usr/lib:${LD_LIBRARY_PATH:-}"

# CD to the directory of the binary so Flutter finds its assets
cd "${HERE}"

exec "${HERE}/workchat" "$@"
EOF
chmod +x "${APPDIR}/AppRun"

# 3. Ensure appimagetool is available
APPIMAGETOOL="/tmp/appimagetool-x86_64.AppImage"
if [ ! -f "${APPIMAGETOOL}" ]; then
  echo "Downloading appimagetool..."
  curl -fsSL -o "${APPIMAGETOOL}" "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
  chmod +x "${APPIMAGETOOL}"
fi

# 4. Generate AppImage
OUTPUT_NAME="WorkChat-v${VERSION}-x86_64.AppImage"
OUTPUT_PATH="${DIST_DIR}/${OUTPUT_NAME}"
LATEST_PATH="${DIST_DIR}/WorkChat-x86_64.AppImage"

echo "Generating AppImage: ${OUTPUT_PATH}..."
ARCH=x86_64 "${APPIMAGETOOL}" --appimage-extract-and-run -n "${APPDIR}" "${OUTPUT_PATH}"
chmod +x "${OUTPUT_PATH}"

cp -f "${OUTPUT_PATH}" "${LATEST_PATH}"

# Also copy to root and apk_server
cp -f "${OUTPUT_PATH}" "${ROOT_DIR}/${OUTPUT_NAME}"
cp -f "${OUTPUT_PATH}" "${ROOT_DIR}/WorkChat-x86_64.AppImage"

if [ -d "${ROOT_DIR}/apk_server" ]; then
  cp -f "${OUTPUT_PATH}" "${ROOT_DIR}/apk_server/${OUTPUT_NAME}"
  cp -f "${OUTPUT_PATH}" "${ROOT_DIR}/apk_server/WorkChat-x86_64.AppImage"
  echo "Copied to apk_server for local network access."
fi

echo "=== Successfully built: ==="
echo "1. ${OUTPUT_PATH}"
echo "2. ${ROOT_DIR}/WorkChat-x86_64.AppImage"
