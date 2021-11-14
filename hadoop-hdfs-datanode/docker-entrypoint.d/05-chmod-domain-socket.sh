#!/usr/bin/env bash
set -Eeo pipefail

if hdfs getconf -confKey dfs.domain.socket.path; then
    readonly sock=$(hdfs getconf -confKey dfs.domain.socket.path)
    readonly sockdir=$(dirname "$sock")
    if [ ! -z "${sockdir}" -a "${sockdir}" != "/" ]; then
	install -d -o hdfs -g hdfs -m 755 "${sockdir}"
    fi
    if [ -e "${sock}" ]; then
	rm "${sock}"
    fi
fi
