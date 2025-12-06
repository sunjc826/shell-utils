#!/usr/bin/env bash
function __bu_make_script_main()
{
# set -e
local script_name
script_name=$(basename -- "$BASH_SOURCE")
local script_dir
script_dir=$(realpath -- "$(dirname -- "$BASH_SOURCE")")
pushd "$script_dir" &>/dev/null
source ../../bu_entrypoint.sh
# bu_exit_handler_setup
bu_scope_push_function
bu_scope_add_cleanup bu_popd_silent
bu_run_log_command "$@"

local dir=
local name=
local is_force=false
local is_source_only=false
local is_help=false
local error_msg=
local options_finished=false
local autocompletion=()
local shift_by=
while (($#))
do
    bu_parse_multiselect
    case "$1" in
    --dir)
        bu_parse_positional $# --enum "${BU_COMMAND_SEARCH_DIRS[@]}" enum--
        dir=${!shift_by}
        ;;
    --name)
        bu_parse_positional $#
        name=${!shift_by}
        ;;
    --force)
        is_force=true
        ;;
    --source)
        is_source_only=true
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
        bu_parse_error_argn "$1"
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

name=${name%.sh}

if [[ -z "$name" ]]
then
    bu_assert_err '--name not provided'
fi

local target=
local template=
target=$dir/$name.sh
template=$BU_LIB_TEMPLATE_DIR/script_template.sh

mkdir -p "$(dirname -- "$target")"

if [[ -e "$target" ]]
then
    if ! "$is_force"
    then
        bu_assert_err "$target already exists"
    else
        rm -vf "$target"
    fi
fi

if ! "$is_source_only"
then
    chmod +x "$target"
fi

(
    SCRIPT_NAME=$name
    bu_gen_substitute SCRIPT_NAME <"$template" >"$target"
)

bu_edit_file "$target" || true

bu_scope_pop_function
}

__bu_make_script_main "$@"
