# shellcheck source=./bu_core_base.sh
source "$BU_NULL"

# shellcheck source=../../bu_user_defined.sh
source "$BU_NULL"

# MARK: Custom compopt
declare -A -g BU_COMPOPT_CURRENT_COMPLETION_OPTIONS=()

# Requires 
# has_name: String
# completion_options: AssociativeArray 
# to be defined
__bu_autocomplete_collect_compopt()
{
    if [[ "$1" = compopt ]]
    then
        shift
    fi
    completion_options=()
    has_name=false
    while (($#))
    do
        case "$1" in
        -o|+o) completion_options[$2]=$1 ; shift 2 ;;
        -D|-E|-I) shift ;;
        *) has_name=true ; shift; break ;;
        esac
    done
}

bu_copy_associative_array()
{
    local -n __map1=$1
    local -n __map2=$2
    __map2=()
    local key
    for key in "${!__map1[@]}"
    do
        # shellcheck disable=SC2004
        __map2[$key]=${__map1[$key]}
    done
}

bu_insert_associative_array()
{
    local -n __map1=$1
    # shellcheck disable=SC2178
    local -n __map2=$2
    local key
    for key in "${!__map1[@]}"
    do
        # shellcheck disable=SC2004
        __map2[$key]=${__map1[$key]}
    done
}

bu_autocomplete_initialize_current_completion_options()
{
    local completion_command=$1
    local has_name
    local -A completion_options=()
    # shellcheck disable=SC2046
    __bu_autocomplete_collect_compopt $(compopt "$completion_command")
    bu_copy_associative_array completion_options BU_COMPOPT_CURRENT_COMPLETION_OPTIONS
    # bu_print_var BU_COMPOPT_CURRENT_COMPLETION_OPTIONS 
}

bu_autocomplete_def_compopt()
{
    BU_COMPOPT_IS_CUSTOM=true
    # shellcheck disable=SC2329
    compopt()
    {
        # shellcheck disable=SC2034
        local -A completion_options=()
        local has_name=false
        __bu_autocomplete_collect_compopt "$@"

        if ! "$has_name"
        then
            bu_insert_associative_array completion_options BU_COMPOPT_CURRENT_COMPLETION_OPTIONS
            # local key
            # local value
            # local enabled_options=()
            # for key in "${!completion_options[@]}"
            # do
            #     value=${completion_options[$key]}
            #     case "$value" in
            #     -o) enabled_options+=("$@") ;;
            #     +o) ;;
            #     esac
            # done
        fi

        builtin compopt "$@"
    }
}

bu_autocomplete_undef_compopt()
{
    unset -f compopt
    BU_COMPOPT_IS_CUSTOM=false
}

bu_autocomplete_def_compopt

# MARK: Parsers
__BU_AUTOCOMPLETE_WORKING_DIRECTORY=.
__BU_AUTOCOMPLETE_OPTION_REGEX='([-\+[:alnum:]_/]+[[:space:]]*\|?[[:space:]]*)*[-\+[:alnum:]_/]+[[:space:]]*'

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
    # shellcheck disable=SC1083
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
        ( /^[[:space:]]*'"$__BU_AUTOCOMPLETE_OPTION_REGEX"'\)/ && gsub( /\).*/, "", line ) ) \
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

bu_autohelp_parse_case_block_help()
{
    local function_or_script_path=$1
    local start_indicator=${2:-'case .* in'}
    local end_indicator=$3
    local end_lineno=$4

    start_indicator=/$start_indicator/
    if [[ -z "$end_indicator" ]]
    then
        end_indicator='! is_in_option && /^[[:space:]]*esac[[:space:]]*/'
    else
        end_indicator=/$end_indicator/
    fi

    cat <<EOF
local -a bu_script_options=()
local -a bu_script_option_docs=()
EOF

    local start_row=0
    if [[ -n "$end_lineno" ]]
    then
        start_row=$(
            if bu_symbol_is_function "$function_or_script_path"
            then
                declare -f "$function_or_script_path"
            else
                cat "$function_or_script_path"
            fi |\
            awk '
            BEGIN {
                is_start = 0
                start_row = 0
            }
            '"$start_indicator"' {
                is_start = 1
                start_row = NR
            }
            '"$end_indicator"' {
                is_start = 0
            }
            NR == '"$end_lineno"' {
                print start_row
                exit 0
            }
            '
        )
    fi

    if bu_symbol_is_function "$function_or_script_path"
    then
        declare -f "$function_or_script_path"
    else
        cat "$function_or_script_path"
    fi |\
    awk '
    NR < '"$start_row"' { next }
    '"$start_indicator"' {
        is_start = 1
        idx = -1
        outside = 0
        in_alternatives = 1
        pre_documentation = 2
        in_documentation = 3
        post_documentation = 4
        state = 0
        is_in_option = 0
        is_in_documentation = 0
    }
    
    ! is_start { next }

    # { printf "# state=%s\n", state }

    { line = $0 }

    state < pre_documentation && ( \
        ( /^[[:space:]]*'"$__BU_AUTOCOMPLETE_OPTION_REGEX"'\|\\/ && gsub( /\|\\/, "", line ) ) \
    ) {
        # print "# 1"
        gsub(/^[[:space:]]*/, "", line)
        if ( state == outside ) {
            idx = idx + 1
            state = in_alternatives
            printf "bu_script_options[%d]=\"%s\n", idx, line
        } else {
            printf "%s\n", line
        }
        next
    }

    state < pre_documentation && ( \
        ( /^[[:space:]]*'"$__BU_AUTOCOMPLETE_OPTION_REGEX"'\)/ && gsub( /\).*/, "", line) ) \
    ) {
        # print "# 2"
        gsub(/^[[:space:]]*/, "", line)
        if ( state == outside ) {
            idx = idx + 1
            printf "bu_script_options[%d]=\"%s\"\n", idx, line
        } else {
            printf "%s\"\n", line
        }
        printf "bu_script_option_docs[%d]=\"", idx, line
        state = pre_documentation
        next
    }

    { line = $0 }

    state == pre_documentation {
        # print "# 3"
        if ( $0 ~ /^[[:space:]]*# ?.*/ ) {
            state = in_documentation
        } else {
            state = post_documentation
            printf "\"\n"
        }
    }

    state == in_documentation {
        # print "# 4"
        if ( $0 ~ /^[[:space:]]*# ?.*/ ) {
            sub( /^[[:space:]]*# ?/, "", line )
            print line
        } else {
            state = post_documentation
            printf "\"\n"
        }
    }

    state == post_documentation && /.*;;[[:space:]]*$/ {
        # print "# 5"
        state = outside
    }

    '"$end_indicator"' { exit 0 }
    '
}

bu_parse_multiselect()
{
    if [[ -n "$error_msg" ]]
    then
        return
    fi

    autocompletion=(--options-at "${BASH_SOURCE[1]}" "${BASH_LINENO[0]}" "$@")
    shift_by=1
    : $((__bu_g_shift_by++))
}

bu_parse_positional()
{
    local num_args=$1
    shift
    if (( shift_by >= "$num_args" ))
    then
        return
    fi
    : $((shift_by++)) $((__bu_g_shift_by++))
    autocompletion=("$@")
}

bu_parse_command_context()
{
    BU_RET=()
    local start_marker=$1
    if (($# < 2))
    then
        return
    fi

    local end_marker=${start_marker:2}--
    autocompletion=(
        :"$end_marker"
        --call "$BU_CLI_COMMAND_NAME" "${start_marker:2}"
    )

    local i
    for (( i = 2; i <= $#; i++ ))
    do
        if [[ "${!i}" = "$end_marker" ]]
        then
            break
        fi
        BU_RET+=("${!i}")
    done
    if [[ "${!i}" = "$end_marker" ]]
    then
        autocompletion=()
    else
        autocompletion+=("${BU_RET[@]}" call--)
    fi

    : $(( shift_by += i - 1 )) $(( __bu_g_shift_by += i - 1 ))
}

bu_parse_nested()
{
    local nested_impl=$1
    shift
    if (( shift_by >= $# ))
    then
        return
    fi
    shift "$shift_by"
    local nested_args=("$@")
    local saved_shift_by=$shift_by
    shift_by=0
    local __bu_g_shift_by=0
    "$nested_impl" "${nested_args[@]}"
    : $((shift_by += __bu_g_shift_by))
}

# MARK: Parse errors
bu_parse_error_enum()
{
    local unrecognized_option=$1
    is_help=true
    error_msg="Unrecognized option[$unrecognized_option] for function[${FUNCNAME[1]}]"
}

bu_parse_error_argn()
{
    local option=$1
    local num_args_given=$2
    # shellcheck disable=SC2034
    is_help=true
    error_msg="Expected $shift_by arguments for function[${FUNCNAME[1]}], option[$option], got $num_args_given arguments"
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
        BU_RET=${BU_RET#* -F }
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
        if ! bu_autocomplete_get_completion_func "$1"
        then
            bu_log_err "Failed to get completion func for $1"
            return 1
        fi
    fi
    local completion_func=$BU_RET
    
    local command_line=("$@")
    local COMP_LINE=${command_line[*]}
    local COMP_POINT=${#COMP_LINE}
    local COMP_CWORD=$(( $# - 1 ))
    local COMP_WORDS=( "${command_line[@]}" )
    local COMP_WORDBREAKS=$' \t\n"\'><=;|&(:'
    local completion_command=${command_line[0]}
    local cur_word=${command_line[-1]}
    local prev_word=
    (( $# >= 2 )) && prev_word=${command_line[-2]}
    COMPREPLY=()
    local tries
    # bu_log_debug "$completion_func" "$completion_command" "$cur_word" "$prev_word"
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
    local args=("$@")
    local i=0
    local offset
    local shift_by
    local terminator
    local should_restore_cwd=false
    local original_cwd=$PWD
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
        -c|--append-cur-word)
            opt_cur_word=("$cur_word")
            ;;
        +c|--no-append-cur-word)
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
        --cwd)
            should_restore_cwd=true
            cd "${args[i+1]}"
            shift_by=2
            ;;
        --sh|--enum|--stdout|--ret|--as-if)
            # Generic completion utilities
            terminator=${args[i]#--}--
            for (( offset = 1; i + offset < "${#args[@]}"; offset++ ))
            do
                if [[ "${args[i + offset]}" = "$terminator" ]]
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
            --as-if)
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
                shift_by=$BU_RET
                ;;
            "$BU_AUTOCOMPLETE_EXIT_CODE_RETRY")
                shift_by=$BU_RET
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

    if "$should_restore_cwd"
    then
        cd "$original_cwd"
    fi
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
    # bu_log_tty
    # bu_log_tty "__bu_autocomplete_completion_func_master_impl '$completion_command_path' '$cur_word' '$prev_word' '$comp_cword' '$tail' $*"
    # bu_log_tty
    local comp_words=("$@")
    comp_words[comp_cword]=${comp_words[comp_cword]%$tail}
    local processed_comp_words=(
        "$completion_command_path"
        "${comp_words[@]:1:comp_cword}"
    )
    COMPREPLY=()
    local lazy_autocomplete_args=()
    # bu_log_tty reached0
    if builtin source "${processed_comp_words[@]}" &>/dev/null
    then
        lazy_autocomplete_args=("${BU_RET[@]}")
    fi
    # bu_log_tty reached3
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
__bu_autocomplete_completion_func_cli()
{
    local completion_command=$1
    local cur_word=$2
    local prev_word=$3
    case "$completion_command" in
    "$BU_CLI_COMMAND_NAME");;
    *) return 1;;
    esac
    
    COMPREPLY=()
    if ((COMP_CWORD == 1))
    then
        bu_compgen -W "${!BU_COMMANDS[*]}" -- "$cur_word"
        return 0
    fi

    local arg1=${COMP_WORDS[1]}
    local function_or_script_path=${BU_COMMANDS[$arg1]}
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

__bu_autocomplete_completion_func_script()
{
    local completion_command=$1
    local cur_word=$2
    local prev_word=$3
    __bu_autocomplete_completion_func_master_impl "$completion_command" "$cur_word" "$prev_word" "$COMP_CWORD" "" "${COMP_WORDS[@]}"
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
    IFS='[;' read -r -d R _ row col </dev/tty
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
    local fzf_dynamic_reload=${4:-false}
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
    
    bu_autocomplete_initialize_current_completion_options "${command_line[0]}"
    # bu_print_var BU_COMPOPT_CURRENT_COMPLETION_OPTIONS > /dev/tty
    bu_autocomplete_get_autocompletions "${command_line[@]}" 2>/dev/null
    # bu_print_var BU_COMPOPT_CURRENT_COMPLETION_OPTIONS > /dev/tty
    local is_nospace=false
    if [[ "${BU_COMPOPT_CURRENT_COMPLETION_OPTIONS[nospace]}" = -o ]]
    then
        is_nospace=true
    fi
    local is_filenames=false
    if [[ "${BU_COMPOPT_CURRENT_COMPLETION_OPTIONS[filenames]}" = -o ]]
    then
        is_filenames=true
    fi

    if "$is_filenames"
    then
        local i
        # We won't do this processing if COMPREPLY is too big to avoid lag
        if ((${#COMPREPLY[@]} < 2000))
        then
            for (( i = 0; i < ${#COMPREPLY[@]}; i++ ))
            do
                if [[ -d "${COMPREPLY[i]}" && "${COMPREPLY[i]:${#COMPREPLY[i]}-1}" != / ]]
                then
                    COMPREPLY[i]+=/
                fi
            done
        fi
    fi

    local selected_command
    if selected_command=$(
        if "$fzf_dynamic_reload"
        then
            local command_line_no_last=$("${command_line[@]}")
            unset command_line_no_last[-1]
            __bu_fzf_current_pos --delimiter ' ' --exact +s --sync -q "${command_line[-1]}" --header "$ ${command_line[*]}..." \
            --bind "start:reload-sync(bu_print_autocompletions ${command_line_escaped} $opt_space 2>/dev/null)" \
            --bind "tab:replace-query+reload-sync(bu_print_autocompletions ${command_line_no_last[*]} '{q}' '' 2>/dev/null | sed 's'$'\001''^'$'\001'''{q}' '$'\001')"
        else
            printf "%s\n" "${COMPREPLY[@]}" | uniq | __bu_fzf_current_pos --exact +s --sync -q "${command_line[-1]}" --header "$ ${command_line[*]}..."
        fi
    ) && [[ -n "$selected_command" ]]
    then
        # Bash seems to be bugged sometimes when READLINE_LINE is modified multiple times
        # So we use these temporary variables, and set READLINE_LINE, READLINE_POINT in one shot at the end
        local readline_line
        local readline_point
        command_line[-1]=$selected_command
        readline_line=${command_line[*]}
        if [[ "${command_line_back:0:1}" != ' ' ]]
        then
            local len=${#command_line_back}
            command_line_back=${command_line_back#* }
            # This can happen if command_line_back has no space
            if [[ ${#command_line_back} = "$len" ]]
            then
                command_line_back=
            fi
        fi
        
        # If we are expecting filenames, then if the file is a directory, we're not done, so don't append a space.
        # If nospace is enabled, then don't add a space.
        if ! { "$is_filenames" && [[ "${readline_line:${#readline_line}-1}" = / ]]; } && \
           ! "$is_nospace" && \
           [[ "${readline_line:${#readline_line}-1}" != ' ' && "${command_line_back:0:1}" != ' ' ]]
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

bu_autocomplete()
{
    BU_RET=("${autocompletion[@]}")
    case "$1" in
    --no-pop)
        ;;
    --no-pop-fn)
        bu_scope_pop
        ;;
    '')
        bu_scope_pop_function
        ;;
    *)
        bu_log_unrecognized_option "$1"
        ;;
    esac
}

# Requires
# options_finished: Bool
# remaining_options: Array
bu_autocomplete_remaining()
{
    local arg1=
    case "$1" in
    --no-pop|--no-pop-fn)
        arg1=$1
        ;;
    esac

    # shellcheck disable=SC2154
    if "$options_finished" && ((${#remaining_options[@]}))
    then
        autocompletion=("$@")
    fi
    bu_autocomplete "$arg1"
}

# Read with a fixed set of autocompletions
bu_read_word()
{
    BU_RET=
    local reply_name=BU_RET
    local read_args=()
    while (($#))
    do
        case "$1" in
        --prompt) read_args+=(-p "$2"); shift 2;;
        --reply) reply_name=$2; shift 2;;
        --) shift; break ; ;;
        *) break ;;
        esac
    done
    if (($# <= 100))
    then
        bu_mkdir "$BU_PROC_TMP_DIR"/read
        rm -f "$BU_PROC_TMP_DIR"/read/*
        pushd "$BU_PROC_TMP_DIR"/read &>/dev/null
        touch "$@"
    else
        bu_log_warn "At most 100 autocompletions supported, no autocompletions will be generated"
    fi
    read_args+=("$reply_name")
    read -e -r "${read_args[@]}"

    if (($# <= 100))
    then
        rm -f "$BU_PROC_TMP_DIR"/read/*
        popd &>/dev/null
    fi
}

# These autocompletion specs come in useful pretty often

BU_AUTOCOMPLETE_SPEC_DIRECTORY=(
    --sh compopt -o filenames sh--
    --stdout compgen -d stdout--
)
