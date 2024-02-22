#/bin/bash
set -Eeuo pipefail

root=$(dirname "${BASH_SOURCE[0]}")
mod_folder="/cygdrive/c/Users/Windree/AppData/Roaming/Vortex/downloads/skyrimse/"
mod_file="Notification Filter*.zip"
mod_config="Data/SKSE/Plugins/NotificationFilter.ini"
output_folder="$root/configs"
ini_delimiter=";========================"

function main() {

    local base_config=$(get_base_config)
    for file in $(get_ini_files); do
        local name=$(cat "$file" | parse_ini_description)
        local config_file=$(basename "$file")
        local outout_file="$output_folder/$config_file"
        rm -rfv "$output_folder/*"
        (
            echo
            echo
            echo "$base_config"
            echo "$ini_delimiter"
            cat "$file"
            echo "$ini_delimiter"
        ) >"$outout_file"
    done
    exit
}

function get_ini_files() {
    find "$root" -maxdepth 1 -type f -name '*.ini'
}

function parse_ini_description() {
    head -n 1 | grep -oP '(?<=^;).+' | awk '{$1=$1};1'
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
