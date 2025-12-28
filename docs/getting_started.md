---
layout: page
title: Getting Started
permalink: /getting-started/
nav-order: 2
---

## Installation

### 1. Clone the Repository

Start by cloning the bash-utils repository:

```bash
git clone git@github.com:sunjc826/bash-utils.git
cd bash-utils
```

### 2. Install Optional Dependencies

While bash-utils works without additional dependencies, we recommend installing `fzf` for enhanced interactive features:

**On Debian-based systems (Ubuntu, Debian, etc.):**
```bash
sudo apt install fzf
```

**Other systems:**
Refer to the [fzf installation guide](https://github.com/junegunn/fzf#installation)

## Initialization

### Activate bash-utils

Once you have the repository cloned, initialize bash-utils by sourcing one of the activation scripts from the repository root:

```bash
source ./activate
```

Alternatively, you can source the main entrypoint directly:

```bash
source ./bu_entrypoint.sh
```

### Expected Output

After sourcing the activation script, you should see the following debug and info messages:

```
DEBUG   sourcing(--__bu-once) ./lib/core/bu_core_user_defined.sh
DEBUG   sourcing(--__bu-once) ./config/bu_config_static.sh
DEBUG   sourcing(--__bu-once) ./lib/core/bu_core_var.sh
DEBUG   sourcing(--__bu-once) ./lib/core/bu_core_base.sh
DEBUG   sourcing(--__bu-once) ./lib/core/bu_core_autocomplete.sh
DEBUG   sourcing(--__bu-once) ./lib/core/bu_core_tmux.sh
DEBUG   sourcing(--__bu-once) ./lib/core/bu_core_cli.sh
DEBUG   sourcing(--__bu-once) ./lib/core/bu_core_preinit.sh
DEBUG   sourcing(--__bu-once) dotfiles_bu_pre_init_entrypoint
INFO    bu_core_init.sh:48[__bu_init_vscode] code cli already initialized, to force VSCode CLI setup again, run unset -v VSCODE_IPC_HOOK_CLI
INFO    bu_entrypoint.sh:93[source] Bash utils: fully set up
```

These messages indicate that bash-utils has been successfully initialized and all core modules have been loaded.

## Using bash-utils

### Discover Available Commands

Type `bu` in your terminal to see all available commands and features:

```bash
bu
```

### Expected Output

You should see a help message similar to:

```
WARN    bu_impl.sh:78[__bu_impl] No arguments specified, printing help
Help for bu
bu is the Bash CLI implemented by bash-utils

The following commands using a new shell context are available

    new-command                       /home/sunjc/Documents/bash-utils/commands/bu-new-command.sh

The following commands using the current shell context are available

    get-command                       /home/sunjc/Documents/bash-utils/commands/bu-get-command.sh
    import-environment                /home/sunjc/Documents/bash-utils/commands/bu-import-environment.sh
    invoke-cached-command             /home/sunjc/Documents/bash-utils/commands/bu-invoke-cached-command.sh
    invoke-enhanced-command           /home/sunjc/Documents/bash-utils/commands/bu-invoke-enhanced-command.sh
    invoke-spawn-command              /home/sunjc/Documents/bash-utils/commands/bu-invoke-spawn-command.sh

The following functions are available


The following aliases are available

    gc                                get-command --namespace {} {?} --verb {} {?} --noun {} {...}

The following key bindings are available

    \C-@ -> __bu_bind_fzf_autocomplete_dynamic
    \C-x -> __bu_bind_fzf_autocomplete
    \ea -> __bu_bind_fzf_history
    \ec -> __bu_bind_fzf_autocomplete_dynamic
    \ee -> __bu_bind_fzf_edit
    \eg -> __bu_bind_toggle_gdb
    \et -> dotfiles_bind_tmux_on_off
    \ex -> __bu_bind_fzf_autocomplete
```

This output shows you all the commands and keybindings available in your bash-utils installation.

### Query Commands with get-command

To explore all available commands and aliases in more detail, use the `get-command` command:

```bash
bu get-command
```

This command is inspired by PowerShell's `Get-Command` and is used to query all commands and aliases installed with `bu`. It provides a powerful way to discover and filter the available functionality.

#### Using Bash Completions

For an interactive way to explore commands, type `bu` followed by a space and then press **TAB** twice:

```bash
bu <TAB>
```

Bash completions will list all available commands:

```
$ bu
gc                       import-environment       invoke-enhanced-command  new-command
get-command              invoke-cached-command    invoke-spawn-command
```

Now type `bu get-command` and press **TAB** twice to see the available options:

```bash
bu get-command <TAB><TAB>
```

Bash completions will show all available flags and options:

```
$ bu get-command
--                       --help                   +ns                      -v
--allow-empty-namespace  +n                       -ns                      --verb
--allow-empty-noun       -n                       -t
--allow-empty-verb       --namespace              --type
-h                       --noun                   +v
```

Notice there's a `--help` flag available. Let's check it out:

```bash
bu get-command --help
```

This displays the full help documentation with all available options:

```
$ bu get-command --help
Help for /home/sunjc/Documents/bash-utils/commands/bu-get-command.sh

OPTIONS

-v,--verb
        Glob pattern to filter by verb

+v,--allow-empty-verb
        If a command has no associated verb, it is also included in the results

-n,--noun
        Glob pattern to filter by noun

+n,--allow-empty-noun
        If a command has no associated noun, it is also included in the results

-ns,--namespace
        Glob pattern to filter by namespace

+ns,--allow-empty-namespace
        If a command has no associated namespace, it is also included in the results

-t,--type
        Type of the command

--
        Remaining options will be collected

-h,--help
        Print help
```

As you can see, options have both short and long forms (e.g., `-v` or `--verb`, `-n` or `--noun`), and each option includes a description explaining what it does. This makes it easy to query and filter commands based on different criteria.

## Querying Commands

Now let's use `get-command` to actually filter and discover commands. Here are some practical examples:

### Filter by Namespace

To query all commands namespaced under `bu`, type:

```bash
bu get-command -ns bu
```

Output:
```
$ bu get-command -ns bu
get-command
import-environment
invoke-cached-command
invoke-enhanced-command
new-command
invoke-spawn-command
```

The namespace is derived from the command script's filename. For example, `get-command` links to `bu-get-command.sh`, where the `bu-` prefix indicates the `bu` namespace.

Note that `gc` is an alias and doesn't have an associated namespace, so it's not included in the results above. To include commands without a namespace, use the `+ns` flag:

```bash
bu get-command -ns bu +ns
```

Output:
```
$ bu get-command -ns bu +ns
get-command
import-environment
invoke-cached-command
invoke-enhanced-command
new-command
invoke-spawn-command
gc
```

The `+ns` flag includes any commands or aliases that don't have an associated namespace.

### Filter by Verb

Another useful way to query is by verb. The verb describes the high-level action taken by the command, for example, `get` suggests that we are querying or retrieving some info without modifying any underlying state. Type `bu get-command --verb` and press **TAB** twice to see available verbs:

```bash
bu get-command --verb <TAB><TAB>
```

Output:
```
$ bu get-command --verb
get     import  invoke  new
```

Now, if you want to see all commands related to invoking other commands:

```bash
bu get-command --verb invoke
```

Output:
```
$ bu get-command --verb invoke
invoke-cached-command
invoke-enhanced-command
invoke-spawn-command
```

This filtering makes it easy to discover related functionality and understand how bash-utils is organized.

## What's Next?

Now that you have bash-utils installed and initialized, you can:
- Explore the available commands by using `bu COMMAND_NAME` with different command names
- Create custom commands with `bu new-command`
- Configure bash-utils for your specific workflows

For more information, check out the [README](../README.md) or explore the [commands documentation](../commands/README.md).
