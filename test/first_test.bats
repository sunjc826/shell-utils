#!/usr/bin/env bats

# Alternative syntax to @test "first_test"
# to be IDE-friendly
function first_test { #@test
    echo '# hello world' >&3
    return 0
}

# To have text printed unconditionally from within a test function 
# you need to redirect the output to file descriptor 3, 
# eg echo 'text' >&3. This output will become part of the TAP stream. 
# You are encouraged to prepend text printed this way with a hash 
# (eg echo '# text' >&3) in order to produce 100% TAP compliant output. 
# Otherwise, depending on the 3rd-party tools you use to analyze the TAP stream, 
# you can encounter unexpected behavior or errors.
function check_BATS_internals { #@test
    {
        printf '%s' '# '
        type source 
    } >&3 # Apparently BATS doesn't override source
}
