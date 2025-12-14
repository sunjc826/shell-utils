if false; then
source ./bu_core_base.sh
source ./bu_core_autocomplete.sh
source ./bu_core_cli.sh
fi

# ```
# *Description*:
# Register a user-defined key binding for the shell
#
# *Params*:
# - `$1`: Key binding (e.g. `\ee`, `\eg`)
# - `$2`: Command or function name to bind to the key
#
# *Returns*: None
#
# *Examples*:
# ```bash
# bu_preinit_register_user_defined_key_binding '\em' my_custom_command
# ```
#
# *Notes*:
# - This adds the binding to the `${BU_KEY_BINDINGS[@]}` associative array, which is later passed to `bind -x`
# ```
bu_preinit_register_user_defined_key_binding()
{
    local -r key=$1
    local -r binding=$2
    BU_KEY_BINDINGS[$key]=$binding
}

# ```
# *Description*:
# Register a user-defined completion function for a command
#
# *Params*:
# - `$1`: Command name to register completion for
# - `$2`: Completion function name to associate with the command
#
# *Returns*: None
#
# *Examples*:
# ```bash
# bu_preinit_register_user_defined_completion_func mycmd my_completion_func
# ```
#
# *Notes*:
# - This adds the mapping to the `BU_AUTOCOMPLETE_COMPLETION_FUNCS` associative array, which is later passed to `complete -F`
# ```
bu_preinit_register_user_defined_completion_func()
{
    local completion_command=$1
    local completion_func=$2
    BU_AUTOCOMPLETE_COMPLETION_FUNCS[$completion_command]=$completion_func
}

# ```
# *Description*:
# Register a directory containing user-defined subcommands
#
# *Params*:
# - `$1`: Directory path containing subcommand scripts
# - `...` (optional): Conversion function to convert file names to command names
#
# *Returns*:
# - Exit code 0 on success, 1 if directory does not exist
#
# *Examples*:
# ```bash
# bu_preinit_register_user_defined_subcommand_dir /path/to/commands bu_convert_file_to_command_namespace prefix
# ```
#
# *Notes*:
# - The directory is added to `BU_COMMAND_SEARCH_DIRS` for dynamic command discovery. New commands can be added by re-sourcing the init script.
# - If no conversion function is provided, file names are used as-is (after removing .sh extension)
# ```
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

# ```
# *Description*:
# Register a single user-defined subcommand file
#
# *Params*:
# - `$1`: File path to the subcommand script
# - `$2` (optional): Command name to register (default: derived from file name)
# - `$3` (optional): Type of the command (e.g. `function`, `execute`, `source`)
#
# *Returns*: None
#
# *Examples*:
# ```bash
# bu_preinit_register_user_defined_subcommand_file /path/to/my-cmd.sh my-cmd execute
# bu_preinit_register_user_defined_subcommand_file /path/to/my-cmd.sh
# ```
#
# *Notes*:
# - If no command name is provided, it is derived from the file name (with .sh extension removed)
# - The command is added to the `BU_COMMANDS` associative array
# ```
bu_preinit_register_user_defined_subcommand_file()
{
    local -r file=$1
    local command=$2
    local -r type=$3

    if [[ -z "$command" ]]
    then
        bu_basename "$file"
        local file_base=$BU_RET
        command=${file_base%.sh}
    fi

    BU_COMMANDS[$command]=$file

    if [[ -n "$type" ]]
    then
        BU_COMMAND_PROPERTIES[$command,type]=$type
    fi
}

# ```
# *Description*:
# Register a user-defined subcommand function
#
# *Params*:
# - `$1`: Function name implementing the subcommand
# - `$2` (optional): Command name to register (default: same as function name)
# - `$3` (optional): Type of the command (e.g. `function`, `execute`, `source`)
#
# *Returns*: None
#
# *Examples*:
# ```bash
# bu_preinit_register_user_defined_subcommand_function my_cmd_func my-cmd function
# bu_preinit_register_user_defined_subcommand_function my_cmd_func
# ```
#
# *Notes*:
# - If no command name is provided, the function name is used as the command name
# - The command is added to the `BU_COMMANDS` associative array
# ```
bu_preinit_register_user_defined_subcommand_function()
{
    local -r fn=$1
    local command=$2
    local -r type=$3

    if [[ -z "$command" ]]
    then
        command=$fn
    fi

    BU_COMMANDS[$command]=$file

    if [[ -n "$type" ]]
    then
        BU_COMMAND_PROPERTIES[$command,type]=$type
    fi
}

# ```
# *Description*:
# Convert a file name to a command name using prefix style with delimiter
#
# *Params*:
# - `$1`: Delimiter character (e.g. `-`)
# - `$2`: File path to convert
#
# *Returns*:
# - `$BU_RET`: The derived command name in format `verb-noun`
#
# *Examples*:
# ```bash
# bu_convert_file_to_command_prefix - /path/to/my-get-status.sh  # $BU_RET=get-status
# ```
#
# *Notes*:
# - This parses the file name (without .sh extension) and extracts verb and noun components
# - Updates the global `BU_COMMAND_VERBS` and `BU_COMMAND_NOUNS` sets
# - Stores verb/noun properties in `BU_COMMAND_PROPERTIES`
# ```
bu_convert_file_to_command_prefix()
{
    local -r delimiter=$1
    local -r file_path=$2
    bu_basename "$file_path"
    local -r file_base=$BU_RET
    local -r file_base_no_ext=${file_base%.sh}
    local -r namespace=${file_base_no_ext%%$delimiter*}
    local -r no_namespace=${file_base_no_ext#*$delimiter} # Don't quote prefix, we allow it to be a pattern
    local -r verb=${no_namespace%%-*}
    local -r noun=${no_namespace#*-}
    BU_COMMAND_VERBS[$verb]=1
    BU_COMMAND_NOUNS[$noun]=1
    BU_COMMAND_NAMESPACES[$namespace]=1
    local -r command=${verb}-${noun}
    BU_COMMAND_PROPERTIES[$command,verb]=$verb
    BU_COMMAND_PROPERTIES[$command,noun]=$noun
    BU_COMMAND_PROPERTIES[$command,namespace]=$namespace
    BU_RET=$command
}

# ```
# *Description*:
# Convert a file name to a command name using PowerShell style naming convention
#
# *Params*:
# - `$1`: File path to convert
#
# *Returns*:
# - `$BU_RET`: The derived command name in format `verb-noun`
#
# *Examples*:
# ```bash
# bu_convert_file_to_command_powershell /path/to/get-my-process-status.sh  # $BU_RET=get-process-status
# ```
#
# *Notes*:
# - This parses the file name (without .sh extension) in PowerShell style: `verb-namespace-noun`
# - Extracts the verb and noun components, discarding the namespace
# - Updates the global `BU_COMMAND_VERBS` and `BU_COMMAND_NOUNS` sets
# - Stores verb/noun properties in `BU_COMMAND_PROPERTIES`
# ```
bu_convert_file_to_command_powershell()
{
    local -r file_path=$1
    bu_basename "$file_path"
    local -r file_base_no_ext=${BU_RET%.sh}
    local -r verb=${file_base_no_ext%%-*}
    local -r no_verb=${file_base_no_ext#*-}
    local -r namespace=${no_verb%%-*}
    local -r noun=${no_verb#*-}
    BU_COMMAND_VERBS[$verb]=1
    BU_COMMAND_NOUNS[$noun]=1
    BU_COMMAND_NAMESPACES[$namespace]=1
    local -r command=${verb}-${noun}
    BU_COMMAND_PROPERTIES[$command,verb]=$verb
    BU_COMMAND_PROPERTIES[$command,noun]=$noun
    BU_COMMAND_PROPERTIES[$command,namespace]=$namespace
    BU_RET=$command
}

# ```
# *Description*:
# Convert a file name to a command name using a specified naming style
#
# *Params*:
# - `$1`: Naming style (one of `none`, `prefix`, `powershell`, `prefix-keep`, `powershell-keep`)
# - `$2`: File path to convert
#
# *Returns*:
# - `$BU_RET`: The derived command name
#
# *Examples*:
# ```bash
# bu_convert_file_to_command_namespace prefix /path/to/my-get-status.sh  # $BU_RET=get-status
# bu_convert_file_to_command_namespace powershell /path/to/get-my-status.sh  # $BU_RET=get-status
# bu_convert_file_to_command_namespace none /path/to/mycmd.sh  # $BU_RET=mycmd
# ```
#
# *Notes*:
# - `none`, `prefix-keep`, and `powershell-keep` styles preserve the file name (without .sh extension)
# - `prefix` style delegates to `bu_convert_file_to_command_prefix` with `-` as delimiter
# - `powershell` style delegates to `bu_convert_file_to_command_powershell`
# ```
bu_convert_file_to_command_namespace()
{
    local -r style=$1
    local -r file_path=$2
    case "$style" in
    none)
        bu_basename "$file_path"
        BU_RET=${BU_RET%.sh}
        ;;
    prefix-keep)
        # -keep means don't throw away the namespace
        bu_convert_file_to_command_prefix - "$file_path"
        # We only need to do some processing of the other bookkeeping variables
        # Otherwise, we don't change the command name
        bu_basename "$file_path"
        BU_RET=${BU_RET%.sh}
        ;;
    powershell-keep)
        # -keep means don't throw away the namespace
        # We only need to do some processing of the other bookkeeping variables
        # Otherwise, we don't change the command name
        bu_convert_file_to_command_powershell "$file_path"
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
    *)
        bu_log_err "Invalid naming style[$style]"
        return 1
        ;;
    esac
}

bu_preinit_register_user_defined_subcommand_dir "$BU_BUILTIN_COMMANDS_DIR" bu_convert_file_to_command_namespace prefix

# Alias spec
# '{}' represents 1 input
# '{...}' represents remaining input
# '{?}' represents don't add the remaining if there are no more inputs
#
# There can be no '{}' after '...'
# There can be at most 1 '...'
#
# Example:
# my_command --arg1 '{}' '{?}' --arg2 '{}' '{...}'
#
# Aliases are using for creating positional commands and transforming them into named argument commands 
bu_preinit_register_new_alias()
{
    local -r alias_name=$1
    if [[ -z "$alias_name" ]]
    then
        bu_log_err "Alias name is empty"
        return 1
    fi
    shift

    local i
    local has_remaining_input=false
    # Validate
    for ((i = 0; i < $#; i++))
    do
        case "${!i}" in
        '{...}')
            if "$has_remaining_input"
            then
                bu_log_err "Bad alias spec, there should not be another {...}"
                return 1
            fi
            has_remaining_input=true
            ;;
        '{}'|'{?}')
            if "$has_remaining_input"
            then
                bu_log_err "Bad alias spec, there should not be ${!i} after a {...}"
                return 1
            fi
        esac
    done
    local alias_spec=$*
    # printf -v alias_spec '%q ' "$@" 
    BU_COMMANDS[$alias_name]="$alias_spec"
    BU_COMMAND_PROPERTIES[$alias_name,type]=alias
    return 0
}

bu_preinit_register_new_alias gc get-command --namespace {} {?} --verb {} {?} --noun {} {...}
