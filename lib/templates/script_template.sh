#!/usr/bin/env bash
function __bu_@BU_SCRIPT_NAME@_main()
{
set -e
# Considering how slow WSL1 is, let's optimize a bit here too
local -r invocation_dir=$PWD
local script_name
local script_dir
case "$BASH_SOURCE" in
*/*)
    script_name=${BASH_SOURCE##*/}
    script_dir=${BASH_SOURCE%/*}
    ;;
*)
    script_name=$BASH_SOURCE
    script_dir=.
    ;;
esac
pushd "$script_dir" &>/dev/null
script_dir=$PWD

# This seems to be the most important optimization for WSL1, autocomplete is way more responsive
if [[ -z "$COMP_CWORD" ]]
then
# shellcheck source=./__bu_entrypoint_decl.sh
source "$BU_DIR"/bu_entrypoint.sh
fi

bu_exit_handler_setup
bu_scope_push_function
bu_scope_add_cleanup bu_popd_silent
bu_run_log_command "$@"

local is_help=false
local error_msg=
local options_finished=false
local autocompletion=()
local shift_by=
while (($#))
do
    bu_parse_multiselect
    case "$1" in
    --)
        # Remaining options will be collected
        options_finished=true
        shift
        break
        ;;
    -h|--help)
        # Print help
        is_help=true
        ;;
    *)
        bu_parse_error_enum "$1"
        break
        ;;
    esac
    if (( $# < shift_by ))
    then
        bu_parse_error_argn "$1" $#
        break
    fi
    shift "$shift_by"
done
local remaining_options=("$@")
if bu_env_is_in_autocomplete
then
    bu_autocomplete
    return 0
fi

if "$is_help"
then
    bu_autohelp
    return 0
fi

bu_scope_pop_function
}

__bu_@BU_SCRIPT_NAME@_main "$@"
