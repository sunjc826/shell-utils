case "${BASH_SOURCE}" in
*/*) pushd "${BASH_SOURCE%/*}" &>/dev/null ;; # Enter the current directory
*) pushd . &>/dev/null ;; # This seems like duplicate work but we need to match the popd later
esac

source ./bu_entrypoint.sh

bu import-environment --command-dir "$BU_DIR"/examples/commands --namespace-style prefix

popd &>/dev/null
