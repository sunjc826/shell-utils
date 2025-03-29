source ../../config/static.sh



bu_mkdir()
{
    local missing=()
    local d
    for d
    do
        if ! [[ -e "$d" ]]
        then
            missing+=("$d")
        fi
    done
    if (( ${#missing[@]} == 0 ))
    then
        return
    fi
    mkdir -p "${missing[@]}"
}

# TODO: Customizable TMP
BU_TMP_DIR=/tmp/bu/"$USER"

bu_mkdir "$BU_TMP_DIR"
BU_FIFO="$BU_TMP_DIR"/$$.fifo
BU_FIFO_FD=
# Probably have some kind of cleanup policy
if ! [[ -e "$BU_FIFO" ]]
then
    mkfifo "$BU_FIFO"
    exec {BU_FIFO_FD}<>"$BU_FIFO"
fi
bu_builtin_read()
{
    BU_RV=
    "$@" >&"$BU_FIFO_FD" || return 1
    read -r BU_RV <&"$BU_FIFO_FD"
}

bu_builtin_mapfile()
{
    :
}


# Logging
: BU_LOG_DEPTH=${BU_LOG_DEPTH:-0}
bu_log_depth++()
{
    : "$((BU_LOG_DEPTH++))"
}
bu_log_depth--()
{
    : "$((BU_LOG_DEPTH--))"
}
# This should not be called, because it assumes it is called by a bu_log_[LOG_LVL] function.
__bu_log()
{
    local color=$1
    local BU_RV
    bu_basename "${BASH_SOURCE[BU_LOG_DEPTH+2]}"
    printf "${color}${FUNCNAME[BU_LOG_DEPTH+1]}@${BU_RV}:${BASH_LINENO[BU_LOG_DEPTH+2]}%s${BU_SGR0}\n" >&2
}
bu_log_err()
{
    __bu_log "$BU_RED" "$*"
}
bu_log_warn() { :; }
bu_log_info() { :; }
bu_log_debug() { :; }

if (( BU_LOG_LVL >= BU_LOG_LVL_WARN )); then
bu_log_warn() { __bu_log "$BU_YELLOW" "$*"; }
if (( BU_LOG_LVL >= BU_LOG_LVL_INFO )); then
bu_log_info() { __bu_log "$BU_BLUE" "$*"; }
if (( BU_LOG_LVL >= BU_LOG_LVL_DEBUG )); then
bu_log_debug() { __bu_log "$BU_VIOLET" "$*"; }
fi
fi
fi

