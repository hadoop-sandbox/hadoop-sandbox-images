#!/usr/bin/env bash
set -Eeo pipefail

install -d -o sandbox -g sandbox 755 /home/sandbox
setpriv --reuid=hdfs --regid=hdfs --init-groups hdfs dfs -mkdir -p /user/sandbox
setpriv --reuid=hdfs --regid=hdfs --init-groups hdfs dfs -chown sandbox:sandbox /user/sandbox
