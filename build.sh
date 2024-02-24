#!/bin/bash

set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/fomod/ModuleConfig.sh"

root=$(dirname "${BASH_SOURCE[0]}")
temporary_folder="$(mktemp -d)"

mods_folder="/cygdrive/c/Users/Windree/AppData/Roaming/Vortex/downloads/skyrimse/"
mod_file="Notification Filter*.zip"
mod_ini=NotificationFilter.ini
mod_folder=Data/SKSE/Plugins

config_folder="$root/configs"
output_folder="$root/configs"
fomod_folder="$temporary_folder/fomod"
fomod_recomended="Recommended"
fomod_optional="Optional"

target_file="$root/target/Disable-Notification-Messages.7z"

function main() {
    local debug=false
    while [ $# -gt 0 ]; do
        case $1 in
        "debug")
            debug=true
            ;;
        *)
            echo >&2 "Unknown parameter $1"
            exit
            ;;
        esac
        shift
    done

    local base_config=$(get_base_config "$mods_folder" "$mod_file" "$mod_folder/$mod_ini")
    local config_files="$(find_files "$config_folder" | sort)"
    local config_count=$(echo "$config_files" | wc -l)
    local fomod_plugins=()
    echo "Config files:"
    echo "$config_files"
    echo
    for length in $(seq 1 $config_count); do
        while IFS= read -r row; do
            local plugin=
            local indexes=$(echo "$row" | sed -e "s/ /\n/g")
            local configs=$(
                for index in $indexes; do
                    echo "$config_files" | slice $index 1
                done
            )
            local titles=$(
                for file in $configs; do
                    cat "$file" | parse_ini_description "$file"
                done
            )
            local sections=$(
                for file in $configs; do
                    cat "$file" | parse_ini_sections "$file"
                done
            )
            local title=$(echo "$titles" | concat " + ")
            local name=$(echo "$configs" | parse_number_file_prefix | concat "-")
            local description=$(echo "$sections" | concat $'\n')
            local folder="$temporary_folder/$name/"
            local ini="$folder/$mod_ini"
            echo "Combine folowing fieles into '$ini'    Title: $title"
            mkdir -p "$folder"
            echo "$base_config" >"$ini"
            echo >>"$ini"
            for file in $configs; do
                echo "File: $file"
                cat "$file" >>"$ini"
                echo >>"$ini"
            done
            echo
            echo

            plugin="${MODULE_PLUGIN//%NAME%/$name}"
            plugin="${plugin//%TITLE%/$title}"
            plugin="${plugin//%TYPE%/$fomod_optional}"
            plugin="${plugin//%DESCRIPTION%/$description}"
            fomod_plugins+=("$plugin"$'\n')
        done < <(sequence_generator "" $length $config_count)
    done

    echo "Creating fomod config"
    mkdir -p "$fomod_folder"
    local fomod_info_file="$fomod_folder/info.xml"
    local fomod_module_file="$fomod_folder/ModuleConfig.xml"
    cat "$root/fomod/info.xml" >>"$fomod_info_file"
    echo "${MODULE_CONFIG//%PLUGINS%/${fomod_plugins[@]}}" >"$fomod_module_file"
    echo "Pack files into plugin"
    local target_folder=$(dirname "$target_file")
    rm -rf "$target_folder"
    mkdir -p "$target_folder"
    7z a "$target_file" "$temporary_folder/*"
    if $debug; then
        rsync -av --delete "$temporary_folder/" "$root/tmp"
    fi
}

function find_files() {
    find "$1" -type f -name "*.ini"
}

# print config from base mod file
function get_base_config() {
    local mod_zip=$(find "$1" -maxdepth 1 -type f -name "$2" | tail -n 1)
    if [ ! -f "$mod_zip" ]; then
        echo >&2 "No mod archive found"
        exit 1
    fi
    local content=$(7za e -so "$mod_zip" "$3")
    if [ -z "$content" ]; then
        echo >&2 "No mod config file '$3' found in archive"
        exit 1
    fi
    echo "$content"
}

function parse_number_file_prefix() {
    while IFS= read -r line; do
        basename "$line" | grep -oP '^\d+'
    done
}

function parse_ini_description() {
    head -n 1 | grep -oP '(?<=^; #).+' | awk '{$1=$1};1'
}

function parse_ini_sections() {
    tail -n +2 | grep -oP '(?<=^; #).+' | awk '{$1=$1};1'
}

function concat() {
    local concatinator=$1
    local pipe=$(cat)
    local count=$(echo "$pipe" | wc -l)
    for index in $(seq 1 $count); do
        local item=$(echo "$pipe" | slice $index 1)
        echo -n "$item"
        if ((index < count)); then
            echo -n "$concatinator"
        fi
    done
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
    echo "Cleaning up temporary folders/files ($(rm -rfv "$temporary_folder" | wc -l))"
}

trap cleanup exit

main "$@"
