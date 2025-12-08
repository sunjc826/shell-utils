case "${BASH_SOURCE}" in
*/*) pushd "${BASH_SOURCE%/*}" &>/dev/null ;; # Enter the current directory
*) pushd . &>/dev/null ;; # This seems like duplicate work but we need to match the popd later
esac

source ./bu_entrypoint.sh

# Get access to the bats binary
bu_env_append_path "$BU_DIR"/test/bats/bin

# Run .bats tests
bu_env_append_path "$BU_DIR"/test

popd &>/dev/null
