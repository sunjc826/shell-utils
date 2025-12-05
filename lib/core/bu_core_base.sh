# It is expected that source is implemented by bu_def_source at this point.
# shellcheck source=../../bu_custom_source.sh
source "$BU_NULL"

# Note: static.sh should be sourced outside of this file!
# shellcheck source=../../config/bu_config_static.sh
source "$BU_NULL"
# Note: dynamic.sh should be sourced outside of this file!
# shellcheck source=../../config/bu_config_dynamic.sh
source "$BU_NULL"

# MARK: Filesystem utilities

# ```
# *Description*:
# Create directories if they do not exist
#
# *Params*:
# - `...`: List of directories to create
#
# *Examples*:
# ```bash
# bu_mkdir /tmp/dir1 /tmp/dir2
# ```
# ```
bu_mkdir()
{
    local missing=()
    local dir
    for dir
    do
        if [[ ! -e "$dir" ]]
        then
            missing+=("$dir")
        fi
    done
    if ((${#missing[@]}))
    then
        mkdir -p "${missing[@]}"
    fi
}

BU_BASE_PROC_DIR=$BU_TMP_DIR/proc
BU_PROC_DIR=$BU_BASE_PROC_DIR/$$
BU_CACHE_DIR=$BU_TMP_DIR/cache
BU_NAMED_CACHE_DIR=$BU_CACHE_DIR/named
BU_HASHED_CACHE_DIR=$BU_CACHE_DIR/hashed
BU_LOG_DIR=$BU_TMP_DIR/log
BU_LAST_RUN_CMDS=$BU_LOG_DIR/last_run_cmds.sh

bu_mkdir \
    "$BU_BASE_PROC_DIR" \
    "$BU_NAMED_CACHE_DIR" \
    "$BU_HASHED_CACHE_DIR" \
    "$BU_LOG_DIR"

# Variables prefixed with BU_PROC_ are process specific
# BU_PROC_FIFO is allows reading from stdout of a command without using a subshell
# Iirc, bash 5 will support subshell-less process substitution, but until then, this is a workaround
BU_PROC_FIFO=$BU_PROC_DIR/scratch.fifo
# Use an fd to further reduce overhead
BU_PROC_FIFO_FD=
# Probably have some kind of cleanup policy
if [[ ! -e "$BU_PROC_DIR" ]]
then
    mkdir "$BU_PROC_DIR"
fi
if [[ ! -e "$BU_PROC_FIFO" ]]
then
    mkfifo "$BU_PROC_FIFO"
    exec {BU_PROC_FIFO_FD}<>"$BU_PROC_FIFO"
fi

# MARK: Conversion utilities

# ```
# *Description*:
# Execute a command and capture its output into the global variable `BU_RET`,
# then print `BU_RET` to stdout in the specified format.
#
# *Params*:
# - `--str` or `--spaces`: Specify the output format. `--str` prints `BU_RET` as a single string,
#   while `--spaces` prints each element of `BU_RET` on a new line. Default is `--spaces`.
# - `...`: Command to execute
#
# *Returns*:
# - Exit code of the executed command
# - `stdout`: Formatted output of `BU_RET` from the executed command
#
# *Examples*:
# ```bash
# some_command() { BU_RET=hello; }
# bu_ret_to_stdout --str some_command  # stdout=hello
#
# some_command2() { BU_RET=(hello world); }
# # Note that --str will only print the first element of the array
# bu_ret_to_stdout --str some_command2  # stdout='hello'
# bu_ret_to_stdout --spaces some_command2 # stdout='hello world '
# bu_ret_to_stdout --lines some_command2  # stdout='hello\nworld\n'
# ```
bu_ret_to_stdout()
{
    local mode=str
    case "$1" in
    --str|--spaces|--lines)
        mode=${1#--}
        ;;
    -*)
        echo "Unrecognized option $1" >&2
        return 1
        ;;
    esac
    shift

    "$@"
    case "$mode" in
    str)
        printf '%s' "$BU_RET"
        ;;
    spaces)
        printf '%s ' "${BU_RET[@]}"
        ;;
    lines)
        printf '%s\n' "${BU_RET[@]}" 
        ;;
    esac
}


bu_stdout_to_ret()
{
    local mode=str
    local is_proc=false
    local outparam_name=BU_RET
    local shift_by
    while (($#))
    do
        shift_by=1
        case "$1" in
        --str|--spaces|--lines)
            mode=${1#--}
            ;;
        --proc)
            is_proc=true
            ;;
        -o|--outparam)
            outparam_name=$2
            shift_by=2
            ;;
        -*)
            echo "Unrecognized option $1" >&2
            return 1
            ;;
        *)
            break
            ;;
        esac
        shift "$shift_by"
    done

    local -n outparam=$outparam_name
    case "$mode" in
    str)
        if "$is_proc"
        then
            outparam=
            "$@" >&"$BU_PROC_FIFO_FD" || return 1
            read -r "$outparam_name" <&"$BU_PROC_FIFO_FD"  
        else
            outparam=$("$@")
        fi
        ;;
    spaces)
        # Note that the behavior is slightly different between is_proc true and false
        # For multiline output, is_proc=true will only process the first line
        if "$is_proc"
        then
            outparam=()
            "$@" >&"$BU_PROC_FIFO_FD" || return 1
            read -r -a "$outparam_name" <&"$BU_PROC_FIFO_FD"
        else
            outparam=($("$@"))
        fi
        ;;
    lines)
        if "$is_proc"
        then
            outparam=()
            "$@" >&"$BU_PROC_FIFO_FD" || return 1
            mapfile -t "$outparam_name" <&"$BU_PROC_FIFO_FD"
        else
            mapfile -t "$outparam_name" < <("$@")
        fi
        ;;
    esac
}

# ```
# *Description*:
# Read the entire content of a file into a string variable
#
# *Params*:
# - `$1`: File to read
# - `$2` (optional): Name of the variable to store the result in (default: `BU_RET`)
#
# *Returns*:
# - `$BU_RET` or the variable named in `$2`: Content of the file as a string
#
# *Examples*:
# ```bash
# bu_cat_str /path/to/file # $BU_RET contains the file content as a string
# bu_cat_str /path/to/file MY_VAR # $MY_VAR contains the file content as a string
# ```
# ```
bu_cat_str()
{
    local file=$1
    local ret=${2:-BU_RET}
    eval "$ret"=
    mapfile -d '' "$ret" <"$file"
}

# ```
# *Description*:
# Read the entire content of a file into an array variable, splitting by lines
#
# *Params*:
# - `$1`: File to read
# - `$2` (optional): Name of the array variable to store the result in (default: `BU_RET`)
#
# *Returns*:
# - `${BU_RET[@]}` or the array variable named in `$2`: Content of the file as an array of lines
#
# *Examples*:
# ```bash
# bu_cat_arr /path/to/file # ${BU_RET[@]} contains the file content as an array of lines
# bu_cat_arr /path/to/file MY_ARR # ${MY_ARR[@]} contains the file content as an array of lines
# ```
# ```
bu_cat_arr()
{
    local file=$1
    local ret=${2:-BU_RET}
    mapfile -t "$ret" <"$file"
}

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

# MARK: Shell symbol helpers
bu_symbol_is_function()
{
    bu_stdout_to_ret --proc type -t "$1"
    [[ "$BU_RET" = function ]]
}

bu_symbol_is_file()
{
    bu_stdout_to_ret --proc type -t "$1"
    [[ "$BU_RET" = file ]]
}

# MARK: Caching functions
bu_cached_keyed_execute()
{
    local mode=lines
    local is_invalidate_cache=false
    local shift_by
    while (($#))
    do
        shift_by=1
        case "$1" in
        --str|--line|--lines)
            mode=${1#--}
            ;;
        --invalidate-cache)
            is_invalidate_cache=true
            ;;
        --invalidate-cache-bool)
            is_invalidate_cache=$2
            shift_by=2
            ;;
        -*)
            echo "Unrecognized option $1" >&2
            return 1
            ;;
        *)
            break
            ;;
        esac
        shift "$shift_by"
    done

    local cache_key=$1
    shift
    if [[ -z "$cache_key" ]]
    then
        "$@"
        return
    fi

    local cache_path=$BU_NAMED_CACHE_DIR/$cache_key
    if "$is_invalidate_cache"
    then
        rm "$cache_path" || true
    elif [[ -e "$cache_path" ]]
    then
        case "$mode" in
        lines)
            mapfile -t BU_RET < "$cache_path"
            ;;
        str)
            mapfile -d '' -t BU_RET < "$cache_path"
            ;;
        line)
            read -r BU_RET < "$cache_path"
            ;;
        esac
    else
        "$@"
        if (($?))
        then
            echo "Failed: command[$*]" >&2
            return 1
        fi
        case "$mode" in
        str)
            printf "%s" "${BU_RET}" > "$cache_path"
            BU_RET=${BU_RET[*]}
            ;;
        lines)
            printf "%s\n" "${BU_RET[@]}" > "$cache_path"
            ;;
        line)
            printf "%s " "${BU_RET[@]}" > "$cache_path"
            ;;
        esac
    fi
}

# MARK: Colors
__bu_setup_tput()
{
    local -n outvar=$1
    shift
    local joined_cmd=$*
    bu_cached_keyed_execute --str tput_"${joined_cmd// /_}" bu_stdout_to_ret --str tput "$@" 2>/dev/null
    outvar=$BU_RET
}

BU_TPUT_UNDERLINE=
BU_TPUT_NO_UNDERLINE=
BU_TPUT_BOLD=
BU_TPUT_RESET=
BU_TPUT_BLACK=
BU_TPUT_RED=
BU_TPUT_GREEN=
BU_TPUT_YELLOW=
BU_TPUT_DARK_BLUE=
BU_TPUT_VIOLET=
BU_TPUT_BLUE=
BU_TPUT_WHITE=

__bu_setup_tput BU_TPUT_UNDERLINE    smul
__bu_setup_tput BU_TPUT_NO_UNDERLINE rmul
__bu_setup_tput BU_TPUT_BOLD         bold
if tput colors &>/dev/null
then
__bu_setup_tput BU_TPUT_RESET        sgr0
__bu_setup_tput BU_TPUT_BLACK        setaf 0
__bu_setup_tput BU_TPUT_RED          setaf 1
__bu_setup_tput BU_TPUT_GREEN        setaf 2
__bu_setup_tput BU_TPUT_YELLOW       setaf 3
__bu_setup_tput BU_TPUT_DARK_BLUE    setaf 4
__bu_setup_tput BU_TPUT_VIOLET       setaf 5
__bu_setup_tput BU_TPUT_BLUE         setaf 6
__bu_setup_tput BU_TPUT_WHITE        setaf 7
fi


# MARK: Logging

# ```
# *Description*:
# Internal logging function
#
# *Params*:
# - `$1`: Color code
# - `$2`: Log level
# - `$3`: Log prefix
# - `-i|--idx <index>` (optional): Stacktrace index offset for the logging context
# - `...`: Log message
#
# *Notes*:
# - This should not be called externally, because it (in particular log_idx) assumes it is called by a bu_log_[LOG_LVL] function.
# ```
__bu_log()
{
    local color=$1
    local log_lvl=$2
    local log_prefix=$3
    shift 3

    if (( log_lvl < BU_LOG_LVL ))
    then
        return 0
    fi

    local log_idx=0
    case "$1" in
    -i|--idx)
        log_idx=$2
        shift 2
        ;;
    esac
    local BU_RET
    bu_basename "${BASH_SOURCE[log_idx+2]}"
    local basename=$BU_RET
    # 7 because SUCCESS is the longest log prefix
    printf -v log_prefix '%-7s' "$log_prefix"
    printf "${color}${log_prefix}${basename}:${BASH_LINENO[log_idx+1]}[${FUNCNAME[log_idx+2]}] %s${BU_TPUT_RESET}\n" "$*" >&2
}

# ```
# *Description*:
# Log an error message
#
# *Params*:
# - `...`: Log message
# ```
bu_log_err()
{
    __bu_log "$BU_TPUT_RED" "$BU_LOG_LVL_ERR" ERR "$*"
}

# ```
# *Description*:
# Log a warning message
#
# *Params*:
# - `...`: Log message
# ```
bu_log_warn() 
{
    __bu_log "$BU_TPUT_YELLOW" "$BU_LOG_LVL_WARN" WARN "$*"
}

# ```
# *Description*:
# Log an informational message
#
# *Params*:
# - `...`: Log message
# ```
bu_log_info() 
{ 
    __bu_log "$BU_TPUT_BLUE" "$BU_LOG_LVL_INFO" INFO "$*"
}

# ```
# *Description*:
# Log a debug message
#
# *Params*:
# - `...`: Log message
# ```
bu_log_debug()
{ 
    __bu_log "$BU_TPUT_VIOLET" "$BU_LOG_LVL_DEBUG" DEBUG "$*"
}

# ```
# *Description*:
# Log a success message
#
# *Params*:
# - `...`: Log message
# ```
bu_log_success()
{
    __bu_log "$BU_TPUT_GREEN" "$BU_LOG_LVL_INFO" SUCCESS "$*"
}

# ```
# *Description*:
# Internal command logging function
#
# *Params*:
# - `$1`: Color code
# - `$2`: Log level
# - `$3`: Log prefix
# - `-i|--idx <index>` (optional): Stacktrace index offset for the logging context
# - `...`: Command to execute
#
# *Notes*:
# - This should not be called externally, because it (in particular log_idx) assumes it is called by a bu_log_cmd_[LOG_LVL] function.
# ```
__bu_log_cmd()
{
    local BU_RET
    local color=$1
    local log_lvl=$2
    local log_prefix=$3
    shift 3

    local log_idx=0
    case "$1" in
    -i|--idx)
        log_idx=$2
        shift 2
        ;;
    esac
    {
        case "$1" in
        echo|printf)
            ;;
        *)
            bu_basename "${BASH_SOURCE[log_idx+2]}"
            local basename=$BU_RET
            # 7 because SUCCESS is the longest log prefix
            printf -v log_prefix '%-7s' "$log_prefix"
            echo -n "${BU_TPUT_BLUE}${log_prefix}:  ${TPUT_BOLD}${basename}:${BASH_LINENO[log_idx+1]}[${FUNCNAME[log_idx+2]}] "
            printf '%q ' "$@"
            echo "${BU_TPUT_RESET}"
            ;;
        esac
        echo -n "${BU_TPUT_BLUE}"
        if ! "$@"
        then
            echo -n "(cmd failed)${BU_TPUT_RESET}"
            return 1
        fi
        echo -n "${BU_TPUT_RESET}"
        case "$1" in
        printf)
            case "$2" in
            '%q ')
                echo
                ;;
            esac
            ;;
        esac
    } >&2
}

# ```
# *Description*:
# Log an error command message
#
# *Params*:
# - `...`: Command to execute
# ```
bu_log_cmd_err()
{
    __bu_log_cmd "$BU_TPUT_RED" "$BU_LOG_LVL_ERR" ERR "$*"
}

# ```
# *Description*:
# Log a warning command message
#
# *Params*:
# - `...`: Command to execute
# ```
bu_log_cmd_warn()
{
    __bu_log_cmd "$BU_TPUT_YELLOW" "$BU_LOG_LVL_WARN" WARN "$*"
}

# ```
# *Description*:
# Log an informational command message
#
# *Params*:
# - `...`: Command to execute
# ```
bu_log_cmd_info()
{
    __bu_log_cmd "$BU_TPUT_BLUE" "$BU_LOG_LVL_INFO" INFO "$*"
}

# ```
# *Description*:
# Log a debug command message
#
# *Params*:
# - `...`: Command to execute
# ```
bu_log_cmd_debug()
{
    __bu_log_cmd "$BU_TPUT_VIOLET" "$BU_LOG_LVL_DEBUG" DEBUG "$*"
}

# ```
# *Description*:
# Log an unrecognized option error message
#
# *Params*:
# - `-i|--idx <index>` (optional): Index offset for the logging context
# - `$1`: Unrecognized option
#
# *Examples*:
# ```bash
# bu_log_unrecognized_option --idx 1 --unknown-option
# ```
# ```
bu_log_unrecognized_option()
{
    local log_idx=0
    case "$1" in
    -i|--idx)
        log_idx=$2
        shift 2
        ;;
    esac
    : "$((log_idx++))"
    bu_log_err -i "$log_idx" "Unrecognized option $1"
}

# MARK: List manipulation

# ```
# *Params*:
# - `$1`: Separator
# - `...`: List of entries to join
# 
# *Returns*:
# - `$BU_RET`: Value of the joined string
#
# *Examples*:
# ```bash
# join_by , a b c
# echo "$BU_RET" # a,b,c
# ```
# ```
bu_list_join()
{
    local delim=${1-}
    local first_entry=${2-}
    BU_RET=
    if shift 2
    then
        printf -v BU_RET %s "$first_entry" "${@/#/$delim}"
    fi
}

# ```
# *Description*:
# Reverse a list of entries
#
# *Params*:
# - `...`: List of entries
#
# *Returns*:
# - `${BU_RET[@]}`: Array of entries in reverse order
#
# *Examples*:
# ```bash
# bu_list_reverse a b c # ${BU_RET[@]}=(c b a)
# ```
# ```
bu_list_reverse()
{
    BU_RET=()
    for (( i=$#; i>0; i-- ))
    do
        BU_RET+=("${!i}")
    done
}

# ```
# *Description*:
# Remove empty entries from a list
#
# *Params*:
# - `...`: List of entries
#
# *Returns*:
# - `$BU_RET`: Array of entries with empty entries removed
#
# *Examples*:
# ```bash
# bu_list_filter_out_empty a "" b c "" # ${BU_RET[@]}=(a b c)
# ```
bu_list_filter_out_empty()
{
    BU_RET=()
    local arg
    for arg
    do
        if [[ -n "$arg" ]]
        then
            BU_RET+=("$arg")
        fi
    done
}

# ```
# *Description*:
# Sort a list of entries
#
# *Params*:
# - `...`: List of entries
#
# *Returns*:
# - `${BU_RET[@]}`: Array of sorted entries
#
# *Examples*:
# ```bash
# bu_list_sort c a b # ${BU_RET[@]}=(a b c)
# ```
# ```
bu_list_sort()
{
    local ifs_defined=false
    local saved_ifs=$IFS
    if [[ -v IFS ]]
    then
        ifs_defined=true
        saved_ifs=$IFS
    fi
    IFS=$'\n' BU_RET=($(sort "$@"))
    # TODO: Do we need this?
    if "$ifs_defined"
    then
        IFS=$saved_ifs
    fi
}

bu_list_version_sort()
{
    local ifs_defined=false
    local saved_ifs=$IFS
    if [[ -v IFS ]]
    then
        ifs_defined=true
        saved_ifs=$IFS
    fi
    IFS=$'\n' BU_RET=($(sort --version-sort "$@"))
    # TODO: Do we need this?
    if "$ifs_defined"
    then
        IFS=$saved_ifs
    fi
}

# ```
# *Description*:
# Check if a string exists in a list of strings
#
# *Params*:
# - `$1`: String to search for (needle)
# - `...`: List of strings (haystack)
#
# *Returns*:
# - Exit code:
#   - `0`: if the string exists in the list
#   - `1`: if the string does not exist in the list
#
# *Examples*:
# ```bash
# HAYSTACK=(a b c)
# bu_list_exists_str b "${HAYSTACK[@]}" # returns 0
# bu_list_exists_str d "${HAYSTACK[@]}" # returns 1
# ```
bu_list_exists_str()
{
    local needle=$1
    shift
    local arg
    for arg
    do
        if [[ "$arg" == "$needle" ]]
        then
            return 0
        fi
    done
    return 1 # Not found
}

# MARK: String manipulation

# ```
# *Description*:
# Split a string into an array by a given separator
#
# *Params*:
# - `$1`: Separator
# - `$2`: String to split
# - `$3` (optional): Name of the array to store the result in (default: `BU_RET`)
#
# *Returns*:
# - `$BU_RET` or the array named in `$3`: Array of split entries
#
# *Examples*:
# ```bash
# bu_str_split , "a,b,c" # ${BU_RET[@]}=(a b c)
# bu_str_split , "a,b,c" MY_ARR # ${MY_ARR[@]}=(a b c)
# ```
bu_str_split()
{
    local ifs=$1
    local to_split=$2
    local ret=${3:-BU_RET}
    if [[ -z "$to_split" ]]
    then
        eval "$ret"=
    else
        local IFS=$ifs
        read -ra "$ret" <<< "$to_split"
    fi
}

# ```
# *Params*:
# - `$*`: String to convert to lower case
#
# *Returns*:
# - `stdout`: Lower-cased string
#
# *Examples*:
# ```bash
# bu_tolower "AbC" # stdout=abc
# ```
# 
# *Notes*:
# - For better performance, consider using parameter expansion: `${var,,}`
# ```
bu_tolower()
{
    tr '[:upper:]' '[:lower:]' <<<"$*"
}

# ```
# *Params*:
# - `$*`: String to convert to upper case
#
# *Returns*:
# - `stdout`: Upper-cased string
#
# *Examples*:
# ```bash
# bu_toupper "AbC" # stdout=ABC
# ```
#
# *Notes*:
# - For better performance, consider using parameter expansion: `${var^^}`
# ```
bu_toupper()
{
    tr '[:lower:]' '[:upper:]' <<<"$*"
}

# ```
# *Params*:
# - `stdin`: string to trim whitespaces
#
# *Returns*:
# - `stdout`: trimmed string
#
# *Examples*:
# ```bash
# echo '  abc ' | bu_trim # stdout=abc
# ```
# ```
bu_trim()
{
    awk '{$1=$1};1'
}

# ```
# trim is kind of a misnomer here.
# *Params*:
# One of
# - `stdin`: string to trim
# - `$1`: string to trim
#
# *Returns*:
# - `stdout`: string with empty lines, including those with whitespaces only removed
#
# *Examples*:
# ```bash
# echo '
# abc
# ' | bu_trim_empty_lines # stdout='abc'
# ```
#
# ```bash
# bu_trim_empty_lines '
# abc
# ' # stdout='abc'
# ```
# ```
bu_trim_empty_lines()
{
    if [[ -n "$1" ]]
    then
        sed '/^ *$/d' <<<"$1"
    else
        sed '/^ *$/d'
    fi
}

# MARK: RAII Scopes

# ```
# *Description*:
# Push a new scope onto the scope stack
#
# *Params*: None
# *Returns*: None
#
# *Examples*:
# ```bash
# if some_condition; then
#     bu_scope_push
#     touch /tmp/some_temp_file
#     bu_scope_add_cleanup rm -f /tmp/some_temp_file
#     
#     some_command /tmp/some_temp_file
#     some_other_command /tmp/some_temp_file
#
#     bu_scope_pop
# fi
# ```
# ```
bu_scope_push()
{
    BU_SCOPE_STACK+=("${#BU_SCOPE_STACK[@]}")
}

# ```
# *Description*:
# Push a new function-level scope onto the scope stack
#
# *Params*: None
# *Returns*: None
#
# *Examples*:
# ```bash
# function my_function() {
#     bu_scope_push_function
#     if some_condition; then
#         # Early return with cleanup
#         bu_scope_pop_function
#         return 1
#     fi
#     some_command
#     bu_scope_pop_function
# }
# ```
# ```
bu_scope_push_function()
{
    BU_SCOPE_STACK+=("-${#BU_SCOPE_STACK[@]}")
}

bu_scope_handle()
{
    if ((!"${#BU_SCOPE_STACK[@]}"))
    then
        bu_log_err "Dynamic stack is empty"
        return 1
    fi

    BU_RET=${BU_SCOPE_STACK[-1]}
}

bu_scope_handle_add_cleanup()
{
    local handle=$1
    shift
    local -n deferred=BU_SCOPE_CLEANUPS_"$handle"
    printf -v BU_RET "%q " "$@"
    deferred+=("$BU_RET")
}

bu_scope_add_cleanup()
{
    if ((!"${#BU_SCOPE_STACK[@]}"))
    then
        bu_log_err -i 1 "Dynamic stack is empty"
        return 1
    fi

    bu_scope_handle_add_cleanup "${BU_SCOPE_STACK[-1]}"
}

bu_scope_pop()
{
    if ((!"${#BU_SCOPE_STACK[@]}"))
    then
        bu_log_err -i 1 "Dynamic stack is empty"
        return 1
    fi

    local -n deferred=BU_SCOPE_CLEANUPS_${BU_SCOPE_STACK[-1]}
    local i
    local ret=0
    for (( i=${#deferred}-1; i >= 0; i-- ))
    do
        bu_log_debug "Cleaning up ${BU_SCOPE_STACK[-1]}: ${deferred[$i]}"
        if ! "${deferred[$i]}"
        then
            bu_log_err "Cleanup failed: ${deferred[$i]}"
            ret=1
        fi
    done
    unset -v "BU_SCOPE_CLEANUPS_${BU_SCOPE_STACK[-1]}" 'BU_SCOPE_STACK[-1]'
    return "$ret"
}

bu_scope_pop_function()
{
    if ((!"${#BU_SCOPE_STACK[@]}"))
    then
        bu_log_err -i 1 "Dynamic stack is empty"
        return 1
    fi

    local i
    for (( i=${#BU_SCOPE_STACK[@]}-1; i >= 0; i-- ))
    do
        if (( "${BU_SCOPE_STACK[-1]}" < 0 ))
        then
            break
        fi
    done

    if (( i < 0 ))
    then
        log_err "No function-level scope found"
        return 1
    fi
    local j
    local target=$i
    local ret=0
    for (( i=${#BU_SCOPE_STACK[@]}-1; i >= "$target"; i-- ))
    do
        local -n deferred="BU_SCOPE_CLEANUPS_${BU_SCOPE_STACK[$i]}"
        for (( j=${#deferred}-1; j >= 0; j-- ))
        do
            bu_log_debug "Cleaning up ${BU_SCOPE_STACK[-1]}: ${deferred[-1]}"
            if ! "${deferred[$j]}"
            then
                bu_log_err "Cleanup failed: ${deferred[-1]}"
                ret=1
            fi
        done
        unset -v "BU_SCOPE_CLEANUPS_${BU_SCOPE_STACK[$i]}" "BU_SCOPE_STACK[$i]"
    done
    return "$ret"
}

bu_scope_pop_all()
{
    local ret=1
    for (( i=${#BU_SCOPE_STACK[@]}; i > 0; i-- ))
    do
        if ! bu_scope_pop
        then
            ret=1
        fi
    done
    return "$ret"
}

# MARK: Scope-related utilities
bu_pushd_silent()
{
    pushd "$1" >/dev/null || return 1
}

bu_popd_silent()
{
    popd >/dev/null || return 1
}

bu_close_fd()
{
    local fd=$1
    exec {fd}>&-
}

bu_scoped_set_opt()
{
    local opt=$1
    if ! [[ -o "$opt" ]]
    then
        set -o "$opt"
        bu_scope_add_cleanup set +o "$opt"
    fi
}

bu_scoped_unset_opt()
{
    local opt=$1
    if [[ -o "$opt" ]]
    then
        set +o "$opt"
        bu_scope_add_cleanup set -o "$opt"
    fi
}

bu_scoped_set()
{
    local opt
    case "${1:1}" in
    a) opt=allexport;;
    B) opt=braceexpand;;
    e) opt=errexit;;
    E) opt=errtrace;;
    T) opt=functrace;;
    h) opt=hashall;;
    H) opt=histexpand;;
    k) opt=keyword;;
    m) opt=monitor;;
    C) opt=noclobber;;
    n) opt=noexec;;
    b) opt=notify;;
    u) opt=nounset;;
    t) opt=onecmd;;
    P) opt=physical;;
    f) opt=noglob;;
    v) opt=verbose;;
    x) opt=xtrace;;
    *) bu_log_unrecognized_option "$1"; return 1;;
    esac

    case "${1:0:1}" in
    +) bu_scoped_unset_opt "$opt";;
    -) bu_scoped_set_opt "$opt";;
    *) bu_log_unrecognized_option "$1"; return 1;;
    esac
}

BU_EXIT_HANDLER_CLEANING_UP=false
__bu_exit_handler()
{
    local exit_code=$?
    set +xv
    if [[ $- =~ e && "$exit_code" != 0 ]]
    then
        set +e
        echo
        echo "Script exited with code: ${BU_TPUT_RED}$exit_code${BU_TPUT_RESET}"
        echo "Traceback (most recent call last):"
        local i
        for i in "${!BASH_LINENO[@]}"
        do
            if (( i == 0 ))
            then
                printf "    %s: %s%s%s at %s%s:%s%s\n" \
                    "$i" \
                    "$BU_TPUT_BOLD" "$BU_ERR_COMMAND" "$BU_TPUT_RESET" \
                    "$BU_TPUT_UNDERLINE" "$(basename -- "${BASH_SOURCE[i+1]}")" "$BU_ERR_LINENO" "$BU_TPUT_NO_UNDERLINE"
            else
                printf "    %s: %s%s%s at %s%s:%s%s\n" \
                    "$i" \
                    "$BU_TPUT_BOLD" "${FUNCNAME[i+1]}" "$BU_TPUT_RESET" \
                    "$BU_TPUT_UNDERLINE" "$(basename -- "${BASH_SOURCE[i+1]}")" "${BASH_LINENO[i]}" "$BU_TPUT_NO_UNDERLINE"
            fi
        done

        if "${BU_EXIT_HANDLER_VSCODE_POPUP:-false}"
        then
            if command -v code &>/dev/null
            then
                code --goto "${BASH_SOURCE[1]}${BU_ERR_LINENO:+:$BU_ERR_LINENO}"
            fi
        fi
    fi

    set +e
    BU_EXIT_HANDLER_CLEANING_UP=true
    if ! bu_scope_pop_all
    then
        bu_log_err Something failed during cleanup
    fi

    exit "$exit_code"
}

bu_exit_handler_setup_no_e()
{
    trap 'BU_ERR_LINENO=$LINENO; BU_ERR_COMMAND=$BASH_COMMAND' ERR
    trap __bu_exit_handler EXIT
}

bu_exit_handler_setup()
{
    set -e -E
    bu_exit_handler_setup_no_e
}

bu_exit_handler_restore()
{
    if [[ $- == *e* ]]
    then
        bu_exit_handler_setup
    fi
}

# MARK: Synchronization, file management
bu_sync_acquire_file()
{
    local file_path=$1
    local lockfile_path=${file_path}.lock
    local fd_path=${file_path}.lockfd
    local lockfile_fd=
    exec {lockfile_fd}>"$lockfile_path"
    flock --exclusive "$lockfile_fd"
    bu_log_debug "lockfile_fd[$lockfile_fd]"
    echo "$lockfile_fd" > "$fd_path"
}

bu_sync_acquire_fd()
{
    local fd=$1
    bu_log_debug "fd[$fd]"
    flock --exclusive "$fd"
}

bu_sync_release_file()
{
    local file_path=$1
    local lockfile_path=${file_path}.lock
    local fd_path=${file_path}.lockfd
    local lockfile_fd=
    if ! lockfile_fd=$(cat "$fd_path")
    then
        bu_log_err "cat fd_path[$fd_path] failed"
        return 1
    fi
    if [[ -z "$lockfile_fd" ]]
    then
        bu_log_err "lockfile doesn't contain fd"
        return 1
    fi
    : > "$fd_path"
    bu_log_debug "Unlocking file descriptor lockfile_fd[$lockfile_fd]"
    if ! flock --unlock "$lockfile_fd"
    then
        bu_log_err "Unlock lockfile_fd[$lockfile_fd] failed"
        if ! exec {lockfile_fd}>&-
        then
            bu_log_err "Could not close lockfile_fd[$lockfile_fd]"
        fi
        return 1
    fi
    bu_log_debug "Closing file descriptor lockfile_fd[$lockfile_fd]"
    if ! exec {lockfile_fd}>&-
    then
        bu_log_err "Close lockfile_fd[$lockfile_fd] failed"
        return 1
    fi
    return 0
}

bu_sync_release_fd()
{
    local fd=1
    bu_log_debug "Unlocking fd[$fd]"
    flock --unlock "$fd"
    bu_log_debug "Closing fd[$fd]"
    if ! exec {fd}>&-
    then
        bu_log_err "Close fd[$fd] failed"
        return 1
    fi
}

bu_sync_cycle_file()
{
    local filepath=$1
    local should_lock=$2
    local num_lines=${3:-"+1"}
    local unique=4

    if [[ ! -e "$filepath" ]]
    then
        return 0
    fi

    if "$should_lock"
    then
        if ! bu_sync_acquire_file "$filepath"
        then
            bu_log_warn "Failed to acquire filepath[$filepath]"
            return 0
        fi
    fi

    if "$unique"
    then
        tac "$filepath" | awk '! seen[$0] { seen[0] = 1; print $0; }' | tac
    else
        uniq "$filepath"
    fi |\
    tail -n "$num_lines" > "$filepath".tmp

    mv "$filepath"{.tmp,}

    if "$should_lock"
    then
        if ! bu_sync_release_file "$filepath"
        then
            bu_log_err "Failed to release filepath[$filepath]"
            return 1
        fi
    fi
}

bu_sync_cycle_last_run_cmds()
{
    bu_sync_cycle_file "$BU_LAST_RUN_CMDS" true 500 false || return 1
}

bu_sync_cycle_numbered_files()
{
    local file_base=$1
    local cycle_length=$2
    local target_dir=${3:-.}
    local file_ext=${4:-log}

    mkdir -p "$target_dir"
    local original_dir=$PWD

    if ! cd "$target_dir" 2>/dev/null
    then
        bu_log_err "Failed to cd to $target_dir"
        return 1
    fi

    if ! bu_sync_acquire_file "$file_base"
    then
        bu_log_warn "Failed to acquire lock for file_base[$file_base]"
        cd "$original_dir" || true
        return 0
    fi

    # Rotate existing log files
    if [[ -e "$file_base"."$file_ext" ]]
    then
        mv "$file_base"{.,.0.}"$file_ext"
    fi

    local i
    for (( i=$cycle_length; i > 0; i-- ))
    do
        if [[ -e "$file_base.$((i-1)).$file_ext" ]]
        then
            mv "$file_base.$((i-1)).$file_ext" "$file_base.$i.$file_ext"
        fi
    done

    # Create file descriptors for the new log file
    local read_fd=
    local write_fd=
    touch "$file_base.$file_ext"
    exec {write_fd}>"$file_base.$file_ext"
    exec {read_fd}<"$file_base.$file_ext"

    bu_sync_release_file "$file_base"

    BU_RET=("$write_fd" "$read_fd")
    cd "$original_dir" || return 1
}


# MARK: Run utils
bu_cached_execute()
{
    local is_check=false
    local error_pattern=
    local error_if_empty=true
    local cache_env_vars=()
    local cache_bash_vars=()
    local cache_dir=$BU_HASHED_CACHE_DIR
    local is_strict_equality=false
    local is_invalidate_cache=false

    local shift_by
    while (($#))
    do
        shift_by=1
        case "$1" in
        --check)
            is_check=true
            ;;
        --error-pattern)
            error_pattern=$2
            shift_by=2
            ;;
        --allow-empty)
            error_if_empty=false
            ;;
        --env-vars)
            bu_str_split , "$2" cache_env_vars
            shift_by=2
            ;;
        --bash-vars)
            bu_str_split , "$2" cache_bash_vars
            shift_by=2
            ;;
        --dir)
            cache_dir=$2
            shift_by=2
            ;;
        --invalidate|--invalidate-cache)
            is_invalidate_cache=true
            ;;
        --invalidate-bool|--invalidate-cache-bool)
            is_invalidate_cache=$2
            shift_by=2
            ;;
        --strict-equality)
            is_strict_equality=true
            ;;
        --)
            shift
            break
            ;;
        -*)
            bu_log_unrecognized_option "$1"
            return 1
            ;;
        *)
            break
            ;;
        esac

        shift "$shift_by"
    done
}

__bu_cycle_logs()
{
    BU_RET=()
    local command=$1
    local cycle_length=$2
    mkdir -p "$BU_LOG_DIR/$command"
    pushd "$BU_LOG_DIR" &>/dev/null

    if ! bu_sync_acquire_file "$command"
    then
        bu_log_warn "Failed to acquire command[$command]"
        return 1
    fi

    pushd "$command" &>/dev/null

    if [[ -e "$command.log" ]]
    then
        mv "$command.log" "$command.0.log"
    fi

    for (( i=$cycle_length; i > 0; i-- ))
    do
        if [[ -e "$command.$((i-1)).log" ]]
        then
            mv "$command.$((i-1)).log" "$command.$i.log"
        fi
    done

    local read_fd=
    local write_fd=
    touch "$command.log"
    exec {write_fd}>"$command.log"
    exec {read_fd}<"$command.log"

    popd &>/dev/null

    bu_sync_release_file "$command"

    BU_RET=("$write_fd" "$read_fd")
    popd &>/dev/null
}

bu_run_log_command()
{
    if [[ -n "$COMP_LINE" ]]
    then
        return 0
    fi

    bu_basename "${BASH_SOURCE[1]}" 
    printf '%q ' "$BU_RET" "$@" >> "$BU_LAST_RUN_CMDS"
    bu_scope_add_cleanup bu_sync_cycle_last_run_cmds
}

bu_run()
{
    bu_scope_push_function
    local is_gdb=false
    local is_log=false
    local is_log_stdout=false
    local copy_logs_to=
    local is_open_logs=false
    local is_kill_existing=false
    local is_ignore_non_zero_exit_code=false
    local watch_interval=
    local is_ldd=false
    local is_dry_run=false
    local is_cached_execute=false
    local is_log_last_run_cmd=true
    local cmd_log_file=
    local working_directory=
    local is_mapfile=false
    local is_mapfile_str=false
    local mapfile_outparam=BU_RET
    local tmux_name=
    local wait_group_fifo=
    local shift_by
    while (($#))
    do
        shift_by=1
        case "$1" in
        --gdb)
            is_gdb=true
            ;;
        --log)
            is_log=true
            ;;
        --log-stdout)
            is_log_stdout=true
            ;;
        --copy-logs-to)
            copy_logs_to=$2
            shift_by=2
            ;;
        --open-logs)
            is_open_logs=true
            ;;
        --kill)
            is_kill_existing=true
            ;;
        --ignore-non-zero-exit-code)
            is_ignore_non_zero_exit_code=true
            ;;
        --watch)
            watch_interval=$2
            shift_by=2
            ;;
        --ldd)
            is_ldd=true
            ;;
        --dry-run)
            is_dry_run=true
            ;;
        --cached)
            is_cached_execute=true
            ;;
        --no-log-last-run-cmd)
            is_log_last_run_cmd=false
            ;;
        --cmd-log-file)
            cmd_log_file=$2
            shift_by=2
            ;;
        --working-directory)
            working_directory=$(realpath -- "$1")
            shift_by=2
            ;;
        --mapfile)
            is_mapfile=true
            ;;
        --mapfile-str)
            is_mapfile_str=true
            ;;
        --mapfile-outparam)
            mapfile_outparam=$2
            shift_by=2
            ;;
        --tmux-name)
            tmux_name=$2
            shift_by=2
            ;;
        --wait-group)
            wait_group_fifo=$2
            shift_by=2
            ;;
        "")
            ;;
        --)
            shift
            break
            ;;
        -*)
            bu_log_unrecognized_option "$1"
            bu_scope_pop_function
            return 1
            ;;
        esac
        shift "$shift_by"
    done

    local command_list=("$@")
    local command_type
    if ! command_type=$(type -t "$command_list")
    then
        bu_log_err "type $command_list failed"
        return 1
    fi

    case "$command_type" in
    function)
        ;;
    file)
        if ! command_list[0]=$(command -v "$command_list")
        then
            bu_log_err "command -v $command_list" failed
            bu_scope_pop_function
            return 1
        fi
        ;;
    *)
        bu_log_err "Unexpected type $command_type"
        bu_scope_pop_function
        return 1
    esac
    bu_basename "$command_list"
    local command=$BU_RET
    local gdb_prefix=()
    local cached_execute_prefix=()
    if "$is_gdb"
    then
        gdb_prefix=(gdb)
        gdb_prefix+=("${command_list[0]}" --args)
        if "$is_log" || "$is_log_stdout"
        then
            bu_log_warn "Logging not supported when debugging with gdb"
            is_log=false
            is_log_stdout=false
            copy_logs_to=
        fi
    elif "$is_cached_execute"
    then
        cached_execute_prefix=(bu_cached_execute)
    else
        # TODO: Trap here?
        :
    fi

    if "$is_log_last_run_cmd"
    then
        {
            printf '%q ' "${command_list[@]}"
            echo
        } >> "$BU_LAST_RUN_CMDS"

        if [[ -n "$cmd_log_file" ]]
        then
            bu_dirname "$cmd_log_file"
            local cmd_log_file_dir=$BU_RET
            bu_mkdir "$cmd_log_file_dir"
            {
                printf '%q ' "${command_list[@]}"
                echo
            } >> "$cmd_log_file"
        fi

        if bu_tmux_is_active
        then
            tmux rename-window -t "$TMUX_PANE" "${tmux_name:-$command}"
        fi
    fi

    if "$is_ldd"
    then
        bu_log_info "LD_LIBRARY_PATH=$LD_LIBRARY_PATH"

    fi
}

# MARK: tmux
bu_tmux_is_active()
{
    [[ -n "$TMUX" && ("$TERM" == screen* || "$TERM" == tmux*) ]]
}


bu_spawn()
{
    :
}


# MARK: VSCode
BU_ENV_IS_WSL=
read -r < /proc/version
if [[ "$REPLY" = *Microsoft* ]]
then
    BU_ENV_IS_WSL=true
else
    BU_ENV_IS_WSL=false
fi

bu_vscode_find_latest_server()
{
    if "$BU_ENV_IS_WSL"
    then
        ls -dt "$HOME"/.vscode-server/bin/* | head -n 1
    else
        ls -dt "$HOME"/.vscode-server/cli/servers/Stable-* | head -n 1
    fi
}

bu_vscode_find_latest_socket()
{
    if "$BU_ENV_IS_WSL"
    then
        ls -t /tmp/vscode-ipc* | head -n 1
    else
        ls -t /run/user/"$UID"/vscode-ipc* | head -n 1
    fi
}

bu_vscode_is_socket_inactive()
{
    local grep_result
    if ! grep_result=$(timeout 1 code --status |& grep --only-matching --max-count=1 -E 'Version|ENOENT')
    then
        return 1
    fi
    case "$grep_result" in
    Version)
        return 0
        ;;
    ENOENT)
        return 1
        ;;
    *)
        return 1
        ;;
    esac
}

# MARK: Environment/Path utilities
bu_env_whichfunc()
{
    shopt -s extdebug
    declare -F "$1"
    shopt -u extdebug
}

__bu_env_append_generic_path()
{
    local -n __path_var=$1
    local path_to_append=$2
    if [[ ":$__path_var:" != *":$path_to_append:"* ]]
    then
        __path_var=${__path_var:+$__path_var:}$path_to_append
    fi
}

__bu_env_prepend_generic_path()
{
    local -n __path_var=$1
    local path_to_prepend=$2
    if [[ ":$__path_var:" != *":$path_to_prepend:"* ]]
    then
        __path_var=$path_to_prepend${__path_var:+:$__path_var}
    fi
}

__bu_env_prepend_generic_path_force()
{
    local -n __path_var=$1
    local path_to_prepend=$2
    __path_var=$path_to_prepend${__path_var:+:$__path_var}
}

bu_env_append_path()
{
    __bu_env_append_generic_path PATH "$1"
}

bu_env_prepend_path()
{
    __bu_env_prepend_generic_path PATH "$1"
}

bu_env_prepend_path_force()
{
    __bu_env_prepend_generic_path_force PATH "$1"
}

bu_env_append_ld_library_path()
{
    __bu_env_append_generic_path LD_LIBRARY_PATH "$1"
}

bu_env_prepend_pythonpath()
{
    __bu_env_prepend_generic_path PYTHONPATH "$1"
}

bu_env_append_pythonpath()
{
    __bu_env_append_generic_path PYTHONPATH "$1"
}

bu_env_prepend_path_force()
{
    __bu_env_prepend_generic_path_force PYTHONPATH "$1"
}

__bu_env_remove_from_generic_path()
{
    local -n __path_var=$1
    local path_to_remove=$2
    __path_var=${__path_var//:$path_to_remove:/:} # delete instances in the middle
    __path_var=${__path_var/#$path_to_remove:/} # delete instance at the beginning
    __path_var=${__path_var%:$path_to_remove/} # delete instance at the end
}

bu_env_remove_from_path()
{
    __bu_env_remove_from_generic_path PATH "$1"
}

bu_env_remove_from_ld_library_path()
{
    __bu_env_remove_from_generic_path LD_LIBRARY_PATH "$1"
}

bu_env_remove_from_pythonpath()
{
    __bu_env_remove_from_generic_path PYTHONPATH "$1"
}

bu_env_rename_func()
{
    local old_func_name=$1
    local new_func_name=$2

    eval "$(declare -f "$old_func_name" | sed -r "s/\b$old_func_name\b/$new_func_name/g")"
}

# MARK: Pretty printers
bu_print_var()
{
    local -n __bu_print_var_name=$1
    local key
    local value
    printf "name: %s\nvalue:\n" "$1"
    for key in "${__bu_print_var_name[@]}"
    do
        printf "  [%s]=%s\n" "$key" "${__bu_print_var_name[$key]}"
    done
}

# MARK: Pre-Init utilities
__bu_bind_edit()
{
    local editor=${EDITOR:-vim}
    local tmp_file=$(mktemp).sh
    printf '%s\n' "$READLINE_LINE" > "$tmp_file"
    $editor "$tmp_file"
    READLINE_LINE=$(< "$tmp_file")
    READLINE_POINT=${#READLINE_LINE}
    rm -f "$tmp_file"
}

__bu_bind_toggle_gdb()
{
    local words=()
    read -a words <<<"$READLINE_LINE"
    case "$words" in
    gdb) words=("${words[@]:3}") ;;
    '') return ;;
    *) words=(gdb "${words[0]}" --args "${words[@]}")
    esac
    READLINE_LINE=${words[*]}
}

declare -A -g BU_KEY_BINDINGS=(
    ['\ee']=__bu_bind_edit
    ['\eg']=__bu_bind_toggle_gdb
    ['\ea']=__bu_bind_fzf_history
    ['\ex']=__bu_bind_fzf_autocomplete
)
bu_preinit_register_user_defined_key_binding()
{
    local key=$1
    local binding=$2
    BU_KEY_BINDINGS[$key]=$binding
}

