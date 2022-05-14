#!/usr/bin/env bash
set -Eeo pipefail

export SETPRIV_REUID=hdfs
export SETPRIV_REGID=hdfs
export SETPRIV_CAP_OPTS=""

