#!/usr/bin/env bash
set -Eeo pipefail

export SETPRIV_REUID=yarn
export SETPRIV_REGID=yarn
export SETPRIV_CAP_OPTS=""
