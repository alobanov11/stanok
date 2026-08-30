#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
srcroot="${SRCROOT:-$(cd "${script_dir}/.." && pwd)}"
ghostty_dir="${srcroot}/ThirdParty/ghostty"
build_root="${srcroot}/.build/ghostty"
xcframework_path="${build_root}/GhosttyKit.xcframework"

# Zig 0.15.2 cannot link the macOS 26.4+ SDK (ziglang/zig#31658), so pin an Xcode
# whose SDK still carries the arm64-macos slice.
for candidate in /Applications/Xcode_26.3.app /Applications/Xcode.app; do
  sdk="${candidate}/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.2.sdk"
  if [ -d "${sdk}" ]; then
    export DEVELOPER_DIR="${candidate}/Contents/Developer"
    break
  fi
done
if [ -z "${DEVELOPER_DIR:-}" ]; then
  echo "error: no Xcode with MacOSX26.2.sdk found" >&2
  exit 1
fi
echo "[build-ghostty] DEVELOPER_DIR=${DEVELOPER_DIR}"

mkdir -p "${build_root}"
cd "${ghostty_dir}"
mise exec -- zig build \
  -Doptimize=ReleaseFast \
  -Demit-xcframework=true \
  -Dxcframework-target=native \
  -Demit-macos-app=false \
  -Dsentry=false \
  --prefix "${build_root}" \
  --cache-dir "${build_root}/.zig-cache" \
  --global-cache-dir "${build_root}/.zig-global-cache"

rsync -a --delete "${ghostty_dir}/macos/GhosttyKit.xcframework/" "${xcframework_path}/"

# Ghostty emits a modulemap that Swift cannot consume directly; flatten it.
find "${xcframework_path}" -path '*/Headers/module.modulemap' -print0 |
  while IFS= read -r -d '' modulemap; do
    cat > "${modulemap}" <<'EOF'
module GhosttyKit {
    header "ghostty.h"
    export *
}
EOF
  done

echo "[build-ghostty] done -> ${xcframework_path}"
