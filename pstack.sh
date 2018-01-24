#!/bin/bash

if test $# -ne 1; then
    echo "Usage: `basename $0 .sh` <process-id>      " 1>&2
    echo "Usage: `basename $0 .sh` <process-exe-file>" 1>&2
    exit 1
fi

ARG_PID=$1

if [ "${ARG_PID}" -eq "${ARG_PID}" ] 2>/dev/null; then
    :
else
    ARG_PID=`/bin/ps -e -o "user pid fname" |   \
        awk -v USR_NAME="${USER}"               \
            -v CMD_NAME="${ARG_PID}" '{if(($1 == USR_NAME) && ($3 ~ CMD_NAME)){print $2}}' | head -1`
fi

if test ! -r /proc/${ARG_PID}; then
    echo "Process ${ARG_PID} not found." 1>&2
    exit 1
fi

# GDB doesn't allow "thread apply all bt" when the process isn't
# threaded; need to peek at the process to determine if that or the
# simpler "bt" should be used.

backtrace="bt"
if test -d /proc/${ARG_PID}/task ; then
    # Newer kernel; has a task/ directory.
    if test `/bin/ls /proc/${ARG_PID}/task | /usr/bin/wc -l` -gt 1 2>/dev/null ; then
        backtrace="thread apply all bt"
    fi
elif test -f /proc/${ARG_PID}/maps ; then
    # Older kernel; go by it loading libpthread.
    if /bin/grep -e libpthread /proc/${ARG_PID}/maps > /dev/null 2>&1 ; then
        backtrace="thread apply all bt"
    fi
fi

GDB=${GDB:-/usr/bin/gdb}

if $GDB -nx --quiet --batch --readnever > /dev/null 2>&1; then
    readnever=--readnever
else
    readnever=
fi

# Run GDB, strip out unwanted noise.
$GDB --quiet $readnever -nx /proc/${ARG_PID}/exe ${ARG_PID} <<EOF 2>&1 |
$backtrace
EOF
/bin/sed -n \
    -e 's/^(gdb) //' \
    -e '/^#/p' \
    -e '/^Thread/p'
