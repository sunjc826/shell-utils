---
layout: page
title: "How To: The bash-utils workflow"
permalink: /how-to-02-bash-utils-workflow/
nav-order: 4
---

An example on how bash-utils can complement a project. We use Python as an example.

`${PROJECT_DIR}/deps`: Place bash-utils here with `git submodule add git@github.com:sunjc826/bash-utils.git`

`${PROJECT_DIR}/activate`: activation script to enable the environment for the project

```bash
#!/usr/bin/env bash
# Sample project activation script, replace PROJECT with the name of your project
function PROJECT_activate()
{
local PROJECT_invocation_dir=$PWD
pushd "$(dirname -- "$BASH_SOURCE")" &>/dev/null
local PROJECT_dir=$PWD

# project variables can be placed into a .env file for convenience
if [[ -f ./.env ]]
then
    source ./.env
fi

# Option parsing
while (($#))
do
case "$1" in
--option1)
    # Do something
    ;;
*)
    echo "Unsupported option $1" >&2
    popd &>/dev/null
    return 1
        ;;
esac
done

# Generally speaking, bash-utils should have very few if any conflicts with other environments since
# all commands and variables are prefixed with BU_/bu_
if command -v bu &>/dev/null
then
    bu import-environment --reset-leaky --no-init
fi
if [[ "$BU_MODULE_PATH" != */PROJECT_bu_module.sh* ]]
then
    BU_MODULE_PATH+=:$PROJECT_dir/PROJECT_bu_module.sh
fi

source ./deps/shell-utils/bu_entrypoint.sh
bu_scope_push_function
bu_scope_add_cleanup bu_popd_silent

# Python environment if any (only relevant to python projects)
if [[ -d .venv ]]
then
    source .venv/bin/activate
fi

# Any other completion specs useful to the project
# E.g. if using uv package manager
if command -v uv &>/dev/null
then
    eval "$(uv generate-shell-completion bash)"
fi
# E.g. if using shtab completion generator
if command -v shtab &>/dev/null
then
    eval "$(shtab --shell=bash shtab.main.get_main_parser)"
    # Other parsers
    eval "$(shtab --shell=bash --prog=command1 package1.module1._get_parser)"
fi

bu_scope_pop_function
}

PROJECT_activate "$@"
```

`${PROJECT_DIR}/PROJECT_bu_module.sh`
```bash
PROJECT_DIR=$(realpath -- "$(dirname -- "${BASH_SOURCE}")")
BU_USER_DEFINED_STATIC_PRE_INIT_ENTRYPOINT_CALLBACKS+=(
    "$PROJECT_DIR"/PROJECT_bu_preinit.sh
)

```

`${PROJECT_DIR}/PROJECT_bu_preinit.sh`
```bash
#!/usr/bin/env bash
# shellcheck source=./commands/__bu_entrypoint_decl.sh
source "$BU_NULL"
bu_pushd_current "$BASH_SOURCE"
bu_preinit_register_new_alias mk build-PROJECT-project --chapter {} {} {?} --make-target {}
bu import-environment +i -c ./commands -ns prefix
bu_popd_silent
```

Place custom commands inside `${PROJECT_DIR}/commands`.
