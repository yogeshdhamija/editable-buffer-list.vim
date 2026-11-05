#!/bin/sh
# Test suite for editable-buffer-list.vim. Run it from anywhere:
#
#     test/run.sh            # against `vim`
#     VIM=nvim test/run.sh   # against something else
#
# Exits nonzero if any assertion failed.
#
# Vim runs under a pty (via script(1)) with the tests typed in as keystrokes
# from driver.ex. Both are necessary: TextChanged, which is what the plugin
# hangs the whole sync on, only fires when Vim returns to its main input loop,
# so a `dd` run from a sourced script or `-c` command never triggers it. Tests
# that drove the plugin that way would pass while testing nothing.
#
# The one thing replayed keystrokes do not reproduce is the undo-block
# boundary that real typing puts between commands -- see Sync() in
# harness.vim, which the driver calls before any edit in an ordinary buffer
# that undo depends on.

set -eu

EBL_ROOT=$(cd "$(dirname "$0")/.." && pwd)
export EBL_ROOT
VIM=${VIM:-vim}

command -v "$VIM" >/dev/null || { echo "no $VIM in PATH" >&2; exit 1; }
command -v script >/dev/null || { echo "need script(1) to give vim a pty" >&2; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Fixtures. The names show up verbatim in :ls output, which is what the tests
# search for, so keep them relative by running vim from here.
for f in a b c; do echo "$f" > "$work/$f.txt"; done

# Only the ':' lines are input; the rest of driver.ex is commentary. Vim reads
# the stream as typed keys, so lines are separated by CR.
grep '^:' "$EBL_ROOT/test/driver.ex" | tr '\n' '\r' > "$work/keys"

cmd="$VIM -N -u '$EBL_ROOT/test/harness.vim' -i NONE -n -s '$work/keys'"

# util-linux and BSD script(1) disagree about how to take a command.
if script -qec true /dev/null >/dev/null 2>&1; then
    runner="script -qec \"$cmd\" /dev/null"
else
    runner="script -q /dev/null $VIM -N -u '$EBL_ROOT/test/harness.vim' -i NONE -n -s '$work/keys'"
fi

# stdin is /dev/null on purpose. script(1) still builds vim its own pty either
# way, but if script's *own* stdin is the terminal you launched from, it sits
# there copying that terminal and never exits after vim does -- so running the
# suite by hand would hang, while a piped/CI run (stdin already not a tty)
# would not. Closing it off makes the two behave the same.
#
# If the driver desyncs, vim then runs out of typed input and waits for a key
# that will never come. The timeout caps that rather than hang.
status=0
( cd "$work" && TERM=xterm timeout 120 sh -c "$runner" </dev/null >/dev/null 2>&1 ) || status=$?

if [ ! -f "$work/result.txt" ]; then
    echo "vim wrote no results at all (status $status)." >&2
    exit 1
fi

cat "$work/result.txt"

if [ "$status" -eq 124 ]; then
    echo >&2
    echo "TIMED OUT -- vim was still waiting for input. The results above stop" >&2
    echo "at the last assertion that ran; the driver desynced after it." >&2
    exit 1
fi
exit "$status"
