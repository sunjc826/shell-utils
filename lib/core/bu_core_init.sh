# shellcheck source=./bu_core_base.sh
source "$BU_NULL"
# shellcheck source=./bu_core_autocomplete.sh
source "$BU_NULL"
# shellcheck source=./bu_core_preinit.sh
source "$BU_NULL"

# MARK: Initialization logic
__bu_init_env()
{
    bu_env_append_path "$BU_LIB_BIN_DIR"
    bu_env_append_path "$BU_LIB_BINSRC_DIR"
    bu_env_append_path "$BU_BUILTIN_COMMANDS_DIR"
}

__bu_init_keybindings()
{
    if [[ $- == *i* ]]
    then
        local shortcut_key
        for shortcut_key in "${!BU_KEY_BINDINGS[@]}"
        do
            bu_log_debug "Mapping shortcut_key[$shortcut_key] to command[${BU_KEY_BINDINGS[$shortcut_key]}]"
            bind -x '"'"$shortcut_key"'": '"${BU_KEY_BINDINGS[$shortcut_key]}"
        done
    fi
}

# Technically, WSL code setup isn't needed, 
# for e.g. I see /mnt/c/Users/sunjc/AppData/Local/Programs/Microsoft VS Code/bin/code
# when I enter wsl.
# Though note that the code CLI binary in /mnt/c and 
# the vscode server code CLI binary in ~/.vscode-server
# are 2 different binaries, though with similar options.
__bu_init_vscode()
{
    if [[ -n "$VSCODE_IPC_HOOK_CLI" && -n "$VSCODE_GIT_ASKPASS_NODE" ]]
    then
        bu_log_info setting vscode links
        ln -sf "$VSCODE_IPC_HOOK_CLI" "$BU_OUT_DIR"/VSCODE_IPC_HOOK_CLI.sock
        ln -sf "$(realpath -- "$(dirname -- "$VSCODE_GIT_ASKPASS_NODE")"/..)" "$BU_OUT_DIR"/vscode_server_instance
    else
        if  [[ ! ( -e "$BU_OUT_DIR"/VSCODE_IPC_HOOK_CLI.sock && -d "$BU_OUT_DIR"/vscode_server_instance ) ]]
        then
            local latest_server=$(bu_vscode_find_latest_server)
            local latest_socket=$(bu_vscode_find_latest_socket)
            if [[ -n "$latest_server" && -n "$latest_socket" ]]
            then
                ln -sf "$latest_socket" "$BU_OUT_DIR"/VSCODE_IPC_HOOK_CLI.sock
                ln -sf "$latest_server" "$BU_OUT_DIR"/vscode_server_instance
            else
                bu_log_info vscode server not found
                unset VSCODE_IPC_HOOK_CLI
                if [[ VISUAL == code* || EDITOR == code* ]]
                then
                    export VISUAL=vim
                    export EDITOR=vim
                fi
                return
            fi
        fi
        export VSCODE_IPC_HOOK_CLI="$BU_OUT_DIR"/VSCODE_IPC_HOOK_CLI.sock
        bu_log_debug VSCODE_IPC_HOOK_CLI=$VSCODE_IPC_HOOK_CLI
        if [[ -e "$BU_OUT_DIR"/vscode_server_instance/server/bin/remote-cli ]]
        then
            # Remote SSH
            bu_env_append_path "$BU_OUT_DIR"/vscode_server_instance/server/bin/remote-cli
        elif [[ -e "$BU_OUT_DIR"/vscode_server_instance/bin/remote-cli ]]
        then
            # WSL
            bu_env_prepend_path "$BU_OUT_DIR"/vscode_server_instance/bin/remote-cli
        else
            bu_log_err Cannot find code binary
            return 1
        fi
        if [[ -z "$VISUAL" || -z "$EDITOR" ]]
        then
            if bu_vscode_is_socket_inactive
            then
                rm -f "$BU_OUT_DIR"/VSCODE_IPC_HOOK_CLI.sock "$BU_OUT_DIR"/vscode_server_instance
                export VISUAL=vim
                export EDITOR=vim
                bu_log_warn code server is not running
            else
                export VISUAL=$BU_LIB_BIN_DIR/bu_code_wait.sh
                export EDITOR=$VISUAL
                bu_log_info code cli initialized
            fi
        fi

        bu_ext_source "$(code --locate-shell-integration-path bash)"
    fi
}

__bu_init_tmux()
{
    if ! bu_env_is_in_tmux
    then
        return
    fi

    bu_log_debug Setting window status
    tmux set-option window-status-format '#I:#{?@bu_use_window_name,#{window_name},#{b:pane_current_path}}#F'
    tmux set-option window-status-current-format '#I:#{?@bu_use_window_name,#{window_name},#{b:pane_current_path}}#F'
}

__bu_init_autocomplete()
{
    local completion_command
    for completion_command in "${!BU_AUTOCOMPLETE_COMPLETION_FUNCS[@]}"
    do
        local completion_func=${BU_AUTOCOMPLETE_COMPLETION_FUNCS[$completion_command]}
        bu_log_debug "Completing command[$completion_command] with completion_func[$completion_func]"
        complete -F "$completion_func" "$completion_command"
    done
    complete -F __bu_autocomplete_completion_func_default -D
}

bu_init()
{
    __bu_init_env
    __bu_init_keybindings
    __bu_init_vscode
    __bu_init_tmux
    __bu_init_autocomplete
}

bu_init
