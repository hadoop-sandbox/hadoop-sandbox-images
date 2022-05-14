#!/usr/bin/env bash
set -Eeo pipefail
setpriv --reuid=hdfs --regid=hdfs --init-groups hdfs dfs -mkdir -p /mr-history
setpriv --reuid=hdfs --regid=hdfs --init-groups hdfs dfs -mkdir -p /tmp
setpriv --reuid=hdfs --regid=hdfs --init-groups hdfs dfs -chmod 1777 /tmp
setpriv --reuid=hdfs --regid=hdfs --init-groups hdfs dfs -chmod 755 /mr-history
setpriv --reuid=hdfs --regid=hdfs --init-groups hdfs dfs -chown mapred:hadoop /mr-history
