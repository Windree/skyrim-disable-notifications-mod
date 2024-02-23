#!/bin/bash

set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/fomod/ModuleConfig.sh"

root=$(dirname "${BASH_SOURCE[0]}")
temporary_folder="$(mktemp -d)"

mod_folder="/cygdrive/c/Users/Windree/AppData/Roaming/Vortex/downloads/skyrimse/"
mod_file="Notification Filter*.zip"
mod_ini=NotificationFilter.ini
mod_folder=Data/SKSE/Plugins
mod_config="$mod_folder/$mod_ini"

config_folder="$root/configs"
output_folder="$root/configs"
fomod_folder="$temporary_folder/fomod"
fomod_recomended="Recommended"
fomod_optional="Optional"

function main() {
    local base_config=$(get_base_config)
    local config_files="$(get_ini_files "$config_folder" | sort)"
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
            local title=$(echo "$titles" | concat " + ")
            local name=$(echo "$configs" | parse_config_file_id | concat "-")
            local folder="$temporary_folder/$name/$mod_folder"
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
            fomod_plugins+=("$plugin"$'\n')
        done < <(sequence_generator "" $length $config_count)
    done

    echo "Creating fomod config"
    mkdir -p "$fomod_folder"
    local fomod_info_file="$fomod_folder/info.xml"
    local fomod_module_file="$fomod_folder/ModuleConfig.xml"
    echo "${MODULE_CONFIG//%PLUGINS%/${fomod_plugins[@]}}" >"$fomod_folder/ModuleConfig.xml"
    cat "$root/fomod/info.xml" >>"$fomod_folder/info.xml"

    rsync -av "$temporary_folder/" "$root/tmp"
}

function get_ini_files() {
    find "$1" -type f
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

function parse_config_file_id() {
    while IFS= read -r line; do
        basename "$line" | grep -oP '^\d+'
    done
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

function f() {
    set -x
    local ids=()
    for id in $(seq 1 5); do
        ids+=($id)
    done
    echo "${ids[@]}"
}

clear
main
