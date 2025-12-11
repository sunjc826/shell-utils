These are the builtin `bu` commands.
For the executable scripts, there are 3 ways of invoking them.
1. They are found through `bu`, e.g. `bu new-command ...`. Note that the `bu-` prefix and the `.sh` suffix are stripped out. See [bu_convert_file_to_command_remove_prefix](../lib/core/bu_core_preinit.sh).
2. They can be invoked directly because shell-utils/lib/commands has been added to PATH (assuming bu-entrypoint has been sourced). `bu-new-command.sh ...`
3. Even without having sourced `bu_entrypoint.sh`, a script can be executed directly! E.g. `/path/to/commands/bu-new-command.sh ...`. E.g. on my machine: `/home/$USER/Documents/shell-utils/commands/bu-new-command.sh --help`.

For the non-executable scripts, they are meant to be sourced. There are 3 ways of sourcing them.
1. They are found through `bu`, e.g. `bu import-environment ...`.
2. They can be sourced without the full path because shell-utils/lib/commands has been added to PATH (assuming bu-entrypoint has been sourced). `source bu-import-environment.sh ...`
3. Note that `source /path/to/commands/bu-import-environment.sh ...` does not work without having sourced `bu_entrypoint.sh` first. The sourceable scripts all assume that the user is already in a bu environment.
```sh
source /path/to/bu_entrypoint.sh # This is necessary for sourceable scripts
source /path/to/commands/bu-import-environment.sh ...
```
