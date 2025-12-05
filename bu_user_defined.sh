#!/usr/bin/env bash
# shellcheck source=./bu_custom_source.sh
source "$BU_NULL"

bu_source_user_defined_configs()
{
    bu_source_multi_once "${BU_USER_DEFINED_STATIC_CONFIGS[@]}"
    bu_source_multi "${BU_USER_DEFINED_DYNAMIC_CONFIGS[@]}"
}

bu_source_user_defined_pre_init_callbacks()
{
    bu_source_multi_once "${BU_USER_DEFINED_STATIC_PRE_INIT_ENTRYPOINT_CALLBACKS[@]}"
    bu_source_multi "${BU_USER_DEFINED_DYNAMIC_POST_ENTRYPOINT_CALLBACKS[@]}"
}

bu_source_user_defined_post_entrypoint_callbacks()
{
    bu_source_multi_once "${BU_USER_DEFINED_STATIC_POST_ENTRYPOINT_CALLBACKS[@]}"
    bu_source_multi "${BU_USER_DEFINED_DYNAMIC_POST_ENTRYPOINT_CALLBACKS[@]}"
}

# ```
# *Params*
# - `$1`: Command to convert to a key
#
# *Returns*
# - `$BU_RET`: Key. By default it will be of the form `command-$1`, but users can override the behavior with user defined functions in `${BU_USER_DEFINED_COMPLETION_COMMAND_TO_KEY_CONVERSIONS[@]}`.
#              The first user defined function to perform the conversion successfully will take priority.
#
# Each function will be of the following signature
# *Function Params*
# - `$1`: Command to convert to a key
#
# *Function Returns*
# - Exit code:
#   - 0: Function successfully maps command to a key
#   - 1 or any other non-zero exit code: Mapping is unsuccessful
# - `$BU_RET`: If exit code is 0, then this should be the key
# ```
bu_user_defined_convert_command_to_key()
{
    local command=$1
    local fn
    for fn in "${BU_USER_DEFINED_COMPLETION_COMMAND_TO_KEY_CONVERSIONS[@]}"
    do
        "$fn" "$command"
        if (($? == 0))
        then
            return
        fi
    done
    BU_RET=command-$command # default conversion
}

# ```
# *Params*
# - `$1`: Command to convert to a key
#
# *Returns*
# - `$BU_RET`: Key. By default it will be of the form `command-$1`, but users can override the behavior with user defined functions in `${BU_USER_DEFINED_COMPLETION_COMMAND_TO_KEY_CONVERSIONS[@]}`.
#              The first user defined function to perform the conversion successfully will take priority.
#
# Each function will be of the following signature
# *Function Params*
# - `$1`: Command to convert to a key
#
# *Function Returns*
# - Exit code:
#   - 0: Function successfully maps command to a key
#   - 1 or any other non-zero exit code: Mapping is unsuccessful
# - `$BU_RET`: If exit code is 0, then this should be the key
# ```
bu_user_defined_autocomplete_lazy()
{
    local fn
    for fn in "${BU_USER_DEFINED_}"
    do
        :
    done
}
