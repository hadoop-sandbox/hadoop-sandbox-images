#!/usr/bin/env bash
set -Eeo pipefail

export SETPRIV_REUID=spark
export SETPRIV_REGID=spark
export SETPRIV_CAP_OPTS=""
