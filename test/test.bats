#!/usr/bin/env -S bats --jobs 16 

setup() {
    load "test_helper/bats-assert/load.bash"    
    load "test_helper/bats-support/load.bash"

    # get the containing directory of this file
    # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
    # as those will point to the bats executable's location or the preprocessed file respectively
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    # shellcheck source=../bu_entrypoint.sh
    source "$DIR"/../bu_entrypoint.sh

    # shellcheck source=./test_helper/bu_bats_decl.sh
    source "$BU_NULL"
}

function test_bu_basename { #@test
    bu_basename /a/ab/abc/d.txt
    assert_equal "$BU_RET" d.txt

    bu_basename a/ab/abc/d.txt.log
    assert_equal "$BU_RET" d.txt.log

    bu_basename ./.././d.txt
    assert_equal "$BU_RET" d.txt

    bu_basename ../d.txt
    assert_equal "$BU_RET" d.txt

    bu_basename d.txt
    assert_equal "$BU_RET" d.txt
}

function test_bu_dirname { #@test
    bu_dirname /a/ab/abc/d.txt
    assert_equal "$BU_RET" /a/ab/abc

    bu_dirname a/ab/abc/d.txt.log
    assert_equal "$BU_RET" a/ab/abc

    bu_dirname ./d.txt
    assert_equal "$BU_RET" .

    bu_dirname ../d.txt
    assert_equal "$BU_RET" ..

    bu_dirname d.txt
    assert_equal "$BU_RET" .
}

function test_bu_realpath { #@test
    bu_realpath /a/ab/abc/d.txt
    assert_equal "$BU_RET" /a/ab/abc/d.txt

    bu_realpath d.txt
    assert_equal "$BU_RET" "$PWD/d.txt"

    bu_realpath ./d.txt
    assert_equal "$BU_RET" "$PWD/d.txt"

    bu_realpath d.txt "$DIR"
    assert_equal "$BU_RET" "$DIR/d.txt"
}

# Helper functions for bu_ret_to_stdout tests
__test_cmd_hello() { BU_RET="hello"; }
__test_cmd_world() { BU_RET="world"; }
__test_cmd_array() { BU_RET=(one two three); }
__test_cmd_lines() { BU_RET=(line1 line2 line3); }
__test_cmd_array_first() { BU_RET=(first second); }
__test_cmd_empty() { BU_RET=""; }
__test_cmd_failing() { BU_RET="test"; return 42; }

# Helper functions for bu_stdout_to_ret tests
__test_stdout_hello() { echo -n "hello"; }
__test_stdout_world() { echo -n "world"; }
__test_stdout_words() { echo "one two three"; }
__test_stdout_lines() { printf "line1\nline2\nline3\n"; }
__test_stdout_multiline() { printf "line1\nline2\nline3"; }
__test_stdout_failing() { echo "output"; return 7; }

# Tests for bu_ret_to_stdout
function test_bu_ret_to_stdout { #@test
    local output
    
    # Test --str mode
    output=$(bu_ret_to_stdout --str __test_cmd_hello)
    assert_equal "$output" "hello"
    
    # Test default mode (same as --spaces)
    output=$(bu_ret_to_stdout __test_cmd_world)
    assert_equal "$output" "world"
    
    # Test --spaces with array
    output=$(bu_ret_to_stdout --spaces __test_cmd_array)
    assert_equal "$output" "one two three "
    
    # Test --lines with array
    output=$(bu_ret_to_stdout --lines __test_cmd_lines)
    # Note that Bash will strip any trailing whitespace produced from a subshell
    assert_equal "$output" $'line1\nline2\nline3'
    
    # Test --str with array (only outputs first element)
    output=$(bu_ret_to_stdout --str __test_cmd_array_first)
    assert_equal "$output" "first"
    
    # Test with empty string
    output=$(bu_ret_to_stdout --str __test_cmd_empty)
    assert_equal "$output" ""
    
    # Test that exit code is preserved
    run bu_ret_to_stdout --str __test_cmd_failing
    assert_failure 42
    
    # Test invalid option
    run bu_ret_to_stdout --invalid __test_cmd_hello
    assert_failure 1
}

# Tests for bu_stdout_to_ret
function test_bu_stdout_to_ret { #@test
    # Test --str mode
    bu_stdout_to_ret --str __test_stdout_hello
    assert_equal "$BU_RET" "hello"
    
    # Test default mode (same as --spaces)
    bu_stdout_to_ret __test_stdout_world
    assert_equal "$BU_RET" "world"
    
    # Test --spaces with multiple words
    bu_stdout_to_ret --spaces __test_stdout_words
    assert_equal "${BU_RET[0]}" "one"
    assert_equal "${BU_RET[1]}" "two"
    assert_equal "${BU_RET[2]}" "three"
    
    # Test --lines mode
    bu_stdout_to_ret --lines __test_stdout_lines
    assert_equal "${BU_RET[0]}" "line1"
    assert_equal "${BU_RET[1]}" "line2"
    assert_equal "${BU_RET[2]}" "line3"
    
    # Test custom outparam with short form
    bu_stdout_to_ret --str -o MY_VAR __test_stdout_hello
    assert_equal "$MY_VAR" "hello"
    
    # Test custom outparam with long form
    bu_stdout_to_ret --str --outparam MY_VAR2 __test_stdout_hello
    assert_equal "$MY_VAR2" "hello"
    
    # Test exit code preservation
    run bu_stdout_to_ret --str __test_stdout_failing
    assert_failure 7
    
    # Test multiline output is preserved
    bu_stdout_to_ret --lines __test_stdout_multiline
    assert_equal ${#BU_RET[@]} 3
    assert_equal "${BU_RET[0]}" "line1"
    assert_equal "${BU_RET[1]}" "line2"
    assert_equal "${BU_RET[2]}" "line3"
    
    # Test invalid option
    run bu_stdout_to_ret --invalid __test_stdout_hello
    assert_failure 1
}

# Tests for bu_symbol_is_function
function test_bu_symbol_is_function { #@test
    # Test with an existing function
    run bu_symbol_is_function bu_realpath
    assert_success
    
    # Test with builtin command (not a function)
    run bu_symbol_is_function echo
    assert_failure
    
    # Test with another builtin
    run bu_symbol_is_function cd
    assert_failure
    
    # Test with nonexistent symbol
    run bu_symbol_is_function nonexistent_function_xyz
    assert_failure
}

# Tests for bu_symbol_is_file
function test_bu_symbol_is_file { #@test
    # Test with absolute path to existing file
    run bu_symbol_is_file /bin/bash
    assert_success
    
    # Test with nonexistent path
    run bu_symbol_is_file /nonexistent/path/to/file
    assert_failure
    
    # Test with function (not a file)
    run bu_symbol_is_file bu_realpath
    assert_failure
    
    # Test with builtin (not a file)
    run bu_symbol_is_file echo
    assert_failure
    
    # Test with executable in PATH
    run bu_symbol_is_file bash
    assert_success
}

# Tests for bu_list_join
function test_bu_list_join { #@test
    # Test with comma separator
    bu_list_join , a b c
    assert_equal "$BU_RET" "a,b,c"
    
    # Test with space separator
    bu_list_join " " one two three
    assert_equal "$BU_RET" "one two three"
    
    # Test with pipe separator
    bu_list_join "|" x y z
    assert_equal "$BU_RET" "x|y|z"
    
    # Test with single element
    bu_list_join , single
    assert_equal "$BU_RET" "single"
    
    # Test with empty list
    bu_list_join ,
    assert_equal "$BU_RET" ""
    
    # Test with two elements
    bu_list_join "-" first second
    assert_equal "$BU_RET" "first-second"
}

# Tests for bu_list_reverse
function test_bu_list_reverse { #@test
    # Test with three elements
    bu_list_reverse a b c
    assert_equal "${BU_RET[0]}" "c"
    assert_equal "${BU_RET[1]}" "b"
    assert_equal "${BU_RET[2]}" "a"
    
    # Test with single element
    bu_list_reverse single
    assert_equal "${BU_RET[0]}" "single"
    
    # Test with two elements
    bu_list_reverse first second
    assert_equal "${BU_RET[0]}" "second"
    assert_equal "${BU_RET[1]}" "first"
    
    # Test with many elements
    bu_list_reverse 1 2 3 4 5
    assert_equal "${BU_RET[0]}" "5"
    assert_equal "${BU_RET[1]}" "4"
    assert_equal "${BU_RET[2]}" "3"
    assert_equal "${BU_RET[3]}" "2"
    assert_equal "${BU_RET[4]}" "1"
}

# Tests for bu_list_filter_out_empty
function test_bu_list_filter_out_empty { #@test
    # Test with mixed empty and non-empty elements
    bu_list_filter_out_empty a "" b "" c
    assert_equal "${BU_RET[0]}" "a"
    assert_equal "${BU_RET[1]}" "b"
    assert_equal "${BU_RET[2]}" "c"
    assert_equal ${#BU_RET[@]} 3
    
    # Test with no empty elements
    bu_list_filter_out_empty x y z
    assert_equal "${BU_RET[0]}" "x"
    assert_equal "${BU_RET[1]}" "y"
    assert_equal "${BU_RET[2]}" "z"
    assert_equal ${#BU_RET[@]} 3
    
    # Test with all empty elements
    bu_list_filter_out_empty "" "" ""
    assert_equal ${#BU_RET[@]} 0
    
    # Test with leading/trailing empty
    bu_list_filter_out_empty "" one two ""
    assert_equal "${BU_RET[0]}" "one"
    assert_equal "${BU_RET[1]}" "two"
    assert_equal ${#BU_RET[@]} 2
}

# Tests for bu_list_sort
function test_bu_list_sort { #@test
    # Test basic sorting
    bu_list_sort c a b
    assert_equal "${BU_RET[0]}" "a"
    assert_equal "${BU_RET[1]}" "b"
    assert_equal "${BU_RET[2]}" "c"
    
    # Test with numbers (lexicographic order)
    bu_list_sort 30 1 20 10
    assert_equal "${BU_RET[0]}" "1"
    assert_equal "${BU_RET[1]}" "10"
    assert_equal "${BU_RET[2]}" "20"
    assert_equal "${BU_RET[3]}" "30"
    
    # Test with single element
    bu_list_sort single
    assert_equal "${BU_RET[0]}" "single"
    
    # Test with duplicate elements
    bu_list_sort b a b c a
    assert_equal "${BU_RET[0]}" "a"
    assert_equal "${BU_RET[1]}" "a"
    assert_equal "${BU_RET[2]}" "b"
    assert_equal "${BU_RET[3]}" "b"
    assert_equal "${BU_RET[4]}" "c"
}

# Tests for bu_list_exists_str
function test_bu_list_exists_str { #@test
    local haystack=(apple banana cherry)
    
    # Test element exists
    run bu_list_exists_str banana "${haystack[@]}"
    assert_success
    
    # Test first element
    run bu_list_exists_str apple "${haystack[@]}"
    assert_success
    
    # Test last element
    run bu_list_exists_str cherry "${haystack[@]}"
    assert_success
    
    # Test element not in list
    run bu_list_exists_str orange "${haystack[@]}"
    assert_failure 1
    
    # Test with single element list (match)
    run bu_list_exists_str single single
    assert_success
    
    # Test with single element list (no match)
    run bu_list_exists_str needle haystack
    assert_failure 1
    
    # Test with empty list
    run bu_list_exists_str something
    assert_failure 1
}

# Tests for bu_str_split
function test_bu_str_split { #@test
    # Test basic comma split
    bu_str_split , "a,b,c"
    assert_equal "${BU_RET[0]}" "a"
    assert_equal "${BU_RET[1]}" "b"
    assert_equal "${BU_RET[2]}" "c"
    
    # Test space separator
    bu_str_split " " "one two three"
    assert_equal "${BU_RET[0]}" "one"
    assert_equal "${BU_RET[1]}" "two"
    assert_equal "${BU_RET[2]}" "three"
    
    # Test with custom separator
    bu_str_split "|" "x|y|z"
    assert_equal "${BU_RET[0]}" "x"
    assert_equal "${BU_RET[1]}" "y"
    assert_equal "${BU_RET[2]}" "z"
    
    # Test with single element (no separator in string)
    bu_str_split , "single"
    assert_equal "${BU_RET[0]}" "single"
    
    # Test with custom output variable
    bu_str_split , "a,b,c" MY_ARRAY
    assert_equal "${MY_ARRAY[0]}" "a"
    assert_equal "${MY_ARRAY[1]}" "b"
    assert_equal "${MY_ARRAY[2]}" "c"
    
    # Test empty string results in single empty element
    bu_str_split , ""
    assert_equal ${#BU_RET[@]} 1
    assert_equal "${BU_RET[0]}" ""
}

# Tests for __bu_env_append_generic_path
function test_bu_env_append_generic_path { #@test
    # Test appending to empty path variable
    local TEST_PATH=""
    __bu_env_append_generic_path TEST_PATH "/usr/bin"
    assert_equal "$TEST_PATH" "/usr/bin"
    
    # Test appending to existing path
    TEST_PATH="/usr/bin"
    __bu_env_append_generic_path TEST_PATH "/usr/local/bin"
    assert_equal "$TEST_PATH" "/usr/bin:/usr/local/bin"
    
    # Test appending when path already exists (should not duplicate)
    TEST_PATH="/usr/bin:/usr/local/bin"
    __bu_env_append_generic_path TEST_PATH "/usr/bin"
    assert_equal "$TEST_PATH" "/usr/bin:/usr/local/bin"
    
    # Test appending another new path
    TEST_PATH="/usr/bin:/usr/local/bin"
    __bu_env_append_generic_path TEST_PATH "/opt/bin"
    assert_equal "$TEST_PATH" "/usr/bin:/usr/local/bin:/opt/bin"

    TEST_PATH="/usr/local/bin"
    __bu_env_append_generic_path TEST_PATH "/usr/bin"
    assert_equal "$TEST_PATH" "/usr/local/bin:/usr/bin"
    
    # Test appending to path with multiple entries
    TEST_PATH="/a:/b:/c"
    __bu_env_append_generic_path TEST_PATH "/d"
    assert_equal "$TEST_PATH" "/a:/b:/c:/d"

    TEST_PATH="/a:/b:/c"
    __bu_env_append_generic_path TEST_PATH "/d:/a:/b:/c"
    assert_equal "$TEST_PATH" "/a:/b:/c:/d:/a:/b:/c"
}

# Tests for __bu_env_prepend_generic_path
function test_bu_env_prepend_generic_path { #@test
    # Test prepending to empty path variable
    local TEST_PATH=""
    __bu_env_prepend_generic_path TEST_PATH "/usr/bin"
    assert_equal "$TEST_PATH" "/usr/bin"
    
    # Test prepending to existing path
    TEST_PATH="/usr/local/bin"
    __bu_env_prepend_generic_path TEST_PATH "/usr/bin"
    assert_equal "$TEST_PATH" "/usr/bin:/usr/local/bin"
    
    # Test prepending when path already exists (should not duplicate)
    TEST_PATH="/usr/bin:/usr/local/bin"
    __bu_env_prepend_generic_path TEST_PATH "/usr/bin"
    assert_equal "$TEST_PATH" "/usr/bin:/usr/local/bin"
    
    # Test prepending another new path (goes to front)
    TEST_PATH="/usr/bin:/usr/local/bin"
    __bu_env_prepend_generic_path TEST_PATH "/opt/bin"
    assert_equal "$TEST_PATH" "/opt/bin:/usr/bin:/usr/local/bin"
    
    # Test prepending to path with multiple entries
    TEST_PATH="/a:/b:/c"
    __bu_env_prepend_generic_path TEST_PATH "/z"
    assert_equal "$TEST_PATH" "/z:/a:/b:/c"
    
    # Test that prepend checks for exact match (with colons)
    TEST_PATH="/usr/local/bin"
    __bu_env_prepend_generic_path TEST_PATH "/usr/bin"
    assert_equal "$TEST_PATH" "/usr/bin:/usr/local/bin"
}



# Tests for __bu_env_remove_from_generic_path
function test_bu_env_remove_from_generic_path { #@test
    # Remove from empty path (no-op)
    local TEST_PATH=""
    __bu_env_remove_from_generic_path TEST_PATH "/usr/bin"
    assert_equal "$TEST_PATH" ""

    # Remove middle element
    TEST_PATH="/a:/b:/c"
    __bu_env_remove_from_generic_path TEST_PATH "/b"
    assert_equal "$TEST_PATH" "/a:/c"

    # Remove first element
    TEST_PATH="/b:/a:/c"
    __bu_env_remove_from_generic_path TEST_PATH "/b"
    assert_equal "$TEST_PATH" "/a:/c"

    # Remove last element
    TEST_PATH="/a:/b:/c"
    __bu_env_remove_from_generic_path TEST_PATH "/c"
    assert_equal "$TEST_PATH" "/a:/b"

    # Remove duplicate elements
    TEST_PATH="/a:/b:/a:/c"
    __bu_env_remove_from_generic_path TEST_PATH "/a"
    # both /a occurrences should be removed
    assert_equal "$TEST_PATH" "/b:/c"

    # Remove non-existent element (no-op)
    TEST_PATH="/x:/y:/z"
    __bu_env_remove_from_generic_path TEST_PATH "/notfound"
    assert_equal "$TEST_PATH" "/x:/y:/z"

    # Ensure substrings are not removed (exact match required)
    TEST_PATH="/usr/local/bin:/usr/bin"
    __bu_env_remove_from_generic_path TEST_PATH "/usr"
    assert_equal "$TEST_PATH" "/usr/local/bin:/usr/bin"

    # It is allowed to remove multiple consecutive paths at once
    TEST_PATH="/a:/b:/c"
    __bu_env_remove_from_generic_path TEST_PATH "/b:/c"
    assert_equal "$TEST_PATH" "/a"

    TEST_PATH="/a:/b:/c"
    __bu_env_remove_from_generic_path TEST_PATH "/a:/b"
    assert_equal "$TEST_PATH" "/c"

    TEST_PATH="/a"
    __bu_env_remove_from_generic_path TEST_PATH "/a"
    assert_equal "$TEST_PATH" ""
}


