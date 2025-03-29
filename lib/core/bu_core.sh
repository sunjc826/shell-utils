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
        if [[ -n "${BU_SOURCE_ONCE_CACHE[$BU_CURRENT_SCRIPT_KEY]}" ]]
        then
            return 0
        fi

        BU_SOURCE_ONCE_CACHE[$BU_CURRENT_SCRIPT_KEY]=1
        builtin source "$@"
    }
}

bu_undef_source()
{
    unset -f source
}
