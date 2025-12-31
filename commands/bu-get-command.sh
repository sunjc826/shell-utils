#!/usr/bin/env bash
function __bu_bu_get_command_main()
{
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

# Note that we do not source bu_entrypoint inside the sourceable script template
# as it is assumed that sourceable scripts are sourced AFTER 
# bu_entrypoint has been sourced by the user.

# shellcheck source=./__bu_entrypoint_decl.sh
source "$BU_NULL"

bu_scope_push_function
bu_scope_add_cleanup bu_popd_silent
bu_run_log_command "$@"

local verb_filter=
local noun_filter=
local namespace_filter=
local type_filter=
local is_allow_empty_verb=false
local is_allow_empty_noun=false
local is_allow_empty_namespace=false
local is_help=false
local error_msg=
local options_finished=false
local autocompletion=()
local shift_by=
while (($#))
do
    bu_parse_multiselect $# "$1"
    case "$1" in
    -v|--verb)
        # Glob pattern to filter by verb
        bu_parse_positional $# --enum "${!BU_COMMAND_VERBS[@]}" enum--
        verb_filter=${!shift_by}
        ;;
    +v|--allow-empty-verb)
        # If a command has no associated verb, it is also included in the results
        is_allow_empty_verb=true
        ;;
    -n|--noun)
        # Glob pattern to filter by noun
        bu_parse_positional $# --enum "${!BU_COMMAND_NOUNS[@]}" enum--
        noun_filter=${!shift_by}
        ;;
    +n|--allow-empty-noun)
        # If a command has no associated noun, it is also included in the results
        is_allow_empty_noun=true
        ;;
    -ns|--namespace)
        # Glob pattern to filter by namespace
        bu_parse_positional $# --enum "${!BU_COMMAND_NAMESPACES[@]}" enum--
        namespace_filter=${!shift_by}
        ;;
    +ns|--allow-empty-namespace)
        # If a command has no associated namespace, it is also included in the results
        is_allow_empty_namespace=true
        ;;
    -t|--type)
        # Type of the command
        bu_parse_positional $# --enum function execute source alias enum--
        bu_validate_positional "${!shift_by}"
        type_filter=${!shift_by}
        ;;
    -h|--help)
        # Print help
        is_help=true
        ;;
    --)
        # Remaining options will be collected
        options_finished=true
        shift
        break
        ;;
    *)
        bu_parse_error_enum "$1"
        break
        ;;
    esac
    if "$is_help"
    then
        break
    fi
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

local command
local command_verb
local command_noun
local command_namespace
local command_type

local filtered_commands=()

for command in "${!BU_COMMANDS[@]}"
do
    if [[ -n "$verb_filter" ]]
    then
        command_verb=${BU_COMMAND_PROPERTIES[$command,verb]}
        if ! { { [[ -z "$command_verb" ]] && "$is_allow_empty_verb" ; } || [[ "$command_verb" == $verb_filter ]] ; }
        then
            continue
        fi
    fi

    if [[ -n "$noun_filter" ]]
    then
        command_noun=${BU_COMMAND_PROPERTIES[$command,noun]}
        if ! { { [[ -z "$command_noun" ]] && "$is_allow_empty_noun" ; } || [[ "$command_noun" == $noun_filter ]] ; }
        then
            continue
        fi
    fi

    if [[ -n "$namespace_filter" ]]
    then
        command_namespace=${BU_COMMAND_PROPERTIES[$command,namespace]}
        if ! { { [[ -z "$command_namespace" ]] && "$is_allow_empty_namespace" ; } || [[ "$command_namespace" == $namespace_filter ]] ; }
        then
            continue
        fi
    fi

    if [[ -n "$type_filter" ]]
    then
        __bu_cli_command_type "$command"
        command_type=$BU_RET
        if [[ "$command_type" != "$type_filter" ]]
        then
            continue
        fi
    fi

    filtered_commands+=("$command")
done

# TODO: Better output
printf "%s\n" "${filtered_commands[@]}"


bu_scope_pop_function
}

__bu_bu_get_command_main "$@"
