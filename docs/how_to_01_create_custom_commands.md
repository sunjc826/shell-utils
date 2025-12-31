---
layout: page
title: "How To: Creating custom commands"
permalink: /how-to-01-create-custom-commands/
nav-order: 3
---

In this How-To, let us look at how to create a new command.

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

Note that even in the subshell approach, bash-utils style autocompletion requires the parsing and autocompletion part to be outside a subshell since it needs to communicate state back to the current shell environment via variables.




