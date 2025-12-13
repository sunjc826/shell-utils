# shellcheck source=./bu_core_autocomplete.sh
source "$BU_NULL"

# MARK: Top-level CLI

# ```
# The master command name. Default is `bu`, but users can override it by defining `BU_USER_DEFINED_CLI_COMMAND_NAME`.
# ```
BU_CLI_COMMAND_NAME=${BU_USER_DEFINED_CLI_COMMAND_NAME:-bu}

__bu_cli_sort_keys()
{
    tr ' ' '\n' | sort
}

# ```
# *Description*:
# Gets the properties of a bu sub-command
#
# *Params*
# - `$1`: bu sub-command
#
# *Returns*
# - `$BU_RET`: Properties of the command. One of `function`, `source`, `execute`, or `no-default-found`.
# ```
__bu_cli_command_type()
{
    local bu_command=$1
    local function_or_script_path=${BU_COMMANDS[$bu_command]}
    if [[ -z "$function_or_script_path" ]]
    then
        # Also accept non bu command
        function_or_script_path=$bu_command
    fi
    local properties="${BU_COMMAND_PROPERTIES[$bu_command,type]}"
    if [[ -z "$properties" ]]
    then
        if bu_symbol_is_function "$function_or_script_path"
        then
            properties=function
        elif [[ -x "$function_or_script_path" ]]
        then
            properties=execute
        elif [[ -f "$function_or_script_path" ]]
        then
            properties=source
        else
            properties=no-default-found
        fi
    fi
    BU_RET=$properties
}

# ```
# *Description*:
# Displays help information for the master command
#
# *Params*: None
#
# *Returns*: None
# ```
__bu_cli_help()
{
    echo "${BU_TPUT_BOLD}${BU_TPUT_DARK_BLUE}Help for ${BU_CLI_COMMAND_NAME}${BU_TPUT_RESET}"
    echo "${BU_CLI_COMMAND_NAME} is the Bash CLI implemented by shell-utils"

    local key
    local value

    local -A executable_scripts=()
    local -A source_scripts=()
    local -A functions=()
    local -A aliases=()
    for key in "${!BU_COMMANDS[@]}"
    do
        value=${BU_COMMANDS[$key]}
        __bu_cli_command_type "$key"
        properties=$BU_RET
        case "$properties" in
        execute)
            executable_scripts[$key]=$value
            ;;
        source)
            source_scripts[$key]=$value
            ;;
        function)
            functions[$key]=$value
            ;;
        alias)
            aliases[$key]=$value
            ;;
        *)
            bu_log_warn "Unrecognized properties[$properties] for command[$key]"
            ;;
        esac
    done


    echo
    echo "The following commands using a ${BU_TPUT_UNDERLINE}new${BU_TPUT_RESET} shell context are available"
    echo

    for key in $(__bu_cli_sort_keys <<<"${!executable_scripts[*]}")
    do
        value=${executable_scripts[$key]}
        printf "    ${BU_TPUT_BOLD}%-30s${BU_TPUT_RESET}    %s\n" "$key" "$value"
    done

    echo
    echo "The following commands using the ${BU_TPUT_UNDERLINE}current${BU_TPUT_RESET} shell context are available"
    echo
    
    local opt_err=
    for key in $(__bu_cli_sort_keys <<<"${!source_scripts[*]}")
    do
        value=${source_scripts[$key]}
        if grep -q 'set -e' "$value"
        then
            opt_err="${BU_TPUT_YELLOW}WARNING: set -e found${BU_TPUT_RESET}"
        else
            opt_err=
        fi
        printf "    ${BU_TPUT_BOLD}%-30s${BU_TPUT_RESET}    %s %s\n" "$key" "$value" "$opt_err"
    done

    echo
    echo "The following functions are available"
    echo

    for key in $(__bu_cli_sort_keys <<<"${!functions[*]}")
    do
        value=${functions[$key]}
        printf "    ${BU_TPUT_BOLD}%-30s${BU_TPUT_RESET}    %s\n" "$key" "$value"
    done

    echo
    echo "The following aliases are available"
    echo

    for key in $(__bu_cli_sort_keys <<<"${!aliases[*]}")
    do
        value=${aliases[$key]}
        printf "    ${BU_TPUT_BOLD}%-30s${BU_TPUT_RESET}    %s\n" "$key" "$value"
    done

    echo
    echo "The following ${BU_TPUT_UNDERLINE}key bindings${BU_TPUT_NO_UNDERLINE} are available"
    echo

    for key in $(__bu_cli_sort_keys <<<"${!BU_KEY_BINDINGS[*]}")
    do
        value=${BU_KEY_BINDINGS[$key]}
        printf "    %s -> %s\n" "$key" "$value"
    done
} >&2

bu_autohelp()
{
    set +e
    local header=
    local example_purposes=()
    local example_command_lines=()
    local shift_by
    while (($#))
    do
        shift_by=1
        case "$1" in
        --description)
            header=$2
            shift_by=2
            ;;
        --example)
            local purpose=$2
            local command_line=$3
            example_purposes+=("$purpose")
            example_command_lines+=("$command_line")
            shift_by=3
            ;;
        *)
            bu_log_unrecognized_option "$1"
            ;;
        esac
        if (( $# < shift_by ))
        then
            bu_log_err "Expected $((shift_by-1)) arguments for option $1"
        fi
        shift "$shift_by"
    done
    local script_path=${BASH_SOURCE[1]}
    bu_basename "$script_path"
    local script_name=$BU_RET

    local exit_code=0
    if [[ -n "$error_msg" ]]
    then
        bu_log_err "$error_msg"
        exit_code=1
    fi

    local -a bu_script_options=()
    local -a bu_script_option_docs=()
    eval "$(bu_autohelp_parse_case_block_help "${script_path}" "" "" "${BASH_LINENO[0]}")"

    printf '%s\n' "Help for ${BU_TPUT_BOLD}${script_path}${BU_TPUT_RESET}"
    if [[ -n "$header" ]]
    then
        printf '\n%s\n\n' "${BU_TPUT_BOLD}${BU_TPUT_DARK_BLUE}DESCRIPTION${BU_TPUT_RESET}"
        printf '%s\n' "$(bu_gen_remove_empty_lines <<<"$header" | bu_gen_trim)"
    fi

    printf '\n%s\n\n' "${BU_TPUT_BOLD}${BU_TPUT_DARK_BLUE}OPTIONS${BU_TPUT_RESET}"
    local i
    local option
    local option_docs
    for i in "${!bu_script_options[@]}"
    do
        option=${bu_script_options[i]}
        option_docs=${bu_script_option_docs[i]}
        option=${option//\|/${BU_TPUT_BLUE},${BU_TPUT_RESET}${BU_TPUT_BOLD}}
        if [[ -z "$option_docs" ]]
        then
            printf '%s (No additional help)\n' "${BU_TPUT_BOLD}$option${BU_TPUT_RESET}"
        else
            printf '%s\n\t%s\n' "${BU_TPUT_BOLD}$option${BU_TPUT_RESET}" "${option_docs//$'\n'/$'\n\t'}"
        fi
    done

    if ((${#example_purposes[@]}))
    then
        printf "\n%s\n\n" "${BU_TPUT_BOLD}${BU_TPUT_DARK_BLUE}EXAMPLES${BU_TPUT_RESET}"

        __bu_cli_command_type "${script_path}"
        local opt_source=
        case "$BU_RET" in
        source) opt_source='source ';;
        esac

        local i
        for i in "${!example_purposes[@]}"
        do
            printf "%s:\n" "- ${example_purposes[i]}"
            printf "\t%s %s\n\n" "${BU_TPUT_BOLD}${opt_source}${script_name}" "${example_command_lines[i]}${BU_TPUT_RESET}"
        done
    fi

    bu_scope_pop_function 2>/dev/null || true
    return "$exit_code"
}

# ```
# *Description*:
# The top-level CLI command `$BU_CLI_COMMAND_NAME` (default `bu`)
#
# *Params*:
# - `$1`: Sub-command
# - `...`: All parameters are passed to the sub-command
#
# *Returns*:
# - Exit code of the sub-command
# ```
eval "$BU_CLI_COMMAND_NAME"'() { builtin source bu_impl.sh "$@"; }'

# Always define bu
if [[ "$BU_CLI_COMMAND_NAME" != bu ]]
then
    bu() { builtin source bu_impl.sh "$@"; }
fi


BU_ENUM_NAMESPACE_STYLE=(
    none # default
    prefix-keep
    powershell-keep
    prefix
    powershell
)
