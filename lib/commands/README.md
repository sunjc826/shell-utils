These are the builtin subcommands.
There are 2 ways of invoking them.
1. They are found through `bu`, e.g. `bu make-script ...`. Note that to the `bu-` prefix and the `.sh` suffix are stripped out. See [__bu_remove_bu_prefix](../core/bu_core_preinit.sh).
2. They can be invoked directly because shell-utils/lib/commands has been added to PATH. `bu-make-script.sh ...`
