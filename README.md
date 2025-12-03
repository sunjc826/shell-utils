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

