# shellcheck source=./bu_core_base.sh
source "$BU_NULL"

# shellcheck source=../../bu_user_defined.sh
source "$BU_NULL"

# MARK: Parsers
__BU_AUTOCOMPLETE_WORKING_DIRECTORY=.
__BU_AUTOCOMPLETE_OPTION_REGEX='([-[:alnum:]_/]+[[:space:]]*\|?[[:space:]]*)*[-[:alnum:]_/]+[[:space:]]*'

# ```
# *Description*:
# Append the content of a file to an existing array variable, splitting by lines
#
# *Params*:
# - `$1`: File to read
# - `$2` (optional): Name of the array variable to append to (default: `BU_RET`)
#
# *Returns*:
# - `${BU_RET[@]}` or the array variable named in `$2`: Content of the file appended to the array
#
# *Examples*:
# ```bash
# bu_cat_arr_append /path/to/file # ${BU_RET[@]} has the file content appended
# bu_cat_arr_append /path/to/file MY_ARR # ${MY_ARR[@]} has the file content appended
# ```
# ```
bu_cat_arr_append()
{
    local file=$1
    local ret=${2:-BU_RET}
    mapfile -t <"$file"
    eval "$ret"+=\( \"\${MAPFILE[@]}\" \)
}

# ```
# *Description*:
# Parses out all the cases inside a case block. 
#
# *Params*
# - `$1`: Function name or script path to parse
# - `$2` (optional): Start indicator regex (default: `case .* in`)
# - `$3` (optional): End indicator regex (default: `esac`)
# - `$4` (optional): Start line number of the function/script (default: 1)
#
# *Returns*:
# - `stdout`: List of options inside the case block, separated by newlines and spaces
#
# *Examples*:
# ```bash
# bu_autocomplete_parse_case_block_options my_function
# bu_autocomplete_parse_case_block_options /path/to/script.sh
# ```
# ```
bu_autocomplete_parse_case_block_options()
{
    local function_or_script_path=$1
    local start_indicator=${2:-'case .* in'}
    local end_indicator=$3
    local start_lineno=${4:-1}

    start_indicator=/$start_indicator/
    if [[ -z "$end_indicator" ]]
    then
        end_indicator='! is_in_option && /^[[:space:]]*esac[[:space:]]*/'
    else
        end_indicator=/$end_indicator/
    fi

    if bu_symbol_is_function "$function_or_script_path"
    then
        declare -f "$function_or_script_path"
    else
        cat "$function_or_script_path"
    fi |\
    awk '
    BEGIN {
        is_start = 0
        is_in_option = 0
    }
    NR < '"$start_lineno"' { next }
    ! is_start && '"$start_indicator"' {
        is_start = 1
        is_in_option = 0
    }

    ! is_start { next }

    { line = $0 }

    ! is_in_option && ( \
        ( /^[[:space:]]*'"$__BU_AUTOCOMPLETE_OPTION_REGEX"'\)/ && gsub( /\).*/, "", line ) \
        || \
        ( /^[[:space:]]*'"$__BU_AUTOCOMPLETE_OPTION_REGEX"'\|\\/ && gsub( /\|\\/, "", line ) ) \
    ) {
        print line
    }

    { line = $0 }

    ! is_in_option && ( \
        ( /^[[:space:]]*'"$__BU_AUTOCOMPLETE_OPTION_REGEX"'\)/ && gsub( /\).*/, "", line ) ) \
    ) {
        is_in_option = 1
    }

    is_in_option && /.*;;[[:space:]]*$/ {
        is_in_option = 0
    }

    '"$end_indicator"' { exit }
    ' | tr '|' ' '
}

# ```
# *Description*:
# Cached version of `bu_autocomplete_parse_case_block_options`
#
# *Params*
# - `$1`: Function name or script path to parse
# - `$2` (optional): Start indicator regex (default: `case .* in`)
# - `$3` (optional): End indicator regex (default: `esac`)
# - `$4` (optional): Start line number of the function/script (default: 1)
# - `$5`: Cache key
# - `$6` (optional): Invalidate cache boolean (default: false)
#
# *Returns*:
# - `${BU_RET[@]}`: List of options inside the case block
#
# *Examples*:
# ```bash
# bu_autocomplete_parse_case_block_options_cached my_function '' '' '' my_cache_key false # ${BU_RET[@]} has the options
# bu_autocomplete_parse_case_block_options_cached /path/to/script.sh '' '' '' my_cache_key false # ${BU_RET[@]} has the options
# ```
# ```
bu_autocomplete_parse_case_block_options_cached()
{
    local function_or_script_path=$1
    local start_indicator=$2
    local end_indicator=$3
    local start_lineno=$4
    local cache_key=$5
    local is_invalidate_cache=$6
    bu_cached_keyed_execute \
        --invalidate-cache-bool "$is_invalidate_cache" \
        "$cache_key" \
        bu_stdout_to_ret --lines bu_autocomplete_parse_case_block_options "$function_or_script_path" "$start_indicator" "$end_indicator" "$start_lineno"
}

bu_autocomplete_parse_command_context()
{
    :
}

# ```
# *Description*:
# Gets the completion function name for a given command
#
# *Params*:
# - `$1`: Command to get the completion function for
#
# *Returns*:
# - `$BU_RET`: Name of the completion function
# ```
bu_autocomplete_get_completion_func()
{
    local completion_for=$1
    bu_stdout_to_ret complete -p "$completion_for"
    case "$BU_RET" in
    *' -F '*)
        # Strip everything before (inclusive of) -F
        BU_RET=${BU_RET#*  -F }
        # Strip all words after the completion function's name
        BU_RET=${BU_RET%% *}
        ;;
    *)
        BU_RET=
        return 1
    esac
}

# ```
# *Description*:
# Populates the `${COMPREPLY[@]}` array with autocompletions for a given command line
#
# *Params*:
# - `...`: All parameters are treated as the command line to get autocompletions for
#
# *Returns*:
# - `${COMPREPLY[@]}`: List of autocompletions
# ```
bu_autocomplete_get_autocompletions()
{
    if ! bu_autocomplete_get_completion_func "$1"
    then
        __bu_autocomplete_completion_func_default "$1"
    fi
    if ! bu_autocomplete_get_completion_func
    then
        bu_log_err "Failed to get completion func for $1"
        return 1
    fi
    local completion_func=$BU_RET
    
    local command_line=("$@")
    local COMP_LINE=${command_line[*]}
    local COMP_POINT=$READLINE_POINT # TODO: Is this a bug?
    local COMP_CWORD=$(( $# - 1 ))
    local COMP_WORDS=( "${command_line[@]}" )
    local COMP_WORDBREAKS=$' \t\n"\'><=;|&(:'
    local completion_command=${command_line[0]}
    local cur_word=${command_line[-1]}
    local prev_word=
    (( $# >= 2 )) && prev_word=${command_line[-2]}
    COMPREPLY=()
    local tries
    "$completion_func" "$completion_command" "$cur_word" "$prev_word" &>/dev/null
    local ret=$?
    for (( tries = 3; ret == 124 && tries > 0; tries-- ))
    do
        if ! bu_autocomplete_get_completion_func "$1"
        then
            bu_log_err "Failed to get completion func for $1"
            return 1
        fi
        completion_func=$BU_RET
        "$completion_func" "$completion_command" "$cur_word" "$prev_word" &>/dev/null
        ret=$?
    done

    return "$ret"
}

# ```
# *Description*:
# Adds autocompletions to the current `${COMPREPLY[@]}` array
#
# *Params*:
# - All parameters are passed to `bu_autocomplete_get_autocompletions`
#
# *Returns*:
# - `${COMPREPLY[@]}`: Original contents plus new autocompletions
# ```
bu_autocomplete_add_autocompletions()
{
    local saved_compreply=("${COMPREPLY[@]}")
    bu_autocomplete_get_autocompletions "$@"
    COMPREPLY+=("${saved_compreply[@]}")
}

# ```
# *Description*:
# Prints autocompletions to stdout
#
# *Params*:
# - All parameters are passed to `bu_autocomplete_get_autocompletions`
#
# *Returns*:
# - `stdout`: List of autocompletions, one per line
# ```
bu_autocomplete_print_autocompletions()
{
    bu_autocomplete_get_autocompletions "$@"
    printf "%s\n" "${COMPREPLY[@]}"
}

# ```
# *Description*:
# Wrapper around `compgen` that captures output into `${COMPREPLY[@]}`
#
# *Params*:
# - `...`: All parameters are passed to `compgen`
#
# *Returns*:
# - `${COMPREPLY[@]}`: Output of `compgen`
# ```
bu_compgen()
{
    # Some modern versions of bash support a target variable, but we don't assume this
    bu_stdout_to_ret --lines -o COMPREPLY compgen "$@"
}

# ```
# *Description*:
# Appends options parsed from the first occurring case block of the file/function to `${COMPREPLY[@]}`
#
# *Params*:
# - `function_or_script_path`: Path to the function or script to parse options from
#
# *Returns*:
# - `${COMPREPLY[@]}`: Original contents plus new options
# ```
__bu_autocomplete_compreply_append_options_of()
{
    local function_or_script_path=$1
    COMPREPLY+=($(bu_autocomplete_parse_case_block_options "$function_or_script_path"))
}

# ```
# *Description*:
# Appends options parsed from the case block following the given line number of the file to `${COMPREPLY[@]}`
#
# *Params*:
# - `$1`: Path to the script to parse options from
# - `$2`: Line number of the case block to parse options from
#
# *Returns*:
# - `${COMPREPLY[@]}`: Original contents plus new options
# ```
__bu_autocomplete_compreply_append_options_at()
{
    local script_path=$1
    local script_lineno=$2
    COMPREPLY+=($(bu_autocomplete_parse_case_block_options "$script_path" "" "" "$script_lineno"))
}

__bu_autocomplete_compreply_append_find_files()
{
    local base=$1
    local type=$2
    shift 2
    local find_patterns=("$@")
    local pattern
    local candidates=()
    local absolute_base
    if [[ "${base:0:1}" != / ]]
    then
        absolute_base=$(realpath --canonicalize-missing "$__BU_AUTOCOMPLETE_WORKING_DIRECTORY"/"$base"/)
    else
        absolute_base=$base
    fi

    if [[ ! -d "$absolute_base" ]]
    then
        return 0
    fi

    case "$type" in
    directory)
        for pattern in "${find_patterns[@]}"
        do
            candidates+=($(find -L "$absolute_base/" -path "$absolute_base/$pattern/[[:alnum:]_-]*" -prune -o -type d -path "$absolute_base/$pattern" -printf '%P' 2>/dev/null))
        done
        ;;
    file)
        for pattern in "${find_patterns[@]}"
        do
            candidates+=($(find -L "$absolute_base" -type f -path "*/$pattern" -printf '%P' 2>/dev/null))
        done
        ;;
    esac

    COMPREPLY+=("${candidates[@]}")
}

# MARK: Completion

# ```
# Autocomplete worked successfully
# ```
BU_AUTOCOMPLETE_EXIT_CODE_SUCCESS=0
# ```
# Autocomplete failed
# ```
BU_AUTOCOMPLETE_EXIT_CODE_FAIL=1
# ```
# Autocomplete should be retried without moving on to the next word
# ```
BU_AUTOCOMPLETE_EXIT_CODE_RETRY=124
__bu_autocomplete_completion_func_master_helper()
{
    local completion_command_path=$1
    local cur_word=$2
    local prev_word=$3
    shift 3
    local is_retry=false
    local is_fast=false
    local args=("$@")
    local i=0
    local offset
    local shift_by
    local terminator
    local -a sub_args
    local -a opt_cur_word=("$cur_word")
    local exit_code=$BU_AUTOCOMPLETE_EXIT_CODE_SUCCESS
    while ((i<${#args[@]}))
    do
        shift_by=1
        case "${args[i]}" in
        :*)
            # Explicit literal
            COMPREPLY+=("${args[idx]:1}")
            ;;
        --append-cur-word)
            opt_cur_word=("$cur_word")
            ;;
        --no-append-cur-word)
            opt_cur_word=()
            ;;
        --options-of)
            # i+1:function_or_script_path
            __bu_autocomplete_compreply_append_options_of "${args[i+1]}"
            shift_by=2
            ;;
        --options-at)
            # i+1:script_path i+2:lineno
            __bu_autocomplete_compreply_append_options_at "${args[i+1]}" "${args[i+2]}"
            shift_by=3
            ;;
        --sh|--enum|--stdout|--ret|--call)
            # Generic completion utilities
            terminator=${args[i]#--}--
            for (( offset = 1; i + offset < "${#args[@]}"; offset++ ))
            do
                if [[ "${offset[i + offset]}" = "$terminator" ]]
                then
                    break
                fi
            done
            sub_args=("${args[@]:i+1:offset-1}")
            case "${args[i]}" in
            --enum)
                COMPREPLY+=("${sub_args[@]}")
                ;;
            --stdout)
                COMPREPLY+=($("${sub_args[@]}" "${opt_cur_word[@]}"))
                ;;
            --ret)
                if "${sub_args[@]}" "${opt_cur_word[@]}"
                then
                    COMPREPLY+=("${BU_RET[@]}")
                fi
                ;;
            --call)
                bu_autocomplete_add_autocompletions "${sub_args[@]}" "${opt_cur_word[@]}"
                ;;
            --sh)
                # Exec any arbitrary command
                # Useful for pushd and popd
                "${sub_args[@]}"
                ;;
            esac
            shift_by=$(( 1 + offset ))
            ;;
        *)
            bu_user_defined_autocomplete_lazy "${args[@]:i}"
            case $? in
            "$BU_AUTOCOMPLETE_EXIT_CODE_SUCCESS")
                ;;
            "$BU_AUTOCOMPLETE_EXIT_CODE_RETRY")
                exit_code=$BU_AUTOCOMPLETE_EXIT_CODE_RETRY
                ;;
            "$BU_AUTOCOMPLETE_EXIT_CODE_FAIL")
                # If all else fails, treat the arg like a literal
                COMPREPLY+=("${args[i]}")
                ;;
            esac
            ;;
        esac
        : $(( i += shift_by ))
    done
    return "$exit_code"
}

# ```
# *Description*:
# Implementation of the master command completion function for sourcing scripts.
# Does not use any of the global COMP_ variables, instead takes all necessary parameters to be more self-contained.
#
# *Params*
# - `$1`: Completion command path
# - `$2`: Current word being completed
# - `$3`: Previous word
# - `$4`: Current word index
# - `$5`: Tail being completed
# - `...`: All words in the command line
#
# *Returns*
# - `${COMPREPLY[@]}`: List of autocompletions
# ```
__bu_autocomplete_completion_func_master_impl()
{
    local completion_command_path=$1
    local cur_word=$2
    local prev_word=$3
    local comp_cword=$4
    local tail=$5
    shift 5
    local comp_words=("$@")
    comp_words[comp_cword]=${comp_words[comp_cword]%$tail}
    local processed_comp_words=(
        "$completion_command_path"
        "${comp_words[@]:1:comp_cword}"
    )
    COMPREPLY=()
    local lazy_autocomplete_args=()
    if builtin source "${processed_comp_words[@]}" &>/dev/null
    then
        lazy_autocomplete_args=("${BU_RET[@]}")
    fi

    # Scripts might set -e, and because we are sourcing them, we unset it
    set +ex

    __bu_autocomplete_completion_func_master_helper "$completion_command_path" "$cur_word" "$prev_word" "${lazy_autocomplete_args[@]}"
    local exit_code=$?

    bu_compgen -W "${COMPREPLY[*]}" -- "$cur_word"

    if ((exit_code == "$BU_AUTOCOMPLETE_EXIT_CODE_RETRY"))
    then
        compopt -o nospace
    elif ((${#COMPREPLY} == 1)) && [[ -n "${tail:0:1}" ]]
    then
        # Force add a space because compopt +o nospace doesn't create a space in this case
        COMPREPLY[0]+=' '
    else
        compopt +o nospace
    fi
}

# ```
# *Description*:
# Completion function for the master command `bu`
#
# *Params*:
# - `$1`: Completion command (should be `bu`)
# - `$2`: Current word being completed
# - `$3`: Previous word
#
# *Returns*:
# - `${COMPREPLY[@]}`: List of autocompletions
# ```
__bu_autocomplete_completion_func_master()
{
    local completion_command=$1
    local cur_word=$2
    local prev_word=$3
    case "$completion_command" in
    bu);;
    *) return 1;;
    esac

    COMPREPLY=()
    if ((COMP_CWORD == 1))
    then
        bu_compgen -W "${BU_USER_DEFINED_COMMANDS[*]}" -- "$cur_word"
        return 0
    fi

    local arg1=${COMP_WORDS[1]}
    local function_or_script_path=${BU_USER_DEFINED_COMMANDS[$arg1]}
    if [[ -z "$function_or_script_path" ]]
    then
        return 1
    fi

    local comp_cword=$((COMP_CWORD - 1))
    local comp_words=(
        "$function_or_script_path"
        "${COMP_WORDS[@]:2}"
    )
    local tail
    if [[ "${COMP_LINE:COMP_POINT-1:1}" = ' ' ]]
    then
        tail=${COMP_WORDS[COMP_CWORD]}
    else
        tail=${COMP_LINE:COMP_POINT}
        tail=${tail%% *}
    fi

    __bu_autocomplete_completion_func_master_impl "$function_or_script_path" "$cur_word" "$prev_word" "$comp_cword" "$tail" "${comp_words[@]}"
}

# ```
# *Description*:
# Completion function that retrieves autocompletions from a cached file
#
# *Params*:
# - `$1`: Completion command
# - `$2`: Current word being completed
# - `$3`: Previous word
#
# *Returns*:
# - `${COMPREPLY[@]}`: List of autocompletions
# ```
__bu_autocomplete_completion_func_cached()
{
    local completion_command=$1
    local cur_word=$2
    local prev_word=$3

    bu_user_defined_convert_command_to_key "$completion_command"
    local key=$BU_RET

    bu_cat_str "$BU_NAMED_CACHE_DIR/$key"
    bu_compgen -W "$BU_RET" -- "$cur_word"
}

# ```
# *Description*:
# Completion function for the default case when no specific completion function is found.
#
# *Params*:
# - `$1`: Completion command
# - `$2`: Current word being completed (unused)
# - `$3`: Previous word (unused)
#
# *Returns*:
# - Exit code:
#   - 0: Autocomplete worked successfully
#   - 124: Autocomplete should be retried
#   - 1 or any other code: Autocomplete failed
# - `${COMPREPLY[@]}`: List of autocompletions
# ```
__bu_autocomplete_completion_func_default()
{
    local completion_command=$1
    # local cur_word=$2 # unused
    # local prev_word=$3 # unused

    bu_user_defined_convert_command_to_key "$completion_command"
    local key=$BU_RET
    if [[ -e "$BU_NAMED_CACHE_DIR"/"$key" ]]
    then
        complete -F __bu_autocomplete_completion_func_cached -- "$completion_command"
    elif bu_symbol_is_function _completion_loader
    then
        complete -F _completion_loader -- "$completion_command"
    elif bu_symbol_is_function _minimal
    then
        complete -F _minimal -- "$completion_command"
    else
        return 1
    fi

    return 124
}

# Taken from stackoverflow and github gist
__bu_terminal_get_pos()
{
    local col row oldstty=$(stty -g </dev/tty)
    stty raw -echo min 0 </dev/tty
    printf '%b' '\033[6n' >/dev/tty
    IFS='[;' read -d R _ row col </dev/tty
    stty "$oldstty" </dev/tty
    BU_RET=$((row-1))
}

__bu_fzf_current_pos()
{
    local lines=$(tput lines)
    __bu_terminal_get_pos
    local row=$BU_RET
    local halfway=$((lines / 2))
    local start_row=$((lines - row))
    export FZF_DEFAULT_OPTS

    # Start fzf from the current row
    if (( row < halfway ))
    then
        if (( row == 0 ))
        then
            row=1
        fi
        FZF_DEFAULT_OPTS+=" --reverse --margin $((row - 1)),0,0"
    else
        if (( start_row == 1 ))
        then
            start_row=0
        fi
        FZF_DEFAULT_OPTS+=" --no-reverse --margin 0,0,$start_row"
    fi
    fzf --tac "$@"
}

__bu_bind_fzf_autocomplete_impl()
{
    local command_line_front=$1
    local command_line_back=$2
    local move_cursor_to_end=$3
    local command_line=($command_line_front)
    if (( !${#command_line[*]} ))
    then
        return 0
    fi

    local command_line_escaped=$(printf '%q ' "${command_line[@]}")
    local opt_space=
    # We need to append a space if we swallowed a space
    if [[ "${command_line_front:${#command_line_front}-1}" = ' ' ]]
    then
        command_line+=("")
        opt_space="''"
    fi

    local select_command
    if selected_command=$(
        bu_autocomplete_print_autocompletions "${command_line[@]}" 2>/dev/null | uniq | __bu_fzf_current_pos --exact +s --sync -q "${command_line[-1]}" --header "$ ${command_line[*]}..."
    ) && [[ -n "$selected_command" ]]
    then
        # Bash seems to be bugged sometimes when READLINE_LINE is modified multiple times
        # So we use these temporary variables, and set READLINE_LINE, READLINE_POINT in one shot at the end
        local readline_line
        local readline_point
        command_line[-1]=$selected_command
        if [[ "${command_line_back:0:1}" != ' ' ]]
        then
            local len=${#command_line_back}
            command_line_back=${command_line_back#* }
            if [[ ${#command_line_back} = "$len" ]]
            then
                command_line_back=
            fi
        fi
        if [[ "${readline_line:${#readline_line}-1}" != ' ' && "${command_line_back:0:1}" != ' ' ]]
        then
            readline_line+=' '
        fi
        readline_point=${#readline_line}
        readline_line+=$command_line_back
        if "$move_cursor_to_end"
        then
            if [[ "${readline_line:${#readline_line}-1}" != ' ' && "${command_line_back:0:1}" != ' ' ]]
            then
                readline_line+=' '
            fi
            readline_point=${#readline_line}
        fi
        READLINE_LINE=$readline_line
        READLINE_POINT=$readline_point
    fi
}

# ```
# *Description*:
# Binds fzf to the autocomplete of the current command line at the cursor position.
# This is a readline binding function.
#
# *Params*: None
#
# *Returns*: None
# ```
__bu_bind_fzf_autocomplete()
{
    __bu_bind_fzf_autocomplete_impl "${READLINE_LINE:0:$READLINE_POINT}" "${READLINE_LINE:$READLINE_POINT}" false
}

# ```
# *Description*:
# Binds fzf to the history of bu command invocations for easy searching.
# This is a readline binding function.
#
# *Params*: None
#
# *Returns*: None
# ```
__bu_bind_fzf_history()
{
    touch "$BU_HISTORY"
    local history_result
    if history_result=$(cat "$BU_HISTORY" | __bu_fzf_current_pos --exact +s --sync --header 'bu history')
    then
        READLINE_LINE=$history_result
        READLINE_POINT=${#READLINE_LINE}
    fi
}

# MARK: Top-level CLI

# ```
# The master command name. Default is `bu`, but users can override it by defining `BU_USER_DEFINED_MASTER_COMMAND_NAME`.
# ```
BU_MASTER_COMMAND_NAME=${BU_USER_DEFINED_MASTER_COMMAND_NAME:-bu}

__bu_sort_keys()
{
    tr ' ' '\n' | sort
}

# ```
# *Description*:
# Gets the properties of a bu sub-command
#
# *Params*
# - `$1`: bu sub-command
#
# *Returns*
# - `$BU_RET`: Properties of the command. One of `function`, `source`, `execute`, or `no-default-found`.
# ```
__bu_master_command_properties()
{
    local bu_command=$1
    local function_or_script_path=${BU_USER_DEFINED_COMMANDS[$bu_command]}
    local properties="${BU_USER_DEFINED_COMMAND_PROPERTIES[$bu_command]}"
    if [[ -z "$properties" ]]
    then
        if bu_symbol_is_function "$function_or_script_path"
        then
            properties=function
        elif [[ -x "$function_or_script_path" ]]
        then
            properties=execute
        elif [[ -f "$function_or_script_path" ]]
        then
            properties=source
        else
            properties=no-default-found
        fi
    fi
    BU_RET=$properties
}

# ```
# *Description*:
# Displays help information for the master command
#
# *Params*: None
#
# *Returns*: None
# ```
__bu_help()
{
    echo "${BU_TPUT_BOLD}${BU_TPUT_DARK_BLUE}Help for ${BU_MASTER_COMMAND_NAME}${BU_TPUT_RESET}"
    echo "${BU_MASTER_COMMAND_NAME} is the Bash CLI implemented by shell-utils"

    local key
    local value

    local -A executable_scripts=()
    local -A source_scripts=()
    local -A functions=()
    for key in "${!BU_USER_DEFINED_COMMANDS[@]}"
    do
        value=${BU_USER_DEFINED_COMMANDS[$key]}
        __bu_master_command_properties "$key"
        case "$properties" in
        execute)
            executable_scripts[$key]=$value
            ;;
        source)
            source_scripts[$key]=$value
            ;;
        function)
            functions[$key]=$value
            ;;
        esac
    done


    echo
    echo "The following commands using ${BU_TPUT_UNDERLINE}a new shell context${BU_TPUT_RESET} are available"
    echo

    for key in $(__bu_sort_keys <<<"${!executable_scripts[*]}")
    do
        value=${executable_scripts[$key]}
        printf "    ${BU_TPUT_BOLD}%-30s${BU_TPUT_RESET}    %s\n" "$key" "$value"
    done

    echo
    echo "The following commands using ${BU_TPUT_UNDERLINE}the current shell context${BU_TPUT_RESET} are available"
    echo
    
    for key in $(__bu_sort_keys <<<"${!source_scripts[*]}")
    do
        value=${source_scripts[$key]}
        printf "    ${BU_TPUT_BOLD}%-30s${BU_TPUT_RESET}    %s\n" "$key" "$value"
    done

    echo
    echo "The following functions are available"
    echo

    for key in $(__bu_sort_keys <<<"${!functions[*]}")
    do
        value=${functions[$key]}
        printf "    ${BU_TPUT_BOLD}%-30s${BU_TPUT_RESET}    %s\n" "$key" "$value"
    done

    echo
    echo "The following ${BU_TPUT_UNDERLINE}key bindings${BU_TPUT_NO_UNDERLINE} are available"
    echo

    for key in $(__bu_sort_keys <<<"${!BU_KEY_BINDINGS[*]}")
    do
        value=${BU_KEY_BINDINGS[$key]}
        printf "    %s -> %s\n" "$key" "$value"
    done
} >&2

# ```
# *Description*:
# The top-level CLI command `bu`
#
# *Params*:
# - `$1`: Sub-command
# - `...`: All parameters are passed to the sub-command
#
# *Returns*:
# - Exit code of the sub-command
# ```
bu()
{
    builtin source bu_impl.sh "$@"
}
