#!/bin/zsh
set -euo pipefail

app_dir=${1:-}

fail() {
    print -u2 "PUBLIC BUILD CHECK FAILED: $1"
    exit 1
}

search_text() {
    local mode=$1
    local pattern=$2
    local input=${3:--}
    if command -v rg >/dev/null 2>&1; then
        if [[ "$mode" == insensitive ]]; then
            rg -qi -- "$pattern" "$input"
        else
            rg -q -- "$pattern" "$input"
        fi
    elif [[ "$mode" == insensitive ]]; then
        /usr/bin/grep -Eqi -- "$pattern" "$input"
    else
        /usr/bin/grep -Eq -- "$pattern" "$input"
    fi
}

[[ -n "$app_dir" ]] || fail "app bundle path is required"
[[ -d "$app_dir" ]] || fail "app bundle does not exist"

plist_path="$app_dir/Contents/Info.plist"
binary_path="$app_dir/Contents/MacOS/PomodoredTimer"
[[ -f "$plist_path" ]] || fail "Info.plist is missing"
[[ -f "$binary_path" ]] || fail "executable is missing"

bundle_id=$(/usr/bin/plutil -extract CFBundleIdentifier raw -o - "$plist_path")
[[ "$bundle_id" == "jp.tomica.pomodoredtimer.public" ]] \
    || fail "public Bundle ID is incorrect"

if /usr/bin/otool -L "$binary_path" | search_text insensitive 'WebKit'; then
    fail "WebKit is linked"
fi

strings_path=$(/usr/bin/mktemp /private/tmp/pomodored-public-strings.XXXXXX)
trap '/bin/rm -f -- "$strings_path"' EXIT
/usr/bin/strings "$binary_path" > "$strings_path"

if search_text insensitive 'youtube|youtu\.be' "$strings_path"; then
    fail "personal media implementation is present"
fi

if search_text sensitive \
    'pomodored\.timer\.state\.v1|pomodored\.timer\.state\.unreadable-backup\.v1|pomodored\.window\.compact\.v1|pomodored\.window\.alwaysOnTop\.v1' \
    "$strings_path"; then
    fail "personal storage key is present"
fi

if search_text sensitive '/Users/|/home/' "$strings_path"; then
    fail "local filesystem information is present"
fi

if search_text sensitive 'https?://' "$strings_path"; then
    fail "an embedded network URL is present"
fi

search_text sensitive 'pomodored\.public\.timer\.state\.v1' "$strings_path" \
    || fail "public storage key is missing"

search_text sensitive 'pomodored\.public\.timer\.state\.unreadable-backup\.v1' "$strings_path" \
    || fail "public recovery storage key is missing"

typeset unexpected_file=false
while IFS= read -r file_path; do
    relative_path=${file_path#"$app_dir/"}
    case "$relative_path" in
        Contents/Info.plist \
        | Contents/MacOS/PomodoredTimer \
        | Contents/Resources/AppIcon.icns \
        | Contents/Resources/tick.wav \
        | Contents/Resources/tock.wav \
        | Contents/_CodeSignature/CodeResources)
            ;;
        *)
            unexpected_file=true
            ;;
    esac
done < <(/usr/bin/find "$app_dir" -type f)

[[ "$unexpected_file" == false ]] \
    || fail "the app bundle contains an unexpected file"

print "PASS: public bundle contains no personal media, storage keys, records, or local paths"
