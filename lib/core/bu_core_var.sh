# ```
# The master command name. Default is `bu`, but users can override it by defining `BU_USER_DEFINED_CLI_COMMAND_NAME`.
# ```
BU_CLI_COMMAND_NAME=${BU_USER_DEFINED_CLI_COMMAND_NAME:-bu}

# This file can sourced multiple times, but the following variables will only be defined once
# to avoid resetting changes.
# All array/map container variables should be placed below this conditional
if [[ -n "$BU_CORE_VAR_SOURCED" ]]; then return; fi

declare -g BU_CORE_VAR_SOURCED=1

# ```
# This mapping will be passed directly to `complete -F`
# ```
declare -A -g BU_AUTOCOMPLETE_COMPLETION_FUNCS=(
    [$BU_CLI_COMMAND_NAME]="__bu_autocomplete_completion_func_cli"
)

# ```
# Map of command to script path / function
# ```
declare -A -g BU_COMMANDS=()
# ```
# Map of directory to convert_file_to_command
# ```
declare -A -g BU_COMMAND_SEARCH_DIRS=()
# ```
# Map of (<command>,<query>) to properties
# The following queries are currently defined
# - type 
#   - Meaning: The type of Bash object implementing the command
#   - Values: 
#     - function: For Bash functions
#     - execute: For executable Bash scripts
#     - source: For non-executable Bash scripts meant to be sourced
#     - alias: For bu aliases. See `bu_preinit_register_new_alias`.
#     - <empty>: To be dynamically derived
# - verb
#   - Meaning: Breakdown of the command. The verb portion.
# - noun
#   - Meaning: Breakdown of the command. The noun portion.
# - namespace
#   - Meaning: Breakdown of the command. The namespace portion.
# ```
declare -A -g BU_COMMAND_PROPERTIES=()

# ```
# Set of all parsed verbs from the bu command list
# Note: This is an associative array, thus to get all verbs, do `${!BU_COMMAND_VERBS[@]}`
# ```
declare -A -g BU_COMMAND_VERBS=()
# ```
# Set of all parsed nouns from the bu command list
# Note: This is an associative array, thus to get all nouns, do `${!BU_COMMAND_NOUNS[@]}`
# ```
declare -A -g BU_COMMAND_NOUNS=()
# ```
# Set of all parsed namespaces from the bu command list
# Note: This is an associative array, thus to get all nouns, do `${!BU_COMMAND_NAMESPACE[@]}`
# ```
declare -A -g BU_COMMAND_NAMESPACES=()

declare -A -g BU_COMPOPT_CURRENT_COMPLETION_OPTIONS=()

# ```
# Whether the current compopt builtin is overridden by a custom func
# ```
declare -g BU_COMPOPT_IS_CUSTOM=false

# Double quote the value to get Go-To Definition working in bash-language-server

# ```
# This mapping will be passed directly to `bind -x`
# ```
declare -A -g BU_KEY_BINDINGS=(
    ['\ee']="__bu_bind_edit"
    ['\eg']="__bu_bind_toggle_gdb"
    ['\ea']="__bu_bind_fzf_history"
    ['\ex']="__bu_bind_fzf_autocomplete"
    ['\C-x']="__bu_bind_fzf_autocomplete"
)
