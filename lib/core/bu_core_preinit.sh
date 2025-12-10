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
    ['\C-x']="__bu_bind_fzf_autocomplete"
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

declare -A -g BU_COMMANDS=()
declare -A -g BU_COMMAND_SEARCH_DIRS=()
declare -A -g BU_COMMAND_PROPERTIES=()
bu_preinit_register_user_defined_subcommand_dir()
{
    local dir=$1
    shift
    local convert_file_to_command=
    if (($#))
    then
        printf -v convert_file_to_command '%q ' "$@"
    fi

    bu_realpath "$dir"
    dir=$BU_RET

    if [[ ! -d "$dir" ]]
    then
        bu_log_warn "dir[$dir] does not exist"
        return 1
    fi

    BU_COMMAND_SEARCH_DIRS[$dir]=$convert_file_to_command
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

bu_convert_file_to_command_prefix()
{
    local -r delimiter=$1
    local -r file_path=$2
    bu_basename "$file_path"
    local file_base=$BU_RET
    local file_base_no_ext=${file_base%.sh}
    BU_RET=${file_base_no_ext#*$delimiter} # Don't quote prefix, we allow it to be a pattern
}

bu_convert_file_to_command_powershell()
{
    local -r file_path=$1
    bu_basename "$file_path"
    local file_base_no_ext=${BU_RET%.sh}
    local verb=${file_base_no_ext%%-*}
    local no_verb=${file_base_no_ext#*-}
    local namespace=${no_verb%%-*}
    local noun=${no_verb#*-}
    BU_RET=${verb}-${noun}
}

bu_convert_file_to_command_namespace()
{
    local -r style=$1
    local -r file_path=$2
    case "$style" in
    none|prefix-keep|powershell-keep) 
        # -keep means don't throw away the namespace
        # Currently, none, prefix-keep, powershell-keep are synonyms
        # because no additional processing is done for prefix-keep and powershell-keep
        bu_basename "$file_path"
        BU_RET=${BU_RET%.sh}
        ;;
    prefix)
        # Format namespace-verb-noun
        bu_convert_file_to_command_prefix - "$file_path"
        ;;
    powershell)
        # Format verb-namespace-noun
        bu_convert_file_to_command_powershell "$file_path"
        ;;
    esac
}

bu_preinit_register_user_defined_subcommand_dir "$BU_BUILTIN_COMMANDS_DIR" bu_convert_file_to_command_namespace prefix
