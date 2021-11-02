FROM eclipse-temurin:11-jdk-focal AS downloader
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
WORKDIR /tmp
COPY ./hadoop-downloader.sh /tmp/hadoop-downloader.sh
RUN chown root:root /tmp/hadoop-downloader.sh && \
  chmod 755 /tmp/hadoop-downloader.sh && \
  /tmp/hadoop-downloader.sh / && \
  rm /tmp/hadoop-downloader.sh
RUN apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-upgrade --no-install-recommends tini gosu && \
  rm -rf /var/lib/apt/lists/*
COPY ./environment /etc/environment
RUN chown root:root /etc/environment && \
  chmod 644 /etc/environment
 
FROM eclipse-temurin:11-jdk-focal
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
COPY --from=downloader /hadoop /hadoop
COPY --from=downloader /usr/bin/tini /tini
COPY --from=downloader /usr/sbin/gosu /sbin/gosu
COPY --from=downloader /etc/environment /etc/environment
ENV HADOOP_HOME="/hadoop" \
  PATH="/hadoop/bin:/hadoop/sbin:${PATH}" \
  HADOOP_OPTS="-Dhadoop.tmp.dir=/data"
COPY ./docker-entrypoint.sh /docker-entrypoint.sh
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
