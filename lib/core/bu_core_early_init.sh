# The purpose of early init is so that we can make some things available to downstream repos
# to use in their pre-init callbacks. Most importantly, the builtin bu commands.
# This avoids some of the need to do double initialization, i.e.
# initialize BashTab fully just to have the bu builtin commands,
# then call the bu builtin commands inside a downstream repo activation script,
# then reinitialize again.
if false; then
source ./bu_core_base.sh
source ./bu_core_autocomplete.sh
fi
__bu_init_env_commands()
{
    local dir
    local file
    local convert_file_to_subcommand
    local command
    for dir in "${!BU_COMMAND_SEARCH_DIRS[@]}"
    do
        bu_env_append_path "$dir"
        convert_file_to_subcommand=${BU_COMMAND_SEARCH_DIRS[$dir]}
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
                if $convert_file_to_subcommand "$file"
                then
                    command=$BU_RET
                fi
            fi

            BU_COMMANDS[$command]=$dir/$file
        done
    done
}

__bu_init_env_commands
# Get bu_impl.sh on PATH so that bu can be called
bu_env_append_path "$BU_LIB_BINSRC_DIR"
