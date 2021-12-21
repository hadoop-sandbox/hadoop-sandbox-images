#!/usr/bin/env bash
set -Eeo pipefail

readonly hadoop_tmp_dir="$(hdfs getconf -confKey hadoop.tmp.dir)"
if [ -n "${hadoop_tmp_dir}" ]; then
  install -d -o root -g hadoop "${hadoop_tmp_dir}"
  chown root:hadoop "${hadoop_tmp_dir}"
  chmod 775 "${hadoop_tmp_dir}"
fi
