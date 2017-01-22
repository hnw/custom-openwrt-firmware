#!/bin/bash

# パスの存在チェック関数。引数をワイルドカードで渡せる。
#
# if path_exists /foo/bar-*; then
#   some action
# else
#   some other action
# fi
#
function path_exists() {
    local file
    for file in "$@"; do
        if [[ ! -e ${file} ]]; then
            return 1
        fi
    done
    return 0
}

# 色つき表示関数

function _bold()   { echo -e $(tput bold); }
function _reset()  { echo -e $(tput sgr0); }
function _red()    { echo -e $(tput setaf 1); }
function _green()  { echo -e $(tput setaf 2); }
function _yellow() { echo -e $(tput setaf 3); }

function _message() {
    local reset=$(_reset)
    if   [[ $1 = "emergency" ]]; then local color="$(_bold)$(_red)"
    elif [[ $1 = "success"   ]]; then local color="$(_green)"
    elif [[ $1 = "error"     ]]; then local color="$(_red)"
    elif [[ $1 = "header"    ]]; then local color="$(_bold)$(_yellow)"
    fi
    # Don't use colors on pipes or non-recognized terminals
    if [[ ${COLOR} = "never" || (${COLOR} != "always" && ! (-t 1)) || ! (${TERM} =~ ^xterm) ]]; then
        color=""
        reset=""
    fi

    echo -e "${color}${2}${reset}";
}

function die ()       { _message emergency "${*} Exiting."; exit 1; }
function success ()   { _message success   "✔ ${*}"; }
function error ()     { _message error     "✖ ${*}"; }
function header()     { _message header    "========== ${*} ==========  "; }

# タイムスタンプやパーミッションを維持する再帰コピー
# rsyncとかcp -aが動かない環境があるかもしれないので用心のため
function copy_all_files() {
    local src=$1
    local dst=$2
    [[ ! -d ${src} ]] && die "ERROR: directory not found: ${src}"
    [[ ! -d ${dst} ]] && die "ERROR: directory not found: ${dst}"
    tar -C ${src} -cf - . | tar -C ${dst} -xf -
}

# 簡単な時間測定
# bash 3でも動くようにするため、配列を連想配列的に利用している
#
# set_timer
# sleep 65
# echo "Elasped time: $(time_elasped)" # Elasped time: 1 min 5 sec
declare -a _util_timer_marker
function humanized_time() {
    local hour=$(( $1/3600 ))
    local min=$(( ($1%3600)/60 ))
    local sec=$(( $1%60 ))
    local ret="${sec} sec"

    if [[ ${hour} != 0 ]]; then
        ret="${hour} hour ${min} min ${ret}"
    elif [[ ${min} != 0 ]]; then
        ret="${min} min ${ret}"
    fi
    echo ${ret}
}
function set_timer() {
    local marker=$1
    _util_timer_marker=("${marker}:$SECONDS" "${_util_timer_marker[@]}")
}
function time_elasped() {
    local marker=$1
    for keyval in "${_util_timer_marker[@]}"; do
        local key=${keyval%%:*}
        local val=${keyval#*:}
        if [[ ${key} = ${marker} ]]; then
            echo $(humanized_time $(($SECONDS-${val})))
            return 0
        fi
    done
    echo "-"
    return 0
}
