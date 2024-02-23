#/bin/bash
set -Eeuo pipefail

root=$(dirname "${BASH_SOURCE[0]}")
mod_folder="/cygdrive/c/Users/Windree/AppData/Roaming/Vortex/downloads/skyrimse/"
mod_file="Notification Filter*.zip"
mod_config="Data/SKSE/Plugins/NotificationFilter.ini"
output_folder="$root/configs"
output_file_mask="*.ini"
ini_delimiter=";========================"
temporary_folder="$(mktemp -d)"
max=5
clear

function main() {
    local base_config=$(get_base_config)
    echo "Cleaning up.."

    find "$output_folder" -maxdepth 1 -type f -name "$output_file_mask" -delete

    local ini_files="$(get_ini_files | sort)"

    echo -n "$ini_files" | xargs -I% basename "%"
    local count=$(echo "$ini_files" | wc -l)
    for length in $(seq 1 $count); do
        sequence_generator "" $length $count
    done

}

function get_ini_files() {
    find "$root" -maxdepth 1 -type f -name '*.ini'
}

function parse_ini_description() {
    head -n 1 | grep -oP '(?<=^;).+' | awk '{$1=$1};1'
}

# print config from base mod file
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

function sequence_generator() {
    local prefix=$1
    local remaining=$2
    local count=$3
    local previous=$(echo "$prefix" | grep -oP '[\d]+$')
    declare -i number=0
    while ((number < count)); do
        ((number = number + 1))
        if [ -n "$previous" ] && ((number <= previous)); then
            continue
        fi
        local string=
        if [ -n "$prefix" ]; then
            string="$prefix $number"
        else
            string=$number
        fi
        if ((remaining > 1)); then
            sequence_generator "$string" $((remaining - 1)) $count
        else
            echo "$string"
        fi
    done
}

# prints starting $1 line [limit to $2 lines]
function slice() {
    if [ -v 2 ]; then
        tail -n "+$1" | head -n "$2"
    else
        tail -n "+$1"
    fi
}

function cleanup() {
    echo "Cleaning up temporary folders/files ($(rm -rfv "$temporary_folder"))"
}

trap cleanup exit
clear
main
