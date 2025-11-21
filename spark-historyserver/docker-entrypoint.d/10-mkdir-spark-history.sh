#!/usr/bin/env bash
set -Eeo pipefail
setpriv --reuid=hdfs --regid=hdfs --init-groups hdfs dfs -mkdir -p /spark-history
setpriv --reuid=hdfs --regid=hdfs --init-groups hdfs dfs -chmod 1777 /spark-history
setpriv --reuid=hdfs --regid=hdfs --init-groups hdfs dfs -chown spark:hadoop /spark-history
