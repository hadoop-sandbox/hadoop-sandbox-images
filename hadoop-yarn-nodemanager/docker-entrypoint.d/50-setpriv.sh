#!/usr/bin/env bash
set -Eeo pipefail

export SETPRIV_REUID=yarn
export SETPRIV_REGID=yarn

# sys_admin and syslog capabilities allow async-profiler to work if host has
#
# kernel.perf_event_paranoid in (-1, 0, 1, 2) AND
# kernel.kptr_restrict in (0, 1)
#
# see:
# https://github.com/jvm-profiling-tools/async-profiler/blob/master/README.md
# https://sysctl-explorer.net/kernel/perf_event_paranoid/
# https://sysctl-explorer.net/kernel/kptr_restrict/
if setpriv "--reuid=${SETPRIV_REUID}" "--regid=${SETPRIV_REGID}" --init-groups --inh-caps +sys_admin,+syslog --ambient-caps +sys_admin,+syslog -- true; then
    echo "Enabling additional capabilities"
    export SETPRIV_CAP_OPTS="--inh-caps +sys_admin,+syslog --ambient-caps +sys_admin,+syslog"
else
    echo "Not enabling additional capabilities"
    export SETPRIV_CAP_OPTS=""
fi
