# Instead of implementing bu directly in a function, we place it in this script
# so that BASH_LINENO is relative to the file rather than relative to the start of the function

# shellcheck source=../core/bu_core_autocomplete.sh
source "$BU_NULL"
__bu_impl()
{
    if ((!$#))
    then
        bu_log_warn "No arguments specified, printing help"
        __bu_cli_help
        return
    fi

    if (( ${#BASH_SOURCE[@]} == 1 ))
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

    local bu_command=$1
    shift
    local remaining_options=("$@")
    local function_or_script_path=${BU_COMMANDS[$bu_command]}
    __bu_cli_command_properties "$bu_command"
    local properties=$BU_RET
    local exit_code=0
    case "$properties" in
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
    *)
        bu_log_err "Invalid command[$bu_command] properties[$properties]"
        __bu_cli_help
        return 1
        ;;
    esac

    return "$exit_code"
}

__bu_impl "$@"
