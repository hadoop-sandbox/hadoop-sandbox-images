# syntax=docker/dockerfile:1
FROM scratch AS hadoop-downloads
ADD --checksum=sha256:024663a47939ed2de962265a99bc6044747b3c3e751d22381f51c75bd2026a1e https://dlcdn.apache.org/hadoop/common/hadoop-3.4.2/hadoop-3.4.2-src.tar.gz /dists//hadoop-src.tgz
ADD --checksum=sha256:2c6a36c7b5a55accae063667ef3c55f2642e67476d96d355ff0acb13dbb47f09 https://github.com/protocolbuffers/protobuf/releases/download/v21.12/protobuf-all-21.12.tar.gz /dists/protobuf.tgz
ADD --checksum=sha256:4967c72396e34b86b9458d0c34c5ed185770a009d357df8e63951ee2844f769f https://github.com/spotbugs/spotbugs/releases/download/4.2.2/spotbugs-4.2.2.tgz /dists/spotbugs.tgz

FROM ubuntu:noble AS base
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
WORKDIR /root
RUN echo -e "APT::Install-Recommends \"0\";\nAPT::Install-Suggests \"0\";" > /etc/apt/apt.conf.d/10disableextras && \
  apt-get -q update && \
  DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=true apt-get -q install --yes --no-upgrade --no-install-recommends --no-install-suggests tzdata locales && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* && \
  echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
  locale-gen en_US.UTF-8 && \
  ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

FROM base AS hadoop-dist
ENV DEBIAN_FRONTEND="noninteractive" \
  DEBCONF_TERSE="true"

#######
# OpenJDK 8 JDK
#######
RUN apt-get -q update && \
  apt-get -q install --yes --no-upgrade --no-install-recommends --no-install-suggests openjdk-8-jdk openjdk-8-dbg && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*
ARG TARGETARCH
ENV JAVA_HOME="/usr/lib/jvm/java-8-openjdk-$TARGETARCH"
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
    libboost-dev \
    libboost-date-time-dev \
    libboost-program-options-dev \
    locales \
    make \
    maven \
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
# Install Google Protobuf 21.12
######
RUN --mount=type=bind,from=hadoop-downloads,source=/dists,target=/dists --mount=type=cache,target=/root/.m2 install -d "/opt/protobuf-src" && \
  tar xzf "/dists/protobuf.tgz" --strip-components 1 -C "/opt/protobuf-src" && \
  cd /opt/protobuf-src && \
  ./configure --prefix="/opt/protobuf" && \
  make -j$(nproc) && \
  make install && \
  rm -rf "/opt/protobuf-src"
ENV PROTOBUF_HOME="/opt/protobuf" \
  PATH="${PATH}:/opt/protobuf/bin"

######
# Build Hadoop
######
COPY ./hadoop-dist/patches /patches
RUN --mount=type=bind,from=hadoop-downloads,source=/dists,target=/dists --mount=type=cache,target=/root/.m2 install -d "/opt/hadoop-src" && \
  tar xzf "/dists/hadoop-src.tgz" --strip-components 1 -C "/opt/hadoop-src" && \
  cd "/opt/hadoop-src" && \
  for patch in /patches/*; do \
    patch -p1 < "$patch"; \
  done && \
  echo "JAVA_HOME: $JAVA_HOME" && \
  mvn --batch-mode package -Pdist,native -DskipTests -Dcyclonedx.skip=true -Dtar -Dmaven.javadoc.skip=true && \
  install -d -m 755 -o root -g root "/hadoop" && \
  tar xzf "/opt/hadoop-src/hadoop-dist/target/hadoop-3.4.2.tar.gz" --strip-components 1 -C "/hadoop" && \
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
ARG java_version=8
RUN apt-get -q update && \
  DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=true apt-get -q install --yes --no-upgrade --no-install-recommends --no-install-suggests "openjdk-${java_version}-jdk" "openjdk-${java_version}-dbg" ca-certificates curl libsnappy1v5 libzstd1 zlib1g libbz2-1.0 libssl3 libc6-dbg libtirpc3 && \
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
ENV JAVA_HOME="/usr/lib/jvm/java-${java_version}-openjdk-$TARGETARCH" \
  HADOOP_HOME="/hadoop" \
  PATH="${PATH}:/hadoop/bin:/hadoop/sbin"
COPY --chown=root:root ./hadoop-base/docker-entrypoint.sh /docker-entrypoint.sh
RUN userdel -r ubuntu && \
  groupadd -g 1000 sandbox && \
  useradd -ms /bin/bash -u 1000 -g 1000 sandbox && \
  echo "sandbox:sandbox" | chpasswd && \
  groupadd -r -g 120 hadoop && \
  groupadd -r -g 121 hdfs && \
  groupadd -r -g 122 yarn && \
  groupadd -r -g 123 mapred && \
  useradd -r -u 121 -g hdfs -Ms /bin/bash -d / -G hadoop hdfs && \
  useradd -r -u 122 -g yarn -Ms /bin/bash -d / -G hadoop yarn && \
  useradd -r -u 123 -g mapred -Ms /bin/bash -d / -G hadoop mapred && \
  chown root:root /docker-entrypoint.sh && \
  chmod 755 /docker-entrypoint.sh
WORKDIR /
ENTRYPOINT ["/docker-entrypoint.sh"]

FROM hadoop-base AS hadoop-client
COPY --chown=root:root ./hadoop-client/docker-entrypoint.d /docker-entrypoint.d
RUN  apt-get update && \
   DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=true apt-get install --yes --no-upgrade --no-install-recommends openssh-server && \
   apt-get clean && \
   rm -rf /var/lib/apt/lists/* && \
   install -d -o root -g root -m 755 /run/sshd && \
   rm /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub && \
   mv /etc/ssh /etc/ssh.in && \
   echo -e "PATH=\"${PATH}\"\nHADOOP_HOME=\"/hadoop\"\nJAVA_HOME=\"${JAVA_HOME}\"\n" >> /etc/environment
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
