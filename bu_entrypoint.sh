case "${BASH_SOURCE}" in
*/*) pushd "${BASH_SOURCE%/*}" &>/dev/null ;; # Enter the current directory
*) pushd . &>/dev/null ;; # This seems like duplicate work but we need to match the popd later
esac

source ./bu_custom_source.sh --__bu-once
source ./bu_user_defined.sh --__bu-once

source ./config/bu_config_static.sh --__bu-once
source ./config/bu_config_dynamic.sh

bu_source_user_defined_configs

source ./lib/core/bu_core_base.sh --__bu-once
source ./lib/core/bu_core_autocomplete.sh --__bu-once
source ./lib/core/bu_core_preinit.sh --__bu-once

bu_source_user_defined_pre_init_callbacks

source ./lib/core/bu_core_init.sh

popd &>/dev/null

bu_source_user_defined_post_entrypoint_callbacks

bu_log_info "Bash utils: fully set up"
