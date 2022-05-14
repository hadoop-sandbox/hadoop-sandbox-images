#!/usr/bin/env bash
set -Eeo pipefail

export SETPRIV_REUID=mapred
export SETPRIV_REGID=mapred
export SETPRIV_CAP_OPTS=""
