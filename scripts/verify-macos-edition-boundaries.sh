#!/bin/zsh
set -euo pipefail

if (( $# != 3 )); then
    print -u2 "Usage: $0 <sdk-path> <target> <module-cache>"
    exit 2
fi

sdk_path=$1
target=$2
module_cache=$3
project_dir=${0:A:h:h}
edition_source="$project_dir/Sources/PomodoredTimer/AppEdition.swift"

typecheck() {
    env CLANG_MODULE_CACHE_PATH="$module_cache" swiftc \
        -sdk "$sdk_path" \
        -target "$target" \
        -typecheck \
        "$@" \
        "$edition_source"
}

expect_failure() {
    local label=$1
    shift
    if typecheck "$@" >/dev/null 2>&1; then
        print -u2 "FAIL: invalid edition combination compiled: $label"
        exit 1
    fi
}

typecheck -D EDITION_PUBLIC >/dev/null
expect_failure "missing public edition"
expect_failure "private edition" -D EDITION_PERSONAL -D FEATURE_PERSONAL_MEDIA
expect_failure "mixed public and private editions" -D EDITION_PUBLIC -D EDITION_PERSONAL
expect_failure "public with private media" -D EDITION_PUBLIC -D FEATURE_PERSONAL_MEDIA

print "PASS: macOS public boundary rejects implicit and private products"
