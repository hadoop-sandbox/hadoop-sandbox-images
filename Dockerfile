# syntax=docker/dockerfile:1
FROM scratch AS hadoop-downloads
ADD --checksum=sha256:45328a7e5a8fb29ca8503f33e5f0269f8fbbce8824ec9127426aad6d1d9af023 https://archive.apache.org/dist/hadoop/common/hadoop-3.5.0/hadoop-3.5.0-src.tar.gz /dists//hadoop-src.tgz
ADD --checksum=sha256:4356e78744dfb2df3890282386c8568c85868116317d9b3ad80eb11c2aecf2ff https://github.com/protocolbuffers/protobuf/archive/refs/tags/v3.25.5.tar.gz /dists/protobuf.tgz
ADD --checksum=sha256:987ce98f02eefbaf930d6e38ab16aa05737234d7afbab2d5c4ea7adbe50c28ed https://github.com/abseil/abseil-cpp/archive/refs/tags/20230802.1.tar.gz /dists/abseil.tgz
ADD --checksum=sha256:4967c72396e34b86b9458d0c34c5ed185770a009d357df8e63951ee2844f769f https://github.com/spotbugs/spotbugs/releases/download/4.2.2/spotbugs-4.2.2.tgz /dists/spotbugs.tgz
ADD --checksum=sha256:c6569c7e239834bfdc131cb1959125353193381ac2d2a3348a80a8750f006580 https://archive.apache.org/dist/spark/spark-4.1.1/spark-4.1.1-bin-without-hadoop.tgz /dists/spark.tgz
ADD --checksum=sha256:2128a4c96862b5c0970c1e34d76b1d57e4a1016b80df85ad39667f30b1deba26 https://github.com/boostorg/boost/releases/download/boost-1.86.0/boost-1.86.0-b2-nodocs.tar.gz /dists/boost.tgz
ADD --checksum=sha256:4b7195b6a4f5c81af4c0212677a32ee8143643401bc6e1e8412e6b06ea82beac https://archive.apache.org/dist/maven/maven-3/3.9.11/binaries/apache-maven-3.9.11-bin.tar.gz /dists/maven.tgz

FROM ubuntu:noble AS base
ARG TARGETARCH
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
WORKDIR /root
RUN echo -e "APT::Install-Recommends \"0\";\nAPT::Install-Suggests \"0\";" > /etc/apt/apt.conf.d/10disableextras && \
  apt-get -q update && \
  DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=true apt-get -q install --yes --no-upgrade --no-install-recommends --no-install-suggests tzdata locales openjdk-17-jdk && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* && \
  echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
  locale-gen en_US.UTF-8 && \
  ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime && \
  update-java-alternatives -s "java-1.17.0-openjdk-$TARGETARCH" && \
  ln -s "/usr/lib/jvm/java-17-openjdk-$TARGETARCH" /usr/lib/jvm/java-17-openjdk
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8' \
  JAVA_HOME="/usr/lib/jvm/java-17-openjdk-$TARGETARCH"


FROM base AS hadoop-dist
ENV DEBIAN_FRONTEND="noninteractive" \
  DEBCONF_TERSE="true"

#######
# Other build dependencies
#######
ARG TARGETPLATFORM
RUN apt-get -q update && \
  apt-get -q install --yes --no-upgrade --no-install-recommends --no-install-suggests \
    ant \
    apt-utils \
    automake \
    bats \
    build-essential \
    bzip2 \
    libbz2-dev \
    clang \
    cmake \
    curl \
    libcurl4-openssl-dev \
    doxygen \
    fuse \
    libfuse-dev \
    gcc \
    g++ \
    git \
    gnupg-agent \
    hugo \
    libbcprov-java \
    libtool \
    libssl-dev \
    libprotobuf-dev \
    libprotoc-dev \
    libsasl2-dev \
    libsnappy-dev \
    libzstd-dev \
    zlib1g-dev \
    libtirpc-dev \
    locales \
    make \
    pinentry-curses \
    pkg-config \
    python3 \
    python3-pip \
    python3-pkg-resources \
    python3-setuptools \
    python3-wheel \
    rsync \
    shellcheck \
    software-properties-common \
    sudo \
    valgrind \
    yasm \
    python3 \
    pylint \
    python3-dateutil && \
  if [ "$TARGETPLATFORM" == "linux/amd64" ]; then apt-get -q install --yes --no-upgrade --no-install-recommends --no-install-suggests libisal-dev ; fi && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*
ENV PYTHONIOENCODING="utf-8" \
  MAVEN_OPTS="-Xms256m -Xmx1536m"


######
# Install Maven 3.9.11
######
RUN --mount=type=bind,from=hadoop-downloads,source=/dists,target=/dists --mount=type=cache,target=/root/.m2 install -d "/opt/maven" && \
  tar xzf /dists/maven.tgz --strip-components 1 -C /opt/maven
ENV PATH="${PATH}:/opt/maven/bin"


#######
# Install SpotBugs 4.2.2
#######
RUN --mount=type=bind,from=hadoop-downloads,source=/dists,target=/dists install -d "/opt/spotbugs" && \
  tar xzf "/dists/spotbugs.tgz" --strip-components 1 -C "/opt/spotbugs" && \
  chown -R root:root /opt/spotbugs && \
  find /opt/spotbugs -type d -print0 | xargs -r0 chmod 755 && \
  find /opt/spotbugs -type f -print0 | xargs -r0 chmod 644 && \
  find /opt/spotbugs/bin -type f -print0 | xargs -r0 chmod 755
ENV SPOTBUGS_HOME="/opt/spotbugs"


######
# Install Google Protobuf 3.25.5
######
RUN --mount=type=bind,from=hadoop-downloads,source=/dists,target=/dists --mount=type=cache,target=/root/.m2 install -d "/opt/protobuf-src" && \
  tar xzf "/dists/protobuf.tgz" --strip-components 1 -C "/opt/protobuf-src" && \
  tar xzf /dists/abseil.tgz --strip-components 1 -C /opt/protobuf-src/third_party/abseil-cpp && \
  cd /opt/protobuf-src && \
  cmake -S . -B build -DCMAKE_POSITION_INDEPENDENT_CODE=ON -Dprotobuf_BUILD_TESTS=OFF && \
  cmake --build build --parallel $(nproc) && \
  cmake --install build --prefix /opt/protobuf && \
  rm -rf "/opt/protobuf-src"
ENV PROTOBUF_HOME="/opt/protobuf" \
  PATH="${PATH}:/opt/protobuf/bin"


######
# Install Boost 1.86
######
RUN --mount=type=bind,from=hadoop-downloads,source=/dists,target=/dists --mount=type=cache,target=/root/.m2 install -d "/opt/boost-src" && \
  tar xzf "/dists/boost.tgz" --strip-components 1 -C "/opt/boost-src" && \
  cd /opt/boost-src && \
  ./bootstrap.sh --prefix=/usr/ && \
  ./b2 --without-python install && \
  rm -rf "/opt/boost-src"


######
# Build Hadoop
######
RUN --mount=type=bind,from=hadoop-downloads,source=/dists,target=/dists --mount=type=cache,target=/root/.m2 install -d "/opt/hadoop-src" && \
  tar xzf "/dists/hadoop-src.tgz" --strip-components 1 -C "/opt/hadoop-src" && \
  cd "/opt/hadoop-src" && \
  echo "JAVA_HOME: $JAVA_HOME" && \
  mvn --batch-mode package -Pdist,native -DskipTests -Dcyclonedx.skip=true -Dtar -Dmaven.javadoc.skip=true && \
  install -d -m 755 -o root -g root "/hadoop" && \
  tar xzf "/opt/hadoop-src/hadoop-dist/target/hadoop-3.5.0.tar.gz" --strip-components 1 -C "/hadoop" && \
  chown -R root:root "/hadoop" && \
  find "/hadoop" -type d -print0 | xargs -r0 chmod 755 && \
  find "/hadoop" -type f -print0 | xargs -r0 chmod 644 && \
  find "/hadoop/sbin" -type f -print0 | xargs -r0 chmod 755 && \
  find "/hadoop/bin" -type f -print0 | xargs -r0 chmod 755 && \
  find "/hadoop" -type f -name \*.cmd -print0 | xargs -r0 rm && \
  install -d -o root -g root -m 1777 "/hadoop/logs" && \
  rm -rf "/hadoop/etc/hadoop" && \
  rm -rf "/hadoop/share/doc" && \
  install -d -o root -g root -m 755 "/hadoop/etc/hadoop" && \
  rm -rf "/opt/hadoop-src"

FROM base AS hadoop-base
ARG TARGETPLATFORM
RUN apt-get -q update && \
  DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=true apt-get -q install --yes --no-upgrade --no-install-recommends --no-install-suggests ca-certificates curl libsnappy1v5 libzstd1 zlib1g libbz2-1.0 libssl3 libc6-dbg libtirpc3 && \
  case "${TARGETPLATFORM}" in \
    linux/amd64) \
      DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=true apt-get -q install --yes --no-upgrade --no-install-recommends --no-install-suggests libisal2; \
      ;; \
    *) \
      echo "No additional packages to install"; \
      ;; \
  esac && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* && \
  ln -s libcrypto.so.3 "/usr/lib/$(uname -m)-linux-gnu/libcrypto.so" && \
  ldconfig
COPY --from=hadoop-dist /hadoop /hadoop
ARG TARGETARCH
ENV HADOOP_HOME="/hadoop" \
  PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/hadoop/sbin:/hadoop/bin"
COPY --chown=root:root ./hadoop-base/docker-entrypoint.sh /docker-entrypoint.sh
RUN userdel -r ubuntu && \
  groupadd -g 1000 sandbox && \
  useradd -ms /bin/bash -u 1000 -g 1000 sandbox && \
  echo "sandbox:sandbox" | chpasswd && \
  groupadd -r -g 120 hadoop && \
  groupadd -r -g 121 hdfs && \
  groupadd -r -g 122 yarn && \
  groupadd -r -g 123 mapred && \
  groupadd -r -g 124 spark && \
  useradd -r -u 121 -g hdfs -Ms /bin/bash -d / -G hadoop hdfs && \
  useradd -r -u 122 -g yarn -Ms /bin/bash -d / -G hadoop yarn && \
  useradd -r -u 123 -g mapred -Ms /bin/bash -d / -G hadoop mapred && \
  useradd -r -u 124 -g spark -Ms /bin/bash -d / -G hadoop spark && \
  chown root:root /docker-entrypoint.sh && \
  chmod 755 /docker-entrypoint.sh
WORKDIR /
ENTRYPOINT ["/docker-entrypoint.sh"]

FROM hadoop-base AS hadoop-base-spark
RUN --mount=type=bind,from=hadoop-downloads,source=/dists,target=/dists install -d "/spark" && \
  tar xzf "/dists/spark.tgz" --strip-components 1 -C "/spark" && \
  chown -R root:root /spark && \
  find /spark -type d -print0 | xargs -r0 chmod 755 && \
  find /spark -type f -print0 | xargs -r0 chmod 644 && \
  find /spark/bin -type f -print0 | xargs -r0 chmod 755 && \
  find /spark/sbin -type f -print0 | xargs -r0 chmod 755
ENV HADOOP_HOME="/hadoop" \
  PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/hadoop/sbin:/hadoop/bin:/spark/sbin:/spark/bin"

FROM hadoop-base AS hadoop-client
COPY --chown=root:root ./hadoop-client/docker-entrypoint.d /docker-entrypoint.d
RUN apt-get update && \
  DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=true apt-get install --yes --no-upgrade --no-install-recommends openssh-server && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* && \
  install -d -o root -g root -m 755 /run/sshd && \
  rm /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub && \
  mv /etc/ssh /etc/ssh.in && \
  echo -e "PATH=\"${PATH}\"\nHADOOP_HOME=\"/hadoop\"\nJAVA_HOME=\"${JAVA_HOME}\"\n" > /etc/environment
CMD ["/usr/sbin/sshd", "-D", "-e"]

FROM hadoop-base AS hadoop-hdfs-datanode
COPY --chown=root:root ./hadoop-hdfs-datanode/docker-entrypoint.d /docker-entrypoint.d
CMD ["hdfs", "datanode"]

FROM hadoop-base AS hadoop-hdfs-namenode
COPY --chown=root:root ./hadoop-hdfs-namenode/docker-entrypoint.d /docker-entrypoint.d
CMD ["hdfs", "namenode"]

FROM hadoop-base AS hadoop-mapred-jobhistoryserver
COPY --chown=root:root ./hadoop-mapred-jobhistoryserver/docker-entrypoint.d /docker-entrypoint.d
CMD ["mapred", "historyserver"]

FROM hadoop-base AS hadoop-yarn-nodemanager
COPY --chown=root:root ./hadoop-yarn-nodemanager/docker-entrypoint.d /docker-entrypoint.d
CMD ["yarn", "nodemanager"]

FROM hadoop-base AS hadoop-yarn-resourcemanager
COPY --chown=root:root ./hadoop-yarn-resourcemanager/docker-entrypoint.d /docker-entrypoint.d
CMD ["yarn", "resourcemanager"]

FROM hadoop-base-spark AS hadoop-client-spark
COPY --chown=root:root ./hadoop-client/docker-entrypoint.d /docker-entrypoint.d
RUN apt-get update && \
  DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=true apt-get install --yes --no-upgrade --no-install-recommends openssh-server && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* && \
  install -d -o root -g root -m 755 /run/sshd && \
  rm /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub && \
  mv /etc/ssh /etc/ssh.in && \
  echo -e "PATH=\"${PATH}\"\nHADOOP_HOME=\"/hadoop\"\nJAVA_HOME=\"${JAVA_HOME}\"\n" > /etc/environment
CMD ["/usr/sbin/sshd", "-D", "-e"]

FROM hadoop-base-spark AS hadoop-yarn-nodemanager-spark
COPY --chown=root:root ./hadoop-yarn-nodemanager/docker-entrypoint.d /docker-entrypoint.d
CMD ["yarn", "nodemanager"]

FROM hadoop-base-spark AS spark-historyserver
COPY --chown=root:root ./spark-historyserver/docker-entrypoint.d /docker-entrypoint.d
ENV SPARK_NO_DAEMONIZE=true
CMD ["start-history-server.sh"]
