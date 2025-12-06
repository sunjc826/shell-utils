# This file does not depend on any other file in shell-utils, because we need to 
# define a custom source func ahead of other functions
# e.g. to ensure the correctness of --__bu-once

# ```
# The bu repo base directory
# ```
export BU_DIR=$PWD
# ```
# The directory where non user defined executables are placed
# ```
BU_LIB_BIN_DIR=$BU_DIR/lib/bin
# ```
# The directory where non user defined sourceable shell scripts are placed
# ```
BU_LIB_BINSRC_DIR=$BU_DIR/lib/binsrc
# ```
# The directory of the core library
# ```
BU_LIB_CORE_DIR=$BU_DIR/lib/core

BU_LIB_TEMPLATE_DIR=$BU_DIR/lib/templates

BU_BUILTIN_COMMANDS_DIR=$BU_DIR/lib/subcommands


# ```
# Traditionally, bash has 3 states for a scalar variable
# 1. Undefined: `[[ ! -v VAR ]]` will be true
# 2. Empty: `[[ -v VAR && -z "$VAR" ]]` will be true
# 3. Non-empty: `[[ -n "$VAR" ]]` will be true
#
# However, state 1 isn't that useful if we want to "forward declare" a variable an initialize it to empty
# effectively, we only have states 2 and 3. Thus when we need 3 states (or if empty is considered to be a valid input),
# then we will use the following instead:
# 1. NULL: `bu_is_null "$VAR"` will be true
# 2. Empty: Same as above
# 3. Non-empty: Same as above
# ```
BU_NULL=BU_NULL

# ```
# *Description*:
# Check if a variable is BU_NULL
#
# *Params*:
# - `$1`: variable to check
#
# *Returns*:
# - Returns 0 (true) if the variable is BU_NULL, else returns 1 (false)
# *Examples*:
# ```bash
# bu_is_null "$VAR"
# ```
# ```
bu_is_null()
{
    [[ "$1" = BU_NULL ]]
}

# ```
# *Description*:
# Check if a variable is BU_NULL or empty
#
# *Params*:
# - `$1`: variable to check
#
# *Returns*:
# - Returns 0 (true) if the variable is BU_NULL or empty, else returns 1 (false)
# *Examples*:
# ```bash
# bu_is_null_or_empty "$VAR"
# ```
# ```
bu_is_null_or_empty()
{
    [[ -z "$1" || "$1" = BU_NULL ]]
}

# ```
# *Description*:
# Check if a variable is not BU_NULL
#
# *Params*:
# - `$1`: variable to check
#
# *Returns*:
# - Returns 0 (true) if the variable is not BU_NULL, else returns 1 (false)
# *Examples*:
# ```bash
# bu_is_not_null "$VAR"
# ```
# ```
bu_is_not_null()
{
    [[ "$1" != BU_NULL ]]
}

# ```
# *Description*:
# Check if a variable is not BU_NULL and not empty
#
# *Params*:
# - `$1`: variable to check
#
# *Returns*:
# - Returns 0 (true) if the variable is not BU_NULL and not empty, else returns 1 (false)
# *Examples*:
# ```bash
# bu_is_not_null_or_empty "$VAR"
# ```
# ```
bu_is_not_null_or_empty()
{
    [[ -n "$1" && "$1" != BU_NULL ]]
}

# ```
# *Description*:
# Get directory name of a filepath. Similar to `dirname` except that no process is spawned.
#
# *Params*:
# - `$1`: a filepath
#
# *Returns*:
# - `$BU_RET`: directory name of the filepath
#
# *Examples*:
# ```bash
# bu_dirname /a/b/c.txt # $BU_RET=/a/b
# ```
# ```
bu_dirname()
{
    case "$1" in
    */*) BU_RET=${1%/*};;
    *) BU_RET=.;;
    esac
}

# ```
# *Description*:
# Get base name of a filepath. Similar to `basename` except that no process is spawned.
#
# *Params*:
# - `$1`: a filepath
#
# *Returns*:
# - `$BU_RET`: base name of the filepath
#
# *Examples*:
# ```bash
# bu_basename /a/b/c.txt # $BU_RET=c.txt
# ```
# ```
bu_basename()
{
    case "$1" in
    */*) BU_RET=${1##*/};;
    *) BU_RET=$1;;
    esac
}

if ((!${#BU_SOURCE_ONCE_CACHE[@]}))
then
    declare -A -g BU_SOURCE_ONCE_CACHE=(
        [BU_NULL]=true
    )
fi

BU_SOURCE_IS_CUSTOM=false

bu_def_source()
{
    # Redefine source for the duration of the function
    BU_SOURCE_IS_CUSTOM=true
    source()
    {
        local source_filepath=$1
        shift

        case "$source_filepath" in
        BU_NULL) return 0;;
        esac

        local is_once=false
        local is_pushd=true
        local shift_by
        while (($#))
        do
            shift_by=1
            case "$1" in
            --__bu-once)
                # Source the file only if it hasn't been sourced before
                is_once=true
                ;;
            --__bu-no-pushd)
                # Don't automatically pushd into the directory
                is_pushd=false
                ;;
            --__bu-*)
                echo "Unrecognized source option $1" &>/dev/null
                return 1
                ;;
            *)
                break
                ;;
            esac
            shift "$shift_by"
        done
        # We assume all bu entrypoints to be uniquely named
        # shellcheck disable=SC2317
        bu_basename "$source_filepath"
        local basename=$BU_RET
        # shellcheck disable=SC2317
        if "$is_once" && "${BU_SOURCE_ONCE_CACHE[$basename]:-false}"
        then
            echo "$basename has already been sourced, skipping." >&2
            return 0
        fi

        if "$is_once"
        then
            echo "sourcing(--__bu-once) $source_filepath" >&2
        fi

        # shellcheck disable=SC2317
        BU_SOURCE_ONCE_CACHE[$basename]=true

        # TODO pushd handling

        # Our source implementations allow functions too
        # Functions are in fact more similar to sourcing scripts than invoking a script in a new shell
        case "$(type -t "$source_filepath" 2>/dev/null)" in
        function)
            "$source_filepath" "$@"
            ;;
        *)
            # shellcheck disable=SC2317
            builtin source "$source_filepath" "$@"
            ;;
        esac
    }
}

bu_undef_source()
{
    unset -f source
    BU_SOURCE_IS_CUSTOM=false
}

bu_source()
{
    if "${BU_SOURCE_IS_CUSTOM}"
    then
        source "$@"
    else
        bu_def_source
        source "$@"
        bu_undef_source
    fi
}

bu_ext_source()
{
    if "${BU_SOURCE_IS_CUSTOM}"
    then
        bu_undef_source
        source "$@"
        bu_def_source
    else
        source "$@"
    fi
}

bu_source_multi_once()
{
    local filepath
    for filepath
    do
        source "$filepath" --__bu-once
    done
}
bu_source_multi()
{
    local filepath
    for filepath
    do
        source "$filepath"
    done
}

bu_def_source
