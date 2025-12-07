#!/usr/bin/env bash
function __bu_bu_reload_main()
{
# shellcheck source=./__bu_entrypoint_decl.sh
source "$BU_NULL"

bu_scope_push_function
bu_run_log_command "$@"

local is_git_pull=false
local is_force=false
local is_help=false
local error_msg=
local options_finished=false
local autocompletion=()
local shift_by=
while (($#))
do
    bu_parse_multiselect
    case "$1" in
    -p|--pull)
        is_git_pull=true
        ;;
    -f|--force)
        is_force=true
        ;;
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

if "$is_git_pull"
then
    git -C "$BU_DIR" pull
fi

local opt_force=()
if "$is_force"
then
    opt_force=(--__bu-force)
fi
source "$BU_DIR"/bu_entrypoint.sh "${opt_force[@]}"

bu_scope_pop_function
}

__bu_bu_reload_main "$@"
