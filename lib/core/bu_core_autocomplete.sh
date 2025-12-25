if false; then
source ./bu_core_base.sh
source ../../bu_user_defined.sh
fi

# MARK: Custom compopt

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
    __bu_autocomplete_collect_compopt $(compopt "$completion_command" 2>/dev/null)
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
        case_count = 0
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

    is_in_option && /[[:space:]]*case .* in[[:space:]]*/ {
        ++case_count;
    }

    is_in_option && /[[:space:]]*esac[[:space:]]*/ {
        --case_count;
    }

    is_in_option && !case_count && /.*;;[[:space:]]*$/ {
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
                start_row = 0
                case_count = 0
            }
            '"$start_indicator"' {
                ++case_count;
                # Ignore nested cases
                if (case_count == 1) {
                    start_row = NR
                }
            }
            '"$end_indicator"' {
                --case_count;
            }
            NR == '"$end_lineno"' {
                print start_row
                exit 0
            }
            '
        )
    fi

    # bu_log_debug "end_lineno[$end_lineno] start_row[$start_row]"

    if bu_symbol_is_function "$function_or_script_path"
    then
        declare -f "$function_or_script_path"
    else
        cat "$function_or_script_path"
    fi |\
    awk '
    NR < '"$start_row"' { next }
    '"$start_indicator"' {
        if (!is_start) {
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

            case_count = 0
            debug_print = 0
        }
    }
    
    ! is_start { next }

    {
        if (debug_print) {
            printf "# state=%s\n", state 
        } 
    }

    { line = $0 }

    state < pre_documentation && ( \
        ( /^[[:space:]]*'"$__BU_AUTOCOMPLETE_OPTION_REGEX"'\|\\/ && gsub( /\|\\/, "", line ) ) \
    ) {
        if (debug_print) {
            printf "# 1: %s\n", NR
        }
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
        if (debug_print) {
            printf "# 2: %s\n", NR
        }
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
        if (debug_print) {
            printf "# 3: %s\n", NR
        }
        if ( $0 ~ /^[[:space:]]*# ?.*/ ) {
            state = in_documentation
        } else {
            state = post_documentation
            printf "\"\n"
        }
    }

    state == in_documentation {
        if (debug_print) {
            printf "# 4: %s\n", NR
        }
        if ( $0 ~ /^[[:space:]]*# ?.*/ ) {
            sub( /^[[:space:]]*# ?/, "", line )
            print line
        } else {
            state = post_documentation
            printf "\"\n"
        }
    }

    state == post_documentation && /[[:space:]]*case .* in[[:space:]]*/ {
        ++case_count;
        if (debug_print) {
            printf "# 5: %s\n", NR
        }
    }

    state == post_documentation && /[[:space:]]*esac[[:space:]]*/ {
        --case_count;
        if (debug_print) {
            printf "# 6: %s\n", NR
        }
        next;
    }

    state == post_documentation && !case_count && /.*;;[[:space:]]*$/ {
        if (debug_print) {
            printf "# 7: %s\n", NR
        }
        state = outside
    }

    '"$end_indicator"' && !case_count { exit 0 }
    '
}

bu_parse_multiselect()
{
    if [[ -n "$error_msg" ]]
    then
        return
    fi

    local -r num_args=$1
    local -r arg1=$2
    if shift 2 && bu_env_is_in_autocomplete && ((num_args > 1)) && [[ -n "$arg1" ]]
    then
        bu_parsed_multiselect_arguments[$arg1]=1
    fi

    autocompletion=(--options-at "${BASH_SOURCE[1]}" "${BASH_LINENO[0]}" "$@")
    shift_by=1
    : $((__bu_g_shift_by++))
}

bu_parse_positional()
{
    local -r num_args=$1
    shift
    if (( shift_by >= num_args ))
    then
        return
    fi

    : $((shift_by++)) $((__bu_g_shift_by++))
    autocompletion=("$@")
}

bu_validate_positional()
{
    if bu_env_is_in_autocomplete
    then
        return
    fi
    if (($# == 1))
    then
        local -r cur_word=$1
        local -r prev_word=
    else
        local -r cur_word=${!shift_by}
        if ((shift_by))
        then
            local -r prev_idx=$((shift_by - 1))
            local -r prev_word=${!prev_idx}
        else
            local -r prev_word=
        fi
    fi
    bu_scope_push
    local -r saved_dir=$PWD
    bu_scoped_set +e
    if bu_popd_silent 2>/dev/null
    then
        bu_scope_add_cleanup bu_pushd_silent "$saved_dir"
    fi
    local COMPREPLY=()
    __bu_autocomplete_completion_func_master_helper "${BASH_SOURCE[1]}" "$cur_word" "$prev_word" "${autocompletion[@]}"
    bu_compgen -W "${COMPREPLY[*]}" -- "$cur_word"
    case ${#COMPREPLY[@]} in
    0)
        is_help=true
        error_msg="[$cur_word] did not match any of the options generated by ${BU_TPUT_UNDERLINE}${autocompletion[*]}${BU_TPUT_NO_UNDERLINE}"
        ;;
    1)
        ;;
    *)
        if [[ " ${COMPREPLY[*]} " != *" $cur_word "* ]]
        then
            is_help=true
            error_msg="[$cur_word] did not match any of the options generated by ${BU_TPUT_UNDERLINE}${autocompletion[*]}${BU_TPUT_NO_UNDERLINE}, possible alternatives: $(echo; printf "%q\n" ${COMPREPLY[*]})"
        fi
        ;;
    esac
    bu_scope_pop
}

bu_parse_command_context()
{
    BU_RET=()
    local -r start_marker=$1
    if (($# < 2))
    then
        return
    fi

    local -r end_marker=${start_marker:2}--
    autocompletion=(
        :"$end_marker"
        --as-if bu "${start_marker:2}"
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
        autocompletion+=("${BU_RET[@]}" as-if--)
    fi

    : $(( shift_by += i - 1 )) $(( __bu_g_shift_by += i - 1 ))
}

bu_parse_nested()
{
    local -r nested_impl=$1
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
    shift_by=$saved_shift_by
    : $((shift_by += __bu_g_shift_by))
}

# MARK: Parse errors
bu_parse_error_enum()
{
    local -r unrecognized_option=$1
    is_help=true
    error_msg="Unrecognized option[$unrecognized_option] for function[${FUNCNAME[1]}]"
}

bu_parse_error_argn()
{
    local -r option=$1
    local -r num_args_given=$2
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
    if (($# <= 1))
    then
        bu_compgen -A command "$1"
        return
    fi

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
    local script_path
    local script_lineno
    local option
    local -a sub_args
    local -a opt_cur_word=("$cur_word")
    local BU_RET
    local exit_code=$BU_AUTOCOMPLETE_EXIT_CODE_SUCCESS
    while ((i<${#args[@]}))
    do
        shift_by=1
        case "${args[i]}" in
        :*)
            # Explicit literal
            COMPREPLY+=("${args[i]:1}")
            ;;
        --hint)
            bu_autocomplete_hint=${args[i+1]}
            shift_by=2
            ;;
        -c|--append-cur-word)
            opt_cur_word=("$cur_word")
            ;;
        +c|--no-append-cur-word)
            opt_cur_word=()
            ;;
        --options-of|--options-at)
            script_path=${args[i+1]}
            case "${args[i]}" in
            --options-of) 
                script_lineno= 
                shift_by=2
                ;;
            --options-at) 
                script_lineno=${args[i+2]}
                shift_by=3
                ;;
            esac
            # bu_print_var bu_parsed_multiselect_arguments >/dev/tty
            while read -r -a BU_RET
            do
                # Some heuristics:
                # If ${BU_RET[@]} is of length 2, and one of them is short-form, and the other is long-form
                # e.g. -d --dir
                # then having either the long-form or the short-form will suffice in ruling out the other.
                if ((${#BU_RET[@]} == 2)) &&
                    [[
                        (
                            (${BU_RET[0]} == [-+][^-]* && ${BU_RET[1]} == --*) ||
                            (${BU_RET[1]} == [-+][^-]* && ${BU_RET[0]} == --*)
                        ) && 
                        (
                            "${bu_parsed_multiselect_arguments[${BU_RET[0]}]}" = 1 ||
                            "${bu_parsed_multiselect_arguments[${BU_RET[1]}]}" = 1
                        )
                    ]]
                then
                    continue
                fi
                # Otherwise, we don't assume that options on the same line mean the same thing
                # In this case, we will only leave out the exact options that have been parsed
                # TODO: Handle the case where an option is allowed to be given more than once.
                for option in "${BU_RET[@]}"; do
                    case "${bu_parsed_multiselect_arguments[$option]}" in
                    '') COMPREPLY+=("$option") ;;
                    1) continue ;;
                    esac
                done
            done < <(bu_autocomplete_parse_case_block_options "$script_path" "" "" "$script_lineno")
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
                # shellcheck disable=SC2207
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
    # bu_log_tty "__bu_autocomplete_completion_func_master_impl path[$completion_command_path] cur[$cur_word] prev[$prev_word] cword[$comp_cword] tail[$tail] $(printf "'%s' " "$@")"
    # bu_log_tty
    local comp_words=("$@")
    comp_words[comp_cword]=${comp_words[comp_cword]%$tail}
    local processed_comp_words=(
        "$completion_command_path"
        "${comp_words[@]:1:comp_cword}"
    )
    COMPREPLY=()
    local bu_autocomplete_hint
    local lazy_autocomplete_args=()
    local -A -g bu_parsed_multiselect_arguments=()
    # bu_log_tty reached0
    if builtin source "${processed_comp_words[@]}" &>/dev/null
    then
        lazy_autocomplete_args=("${BU_RET[@]}")
    fi
    # bu_log_tty reached3
    # Scripts might set -e, and because we are sourcing them, we unset it
    set +ex
    # bu_log_tty lazy_autocomplete_args="${lazy_autocomplete_args[*]}"
    __bu_autocomplete_completion_func_master_helper "$completion_command_path" "$cur_word" "$prev_word" "${lazy_autocomplete_args[@]}"
    local exit_code=$?

    # bu_log_tty "COMPREPLY=${COMPREPLY[*]}"
    bu_compgen -W "${COMPREPLY[*]}" -- "$cur_word"
    if ((!${#COMPREPLY[@]})) && [[ -n "$bu_autocomplete_hint" ]]
    then
        compopt -o nosort # Bash 4.4+
        # https://stackoverflow.com/questions/70538848/simulate-bashs-compreply-response-without-actually-completing-it
        # Add an invisible element
        COMPREPLY=("Hint: $bu_autocomplete_hint" $'\xC2\xA0')
    fi
    if ((exit_code == BU_AUTOCOMPLETE_EXIT_CODE_RETRY))
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

__bu_autocomplete_completion_func_cli_resolve_alias()
{
    # shellcheck disable=SC2206
    local -r bu_alias_spec=($1)
    shift
    local -r bu_aliased_command=${bu_alias_spec[0]}
    local -r function_or_script_path=${BU_COMMANDS[$bu_aliased_command]}
    if [[ -z "$function_or_script_path" ]]
    then
        return 1
    fi

    local resolved_options=()

    # bu_log_tty "cmdline: $(printf "'%s' " "$@")"

    local arg
    for arg in "${bu_alias_spec[@]:1}"
    do
        case "$arg" in
        '{?}')
            if ((!$#))
            then
                break
            fi
            ;;
        '{}')
            if ((!$#))
            then
                break
            fi
            resolved_options+=("$1")
            shift
            ;;
        '{...}')
            resolved_options+=("$@")
            shift $#
            ;;
        *)
            resolved_options+=("$arg")
            ;;
        esac
        if ((!$#))
        then
            break
        fi
    done

    __bu_cli_command_type "$bu_aliased_command"
    local -r type=$BU_RET
    BU_RET=()
    case "$type" in
    alias)
        __bu_autocomplete_completion_func_cli_resolve_alias "$function_or_script_path" "${resolved_options[@]}"
        ;;
    execute|source|function)
        BU_RET=("$function_or_script_path" "${resolved_options[@]}")
        ;;
    *)
        return 1
        ;;
    esac
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
    local -r completion_command=$1
    local -r cur_word=$2
    local -r prev_word=$3
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

    if [[ "${BU_COMMAND_PROPERTIES[$arg1,type]}" = 'alias' ]]
    then
        if ! __bu_autocomplete_completion_func_cli_resolve_alias "$function_or_script_path" "${COMP_WORDS[@]:2:COMP_CWORD-1}"
        then
            # bu_log_tty alias comp words failed
            return 1
        fi
        local -r comp_cword=$((${#BU_RET[@]} - 1))
        local -r comp_words=("${BU_RET[@]}")
        # bu_log_tty alias comp words: "${comp_words[@]}"
        __bu_autocomplete_completion_func_master_impl "${comp_words[0]}" "${comp_words[comp_cword]}" "${comp_words[comp_cword-1]}" "$comp_cword" "" "${comp_words[@]}"
    else
        local -r comp_cword=$((COMP_CWORD - 1))
        local -r comp_words=(
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
    fi
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

# ```
# *Description*:
# Completion func for the `source` builtin/function.
# ```
__bu_autocomplete_completion_func_source()
{
    local completion_command=$1
    local cur_word=$2
    local prev_word=$3
    case "$completion_command" in
    source|.) ;;
    *) bu_log_err "Unexpected command[$completion_command]"; return 1;;
    esac

    if ((COMP_CWORD == 1))
    then
        local paths=()
        bu_str_split : "$PATH"
        local dir
        for dir in "${BU_RET[@]}"
        do
            if [[ -d "$dir" ]]
            then
                paths+=("$dir")
            fi
        done
        local -a path_shell_scripts
        mapfile -t path_shell_scripts < <(
            find "${paths[@]}" \
                -mindepth 1 -maxdepth 1 \
                -type f \( -not -executable \) \
                \( -name '*.sh' -or -name 'activate' -or -name '.bashrc' \) \
                -printf "%P\n"
        )

        local -a local_files
        compopt -o filenames
        mapfile -t local_files < <(compgen -f "$cur_word")

        bu_compgen -W "${path_shell_scripts[*]} ${local_files[*]}" -- "$cur_word"
    elif ((COMP_CWORD > 1))
    then
        local script
        if ! script=$(command -v -- "${COMP_WORDS[1]}")
        then
            return
        fi
        # Check if this script is covered by shell-utils
        # String concatenation is not ideal, but it should do
        # Alternatively we can have a hashset of the full command paths
        if [[ " ${BU_COMMANDS[*]} " != *" $script "* ]]
        then
            return # Not covered
        fi

        __bu_autocomplete_completion_func_master_impl "$script" "$cur_word" "$prev_word" "$((COMP_CWORD - 1))" "" "${COMP_WORDS[@]:1}"
    fi
}

# Taken from stackoverflow and github gist
__bu_terminal_get_pos()
{
    local row col
    local oldstty=$(stty -g </dev/tty)
    stty raw -echo min 0 </dev/tty
    printf '%b' '\033[6n' >/dev/tty
    IFS='[;' read -r -d R _ row col </dev/tty
    stty "$oldstty" </dev/tty
    BU_RET=("$row" "$col")
    # IFS=';' read -s -d r -p $'\E[6n' row col >/dev/tty </dev/tty
    # row="${row#*[}"
    # BU_RET=("$row" "$col")
}

# Slight optimization over __bu_terminal_get_pos
__bu_terminal_get_pos2()
{
    local row col
    local oldstty=$1
    stty raw -echo min 0 </dev/tty
    printf '%b' '\033[6n' >/dev/tty
    IFS='[;' read -r -d R _ row col </dev/tty
    stty "$oldstty" </dev/tty
    BU_RET=("$row" "$col")
}

__bu_fzf_print_header()
{
    local proc_tmp_dir=$1
    local fzf_selection=$2
    shift 2

    local prev_fzf_selections=()
    mapfile -t prev_fzf_selections <"$proc_tmp_dir"/fzf_dynamic_autocomplete.txt

    printf "%s " "${prev_fzf_selections[@]}" "$fzf_selection"
}
export -f __bu_fzf_print_header

__bu_fzf_print_autocompletion()
{
    # Not sure why bash -ic ... freezes, we need to assume interactive mode to more effectively replicate the current shell
    # Note: On Ubuntu, in a non-interactive shell, the default .bashrc will just early return. No point sourcing it.
    # source "$HOME"/.bashrc &>/dev/null

    if [[ -f /usr/share/bash-completion/bash_completion ]]; then
        . /usr/share/bash-completion/bash_completion
    elif [[ -f /etc/bash_completion ]]; then
        . /etc/bash_completion
    fi

    source "$BU_DIR"/bu_entrypoint.sh &>/dev/null
    # {
    #     local i
    #     echo "$# arg(s): $*"
    #     for ((i=0;i<=$#;i++)); do
    #         printf "%s: %s\n" "$i" "${!i}"
    #     done
    # } >> "$BU_LOG_DIR"/autocomplete_debug.log

    local proc_tmp_dir=$1
    local fzf_selection=$2
    shift 2

    local prev_fzf_selections=()
    mapfile -t prev_fzf_selections <"$proc_tmp_dir"/fzf_dynamic_autocomplete.txt
    printf "%s\n" "$fzf_selection" >> "$proc_tmp_dir"/fzf_dynamic_autocomplete.txt

    local args=("$@")
    args+=("${prev_fzf_selections[@]}" "$fzf_selection" "")
    #printf "'%s' " bu_autocomplete_print_autocompletions "${args[@]}" >> "$BU_LOG_DIR"/autocomplete_debug.log
    bu_autocomplete_print_autocompletions "${args[@]}" #2>> "$BU_LOG_DIR"/autocomplete_debug.log
}
# We don't really need this export unless we need to do logging earlier than the sourcing of bu_entrypoint.sh
export BU_LOG_DIR
export -f __bu_fzf_print_autocompletion

__bu_fzf_finish()
{
    local proc_tmp_dir=$1

    local prev_fzf_selections=()
    mapfile -t prev_fzf_selections <"$proc_tmp_dir"/fzf_dynamic_autocomplete.txt

    printf "%s " "${prev_fzf_selections[@]}"
}
export -f __bu_fzf_finish

__bu_bind_fzf_autocomplete_impl()
{
    local command_line_front=$1
    local command_line_back=$2
    local move_cursor_to_end=$3
    local fzf_dynamic_reload=${4:-false}
    local command_line=($command_line_front)
    tput sc
    local oldstty=$(stty -g </dev/tty)
    __bu_terminal_get_pos2 "$oldstty"
    local row=${BU_RET[0]}
    # This should always be 1 because
    # readline always clears the current line
    # (note: not necessarily the whole bash prompt if it spans multiple lines!)
    # when invoking a func
    local col=${BU_RET[1]}

    # https://stackoverflow.com/questions/22322879/how-to-print-current-bash-prompt
    # Note that @P is a Bash 4.4 feature.
    local ps1_result
    printf -v ps1_result "%s" "${PS1@P}"
    printf "%s" "$ps1_result"
    __bu_terminal_get_pos2 "$oldstty"
    local row_with_ps1=${BU_RET[0]}
    local col_with_ps1=${BU_RET[1]}

    local ps1_num_rows=$((row_with_ps1 - row))

    # This is a bit tricky, PS1 can end up spanning multiple lines
    # Hence, we want to move the cursor up and then reinvoke PS1
    # TODO: If the bash prompt is >= 3 lines long, we might need to erase some lines..., but that's quite unlikely
    if ((ps1_num_rows > 0))
    then
        # Note that there will be some noticable flickering here as PS1 was printed in the wrong place up top.
        tput el1 # We prefer this to printf "\r"
        tput cuu "$((ps1_num_rows * 2))"
        printf "\r%s" "$ps1_result"
    fi

    local displayed_command_line_back=
    if [[ "${command_line_back:0:1}" != ' ' ]]
    then
        displayed_command_line_back=${BU_TPUT_RED}${command_line_back/ /${BU_TPUT_RESET} }
    else
        displayed_command_line_back=$command_line_back
    fi
    displayed_command_line_back=${displayed_command_line_back/ / ${BU_TPUT_GREY}}

    printf "%s%s%s" "${command_line_front}" "${BU_TPUT_BLUE}${BU_TPUT_UNDERLINE}?${BU_TPUT_RESET}" "$displayed_command_line_back"

    local command_line_escaped=$(printf '%q ' "${command_line[@]}")
    local opt_space=
    # We need to append a space if we swallowed a space
    if [[ "${command_line_front:${#command_line_front}-1}" = ' ' ]]
    then
        command_line+=("")
        opt_space="''"
    fi

    if ((!${#command_line[@]}))
    then
        command_line+=("")
    fi

    if ((${#command_line[@]} > 1))
    then
        bu_autocomplete_initialize_current_completion_options "${command_line[0]}"
    fi
    # bu_print_var BU_COMPOPT_CURRENT_COMPLETION_OPTIONS > /dev/tty
    bu_autocomplete_get_autocompletions "${command_line[@]}" 2>/dev/null
    # bu_print_var BU_COMPOPT_CURRENT_COMPLETION_OPTIONS > /dev/tty
    local is_nospace=false
    local is_filenames=false
    if ((${#command_line[@]} > 1))
    then
        if [[ "${BU_COMPOPT_CURRENT_COMPLETION_OPTIONS[nospace]}" = -o ]]
        then
            is_nospace=true
        fi
        if [[ "${BU_COMPOPT_CURRENT_COMPLETION_OPTIONS[filenames]}" = -o ]]
        then
            is_filenames=true
        fi
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
    __bu_terminal_get_pos2 "$oldstty"
    local row_before_fzf=${BU_RET[0]}

    local selected_command
    if selected_command=$(
        if "$fzf_dynamic_reload"
        then
            # Initial design:
            # - tab: selects a suggestion, then moves on to the next word
            # - enter: selects a suggestion and quits (i.e. almost same as the default accept behavior)
            # - change: no additional handling needed

            local command_line_no_last=("${command_line[@]}")
            if ((${#command_line_no_last[@]}))
            then
                unset command_line_no_last[-1]
            fi
            : > "$BU_PROC_TMP_DIR"/fzf_dynamic_autocomplete.txt
            printf "%s\n" "${COMPREPLY[@]}" | uniq | \
                fzf \
                    --header '' \
                    --tac \
                    --reverse \
                    --height 20% --min-height 14 \
                    --margin "0,0,0,$(( ( col_with_ps1 - 3 + READLINE_POINT - ${#command_line[-1]} ) % COLUMNS))" \
                    --extended --exact -i \
                    --no-sort \
                    --sync \
                    --cycle \
                    --query "${command_line[-1]}" \
                    --bind "tab:clear-query+transform-header(bash -c '__bu_fzf_print_header $BU_PROC_TMP_DIR {} ${command_line_no_last[*]}')+reload-sync(bash -c '__bu_fzf_print_autocompletion $BU_PROC_TMP_DIR {} ${command_line_no_last[*]}')" \
                    --bind "enter:transform-query(bash -c '__bu_fzf_finish $BU_PROC_TMP_DIR')+print-query"

            rm -f "$BU_PROC_TMP_DIR"/fzf_dynamic_autocomplete.txt
        else
            # No need for tput lines and tput cols, bash already has $LINES and $COLUMNS
            # margin is Top,Right,Bottom,Left
            # Note that VSCode's completion suggestion box is 12 lines high, for fzf we also need to account for the finder info and search box
            printf "%s\n" "${COMPREPLY[@]}" | uniq | \
                fzf \
                    --tac \
                    --reverse \
                    --height 20% --min-height 14 \
                    --margin "0,0,0,$(( ( col_with_ps1 - 3 + READLINE_POINT - ${#command_line[-1]} ) % COLUMNS))" \
                    --extended --exact -i \
                    --no-sort \
                    --sync \
                    --cycle \
                    --query "${command_line[-1]}"
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
    __bu_terminal_get_pos2 "$oldstty"
    local row_after_fzf=${BU_RET[0]}
    # fzf might shift our command line up if there isn't enough space at the bottom
    # If fzf shifts, then there is no need to restore the cursor
    if ((row_before_fzf == row_after_fzf))
    then
        tput rc
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
    __bu_bind_fzf_autocomplete_impl "${READLINE_LINE:0:$READLINE_POINT}" "${READLINE_LINE:$READLINE_POINT}" false false
}

__bu_bind_fzf_autocomplete_dynamic()
{
    __bu_bind_fzf_autocomplete_impl "${READLINE_LINE:0:$READLINE_POINT}" "${READLINE_LINE:$READLINE_POINT}" false true
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
        --prompt) read_args+=(-p "$2 "); shift 2;;
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

BU_AUTOCOMPLETE_SPEC_FILE=(
    --sh compopt -o filenames sh--
    --stdout compgen -f stdout--
)
