# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BashTab is a Bash scripting framework providing intelligent autocompletion, argument parsing, IDE integration, and modern CLI tools. It stays 100% in Bash with no DSL or YAML conversion.

## Common Commands

### Testing

```bash
# Initialize test submodules (first time only)
git submodule update --init

# Run tests with parallel execution
source ./activate -t
bats --jobs "$((($(nproc) + 1) / 2))" ./test/test.bats
```

### Development Environment

```bash
source ./activate           # Standard activation
source ./activate -e        # Load examples environment
source ./activate -t        # Load test environment
```

### Build Single-File Distribution

```bash
source ./activate --__bu-inline ./inline.sh
```

## Architecture

### Core Modules (`/lib/core/`)

- **bu_core_base.sh** - Core utilities (filesystem, logging, string manipulation, arrays, caching)
- **bu_core_autocomplete.sh** - Autocompletion generation with lazy loading and script parsing
- **bu_core_cli.sh** - CLI command routing
- **bu_core_preinit.sh** - Pre-initialization for registering commands, key bindings, aliases
- **bu_core_tmux.sh** - Tmux orchestration and job management
- **bu_core_var.sh** - Global variable initialization

### Initialization Flow

1. `bu_entrypoint.sh` - Main entry point that orchestrates loading
2. Loads modules from `BU_MODULE_PATH`
3. Loads static config (`config/bu_config_static.sh`)
4. Loads dynamic config (`config/bu_config_dynamic.sh`)
5. Sources all core modules
6. Runs pre-init callbacks, then main init, then post-entrypoint callbacks

### Commands (`/commands/`)

Scripts named `bu-*.sh` that can be invoked via:
- `bu verb-noun ...`
- `bu-verb-noun.sh ...` (direct executable)

Command types: `execute` (new process), `source` (current shell), `function` (bash function)

## Creating New Commands

Use `bu new-command --dir commands --name my-command` to generate from template.

### Command Structure

All commands follow this pattern (see `lib/templates/script_template.sh`):

```bash
#!/usr/bin/env bash
function __bu_SCRIPT_NAME_main()
{
# 1. Setup: get script location, pushd to script dir
local -r invocation_dir=$PWD
local script_name script_dir
# ... path parsing ...
pushd "$script_dir" &>/dev/null

# 2. Source entrypoint (executable scripts only, skipped during autocomplete)
if [[ -z "$COMP_CWORD" ]]; then
    source "$BU_DIR"/bu_entrypoint.sh
fi

# 3. Initialize scope management
bu_exit_handler_setup
bu_scope_push_function
bu_scope_add_cleanup bu_popd_silent
bu_run_log_command "$@"

# 4. Declare local variables for options
local my_option=
local is_help=false
local error_msg=
local autocompletion=()
local shift_by=

# 5. Parse arguments in while loop
while (($#)); do
    bu_parse_multiselect $# "$1"
    case "$1" in
    -o|--option)# OPTION_HINT
        # Help text for this option (shown in autohelp)
        bu_parse_positional $# --hint "description"
        my_option=${!shift_by}
        ;;
    -f|--flag)# _FLAG
        # Help text for flag
        is_flag=true
        ;;
    -h|--help)# _FLAG
        is_help=true
        ;;
    *)
        bu_parse_error_enum "$1"
        break
        ;;
    esac
    if "$is_help"; then break; fi
    if (( $# < shift_by )); then
        bu_parse_error_argn "$1" $#
        break
    fi
    shift "$shift_by"
done

# 6. Handle autocomplete
if bu_env_is_in_autocomplete; then
    bu_autocomplete
    return 0
fi

# 7. Handle help
if "$is_help"; then
    bu_autohelp
    return 0
fi

# 8. Main logic here

# 9. Cleanup
bu_scope_pop_function
}

__bu_SCRIPT_NAME_main "$@"
```

### Comments in Case Statements (Autohelp Only)

Comments after case patterns are **purely for autohelp generation** and have no runtime effect:
- `# HINT` after case pattern - displayed in autocomplete preview
- `# _FLAG` - marks option as a flag (no argument)
- Comment lines below the case pattern - help text shown in `--help` output

Runtime behavior is determined solely by `bu_parse_*` function calls.

### Parsing Functions

**`bu_parse_multiselect $# "$1"`** - Called at start of each case iteration. Tracks which options have been parsed to exclude them from future autocomplete suggestions. Sets `shift_by=1`. During autocomplete, it invokes an awk parser to extract all options from the enclosing case-esac block (via `--options-at FILE LINE`).

**`bu_parse_positional $# [DSL_ARGS...]`** - Parses the next positional argument. Increments `shift_by`. The value is accessed via `${!shift_by}`. DSL arguments control autocomplete behavior.

**`bu_parse_nested impl_func`** - Delegates parsing to another function for subcommand handling.

**`bu_parse_command_context --marker`** - Parses arguments until `marker--` is found, used for recursive command invocation.

**`bu_validate_positional "${!shift_by}"`** - Validates the parsed value against the autocompletion DSL (used after `--enum`).

### Autocomplete DSL

Arguments to `bu_parse_positional` are processed by `__bu_autocomplete_completion_func_master_helper`. Key DSL options:

| DSL Argument | Description |
|--------------|-------------|
| `--hint "text"` | Display hint text during autocomplete |
| `--enum val1 val2 ... enum--` | Offer literal values as completions |
| `:literal` | Add literal string (colon prefix, Ruby symbol style) |
| `--stdout cmd arg1 ... stdout--` | Run command, use stdout lines as completions |
| `--ret func arg1 ... ret--` | Run function, use `BU_RET` array as completions |
| `--options-at FILE LINE` | Parse case block at location for option completions |
| `--as-if cmd subcmd ... as-if--` | Delegate to another command's autocomplete |
| `--cwd DIR` | Change directory for completion context |
| `-a/--ansi COLOR` | Apply ANSI color to completions |

Example usages from commands:
```bash
# Enum with validation
bu_parse_positional $# --enum function execute source alias enum--
bu_validate_positional "${!shift_by}"

# Directory completion
bu_parse_positional $# "${BU_AUTOCOMPLETE_SPEC_DIRECTORY[@]}"

# Hint only
bu_parse_positional $# --hint "Name of the script"
```

### Sourceable vs Executable Scripts

**Executable** (`script_template.sh`): Sources `bu_entrypoint.sh`, uses `bu_exit_handler_setup`

**Sourceable** (`source_script_template.sh`): Assumes entrypoint already loaded, sources `$BU_NULL` for shellcheck

## Naming Conventions

- **Global variables**: `BU_*` prefix
- **Functions**: `bu_*` prefix
- **Return values**: `BU_RET` for strings/arrays, `BU_RET_MAP` for associative arrays
- **User customization**: `BU_USER_DEFINED_*` prefix

## Key Argument Parsing Functions

- `bu_parse_positional` - Positional arguments
- `bu_parse_multiselect` - Keyword arguments
- `bu_parse_nested` - Subparsers
- `bu_parse_command_context` - Recursive command calls

These functions unify parsing, autocompletion, and variable binding.

## Extension Mechanisms

Register via pre-init functions:
- `bu_preinit_register_user_defined_key_binding`
- `bu_preinit_register_user_defined_completion_func`
- `bu_preinit_register_user_defined_subcommand_dir`
- `bu_preinit_register_user_defined_subcommand_file`
- `bu_preinit_register_user_defined_subcommand_function`
- `bu_preinit_register_new_alias`

## Project Integration Pattern

1. Add BashTab as git submodule (e.g., `deps/shell-utils`)
2. Create project `activate` script
3. Create `PROJECT_bu_module.sh` for callbacks
4. Create `PROJECT_bu_preinit.sh` for pre-init setup
5. Place custom commands in `commands/` directory
6. Use `BU_MODULE_PATH` to register module paths

## Code Documentation

Use triple backtick markdown format for bash-language-server compatibility:
```bash
# ```md
# Description of function
#
# Params:
# - $1: description
#
# Returns:
# - BU_RET: description
# ```
function bu_example() { ... }
```

## Key Utilities

**Scope management (RAII-like cleanup)**:
- `bu_scope_push_function` / `bu_scope_pop_function`
- `bu_scope_add_cleanup`

**I/O conversion**:
- `bu_ret_to_stdout` / `bu_stdout_to_ret`

**Filesystem**:
- `bu_mkdir`, `bu_realpath`, `bu_basename`, `bu_dirname`

**Logging**:
- `bu_log_info`, `bu_log_err`, `bu_log_warn`
