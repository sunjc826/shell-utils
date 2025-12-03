#!/usr/bin/env bash
# clickhouse client doesn't work with vanilla `export EDITOR=code --wait` (not too sure why)
code --wait "$*"
