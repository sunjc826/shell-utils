# Use BU_xxx as project namespace, where BU stands for Bash Utils
# Use BU_RV as standard return name
# Optimized implementations
bu_dirname()
{
    case "$1" in
    */*) BU_RV=${1%/*};;
    *) BU_RV=.;;
    esac
}

bu_basename()
{
    case "$1" in
    */*) BU_RV=${1##*/};;
    *) BU_RV=$1;;
    esac
}

bu_basename "${BASH_SOURCE[0]}"

declare -A -g BU_SOURCE_ONCE_CACHE=()

bu_def_source()
{
    # Redefine source for the duration of the function
    source()
    {
        # We assume all bu entrypoints to be uniquely named
        # shellcheck disable=SC2317
        bu_basename "$1"
        # shellcheck disable=SC2317
        if [[ -n "${BU_SOURCE_ONCE_CACHE[$BU_RV]}" ]]
        then
            return 0
        fi
        # shellcheck disable=SC2317
        BU_SOURCE_ONCE_CACHE[$BU_RV]=1
        # shellcheck disable=SC2317
        builtin source "$@"
    }
}

bu_undef_source()
{
    unset -f source
}
