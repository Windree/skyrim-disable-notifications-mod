#!/bin/bash

set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/fomod/info.sh"
source "$(dirname "${BASH_SOURCE[0]}")/fomod/ModuleConfig.sh"
source "$(dirname "${BASH_SOURCE[0]}")/nexus/mod.sh"

root=$(dirname "${BASH_SOURCE[0]}")
temp="$(mktemp -d)"

mods_folder="/cygdrive/c/Users/Windree/AppData/Roaming/Vortex/downloads/skyrimse/"
mod_file="Notification Filter*.zip"
mod_ini=NotificationFilter.ini
mod_folder=Data/SKSE/Plugins

config_folder="$root/configs"

fomod_recommended="Recommended"
fomod_optional="Optional"

extra_configs=("$root/configs/Everything.ini")

version="1.0.1"
target_file="$root/target/Disable-Notifications.7z"

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
    readarray -t configs < <(find_prefixed_files "$config_folder" | sort)
    local configs_count=${#configs[@]}
    local plugins=()
    echo "Config files($configs_count):"
    echo "${configs[@]}"
    echo

    echo "Creating extra configurations:"
    for file in "${extra_configs[@]}"; do
        echo "File: $file"
        local plugin=$(create_config "$temp" "$file")
        plugins+=("$plugin")
        echo "An extra plugin saved to '$plugin'"
    done

    echo "Creating mixed configurations:"
    for length in $(seq 1 $configs_count); do
        while IFS= read -r row; do
            local indexes=($row)
            local files=()
            echo "Combine following files onto a plugin:"
            for index in "${indexes[@]}"; do
                echo "index: $index"
                local file=${configs[((index - 1))]}
                echo "File: $file"
                files+=("$file")
            done
            local plugin=$(create_config "$temp" "${files[@]}")
            plugins+=("$plugin")
            echo "A plugin saved to '$plugin'"
        done < <(sequence_generator "" $length $configs_count)
    done

    echo "Creating fomod config.."
    local fomod=$(create_fomod_config "$root" "$temp" "${plugins[@]}")
    echo "Fomod config saved to $fomod"
    for plugin in "${plugins[@]}"; do
        rm -f "$plugin"
    done

    local all_files=("${extra_configs[@]}" "${configs[@]}")

    echo "Creating bbcode.."
    create_bbcode "${all_files[@]}" >"$root/target/description.bbcode"
    echo "Pack files into plugin.."
    pack_mod "$temp" "$target_file"

    if $debug; then
        rsync -av --delete "$temp/" "$root/tmp"
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
            cat "$file" | parse_ini_title
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
    local bbcode="$folder/plugin.bbcode"
    if ! mkdir "$folder"; then
        echo >&2 "Unable to create '$folder'"
    fi
    echo "$base_config" >"$ini"
    echo >>"$ini"
    for file in $@; do
        cat "$file" >>"$ini"
        echo >>"$ini"
    done
    local plugin=$MODULE_PLUGIN
    plugin="${plugin//%NAME%/$name}"
    plugin="${plugin//%TITLE%/$title}"
    plugin="${plugin//%TYPE%/$fomod_optional}"
    plugin="${plugin//%DESCRIPTION%/$description}"
    echo "$plugin" >"$xml"
    echo $xml
}

function create_bbcode() {
    local profiles=()
    local new_line=$'\n'

    for file in $@; do
        local profile=$MOD_PROFILE
        local title=$(cat "$file" | parse_ini_title)
        readarray -t sections < <(cat "$file" | parse_ini_sections)
        local items=()
        for section in "${sections[@]}"; do
            items+=("${MOD_SECTION//%SECTION%/$section}")
        done
        profile="${profile//%PROFILE%/$title}"
        profile="${profile//%SECTIONS%/$(concatenate $'\n' "${items[@]}")}"
        profiles+=("$profile")
    done
    local description=$MOD_DESCRIPTION
    description="${description//%PROFILES%/$(concatenate $'\n' "${profiles[@]}")}"
    description="${description//%INI%/$mod_ini}"
    echo "$description"
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

    echo "${INFO//%VERSION%/$version}" >"$info_file"
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

function parse_ini_title() {
    head -n 1 | grep -oP '(?<=^; #).+' | awk '{$1=$1};1'
}

function parse_ini_sections() {
    tail -n +2 | grep -oP '(?<=^; #).+' | awk '{$1=$1};1'
}

function concatenate() {
    local separator=$1
    shift
    local array=()
    if [ ! -t 0 ]; then
        readarray -t array < <(cat)
    else
        array=("$@")
    fi
    local length=${#array[@]}
    for ((i = 0; i < ${length}; i++)); do
        echo -n "${array[$i]}"
        if ((i < length - 1)); then
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
    echo "Cleaning up temporary folders/files ($(rm -rfv "$temp" | wc -l))"
}

trap cleanup exit

main "$@"
