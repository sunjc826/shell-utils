These are the builtin `bu` commands.
There are 3 ways of invoking them.
1. They are found through `bu`, e.g. `bu make-script ...`. Note that to the `bu-` prefix and the `.sh` suffix are stripped out. See [__bu_remove_bu_prefix](../core/bu_core_preinit.sh).
2. They can be invoked directly because shell-utils/lib/commands has been added to PATH (assuming bu-entrypoint has been sourced). `bu-make-script.sh ...`
3. Even without having sourced `bu_entrypoint.sh`, a script can be executed directly! E.g. `/path/to/lib/commands/bu-make-script.sh ...`. E.g. on my machine: `/home/sunjc/Documents/shell-utils/lib/commands/bu-make-script.sh --help`.
