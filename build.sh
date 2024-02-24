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

fomod_recommended="Recommended"
fomod_optional="Optional"

extra_configs=("$root/configs/Everything.ini")

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
    local config_files="$(find_prefixed_files "$config_folder" | sort)"
    local config_count=$(echo "$config_files" | wc -l)
    local plugins=()
    echo "Config files:"
    echo "$config_files"
    echo

    echo "Creating extra configurations:"
    for file in "${extra_configs[@]}"; do
        echo "File: $file"
        local plugin=$(create_config "$temporary_folder" "$file")
        plugins+=("$plugin")
        echo "An extra plugin saved to '$plugin'"
    done

    echo "Creating mixed configurations:"
    for length in $(seq 1 $config_count); do
        while IFS= read -r row; do
            local indexes=($row)
            local files=()
            echo "Combine following files onto a plugin:"
            for index in "${indexes[@]}"; do
                local file=$(echo "$config_files" | slice $index 1)
                echo "File: $file"
                files+=("$file")
            done
            local plugin=$(create_config "$temporary_folder" "${files[@]}")
            plugins+=("$plugin")
            echo "A plugin saved to '$plugin'"
        done < <(sequence_generator "" $length $config_count)
    done

    echo "Creating fomod config.."
    local fomod=$(create_fomod_config "$root" "$temporary_folder" "${plugins[@]}")
    echo "Fomod config saved to $fomod"

    echo "Pack files into plugin.."
    pack_mod "$temporary_folder" "$root/target/Disable-Notification-Messages.7z"

    if $debug; then
        rsync -av --delete "$temporary_folder/" "$root/tmp"
    fi
}

function create_config() {
    local root=$1
    shift

    local configs=$(
        for file in $@; do
            echo "$file"
        done
    )

    local ids=$(
        for file in $@; do
            cat "$file" | parse_ini_id
        done
    )

    local titles=$(
        for file in $@; do
            cat "$file" | parse_ini_description
        done
    )

    local sections=$(
        for file in $@; do
            cat "$file" | parse_ini_sections
        done
    )

    local name=$(echo "$ids" | concatenate "-")
    if [ -z "$name" ]; then
        echo >&2 "Unable to get id from '$@'"
    fi
    local title=$(echo "$titles" | concatenate " + ")
    if [ -z "$title" ]; then
        echo >&2 "Unable to get title from '$@'"
    fi
    local description=$(echo "$sections" | concatenate $'\n')

    local folder="$root/$name"
    local ini="$folder/$mod_ini"
    local xml="$folder/plugin.xml"
    if ! mkdir "$folder"; then
        echo >&2 "Unable to create '$folder'"
    fi
    echo "$base_config" >"$ini"
    echo >>"$ini"
    for file in $@; do
        cat "$file" >>"$ini"
        echo >>"$ini"
    done
    plugin="${MODULE_PLUGIN//%NAME%/$name}"
    plugin="${plugin//%TITLE%/$title}"
    plugin="${plugin//%TYPE%/$fomod_optional}"
    plugin="${plugin//%DESCRIPTION%/$description}"
    echo "$plugin" >"$xml"
    echo $xml
}

function create_fomod_config() {
    local source=$1
    shift
    local target=$1
    shift
    local folder="$target/fomod"
    if ! mkdir -p "$folder"; then
        echo >&2 "unable to create fomod folder 'folder'"
        exit 1
    fi

    local info_file="$folder/info.xml"
    local module_file="$folder/ModuleConfig.xml"

    local plugins=$(
        for file in $@; do
            cat "$file"
            echo
        done
    )
    cp "$source/fomod/info.xml" "$info_file"
    echo "${MODULE_CONFIG//%PLUGINS%/$plugins}" >"$module_file"
    echo "$folder"
}

function pack_mod() {
    local source=$1
    local archive=$2
    7z a "$archive" "$source/*"
}

function find_prefixed_files() {
    local prefix=
    find "$1" -type f | (
        while IFS= read -r file; do
            prefix="$(basename "$file" | grep -oP '^\d+')"
            [ -n "$prefix" ] && echo "$file"
        done
    )
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

function parse_ini_id() {
    grep -oP '(?<=^; %).+' | awk '{$1=$1};1'
}

function parse_ini_description() {
    head -n 1 | grep -oP '(?<=^; #).+' | awk '{$1=$1};1'
}

function parse_ini_sections() {
    tail -n +2 | grep -oP '(?<=^; #).+' | awk '{$1=$1};1'
}

function concatenate() {
    local separator=$1
    local pipe=$(cat)
    local count=$(echo "$pipe" | wc -l)
    for index in $(seq 1 $count); do
        local item=$(echo "$pipe" | slice $index 1)
        echo -n "$item"
        if ((index < count)); then
            echo -n "$separator"
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
