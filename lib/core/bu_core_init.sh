# shellcheck source=./bu_core_base.sh
source "$BU_NULL"

# MARK: Initialization logic
__bu_init_keybindings()
{
    if [[ $- == *i* ]]
    then
        local shortcut_key
        for shortcut_key in "${!BU_KEY_BINDINGS[@]}"
        do
            bind -x '"'"$shortcut_key"'": '"${BU_KEY_BINDINGS[$shortcut_key]}"
        done
    fi
}

__bu_init_vscode()
{
    if [[ -n "$VSCODE_IPC_HOOK_CLI" && -n "$VSCODE_GIT_ASKPASS_NODE" ]]
    then
        bu_log_info setting vscode links
        ln -sf "$VSCODE_IPC_HOOK_CLI" "$BU_TMP_DIR"/VSCODE_IPC_HOOK_CLI.sock
        ln -sf "$(realpath -- "$(dirname -- "$VSCODE_GIT_ASKPASS_NODE")"/..)" "$BU_TMP_DIR"/vscode_server_instance
    else
        if  [[ ! ( -e "$BU_TMP_DIR"/VSCODE_IPC_HOOK_CLI.sock && -d "$BU_TMP_DIR"/vscode_server_instance ) ]]
        then
            local latest_server=$(bu_vscode_find_latest_server)
            local latest_socket=$(bu_vscode_find_latest_socket)
            if [[ -n "$latest_server" && -n "$latest_socket" ]]
            then
                ln -sf "$latest_socket" "$BU_TMP_DIR"/VSCODE_IPC_HOOK_CLI.sock
                ln -sf "$latest_server" "$BU_TMP_DIR"/vscode_server_instance
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
        export VSCODE_IPC_HOOK_CLI="$BU_TMP_DIR"/VSCODE_IPC_HOOK_CLI.sock
        if [[ -e "$BU_TMP_DIR"/vscode_server_instance/server/bin/remote-cli ]]
        then
            # Remote SSH
            bu_env_append_path "$BU_TMP_DIR"/vscode_server_instance/server/bin/remote-cli
        elif [[ -e "$BU_TMP_DIR"/vscode_server_instance/bin/remote-cli ]]
        then
            # WSL
            bu_env_append_path "$BU_TMP_DIR"/vscode_server_instance/bin/remote-cli
        else
            bu_log_err Cannot find code binary
            return 1
        fi
        if [[ -z "$VISUAL" || -z "$EDITOR" ]]
        then
            if bu_vscode_is_socket_inactive
            then
                rm -f "$BU_TMP_DIR"/VSCODE_IPC_HOOK_CLI.sock "$BU_TMP_DIR"/vscode_server_instance
                export VISUAL=vim
                export EDITOR=vim
                bu_log_warn code server is not running
            else
                export VISUAL=$BU_LIB_BIN_DIR/code_wait.sh
                export EDITOR=$VISUAL
                bu_log_info code cli initialized
            fi
        fi
    fi
}

__bu_init_tmux()
{
    :
}

__bu_init_autocomplete()
{
    :
}

bu_init()
{
    __bu_init_keybindings
    __bu_init_vscode
    __bu_init_tmux
    __bu_init_autocomplete
}

bu_init
