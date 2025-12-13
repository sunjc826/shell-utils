# Instead of implementing bu directly in a function, we place it in this script
# so that BASH_LINENO is relative to the file rather than relative to the start of the function

# shellcheck source=../core/bu_core_autocomplete.sh
source "$BU_NULL"
__bu_impl_process_alias()
{
    local -r bu_alias_spec=($1)
    shift

    local -r bu_command=${bu_alias_spec[0]}
    local -r function_or_script_path=${BU_COMMANDS[$bu_command]}

    local exit_code=0

    local resolved_options=()

    local i=0
    local arg
    for arg in "${bu_alias_spec[@]:1}"
    do
        case "$arg" in
        '{?}')
            if ((!$#))
            then
                break
            fi
            ;;
        '{}')
            resolved_options+=("$1")
            if ((!$#))
            then
                bu_log_err "Insufficient arguments provided to satisfy ${BU_TPUT_BOLD}${BU_CLI_COMMAND_NAME} ${bu_alias_spec[*]:0:i+1} ${BU_TPUT_UNDERLINE}{REQUIRED}${BU_TPUT_NO_UNDERLINE} ${bu_alias_spec[*]:i+2}${BU_TPUT_RESET}"
                return 1
            fi
            shift
            ;;
        '{...}')
            resolved_options+=("$@")
            shift $#
            ;;
        *)
            resolved_options+=("$arg")
            ;;
        esac
        : "$((i++))"
    done

    
    __bu_cli_command_type "$bu_command"
    local -r type=$BU_RET
    BU_RET=()
    case "$type" in
    execute)
        BU_RET=("$function_or_script_path" "${resolved_options[@]}")
        ;;
    source)
        BU_RET=(builtin source "$function_or_script_path" "${resolved_options[@]}")
        ;;
    function)
        BU_RET=("$function_or_script_path" "${resolved_options[@]}")
        ;;
    alias)
        __bu_impl_process_alias "$function_or_script_path" "${resolved_options[@]}"
        ;;
    *)
        bu_log_err "Invalid aliased command[$bu_command] properties[$type]"
        return 1
        ;;
    esac
    return 0
}

__bu_impl()
{
    if ((!$#))
    then
        bu_log_warn "No arguments specified, printing help"
        __bu_cli_help
        return
    fi
    # We expect the following values of BASH_SOURCE and FUNCNAME if bu was invoked directly on the command line:
    # .../lib/binsrc/bu_impl.sh .../lib/binsrc/bu_impl.sh ./lib/core/bu_core_cli.sh
    # __bu_impl                 source                    bu
    # Thus the depth of BASH_SOURCE would be 3 if the command is invoked directly
    # We will only write direct invocations to $BU_HISTORY to avoid spam. 
    if (( ${#BASH_SOURCE[@]} <= 3 ))
    then
        {
            printf "%q " "$BU_CLI_COMMAND_NAME" "$@"
            echo
        } >> "$BU_HISTORY"
        mapfile -t BU_RET <"$BU_HISTORY"
        if (( "${#BU_RET[@]}" > 1000 ))
        then
            bu_sync_cycle_file "$BU_HISTORY" false 500 true
        fi
    fi

    local -r bu_command=$1
    shift
    local -r remaining_options=("$@")
    local -r function_or_script_path=${BU_COMMANDS[$bu_command]}
    __bu_cli_command_type "$bu_command"
    local -r type=$BU_RET
    local exit_code=0
    case "$type" in
    execute)
        "$function_or_script_path" "${remaining_options[@]}"
        exit_code=$?
        ;;
    source)
        builtin source "$function_or_script_path" "${remaining_options[@]}"
        exit_code=$?
        ;;
    function)
        "$function_or_script_path" "${remaining_options[@]}"
        exit_code=$?
        ;;
    alias)
        if ! __bu_impl_process_alias "$function_or_script_path" "$@"
        then
            bu_log_err "Processing of alias[$bu_command] failed"
            return 1
        fi
        "${BU_RET[@]}"
        exit_code=$?
        ;;
    *)
        bu_log_err "Invalid command[$bu_command] properties[$type]"
        __bu_cli_help
        return 1
        ;;
    esac

    return "$exit_code"
}

__bu_impl "$@"
