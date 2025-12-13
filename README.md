# shell-utils

Function documentation format:
```sh
# ```
# *Description*
# Short description of function
#
# *Params*:
# - `$1`: Description
#
# *Returns*:
# - `$BU_RET`: Description
#
# *Example*:
# ```bash
# 
# ```
#
# *Notes*:
# - Note 1
# ```
```

The comments are meant to be parsed by [bash-language-server](https://github.com/bash-lsp/bash-language-server).
The way bash-language-server handles comments (as of writing) is that it wraps the comment in a txt code block, hence we need to wrap around the outside with an additional `` ``` ``. After that, whatever is inside is arbitrary markdown.


Variables:
`BU_RET` is used to return strings and non-associative arrays. Depending on the function, it is a scalar or an array.
Use `BU_` to namespace global variables. Use `bu_` to namespace functions. BU stands for Bash Utils.
The `BU_USER_DEFINED_` prefix indicates variables that are not defined anywhere within shell-utils. It is expected that the user defines them externally.


## Usage
Run this:
```sh
source ./bu_entrypoint.sh
```
Consider adding this to the .bashrc to always activate on load.

The core CLI is `bu`. Run `bu` directly to see the help.
The name of the core CLI is modifiable. For example,
```sh
BU_USER_DEFINED_CLI_COMMAND_NAME=mycli
source ./bu_entrypoint.sh
```
will result in the `mycli` as the core CLI rather than `bu`. Though `bu` is still defined for ease of scripting (i.e. both `mycli` and `bu` will be defined).
There are other tweakable aspects of shell-utils, as we will list out below.

### Tweaking
#### Using variables
Bash variables are all strings/arrays of strings/maps of strings, alongside some variable attributes (e.g. number `-i`, readonly `-r` etc.) but we can interpret them differently.
These variables are "declared" (really, it's for shellcheck hovering over hints) in [bu_user_defined_decl.sh](./bu_user_defined_decl.sh). 
The customizable variables all have the `BU_USER_DEFINED_` prefix.

Let us define the following conventional variable "types":
- `Function`: The variable name is a function
- `AbsPath[A]`: The variable name is an absolute path, where A is an optional annotation for the type of file we would expect at the end of the path. Some common annotations include:
  - ExecutableScript: A script that is executable
  - SourceableScript: A script that is meant to be sourced 
- `RelPath[A]`: The variable name is a relative path
- `Path[A]`: `AbsPath[A]|RelPath[A]`
- `Int`: The variable is an integer
- `T *`, or `Ref[T]`: The variable is a nameref to T, where T is some parameterized type.
- `Array[T]`: The variable is a Bash array of type T, where T is some parameterized type.
- `Map[K, V]`: The variable is a Bash associative array, where K, V are some parameterized types

Variable list:
- `BU_USER_DEFINED_STATIC_CONFIGS`: `Array[ Function | Path[SourceableScript] ]`
- `BU_USER_DEFINED_DYNAMIC_CONFIGS`: `Array[ Function | Path[SourceableScript] ]`
- `BU_USER_DEFINED_STATIC_PRE_INIT_ENTRYPOINT_CALLBACKS`: `Array[ Function | Path[SourceableScript] ]`
- `BU_USER_DEFINED_DYNAMIC_POST_ENTRYPOINT_CALLBACKS`: `Array[ Function | Path[SourceableScript] ]`
- `BU_USER_DEFINED_STATIC_POST_ENTRYPOINT_CALLBACKS`: `Array[ Function | Path[SourceableScript] ]`
- `BU_USER_DEFINED_DYNAMIC_POST_ENTRYPOINT_CALLBACKS`: `Array[ Function | Path[SourceableScript] ]`
- `BU_USER_DEFINED_COMPLETION_COMMAND_TO_KEY_CONVERSIONS`: `Array[Function]`
- `BU_USER_DEFINED_AUTOCOMPLETE_HELPERS`: `Array[Function]`
- `BU_USER_DEFINED_CLI_COMMAND_NAME`: `Function`

#### Using pre-init functions
Another point of customization are the pre-init functions. They are found in [bu_core_preinit.sh](./lib/core/bu_core_preinit.sh). They all have the `bu_preinit_` prefix.

- `bu_preinit_register_user_defined_key_binding`:
  - Description: Register a key binding for interactive shells. Values are stored in `BU_KEY_BINDINGS` and later applied via `bind -x`.
  - Params: `$1` = key sequence (e.g. `\ee`), `$2` = command/function to invoke.
  - Example: `bu_preinit_register_user_defined_key_binding '\em' my_custom_edit`

- `bu_preinit_register_user_defined_completion_func`:
  - Description: Register a completion function for a specific command. Mappings are stored in `BU_AUTOCOMPLETE_COMPLETION_FUNCS` and used to call `complete -F`.
  - Params: `$1` = command name, `$2` = completion function name.
  - Example: `bu_preinit_register_user_defined_completion_func mycmd __mycmd_completion`

- `bu_preinit_register_user_defined_subcommand_dir`:
  - Description: Register a directory containing subcommand scripts. Optionally provide a conversion function to transform file names to `verb-noun` command names.
  - Params: `$1` = directory path, `...` = optional conversion function and args.
  - Example: `bu_preinit_register_user_defined_subcommand_dir ~/my-commands bu_convert_file_to_command_namespace prefix`

- `bu_preinit_register_user_defined_subcommand_file`:
  - Description: Register a single script file as a `bu` subcommand.
  - Params: `$1` = file path, `$2` (optional) = command name (derived from filename if omitted), `$3` (optional) = type (`function`, `execute`, `source`).
  - Example: `bu_preinit_register_user_defined_subcommand_file ~/scripts/get-status.sh get-status execute`

- `bu_preinit_register_user_defined_subcommand_function`:
  - Description: Register an in-shell function as a `bu` subcommand.
  - Params: `$1` = function name, `$2` (optional) = command name, `$3` (optional) = type.
  - Example: `bu_preinit_register_user_defined_subcommand_function my_helper_func my-helper function`

- `bu_preinit_register_new_alias`:
  - Description: Create a `bu` alias that expands a positional-style invocation into a named-argument command. Alias specs use `{}` for a single positional, `{...}` for remaining input, and `{?}` for optional remaining input.
  - Params: `$1` = alias name, `$2..` = alias spec (see `bu_preinit_register_new_alias` for syntax rules).
  - Example: `bu_preinit_register_new_alias gc get-command --namespace {} {?} --verb {} {?} --noun {} {...}`

