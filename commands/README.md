These are the builtin `bu` commands.
There are 3 ways of invoking them.
1. They are found through `bu`, e.g. `bu new-script ...`. Note that the `bu-` prefix and the `.sh` suffix are stripped out. See [bu_convert_file_to_command_remove_prefix](../lib/core/bu_core_preinit.sh).
2. They can be invoked directly because shell-utils/lib/commands has been added to PATH (assuming bu-entrypoint has been sourced). `bu-new-script.sh ...`
3. Even without having sourced `bu_entrypoint.sh`, a script can be executed directly! E.g. `/path/to/commands/bu-new-script.sh ...`. E.g. on my machine: `/home/$USER/Documents/shell-utils/commands/bu-new-script.sh --help`.
