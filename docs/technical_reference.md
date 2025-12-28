---
layout: page
title: Technical Reference
permalink: /technical-reference/
nav-order: 5
---

## Using bu as a scripting dependency
The following variables and functions are used by libraries invoking bash-utils to change its behavior at initialization time.

### Initialization variables
Bash variables are all strings/arrays of strings/maps of strings, alongside some variable attributes (e.g. number `-i`, readonly `-r` etc.) but we can interpret them differently.
These variables are "declared" (really, it's for shellcheck hovering over hints) in [bu_user_defined_decl.sh][bu_user_defined_decl].

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

### Initialization callable functions
Another point of customization are the pre-init functions. They are found in [bu_core_preinit.sh][bu_core_preinit]. They all have the `bu_preinit_` prefix.

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


## Development & Contributing

### Code structure
The core library is in [core][core]
- [bu_core_base.sh][bu_core_base] provides the core library functions for the framework
- [bu_core_autocomplete.sh][bu_core_autocomplete] provides the autocompletion functionality for the `bu` command and the scripts it invokes.

There are library functions that are not used by the core scripting framework, but are nonetheless useful in writing your own scripts.
- [bu_core_tmux.sh][bu_core_tmux] provides imperative utilities (`bu_spawn`) for orchestrating jobs across tmux panes.

### Running Tests

bash-utils uses the [BATS (Bash Automated Testing System)](https://github.com/bats-core/bats-core) framework for unit testing. Currently, tests are written for the core functions.

#### Prerequisites

Initialize BATS submodules if not already done:

```sh
git submodule update --init
```

#### Running the Test Suite

Source the test entrypoint to add BATS to your PATH:

```sh
source ./bu_test_entrypoint.sh
```

Alternatively, you can use the activate script with the `-e` flag:

```sh
source ./activate -e
```

Then run the tests with BATS:

```sh
# Run tests in parallel using half of available CPU cores
bats --jobs "$((($(nproc) + 1) / 2))" ./test/test.bats
```

You can also run the test script directly (hardcoded to use 16 jobs):

```sh
./test/test.bats
```

### Code Documentation Standards

This project follows a consistent documentation format for functions and variables, designed to work with [bash-language-server](https://github.com/bash-lsp/bash-language-server).

#### Function Documentation Format

Functions should be documented with the following format:

```sh
# ```
# *Description*
# Short description of function
#
# *Params*:
# - `$1`: Description of first parameter
# - `$2`: Description of second parameter
#
# *Returns*:
# - `$BU_RET`: Description of return value
#
# *Example*:
# ```bash
# function_name "arg1" "arg2"
# ```
#
# *Notes*:
# - Important note 1
# - Important note 2
# ```
```

The outer triple backticks allow bash-language-server to properly parse the markdown documentation inside the comments.

#### Variable Naming Conventions

- **Global Variables**: Prefix with `BU_` to namespace them within bash-utils (e.g., `BU_VERSION`, `BU_CONFIG_PATH`)
- **Functions**: Prefix with `bu_` to namespace them (e.g., `bu_init`, `bu_parse_args`)
- **Return Values**: 
  - Use `BU_RET` to return strings and non-associative arrays. The value can be either scalar or array depending on the function's purpose
  - Use `BU_RET_MAP` to return associative arrays.
- **User-Defined Variables**: Prefix with `BU_USER_DEFINED_` for variables that are expected to be defined externally by users

### Building a Single-File Distribution

To consolidate the entire bash-utils library into a single file for easier distribution or embedding:

```sh
source ./activate --__bu-inline ./inline.sh
```

This generates an `inline.sh` file containing the complete bash-utils library.
`--__bu-inline` makes certain assumptions about where source statements are invoked, so this might break at some points.


{% capture github_base %}{{ site.github.repository_url }}/blob/{{ site.github.build_revision }}/{% endcapture %}
{% capture links %}

[commands]: ../commands/
[bu-import-environment]: ../commands/bu-import-environment.sh
[bu-get-command]: ../commands/bu-get-command.sh
[bu-new-command]: ../commands/bu-new-command.sh
[bu-run-example]: ../examples/commands/bu-run-example.sh
[bu_user_defined_decl]: ../bu_user_defined_decl.sh
[bu_core_preinit]: ../lib/core/bu_core_preinit.sh
[core]: ../lib/core/
[bu_core_base]: ../lib/core/bu_core_base.sh
[bu_core_autocomplete]: ../lib/core/bu_core_autocomplete.sh
[bu_core_tmux]: ../lib/core/bu_core_tmux.sh

{% endcapture %}
<!-- https://shopify.github.io/liquid/filters/replace_first/ -->
<!-- https://stackoverflow.com/questions/27694610/how-can-i-split-a-string-by-newline-in-shopify -->
{% assign links_list = links | newline_to_br | split: '<br />' %}
{% for link in links_list %}
{{ link | replace_first: "../", github_base }}
{% endfor %}
