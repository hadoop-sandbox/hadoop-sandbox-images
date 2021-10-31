#!/usr/bin/env bash
set -Eeo pipefail

if hdfs getconf -confKey dfs.domain.socket.path; then
    readonly sock=$(hdfs getconf -confKey dfs.domain.socket.path)
    readonly sockdir=$(dirname "$sock")
    if [ ! -z "${sockdir}" -a "${sockdir}" != "/"]; then
	install -d -o root -g hdfs -m 775 "${sockdir}"
    fi
    if [ -e "${sock}" ]; then
	rm "${sock}"
    fi
fi
