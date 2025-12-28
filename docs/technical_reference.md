---
layout: page
title: Technical Reference
permalink: /technical-reference/
nav-order: 5
---

## Development & Contributing

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