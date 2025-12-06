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
will result in the `mycli` as the core CLI rather than `bu`. There are other tweakable aspects of shell-utils, as we will list out below.

### Tweaking
Let us denote the following "datatype" as FunctionOrScriptArray: An array of function names or script names. Usually, the way such an array is used is that each element will be called in turn, if it is a function, it is invoked with zero or more arguments, otherwise if it is a script, then it is sourced. (Note: sourced, not executed!)

- `BU_USER_DEFINED_STATIC_CONFIGS`: FunctionOrScriptArray
- `BU_USER_DEFINED_DYNAMIC_CONFIGS`: FunctionOrScriptArray
- `BU_USER_DEFINED_STATIC_PRE_INIT_ENTRYPOINT_CALLBACKS`: FunctionOrScriptArray
- `BU_USER_DEFINED_DYNAMIC_POST_ENTRYPOINT_CALLBACKS`: FunctionOrScriptArray
- `BU_USER_DEFINED_STATIC_POST_ENTRYPOINT_CALLBACKS`: FunctionOrScriptArray
- `BU_USER_DEFINED_DYNAMIC_POST_ENTRYPOINT_CALLBACKS`: FunctionOrScriptArray
- `BU_USER_DEFINED_COMPLETION_COMMAND_TO_KEY_CONVERSIONS`: FunctionOrScriptArray
- `BU_USER_DEFINED_AUTOCOMPLETE_HELPERS`: FunctionOrScriptArray
- `BU_USER_DEFINED_CLI_COMMAND_NAME`: String


