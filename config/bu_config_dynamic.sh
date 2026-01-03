# shellcheck source=./bu_config_static.sh
source "$BU_NULL"

# ```
# Whether to ignore cache when running bu_cached_execute
# ```
BU_INVALIDATE_CACHE=false

# ```
# The log-level when running commands
# ```
BU_LOG_LVL=$BU_LOG_LVL_INFO
# ```
# The log-level when hitting TAB.
# In general, this should only log errors to avoid cluttering the
# autocomplete suggestions.
# ```
BU_AUTOCOMPLETE_LOG_LVL=$BU_LOG_LVL_ERR

BU_AUTOCOMPLETE_BIND_FZF_DISPLAY_METADATA=true

BU_AUTOCOMPLETE_BIND_TAB_TO_FZF=true
