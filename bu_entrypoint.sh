source ./bu_custom_source.sh --__bu-once

source ./config/bu_config_static.sh --__bu-once
source ./config/bu_config_dynamic.sh

case "${BASH_SOURCE}" in
*/*) pushd "${BASH_SOURCE%/*}"/lib/core &>/dev/null
*) pushd ./lib/core;;;
esac

source ./lib/core/bu_core_base.sh --__bu-once

popd &>/dev/null
