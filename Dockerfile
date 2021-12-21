ARG java_version=8

FROM eclipse-temurin:${java_version}-jdk-focal AS downloader
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
WORKDIR /tmp
COPY --chown=root:root ./hadoop-base/hadoop-downloader.sh /tmp/hadoop-downloader.sh
RUN chown root:root /tmp/hadoop-downloader.sh && \
  chmod 755 /tmp/hadoop-downloader.sh && \
  /tmp/hadoop-downloader.sh / && \
  rm /tmp/hadoop-downloader.sh
RUN apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-upgrade --no-install-recommends tini gosu && \
  rm -rf /var/lib/apt/lists/*
COPY --chown=root:root ./hadoop-base/environment /etc/environment
RUN chown root:root /etc/environment && \
  chmod 644 /etc/environment
 
FROM eclipse-temurin:${java_version}-jdk-focal AS hadoop-base
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
COPY --from=downloader /hadoop /hadoop
COPY --from=downloader /usr/bin/tini /tini
COPY --from=downloader /usr/sbin/gosu /sbin/gosu
COPY --from=downloader /etc/environment /etc/environment
ENV HADOOP_HOME="/hadoop" \
  PATH="/hadoop/bin:/hadoop/sbin:${PATH}"
COPY --chown=root:root ./hadoop-base/docker-entrypoint.sh /docker-entrypoint.sh
RUN useradd -ms /bin/bash sandbox && \
  echo "sandbox:sandbox" | chpasswd && \
  groupadd -r -g 120 hadoop && \
  groupadd -r -g 121 hdfs && \
  groupadd -r -g 122 yarn && \
  groupadd -r -g 123 mapred && \
  useradd -r -u 121 -g hdfs -Ms /bin/bash -d / -G hadoop hdfs && \
  useradd -r -u 122 -g yarn -Ms /bin/bash -d / -G hadoop yarn && \
  useradd -r -u 123 -g mapred -Ms /bin/bash -d / -G hadoop mapred && \
  ln -s libcrypto.so.1.1 "/usr/lib/$(uname -m)-linux-gnu/libcrypto.so" && \
  ldconfig && \
  chown root:root /docker-entrypoint.sh && \
  chmod 755 /docker-entrypoint.sh && \
  install -d -o root -g hadoop -m 775 /data && \
  apt-get update && \
  if [ "$(uname -m)" == "x86_64" ]; then DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-upgrade --no-install-recommends libisal2 ; fi && \
  rm -rf /var/lib/apt/lists/*
WORKDIR /
ENTRYPOINT ["/tini", "--", "/docker-entrypoint.sh"]

FROM hadoop-base AS hadoop-client
COPY --chown=root:root ./hadoop-client/docker-entrypoint.d /docker-entrypoint.d
RUN  apt-get update && \
   DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-upgrade --no-install-recommends openssh-server && \
   rm -rf /var/lib/apt/lists/* && \
   install -d -o root -g root -m 755 /run/sshd && \
   rm /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub && \
   mv /etc/ssh /etc/ssh.in
CMD ["/usr/sbin/sshd", "-D", "-e"]

FROM hadoop-base AS hadoop-hdfs-datanode
COPY --chown=root:root ./hadoop-hdfs-datanode/docker-entrypoint.d /docker-entrypoint.d
CMD ["gosu", "hdfs", "hdfs", "datanode"]

FROM hadoop-base AS hadoop-hdfs-namenode
COPY --chown=root:root ./hadoop-hdfs-namenode/docker-entrypoint.d /docker-entrypoint.d
CMD ["gosu", "hdfs", "hdfs", "namenode"]

FROM hadoop-base AS hadoop-mapred-jobhistoryserver
COPY --chown=root:root ./hadoop-mapred-jobhistoryserver/docker-entrypoint.d /docker-entrypoint.d
CMD ["gosu", "mapred", "mapred", "historyserver"]

FROM hadoop-base AS hadoop-yarn-nodemanager
CMD ["gosu", "yarn", "yarn", "nodemanager"]

FROM hadoop-base AS hadoop-yarn-resourcemanager
CMD ["gosu", "yarn", "yarn", "resourcemanager"]
