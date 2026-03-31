#!/bin/zsh

# -----------------------------------------
# BASE PATH (your external drive)
# -----------------------------------------
BASE="/Volumes/2tbSandisk/Applications/Xcode.app"

# -----------------------------------------
# EXPLICIT TARGET PATHS
# -----------------------------------------
declare -a TARGETS=(
    "$BASE"
    "$BASE/Contents"
    "$BASE/Contents/MacOS"
    "$BASE/Contents/Developer"
    "$BASE/Contents/Developer/Applications"
    "$BASE/Contents/Developer/usr/bin"
    "$BASE/Contents/Developer/Toolchains"
    "$BASE/Contents/Developer/Toolchains/XcodeDefault.xctoolchain"
    "$BASE/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin"
)

# -----------------------------------------
# JSON: BEFORE STATE
# -----------------------------------------
echo "{"
echo '  "action": "open_external_xcode_folders",'
echo '  "timestamp": "'$(date)'",'
echo '  "targets": ['

for path in "${TARGETS[@]}"; do
    exists=$( [[ -e "$path" ]] && echo true || echo false )
    echo '    { "path": "'"$path"'", "exists": '"$exists"' },'
done

echo '  ]'
echo "}"
echo ""

# -----------------------------------------
# OPEN FOLDERS IN FINDER
# -----------------------------------------
for path in "${TARGETS[@]}"; do
    if [[ -e "$path" ]]; then
        open "$path"
    fi
done

# -----------------------------------------
# JSON: AFTER STATE
# -----------------------------------------
echo "{"
echo '  "status": "completed",'
echo '  "opened_paths": ['

for path in "${TARGETS[@]}"; do
    if [[ -e "$path" ]]; then
        echo '    { "opened": "'"$path"'" },'
    fi
done

echo '  ]'
echo "}"
