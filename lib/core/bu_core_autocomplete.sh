# shellcheck source=./bu_core_base.sh
source "$BU_NULL"

# shellcheck source=../../bu_user_defined.sh
source "$BU_NULL"

# MARK: Parsers
__BU_AUTOCOMPLETE_WORKING_DIRECTORY=.
__BU_AUTOCOMPLETE_OPTION_REGEX='([-[:alnum:]_/]+[[:space:]]*\|?[[:space:]]*)*[-[:alnum:]_/]+[[:space:]]*'
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

bu_autocomplete_get_autocompletions()
{
    if ! bu_autocomplete_get_completion_func "$1"
    then
        bu_autocomplete_completion_func_default "$1"
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

bu_autocomplete_add_autocompletions()
{
    local saved_compreply=("${COMPREPLY[@]}")
    bu_autocomplete_get_autocompletions "$@"
    COMPREPLY+=("${saved_compreply[@]}")
}

bu_autocomplete_print_autocompletions()
{
    bu_autocomplete_get_autocompletions "$@"
    printf "%s\n" "${COMPREPLY[@]}"
}

bu_compgen()
{
    # Some modern versions of bash support a target variable, but we don't assume this
    bu_stdout_to_ret --lines -o COMPREPLY compgen "$@"
}

# Parses the options from the first occurring case block of the file/function
__bu_autocomplete_compreply_append_options_of()
{
    local function_or_script_path=$1
    COMPREPLY+=($(bu_autocomplete_parse_case_block_options "$function_or_script_path"))
}

# Parses the options from the case block following the lineno of the file
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

# MARK: Completion funcs

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
    local BU_AUTOCOMPLETE_IS_RETRY=false
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
        --stdout)
            for (( offset = 1; i + offset < "${#args[@]}"; offset++ ))
            do
                if [[ "${offset[i + offset]}" = stdout-- ]]
                then
                    break
                fi
            done
            COMPREPLY+=($("${args[@]:idx+1:offset-1}" "$cur_word"))
            shift_by=
            ;;
        *)
            COMPREPLY+=("${args[i]}")
            ;;
        esac
        : $(( i += shift_by ))
    done
    BU_RET=$BU_AUTOCOMPLETE_IS_RETRY
}

__bu_autocomplete_completion_func_master_impl()
{
    local completion_command_path=$1
    local cur_word=$2
    local cur_word=$3
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
    local is_retry=$BU_RET

    bu_compgen -W "${COMPREPLY[*]}" -- "$cur_word"

    if "$is_retry"
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

bu_autocomplete_completion_func_master()
{
    :
}

bu_autocomplete_completion_func_cached()
{
    local completion_command=$1
    local cur_word=$2
    local prev_word=$3

    bu_user_defined_convert_command_to_key "$completion_command"
    local key=$BU_RET

    bu_cat_str "$BU_NAMED_CACHE_DIR/$key"
    bu_compgen -W "$BU_RET" -- "$cur_word"
}

bu_autocomplete_completion_func_default()
{
    local completion_command=$1
    # local cur_word=$2 # unused
    # local prev_word=$3 # unused

    bu_user_defined_convert_command_to_key "$completion_command"
    local key=$BU_RET
    if [[ -e "$BU_NAMED_CACHE_DIR"/"$key" ]]
    then
        complete -F bu_autocomplete_cached -- "$completion_command"
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




