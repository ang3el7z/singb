#!/bin/sh

[ -r "$1" ] || { echo "URL file not found"; exit 1; }
CONFIG_URL=$(cat "$1")
TARGET_FILE="$2"

# Проверка зависимостей
command -v curl >/dev/null || { echo "curl not found"; exit 1; }
command -v jq >/dev/null || { echo "jq not found"; exit 1; }

# Загрузка и обработка конфига
curl -fsSL "$CONFIG_URL" | jq . > "$TARGET_FILE.tmp" 2>/dev/null || { 
    rm -f "$TARGET_FILE.tmp"
    exit 1
}

mv "$TARGET_FILE.tmp" "$TARGET_FILE"
