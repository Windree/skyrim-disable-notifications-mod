#/bin/bash
set -Eeuo pipefail

root=$(dirname "${BASH_SOURCE[0]}")
mod_folder="/cygdrive/c/Users/Windree/AppData/Roaming/Vortex/downloads/skyrimse/"
mod_file="Notification Filter*.zip"
mod_config="Data/SKSE/Plugins/NotificationFilter.ini"
output_folder="$root/configs"
output_file_mask="*.ini"
ini_delimiter=";========================"
log_file="$(mktemp)"
max=5
clear

function main() {
    local base_config=$(get_base_config)
    echo "Cleaning up.."

    find "$output_folder" -maxdepth 1 -type f -name "$output_file_mask" -delete

    local ini_files="$(get_ini_files | sort)"

    echo -n "$ini_files" | xargs -I% basename "%"
    local count=$(echo "$ini_files" | wc -l)
    generate_sequence "" $count $count
    # generate_unique $count
    # echo "$ini_files" | mix_lines

    # for file in $ini_files; do
    #     local name=$(cat "$file" | parse_ini_description)
    #     local config_file=$(basename "$file")
    #     echo "$ini_files" | mix "$file"
    #     # local output_file="$output_folder/$config_file"
    #     # echo "Creating $config_file ($name).."
    #     # (
    #     #     echo
    #     #     echo
    #     #     echo "$base_config"
    #     #     echo "$ini_delimiter"
    #     #     cat "$file"
    #     #     echo "$ini_delimiter"
    #     # ) >"$output_file"
    # done
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

# # prints all possible combinations of lines
# function unique_sets() {
#     local lines="$(cat)"
#     if [ -z "$lines" ]; then
#         return
#     fi
#     local p=$(deep 4)
#     local length=$(echo "$lines" | wc -l)
#     local lines_count=${1:-$lines_count}
#     echo "unique_sets(length:$length); PIPE: $lines" | log $p

#     for length in $(seq $lines_count -1 1); do
#         local offset=$((lines_count - length))
#         echo "LENGTH=$length" | log $offset
#         local lines=$(echo "$lines" | slice $((offset)) $lines_count)
#         echo "v-GROUP-v" | log $offset
#         echo "$lines" | log $offset
#         echo "^-GROUP-^" | log $offset
#     done
#     exit
# }

function generate_sorted_unique() {
    local max_length=$1
    (
        for length in $(seq 1 $max_length); do
            echo "Length: $length" | log
            local number=$(
                for i in $(seq 0 $max_length); do
                    echo -n "$i"
                done
            )
            echo "$set($length) $(set | sort -n)" | log 2
        done
    ) | sort -n | xargs
}

function generate_sequence() {
    local length=$1
    local count=$2
    append_number "" $length $count
}

function append_number() {
    echo -e "========== $(deep 2)\n\n\n" >&2
    local prefix=$1
    local remaining=$2
    local count=$3
    echo >&2 "append_number($prefix, $remaining, count)"
    declare -i number=0
    echo >&2 "(($number <= $count))"
    while ((number < count)); do
        ((number = number + 1))
        echo >&2 "number $number"
        local string=
        if [ -n "$prefix" ]; then
            string="$prefix $number"
        else
            string=$number
        fi
        if (($remaining > 0)); then
            append_number "$string" $((remaining - 1)) $count
        else
            echo "$string"
        fi
    done
}

function append() {
    local prefix=$1
    local number=$2
    if [ ! -z "$prefix" ]; then
        echo -n "$prefix "
    fi
    echo -n $number
}

# prints starting $1 line [limit to $2 lines]
function slice() {
    if [ -v 2 ]; then
        tail -n "+$1" | head -n "$2"
    else
        tail -n "+$1"
    fi
}

function log() {
    local prefix_length=0
    local is_pipe=false
    while [ $# -gt 0 ]; do
        if [[ "$1" == "pipe" ]]; then
            is_pipe=true
            shift
            continue
        elif [ "$1" -eq "$1" ]; then
            prefix_length=$1
            shift
        else
            echo >&2 "log: Incorrect parameter '$1'"
            exit 1
        fi
    done

    local prefix=$(
        for i in $(seq 1 $prefix_length); do
            echo -n "="
        done
    )
    local content=$(cat)
    local line=$(echo "$content" | xargs)
    local log=$(
        echo -ne '\u33D2 '
        echo "$prefix$line" | xargs
    )
    echo "$log"
    echo "$prefix$line" >>"$log_file"

    if ! $is_pipe; then
        return
    fi
    echo "$content"
}

function void() {
    cat >/dev/null
}

function deep {
    set +x
    local i=1
    local omit=${1:-0}
    while read -r line func file < <(caller $i); do
        ((i++))
    done
    echo $(($i - $omit))
}

function cleanup() {
    echo >&2 '--EXIT--'
    echo '__LOG__' >&2
    cat "$log_file" 1>&2
    rm -f "$log_file"
}
clear
# generate_sequence 5 5 2>"$root/debug.txt"| tee "$root/log.txt"
exit

trap cleanup exit

main
