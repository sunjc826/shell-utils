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
BU_TMP_VAR_DIR=$BU_TMP_DIR/var
bu_mkdir "$BU_TMP_VAR_DIR"
BU_FIFO="$BU_TMP_VAR_DIR"/$$.fifo
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

# Dynamic stack

bu_push()
{
    BU_STACK+=("${#BU_STACK[@]}")
}
bu_push_fn()
{
    BU_STACK+=("-${#BU_STACK[@]}")
}
bu_defer()
{
    if (( "${#BU_STACK[@]}" == 0 ))
    then
        bu_log_depth++
        bu_log_err "Dynamic stack is empty"
        bu_log_depth--
        return 1
    fi

    local -n deferred=bu_deferred_${BU_STACK[-1]}
    bu_builtin_read printf "%q " "$@"
    deferred+=("$BU_RV")
}

bu_pop()
{
    bu_log_depth++
    if (( "${#BU_STACK[@]}" == 0 ))
    then
        bu_log_err "Dynamic stack is empty"
        bu_log_depth--
        return 1
    fi

    local -n deferred=bu_deferred_${BU_STACK[-1]}
    local i
    local ret=0
    for (( i=${#deferred}-1; i >= 0; i-- ))
    do
        bu_log_debug "Cleaning up ${BU_STACK[-1]}: ${deferred[$i]}"
        if ! "${deferred[$i]}"
        then
            bu_log_err "Cleanup failed: ${deferred[$i]}"
            ret=1
        fi
    done
    bu_log_depth--
    unset -v "bu_deferred_${BU_STACK[-1]}" 'BU_STACK[-1]'
    return "$ret"
}

bu_pop_fn()
{
    bu_log_depth++
    if (( "${#BU_STACK[@]}" == 0 ))
    then
        bu_log_err "Dynamic stack is empty"
        bu_log_depth--
        return 1
    fi

    local i
    for (( i=${#BU_STACK[@]}-1; i >= 0; i-- ))
    do
        if (( "${BU_STACK[-1]}" < 0 ))
        then
            break
        fi
    done

    if (( i < 0 ))
    then
        log_err "No function-level scope found"
        bu_log_depth--
        return 1
    fi
    local j
    local target=$i
    local ret=0
    for (( i=${#BU_STACK[@]}-1; i >= "$target"; i-- ))
    do
        local -n deferred="bu_deferred_${BU_STACK[$i]}"
        for (( j=${#deferred}-1; j >= 0; j-- ))
        do
            bu_log_debug "Cleaning up ${BU_STACK[-1]}: ${deferred[-1]}"
            if ! "${deferred[$j]}"
            then
                bu_log_err "Cleanup failed: ${deferred[-1]}"
                ret=1
            fi
        done
        unset -v "bu_deferred_${BU_STACK[$i]}" "BU_STACK[$i]"
    done
    bu_log_depth--
    return "$ret"
}
