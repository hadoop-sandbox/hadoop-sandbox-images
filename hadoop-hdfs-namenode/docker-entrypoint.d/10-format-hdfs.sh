#!/usr/bin/env bash
set -Eeo pipefail
if ! setpriv --reuid=hdfs --regid=hdfs --init-groups hdfs namenode -metadataVersion; then
   setpriv --reuid=hdfs --regid=hdfs --init-groups hdfs namenode -format -nonInteractive
fi

