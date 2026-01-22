---
layout: page
title: "How To: Creating custom commands"
permalink: /how-to-01-create-custom-commands/
nav-order: 3
---

In this How-To, let us look at how to create a new command.

We will use `bu new-command` to create a command from a template. As of writing, its synopsis is
```
bu new-command [-d|--dir SCRIPT_DIR] [-n|--name SCRIPT_NAME] [-f|--force] [--source] [--directory-irrelevant] [-h|--help]
``` 

When creating a new command, there are 3 questions we should ask:
1. Should the command be run in the current shell environment? Does the script want to modify the current shell environment?
2. Where should the command be placed? We may want to put different kinds of tools into different directories.
3. How should the command be named? Specifically, what is its namespace, verb, and noun?

Suppose we want a command to pretty print some of the current shell's variables. Note: The current shell's variables is usually a strict super-set of the environment variables, which are exported to child processes.
If we were to execute a new shell (e.g. `bash ...`), we will not have access to the current shell's full environment, for e.g. any Bash variable we defined but did not export is not available. Thus, we must run the command in the current shell environment.
In the current environment, we should decide whether to wrap the logic in a subshell. For e.g.
Wrapping logic in a subshell
```sh
(
    # place logic here
    :
)
```
Wrapping logic in a subshell function
```sh
function subshell_func()
(
    # place logic here
    return 0 # exit 0 is also fine
)
subshell_func
```

Not wrapping logic in a subshell
```sh
{
    # place logic here
    :
}
```
Wrapping logic in a non-subshell function
```sh
function func()
{
    # place logic here
    return 0 # Cannot use exit 0
}
func
```

The pros and cons of using a subshell:

| Category | Pros | Cons |
|---|---|---|
| Isolation | Runs in a separate process so side-effects (vars, cwd, file descriptors) don't affect the parent shell — safe for temporary changes. | Cannot modify parent shell state (variables, `cd`, `umask`, or traps), changes are lost to the caller. Performance is also worse since forking is involved (for Bash subshells). |
| Safety | `exit` terminate only the subshell, not your interactive shell or calling script. This means `set -e` is viable here without killing the calling shell. | Harder to propagate intermediate state or side-effects; must serialize results to communicate back. |
| Resource Scope | Localizes temporary file descriptors and redirects to the subshell; cleanup happens automatically. | Cannot directly return complex structured state, must use stdout, files, or environment files to pass data. |

Since we only want to print the shell's environment, we do not need to modify the shell state. This means the drawbacks to using a subshell are of no effect to us. However, we also don't really have any complex logic that would make the guarantees provided by `set -e` very attractive. Hence, for this How-To, let us go with a completely non-sub-shell approach.

Note that even in the subshell approach, BashTab style autocompletion requires the parsing and autocompletion part to be outside a subshell since it needs to communicate state back to the current shell environment via variables.

We have answered part 1. The relevant `bu new-command` option is the `--source` flag.

Next, we want to decide where to place the script. Let's put this in `BashTab-examples/commands`. The relevant `bu new-command` option is `--dir DIRECTORY`. If we press TAB after `--dir`, we might see autocompletions for `BashTab/commands` only. That's because we have not registered `BashTab-examples/commands` as a command search directory. This registration is done by `bu_preinit_register_user_defined_subcommand_dir` which is intended to be used by scripts sourcing BashTab as a dependency.

Finally, we want to pick a name for the script. Script names should follow all lower case kebab style as it provides various benefits: Dashes are easier to type than underscores. We can also better distinguish commands from functions, which conventionally use underscores. Bash does not have the same level of case insensitivity that Powershell does, and all lower-case letters are easier to type as well.
For greater structure, the name of a script can be split into 3 components, namespace, verb, and noun.
Namespace are useful for distinguishing commands that come from different repositories.
The verb-noun naming scheme is inspired by Powershell, as it makes it easier to tell roughly what kind of action is taken by the command, and on what resource does it operate on. A namespace consists of one word.
Verb: There is no particular standard for this, but for consistency, we can follow the [Powershell verbs](https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands?view=powershell-7.5). It is assumed that the verb is one word. Words are separated by dashes, so a verb cannot have any dashes in it.
Noun: A noun can consist of one or more word, separated by dashes. A noun can generally be anything, there are no guidelines here, just make it intuitive what the noun refers to.

For our example command, we might set
- Namespace: buex (for bu examples)
- Verb: get (print might be fine too, but get is more Powershell-like)
- Noun: envvars (we could also use environment-variables, but that is quite long)

There are a few conventional ways we can arrange this:
Namespace-Verb-Noun: buex-get-envvars
Verb-Namespace-Noun: get-buex-envvars (Powershell style)

Let's go with Namespace-Verb-Noun. The relevant `bu new-command` option is `--name SCRIPT_NAME`.

We also add the `--no-chdir` option because we do not need to change directories when we're just printing the shell environment.

The final invocation is
```bash
bu new-command \
  --source \
  --dir /path/to/BashTab-examples/commands \
  --name buex-get-envvars \
  --no-chdir
```

We will see the following scaffolding:
```bash
#!/usr/bin/env bash
function __bu_buex_get_envvars_main()
{

# Note that we do not source bu_entrypoint inside the sourceable script template
# as it is assumed that sourceable scripts are sourced AFTER 
# bu_entrypoint has been sourced by the user.

# shellcheck source=./__bu_entrypoint_decl.sh
source "$BU_NULL"
bu_scope_push_function
bu_run_log_command "$@"

local is_help=false
local error_msg=
local options_finished=false
local autocompletion=()
local shift_by=
while (($#))
do
    bu_parse_multiselect $# "$1"
    case "$1" in
    -h|--help)
        # Print help
        is_help=true
        ;;
    --)
        # Remaining options will be collected
        options_finished=true
        shift
        break
        ;;
    *)
        bu_parse_error_enum "$1"
        break
        ;;
    esac
    if "$is_help"
    then
        break
    fi
    if (( $# < shift_by ))
    then
        bu_parse_error_argn "$1" $#
        break
    fi
    shift "$shift_by"
done
local remaining_options=("$@")
if bu_env_is_in_autocomplete
then
    bu_autocomplete
    return 0
fi

if "$is_help"
then
    bu_autohelp
    return 0
fi

bu_scope_pop_function
}

__bu_buex_get_envvars_main "$@"
```

We can now plan out which options to support.
- `--all` / `-a`: include both exported environment variables and non-exported shell variables.
- `--exported` / `--env`: show only exported environment variables (default behavior).
- `--pattern` / `-p`: filter variable names by glob or regex (you can choose a convention like `re:PATTERN` to indicate regex).
- `--prefix` / `-P`: show only variables whose names start with the given prefix.
- `--format` / `-f`: choose output format. Suggested values: `plain` (default), `json`, `yaml`, `sh` (export KEY=VAL lines).


First, add these to the `case` block:
```sh
case "$1" in
-a|--all);;
--env|--exported);;
-p|--pattern);;
-P|--prefix);;
-f|--format);;
-h|--help)
    # Print help
    is_help=true
    ;;
--)
    # Remaining options will be collected
    options_finished=true
    shift
    break
    ;;
*)
    bu_parse_error_enum "$1"
    break
    ;;
esac
```

