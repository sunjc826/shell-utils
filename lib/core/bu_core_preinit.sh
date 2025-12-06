# shellcheck source=./bu_core_base.sh
source "$BU_NULL"

# shellcheck source=./bu_core_autocomplete.sh
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
    [$BU_MASTER_COMMAND_NAME]="__bu_autocomplete_completion_func_master"
)

bu_preinit_register_user_defined_completion_func()
{
    local completion_command=$1
    local completion_func=$2
    BU_AUTOCOMPLETE_COMPLETION_FUNCS[$completion_command]=$completion_func
}
