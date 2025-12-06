# shellcheck source=./bu_core_base.sh
source "$BU_NULL"

# shellcheck source=./bu_core_autocomplete.sh
source "$BU_NULL"

# shellcheck source=./bu_core_cli.sh
source "$BU_NULL"

# Quote the value to get Go-To Definition working in bash-language-server
declare -A -g BU_KEY_BINDINGS=(
    ['\ee']="__bu_bind_edit"
    ['\eg']="__bu_bind_toggle_gdb"
    ['\ea']="__bu_bind_fzf_history"
    ['\ex']="__bu_bind_fzf_autocomplete"
)

bu_preinit_register_user_defined_key_binding()
{
    local key=$1
    local binding=$2
    BU_KEY_BINDINGS[$key]=$binding
}

declare -A -g BU_AUTOCOMPLETE_COMPLETION_FUNCS=(
    [$BU_CLI_COMMAND_NAME]="__bu_autocomplete_completion_func_cli"
)

bu_preinit_register_user_defined_completion_func()
{
    local completion_command=$1
    local completion_func=$2
    BU_AUTOCOMPLETE_COMPLETION_FUNCS[$completion_command]=$completion_func
}

declare -a -g BU_COMMAND_SEARCH_DIRS=()
declare -A -g BU_COMMANDS=()
declare -A -g BU_COMMAND_PROPERTIES=()
bu_preinit_register_user_defined_subcommand_dir()
{
    local dir=$1
    local convert_file_to_subcommand=$2
    local properties=$3

    if [[ ! -d "$dir" ]]
    then
        bu_log_warn "dir[$dir] does not exist"
        return 1
    fi

    BU_COMMAND_SEARCH_DIRS+=("$dir")

    local file
    local command
    for file in $(find "$dir" -printf "%P\n")
    do
        case "$file" in
        *.txt|README|README.*|*.md) 
            continue
            ;;
        __*)
            # 2 underscores in front can be used to hide scripts
            continue
            ;;
        esac

        command=${file%.sh}
        if [[ -n "$convert_file_to_subcommand" ]]
        then
            if "$convert_file_to_subcommand" "$file"
            then
                command=$BU_RET
            fi
        fi

        BU_COMMANDS[$command]=$dir/$file

        if [[ -n "$properties" ]]
        then
            BU_COMMAND_PROPERTIES[$command]=$properties
        fi
    done
}

bu_preinit_register_user_defined_subcommand_file()
{
    local file=$1
    local command=$2
    local properties=$3

    if [[ -z "$command" ]]
    then
        bu_basename "$file"
        local file_base=$BU_RET
        command=${file_base%.sh}
    fi

    BU_COMMANDS[$command]=$file

    if [[ -n "$properties" ]]
    then
        BU_COMMAND_PROPERTIES[$command]=$properties
    fi
}

bu_preinit_register_user_defined_subcommand_function()
{
    local fn=$1
    local command=$2
    local properties=$3

    if [[ -z "$command" ]]
    then
        command=$fn
    fi

    BU_COMMANDS[$command]=$file

    if [[ -n "$properties" ]]
    then
        BU_COMMAND_PROPERTIES[$command]=$properties
    fi
}

__bu_remove_bu_prefix()
{
    bu_basename "$1"
    local file_base=$BU_RET
    local file_base_no_ext=${file_base%.sh}
    BU_RET=${file_base_no_ext#bu-}
}
bu_preinit_register_user_defined_subcommand_dir "$BU_BUILTIN_COMMANDS_DIR" __bu_remove_bu_prefix
