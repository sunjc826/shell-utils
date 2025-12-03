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
