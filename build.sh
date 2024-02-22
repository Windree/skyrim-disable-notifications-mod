#/bin/bash
set -Eeuo pipefail

mod_folder=/cygdrive/c/Users/Windree/AppData/Roaming/Vortex/downloads/skyrimse/
mod_file="Notification Filter*.zip"
mod_config=Data/SKSE/Plugins/NotificationFilter.ini

function main() {
    local root=$(dirname "${BASH_SOURCE[0]}")
    local base_config=$(get_base_config)
    echo $base_config
    for file in $(get_ini_files); do
        echo "$file"
        cat "$file" | get_ini_description
    done
    exit
}

function get_ini_files() {
    find "$root" -maxdepth 1 -type f -name *.ini
}

function get_ini_description() {
    head -n 1 | grep -oP '(?<=^;).+'
}

function get_base_config() {
    local mod_zip=$(find "$mod_folder" -maxdepth 1 -type f -name "$mod_file" | tail -n 1)
    if [ ! -f "$mod_zip" ]; then
        echo >&2 "No mod archive found"
        exit 1
    fi
    local content=$(7za e -so "$mod_zip" "$mod_config")
    if [ -z "$content" ]; then
        echo >&2 "No mod config"
        exit 1
    fi
    echo "$content"
}

main
