#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h:h}
cd "$project_dir"

if (( $# > 1 )); then
    print -u2 "Usage: $0 [public]"
    exit 2
fi

edition=${1:-public}
[[ "$edition" == public ]] || {
    print -u2 "This repository builds the public edition only"
    exit 2
}
typeset -a edition_flags
edition_flags=(-D EDITION_PUBLIC)
info_plist="$project_dir/Resources/Info.plist"
expected_bundle_id="jp.tomica.pomodoredtimer.public"
expected_display_name="Pomodored Timer Public"
app_bundle_name="Pomodored Timer Public.app"
product_id="macos-public"
release_status="public"

local_sdk_path=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
if [[ -n "${POMODORED_SDK_PATH:-}" ]]; then
    sdk_path="$POMODORED_SDK_PATH"
elif [[ -d "$local_sdk_path" ]]; then
    sdk_path="$local_sdk_path"
else
    sdk_path=$(xcrun --sdk macosx --show-sdk-path)
fi
module_cache=/private/tmp/pomodored-clang-cache
case "$(uname -m)" in
    arm64) target=arm64-apple-macosx14.0 ;;
    x86_64) target=x86_64-apple-macosx14.0 ;;
    *)
        print -u2 "Unsupported macOS architecture: $(uname -m)"
        exit 1
        ;;
esac
build_dir="$project_dir/.build/native-release-$edition"
mkdir -p "$build_dir" "$module_cache"

/bin/zsh "$project_dir/scripts/verify-macos-edition-boundaries.sh" \
    "$sdk_path" \
    "$target" \
    "$module_cache"

staging_root=$(/usr/bin/mktemp -d /private/tmp/pomodored-build.XXXXXX)
trap '/bin/rm -rf -- "$staging_root"' EXIT

staged_app_dir="$staging_root/$app_bundle_name"
contents_dir="$staged_app_dir/Contents"
macos_dir="$contents_dir/MacOS"
resources_dir="$contents_dir/Resources"
iconset_dir="$staging_root/AppIcon.iconset"
binary_path="$build_dir/PomodoredTimer"
test_binary="$build_dir/TimerCoreTests"
icon_test_binary="$build_dir/MenuBarIconTests"
edition_test_binary="$build_dir/AppEditionTests"
vector_test_binary="$build_dir/PublicCoreVectorTests"

typeset -a app_sources
app_sources=()
for source_path in "$project_dir"/Sources/PomodoredTimer/*.swift; do
    app_sources+=("$source_path")
done

env CLANG_MODULE_CACHE_PATH="$module_cache" swiftc \
    "${edition_flags[@]}" \
    -sdk "$sdk_path" \
    -target "$target" \
    "$project_dir/Sources/PomodoredTimer/TimerCore.swift" \
    "$project_dir/Tests/TimerCoreTestRunner.swift" \
    -o "$test_binary"
"$test_binary"

env CLANG_MODULE_CACHE_PATH="$module_cache" swiftc \
    "${edition_flags[@]}" \
    -sdk "$sdk_path" \
    -target "$target" \
    "$project_dir/Sources/PomodoredTimer/TimerCore.swift" \
    "$project_dir/Tests/PublicCoreVectorTestRunner.swift" \
    -o "$vector_test_binary"
"$vector_test_binary" "$project_dir/Shared/TestVectors/public-core-v1/timer-vectors.json"

env CLANG_MODULE_CACHE_PATH="$module_cache" swiftc \
    "${edition_flags[@]}" \
    -sdk "$sdk_path" \
    -target "$target" \
    "$project_dir/Sources/PomodoredTimer/AppEdition.swift" \
    "$project_dir/Tests/AppEditionTestRunner.swift" \
    -o "$edition_test_binary"
"$edition_test_binary"

env CLANG_MODULE_CACHE_PATH="$module_cache" swiftc \
    -sdk "$sdk_path" \
    -target "$target" \
    "$project_dir/Sources/PomodoredTimer/MenuBarTomatoClockIcon.swift" \
    "$project_dir/Tests/MenuBarIconTestRunner.swift" \
    -framework AppKit \
    -o "$icon_test_binary"
"$icon_test_binary"

env CLANG_MODULE_CACHE_PATH="$module_cache" swiftc \
    "${edition_flags[@]}" \
    -sdk "$sdk_path" \
    -target "$target" \
    -O \
    "${app_sources[@]}" \
    -framework SwiftUI \
    -framework AppKit \
    -framework Combine \
    -o "$binary_path"

mkdir -p "$macos_dir" "$resources_dir" "$iconset_dir"
cp "$binary_path" "$macos_dir/PomodoredTimer"
cp "$info_plist" "$contents_dir/Info.plist"
node "$project_dir/scripts/make-sounds.mjs" "$resources_dir"

source_icon="$project_dir/Resources/AppIconSource.png"
sips -z 16 16 "$source_icon" --out "$iconset_dir/icon_16x16.png"
sips -z 32 32 "$source_icon" --out "$iconset_dir/icon_16x16@2x.png"
sips -z 32 32 "$source_icon" --out "$iconset_dir/icon_32x32.png"
sips -z 64 64 "$source_icon" --out "$iconset_dir/icon_32x32@2x.png"
sips -z 128 128 "$source_icon" --out "$iconset_dir/icon_128x128.png"
sips -z 256 256 "$source_icon" --out "$iconset_dir/icon_128x128@2x.png"
sips -z 256 256 "$source_icon" --out "$iconset_dir/icon_256x256.png"
sips -z 512 512 "$source_icon" --out "$iconset_dir/icon_256x256@2x.png"
sips -z 512 512 "$source_icon" --out "$iconset_dir/icon_512x512.png"
sips -z 1024 1024 "$source_icon" --out "$iconset_dir/icon_512x512@2x.png"
node "$project_dir/scripts/make-icns.mjs" "$iconset_dir" "$resources_dir/AppIcon.icns"

codesign --force --deep --sign - "$staged_app_dir"
plutil -lint "$contents_dir/Info.plist"
codesign --verify --deep --strict "$staged_app_dir"

actual_bundle_id=$(plutil -extract CFBundleIdentifier raw -o - "$contents_dir/Info.plist")
[[ "$actual_bundle_id" == "$expected_bundle_id" ]] || {
    print -u2 "Bundle ID mismatch for $edition build"
    exit 1
}

actual_display_name=$(plutil -extract CFBundleDisplayName raw -o - "$contents_dir/Info.plist")
[[ "$actual_display_name" == "$expected_display_name" ]] || {
    print -u2 "Display name mismatch for $edition build"
    exit 1
}

/bin/zsh "$project_dir/scripts/verify-public-build.sh" "$staged_app_dir"

edition_dist_dir="$project_dir/dist/$edition"
app_dir="$edition_dist_dir/$app_bundle_name"
expected_app_dir="$project_dir/dist/$edition/$app_bundle_name"
[[ "$app_dir" == "$expected_app_dir" ]] || {
    print -u2 "Refusing to replace an unexpected output path"
    exit 1
}

mkdir -p "$edition_dist_dir"
if [[ -e "$app_dir" ]]; then
    /bin/rm -rf -- "$app_dir"
fi
/bin/mv "$staged_app_dir" "$app_dir"

commit_sha=$(git -C "$project_dir" rev-parse HEAD)
dirty_state=false
if [[ -n "$(git -C "$project_dir" status --porcelain)" ]]; then
    dirty_state=true
fi
binary_sha=$(/usr/bin/shasum -a 256 "$app_dir/Contents/MacOS/PomodoredTimer" | /usr/bin/awk '{print $1}')
swift_version=$(swiftc --version 2>/dev/null | /usr/bin/sed -n '1p')
node "$project_dir/scripts/write-build-manifest.mjs" \
    --output "$edition_dist_dir/BUILD-MANIFEST.json" \
    --product "$product_id" \
    --edition "$edition" \
    --release-status "$release_status" \
    --commit "$commit_sha" \
    --dirty "$dirty_state" \
    --platform macos \
    --architecture "$(uname -m)" \
    --toolchain "$swift_version" \
    --sdk "${sdk_path:t}" \
    --artifact "$app_bundle_name/Contents/MacOS/PomodoredTimer" \
    --sha256 "$binary_sha"

echo "$app_dir"
