#/bin/bash
set -Eeuo pipefail

root=$(dirname "${BASH_SOURCE[0]}")

mod_folder="/cygdrive/c/Users/Windree/AppData/Roaming/Vortex/downloads/skyrimse/"
mod_file="Notification Filter*.zip"
mod_ini=NotificationFilter.ini
mod_folder=Data/SKSE/Plugins
mod_config="$mod_folder/$mod_ini"

config_folder="$root/configs"
output_folder="$root/configs"

ini_delimiter=";========================"
temporary_folder="$(mktemp -d)"

function main() {
    local base_config=$(get_base_config)
    local config_files="$(get_ini_files "$config_folder" | sort)"
    local config_count=$(echo "$config_files" | wc -l)
    echo "Config files:"
    echo "$config_files"
    echo
    for length in $(seq 1 $config_count); do
        sequence_generator "" $length $config_count | while IFS= read -r row; do
            local target_folder="$temporary_folder/$(echo "$row" | sed 's/ /-/g')/$mod_folder"
            local target_ini="$target_folder/$mod_ini"
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
            echo "Combine folowing fieles into '$target_ini' Title: $title"
            mkdir -p "$target_folder"
            echo "$base_config" >"$target_ini"
            echo >>"$target_ini"
            echo "$configs"

            # for index in $(); do
            #     local file=$()
            #     local title=$()
            #     titles=$(
            #         (
            #             echo "$title"
            #             echo
            #         ) | concat " + "
            #     )
            #     echo "$title: $file"
            #     cat "$file" >>"$target_ini"
            #     echo >>"$target_ini"
            # done
            echo
            echo
        done
    done
    # find "$temporary_folder/"
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
clear
main
