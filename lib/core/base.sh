# Use BU_xxx as project namespace, where BU stands for Bash Utils
# Use RV as standard return type
# Optimized implementations
bu_dirname()
{
    case "$1" in
    */*) RV=${1%/*};;
    *) RV=.;;
    esac
}

bu_basename()
{
    case "$1" in
    */*) RV=${1##*/};;
    *) RV=$1;;
    esac
}

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
    RV=
    "$@" >&"$BU_FIFO_FD" || return 1
    read -r RV <&"$BU_FIFO_FD"
}

bu_builtin_mapfile()
{
    :
}

LOG_DEPTH=0

# Logging
log_err()
{
    : $((LOG_DEPTH++))
    basename_o "${BASH_SOURCE[i]}"
}