# shellcheck source=./bu_core_base.sh
source "$BU_NULL"

__bu_spawn_tmux_header()
{
    local command=$1
    # Serialize the environment
    awk 'BEGIN{for(v in ENVIRON) { if(v !~ /^(TMUX|TERM|BASH)(_.*|$)/) printf "export %s=\"%s\"\n", v, ENVIRON[v] }}'
    if [[ -n "$command" ]] && bu_symbol_is_function "$command"
    then
        printf "%s\n" "$(declare -f "$command")"
    fi
    echo . /etc/profile
    echo . "$HOME"/.bashrc
    echo 'source '"$BU_DIR"/bu_entrypoint.sh
}

__bu_spawn_tmux_resolve_split_mode()
{
    local split_mode=$1
    case "$split_mode" in
    none)
        BU_RET=(new-window -d)
        ;;
    vertical)
        BU_RET=(split-window -vd -t "$TMUX_PANE")
        ;;
    horizontal)
        BU_RET=(split-window -hd -t "$TMUX_PANE")
        ;;
    *)
        bu_log_err "Bad split mode[$split_mode]"
        return 1
        ;;
    esac
    # Default format: #{session_name}:#{window_index}
    # But window index is not stable, so we should a custom stable format #{pane_id}
    BU_RET+=(-P -F '#{pane_id}')
}

__bu_spawn_tmux_joinable_header()
{
    local command=$1
    local tmp_file=$2
    local ret_file=$tmp_file.ret
    local fifo_file=$tmp_file.fifo
    echo 'rm '"$tmp_file"
    __bu_spawn_tmux_header "$command"
    # echo 1 first to account for possible Ctrl-C
    echo 'echo 1 >'"$ret_file"
    echo 'exec {RET_FILE_FD}>'"$ret_file"
    echo 'rm '"$ret_file"
    echo 'bu_exit_handler_setup_no_e'
    echo 'bu_scope_push'
    # shellcheck disable=SC2016
    echo 'bu_sync_acquire_fd "$RET_FILE_FD"'
    # shellcheck disable=SC2016
    echo 'bu_scope_cleanup bu_release_fd "$RET_FILE_FD"'
    echo 'echo >'"$fifo_file"
}

__bu_spawn_tmux_joinable_footer()
{
    echo
    # shellcheck disable=SC2016
    echo 'echo $? >&"$RET_FILE_FD"'
    echo 'bu_scope_pop'
}

__bu_spawn_tmux_joinable_driver()
{
    local tmp_file=$1
    local split_mode=$2
    local driver_file=$tmp_file.driver.sh
    local fifo_file=$tmp_file.fifo
    {
        echo 'rm '"$driver_file"
        echo . /etc/profile
        echo . "$HOME"/.bashrc
        echo bash "$tmp_file"
    } > "$driver_file"

    bu_log_cmd_info cat "$tmp_file"
    __bu_spawn_tmux_resolve_split_mode "$split_mode" || return 1
    local tmux_subcommand=("${BU_RET[@]}")
    local pane_id
    pane_id=$(tmux "${tmux_subcommand[@]}" bash --init-file "$driver_file")
    local discarded
    # shellcheck disable=SC2034
    read -r discarded <"$fifo_file"
    rm -f "$fifo_file"
    BU_RET=$pane_id
}

bu_spawn_tmux_stop_commands()
{
    local pane
    for pane
    do
        tmux send-keys -t "$pane" q C-c
    done
}

bu_spawn_tmux_join_commands()
{
    bu_log_info "Joining fds[$*]"
    local fd
    local exit_code=0
    local command_exit_code
    for fd
    do
        if ! bu_sync_acquire_fd "$fd"
        then
            bu_log_err 'bu_sync_acquire_fd failed'
            return 1
        fi
        bu_log_debug "Reading from fd[$fd]"
        if ! read -r command_exit_code <&"$fd"
        then
            bu_log_err "Read from fd[$fd] failed"
            return 1
        fi
        if ! bu_sync_release_fd "$fd"
        then
            bu_log_err 'bu_sync_release_fd failed'
            return 1
        fi
        if ((command_exit_code))
        then
            exit_code=$command_exit_code
        fi
    done
    return "$exit_code"
}

bu_spawn_tmux_stop_join_commands()
{
    if (($# / 2 * 2 != $#))
    then
        bu_log_err 'There should be an even number of arguments'
        return 1
    fi

    local to_stop=()
    local to_join=()
    while (($#))
    do
        to_stop+=("$1")
        to_join+=("$2")
        shift 2
    done
    bu_spawn_tmux_stop_commands "${to_stop[@]}"
    bu_spawn_tmux_join_commands "${to_join[@]}"
}

bu_spawn_tmux_command()
{
    local split_mode=$1
    shift
    local tmp_file
    tmp_file=$(mktemp "$BU_TMP_DIR"/tmux.XXXXXXXXXX) || return 1

    {
        echo rm "$tmp_file"
        __bu_spawn_tmux_header "$1"
        printf '%q ' "$@"
        echo
    } > "$tmp_file"

    __bu_spawn_tmux_resolve_split_mode "$split_mode" || return 1
    local tmux_subcommand=("${BU_RET[@]}")
    local pane_id
    pane_id=$(tmux "${tmux_subcommand[@]}" bash --init-file "$tmp_file")
    BU_RET=$pane_id
}

bu_spawn_tmux_joinable_command()
{
    local split_mode=$1
    shift
    local command=$1
    local tmp_file
    tmp_file=$(mktemp "$BU_TMP_DIR"/tmux.XXXXXXXXXX) || return 1
    local fifo_file=$tmp_file.fifo
    mkfifo "$fifo_file" || return 1
    local ret_file=$tmp_file.ret
    : > "$ret_file" || return 1
    local ret_file_fd
    exec {ret_file_fd}<"$ret_file"
    {
        __bu_spawn_tmux_joinable_header "$command" "$tmp_file"
        printf '%q ' "$@"
        __bu_spawn_tmux_joinable_footer
    } > "$tmp_file"
    __bu_spawn_tmux_joinable_driver "$tmp_file" "$split_mode"
    local pane_id=$BU_RET
    BU_RET=("$pane_id" "$ret_file_fd")
}

bu_spawn_tmux_function()
{
    local split_mode=$1
    shift
    local tmp_file
    tmp_file=$(mktemp "$BU_TMP_DIR"/tmux.XXXXXXXXXX) || return 1
    bu_basename "$tmp_file"
    local random_part=${BU_RET#tmux.}
    {
        echo rm "$tmp_file"
        __bu_spawn_tmux_header
        echo 'function func_'"$random_part"'() {'
        cat /dev/stdin
        echo '}'
        echo 'func_'"$random_part"
    } > "$tmp_file"

    __bu_spawn_tmux_resolve_split_mode "$split_mode" || return 1
    local tmux_subcommand=("${BU_RET[@]}")
    local pane_id
    pane_id=$(tmux "${tmux_subcommand[@]}" bash --init-file "$tmp_file")
    BU_RET=$pane_id
}

bu_spawn_tmux_joinable_function()
{
    local split_mode=$1
    shift
    local tmp_file
    tmp_file=$(mktemp "$BU_TMP_DIR"/tmux.XXXXXXXXXX) || return 1
    local fifo_file=$tmp_file.fifo
    mkfifo "$fifo_file" || return 1
    local ret_file=$tmp_file.ret
    : > "$ret_file" || return 1
    local ret_file_fd
    exec {ret_file_fd}<"$ret_file"

    bu_basename "$tmp_file"

    local random_part=${BU_RET#tmux.}
    {
        __bu_spawn_tmux_joinable_header "" "$tmp_file"
        echo 'function func_'"$random_part"'() {'
        cat /dev/stdin
        echo '}'
        echo 'func_'"$random_part"
        __bu_spawn_tmux_joinable_footer
    } > "$tmp_file"

    __bu_spawn_tmux_joinable_driver "$tmp_file"
    local pane_id=$BU_RET
    BU_RET=("$pane_id" "$ret_file_fd")
}

BU_TMUX_PANES_FILE=$BU_PROC_TMP_DIR/tmux_panes.txt
bu_spawn_init()
{
    : >"$BU_TMUX_PANES_FILE"
}

bu_spawn()
{
    local split_mode=none
    local is_split_opposite=false
    local is_joinable=false
    local is_scoped=false
    local is_delete_pane=false # TODO
    local is_wait=false
    local is_function=
    local shift_by
    while (($#))
    do
        shift_by=1
        case "$1" in
        --split|--split-opposite)
            shift_by=2
            split_mode=$2
            case "$split_mode" in
            ''|n|none|new-window) split_mode=none ;;
            v|vert|vertical|split-vertical) split_mode=vertical ;;
            h|hori|horizontal|split-horizontal) split_mode=horizontal ;;
            *) bu_log_err "Unexpected split mode[$split_mode]"; return 1 ;;
            esac
            if [[ "$1" = --split-opposite ]]
            then
                is_split_opposite=true
            fi
            ;;
        --joinable)
            is_joinable=true
            ;;
        --scoped)
            is_scoped=true
            ;;
        --delete-pane)
            is_delete_pane=true
            ;;
        --wait)
            is_joinable=true
            is_wait=true
            ;;
        --command)
            is_function=false
            ;;
        --function)
            is_function=true
            ;;
        --)
            shift
            break
            ;;
        -*)
            bu_log_unrecognized_option "$1"
            return 1
            ;;
        *)
            break
            ;;
        esac
        shift "$shift_by"
    done
    local remaining_options=("$@")

    if "$is_split_opposite"
    then
        case "$split_mode" in
        none) ;;
        vertical) split_mode=horizontal ;;
        horizontal) split_mode=vertical ;;
        esac
    fi

    bu_log_info "Spawning ${remaining_options[*]}"

    if [[ -z "$is_function" ]]
    then
        if [[ -t 0 ]]
        then
            is_function=false
        else
            is_function=true
        fi
    fi

    local exit_code=0

    local pane_id=
    if "$is_function"
    then
        if "$is_joinable"
        then
            bu_spawn_tmux_joinable_function "$split_mode" "${remaining_options[@]}"
            pane_id=$BU_RET
            if "$is_wait" && "$is_scoped"
            then
                bu_scope_add_cleanup bu_spawn_tmux_join_commands "${BU_RET[1]}"
            elif "$is_wait"
            then
                if ! bu_spawn_tmux_join_commands "${BU_RET[1]}"
                then
                    exit_code=1
                fi
            elif "$is_scoped"
            then
                bu_scope_add_cleanup bu_spawn_tmux_stop_join_commands "${BU_RET[@]}"
            fi
        else
            bu_spawn_tmux_function "$split_mode" "${remaining_options[@]}"
            pane_id=$BU_RET
            if "$is_scoped"
            then
                bu_scope_add_cleanup bu_spawn_tmux_stop_commands "$BU_RET"
            fi
        fi
    else
        if "$is_joinable"
        then
            bu_spawn_tmux_joinable_command "$split_mode" "${remaining_options[@]}"
            pane_id=$BU_RET
            if "$is_wait" && "$is_scoped"
            then
                bu_scope_add_cleanup bu_spawn_tmux_join_commands "${BU_RET[1]}"
            elif "$is_wait"
            then
                if ! bu_spawn_tmux_join_commands "${BU_RET[1]}"
                then
                    exit_code=1
                fi
            elif "$is_scoped"
            then
                bu_scope_add_cleanup bu_spawn_tmux_stop_join_commands "${BU_RET[1]}"
            fi
        else
            bu_spawn_tmux_command "$split_mode" "${remaining_options[@]}"
            pane_id=$BU_RET
            if "$is_scoped"
            then
                bu_scope_add_cleanup bu_spawn_tmux_stop_commands "$BU_RET"
            fi
        fi
    fi

    bu_sync_acquire_file "$BU_TMUX_PANES_FILE"
    printf '%s\n' "$pane_id" >> "$BU_TMUX_PANES_FILE"
    bu_sync_release_fd "$BU_TMUX_PANES_FILE"
    bu_log_debug "exit_code[$exit_code]"
    return "$exit_code"    
}

