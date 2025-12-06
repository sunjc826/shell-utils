#!/usr/bin/env bash
function __bu_@SCRIPT_NAME@_main()
{
set -e
local script_name
script_name=$(basename -- "$BASH_SOURCE")
local script_dir
script_dir=$(realpath -- "$(dirname -- "$BASH_SOURCE")")
pushd "$script_dir" &>/dev/null

# shellcheck source=../core/bu_core_base.sh
source "$BU_DIR"/bu_entrypoint.sh

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
        options_finished=true
        shift
        break
        ;;
    --help)
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
if bu_is_autocomplete
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

__bu_@SCRIPT_NAME@_main "$@"
