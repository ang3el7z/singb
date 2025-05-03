#!/bin/sh
set -e

logger -t singb-updater "Starting update with args: $@"

[ $# -eq 2 ] || {
    echo "Usage: $0 <url-file> <target-file>"
    exit 1
}

URL_FILE="$1"
TARGET_FILE="$2"

[ -r "$URL_FILE" ] || {
    logger -t singb-updater "URL file $URL_FILE not found"
    echo "URL file not found"
    exit 1
}

CONFIG_URL=$(cat "$URL_FILE")
[ -n "$CONFIG_URL" ] || {
    logger -t singb-updater "Empty URL in $URL_FILE"
    echo "Empty URL"
    exit 1
}

command -v curl >/dev/null || {
    logger -t singb-updater "curl not found"
    echo "curl not installed"
    exit 1
}

command -v jq >/dev/null || {
    logger -t singb-updater "jq not found"
    echo "jq not installed"
    exit 1
}

TMP_FILE="${TARGET_FILE}.tmp.$$"

logger -t singb-updater "Downloading config from $CONFIG_URL"
curl -fsSL "$CONFIG_URL" | jq . > "$TMP_FILE" 2>&1 || {
    logger -t singb-updater "Download failed: $(cat $TMP_FILE)"
    rm -f "$TMP_FILE"
    exit 1
}

mv "$TMP_FILE" "$TARGET_FILE" || {
    logger -t singb-updater "File move failed: $TMP_FILE -> $TARGET_FILE"
    exit 1
}

logger -t singb-updater "Config updated successfully"
echo "Success"
exit 0
