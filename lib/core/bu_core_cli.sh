# shellcheck source=./bu_core_base.sh
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
__bu_cli_command_properties()
{
    local bu_command=$1
    local function_or_script_path=${BU_COMMANDS[$bu_command]}
    local properties="${BU_COMMAND_PROPERTIES[$bu_command]}"
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
    for key in "${!BU_COMMANDS[@]}"
    do
        value=${BU_COMMANDS[$key]}
        __bu_cli_command_properties "$key"
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
        *)
            bu_log_warn "Unrecognized properties[$properties] for command[$key]"
            ;;
        esac
    done


    echo
    echo "The following commands using ${BU_TPUT_UNDERLINE}a new shell context${BU_TPUT_RESET} are available"
    echo

    for key in $(__bu_cli_sort_keys <<<"${!executable_scripts[*]}")
    do
        value=${executable_scripts[$key]}
        printf "    ${BU_TPUT_BOLD}%-30s${BU_TPUT_RESET}    %s\n" "$key" "$value"
    done

    echo
    echo "The following commands using ${BU_TPUT_UNDERLINE}the current shell context${BU_TPUT_RESET} are available"
    echo
    
    for key in $(__bu_cli_sort_keys <<<"${!source_scripts[*]}")
    do
        value=${source_scripts[$key]}
        printf "    ${BU_TPUT_BOLD}%-30s${BU_TPUT_RESET}    %s\n" "$key" "$value"
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
    echo "The following ${BU_TPUT_UNDERLINE}key bindings${BU_TPUT_NO_UNDERLINE} are available"
    echo

    for key in $(__bu_cli_sort_keys <<<"${!BU_KEY_BINDINGS[*]}")
    do
        value=${BU_KEY_BINDINGS[$key]}
        printf "    %s -> %s\n" "$key" "$value"
    done
} >&2

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
