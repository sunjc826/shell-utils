#!/usr/bin/env bats

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
