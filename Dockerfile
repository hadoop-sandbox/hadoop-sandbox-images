# syntax=docker/dockerfile:1.3
ARG java_version=8

FROM ubuntu:jammy AS hadoop-downloads
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

RUN apt-get -q update && \
  DEBIAN_FRONTEND=noninteractive apt-get -q install --yes --no-upgrade --no-install-recommends tzdata curl ca-certificates locales jq && \
  echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
  locale-gen en_US.UTF-8 && \
  rm -rf /var/lib/apt/lists/*
COPY --chown=root:root ./hadoop-downloads /hadoop-downloads
RUN install -d /dists
ARG TARGETPLATFORM
ARG java_version=8
RUN /hadoop-downloads/download.sh -d /dists -p "$TARGETPLATFORM" -j "$java_version" /hadoop-downloads/deps.json

FROM ubuntu:jammy AS hadoop-dist
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
WORKDIR /root
ENV DEBIAN_FRONTEND="noninteractive" \
  DEBCONF_TERSE="true"

#######
# Adoptium Temurin 8 JDK
#######
COPY --chown=root:root ./hadoop-dist/adoptium.asc /usr/share/keyrings/adoptium.asc
RUN chmod 644 /usr/share/keyrings/adoptium.asc && \
  echo -e "APT::Install-Recommends \"0\";\nAPT::Install-Suggests \"0\";" > /etc/apt/apt.conf.d/10disableextras && \
  apt-get -q update && \
  apt-get -q install --yes --no-upgrade --no-install-recommends apt-transport-https ca-certificates && \
  echo "deb [signed-by=/usr/share/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb focal main" > /etc/apt/sources.list.d/adoptium.list && \
  apt-get -q update && \
  apt-get -q install --yes --no-upgrade --no-install-recommends temurin-8-jdk adoptium-ca-certificates && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

#######
# Other build dependencies
#######
RUN apt-get -q update && \
  apt-get -q install --yes --no-upgrade --no-install-recommends \
    apt-utils \
    bats \
    build-essential \
    bzip2 \
    clang \
    cmake \
    curl \
    doxygen \
    fuse \
    g++ \
    gcc \
    git \
    gnupg-agent \
    libbz2-dev \
    libcurl4-openssl-dev \
    libfuse-dev \
    libsasl2-dev \
    libsnappy-dev \
    libssl-dev \
    libtool \
    libzstd-dev \
    locales \
    make \
    pkg-config \
    python3 \
    python3-pip \
    python3-pkg-resources \
    python3-setuptools \
    python3-wheel \
    shellcheck \
    zlib1g-dev \
    maven \
    libbcprov-java && \
  if [ "$(uname -m)" == "x86_64" ]; then DEBIAN_FRONTEND=noninteractive apt-get -q install --yes --no-upgrade --no-install-recommends libisal-dev ; fi && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*
ENV PYTHONIOENCODING="utf-8" \
  MAVEN_OPTS="-Xms256m -Xmx1536m"


#######
# Install python dependencies
#######
RUN python3 -m pip install --no-cache-dir pylint==2.6.0 python-dateutil==2.8.1


#######
# Install SpotBugs 4.2.2
#######
ARG TARGETPLATFORM
ARG java_version=8
RUN --mount=type=bind,from=hadoop-downloads,source=/dists,target=/dists install -d "/opt/spotbugs" && \
  tar xzf "/dists/$java_version/$TARGETPLATFORM/spotbugs.tgz" --strip-components 1 -C "/opt/spotbugs" && \
  chown -R root:root /opt/spotbugs && \
  find /opt/spotbugs -type d -print0 | xargs -r0 chmod 755 && \
  find /opt/spotbugs -type f -print0 | xargs -r0 chmod 644 && \
  find /opt/spotbugs/bin -type f -print0 | xargs -r0 chmod 755
ENV SPOTBUGS_HOME="/opt/spotbugs"


######
# Install Google Protobuf 3.7.1 (3.6.1 ships with Focal)
######
RUN --mount=type=bind,from=hadoop-downloads,source=/dists,target=/dists --mount=type=cache,target=/root/.m2 install -d "/opt/protobuf-src" && \
  tar xzf "/dists/$java_version/$TARGETPLATFORM/protobuf-java.tgz" --strip-components 1 -C "/opt/protobuf-src" && \
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
  tar xzf "/dists/$java_version/$TARGETPLATFORM/hadoop-src.tgz" --strip-components 1 -C "/opt/hadoop-src" && \
  cd "/opt/hadoop-src" && \
  for patch in /patches/*; do \
    patch -p1 < "$patch"; \
  done && \
  export JAVA_HOME=$(echo /usr/lib/jvm/temurin-8-jdk*) && \
  mvn dependency:go-offline -Pdist,native -DskipTests -Dtar -Dmaven.javadoc.skip=true && \
  mvn package -Pdist,native -DskipTests -Dtar -Dmaven.javadoc.skip=true && \
  install -d -m 755 -o root -g root "/hadoop" && \
  tar xzf "/opt/hadoop-src/hadoop-dist/target/hadoop-3.3.4.tar.gz" --strip-components 1 -C "/hadoop" && \
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

FROM ubuntu:jammy AS hadoop-base
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'
ARG TARGETPLATFORM
RUN apt-get -q update && \
  DEBIAN_FRONTEND=noninteractive apt-get -q install --yes --no-upgrade --no-install-recommends tzdata curl ca-certificates fontconfig locales libsnappy1v5 libzstd1 zlib1g libbz2-1.0 libssl3 libc6-dbg && \
  case "${TARGETPLATFORM}" in \
    linux/amd64) \
      DEBIAN_FRONTEND=noninteractive apt-get -q install --yes --no-upgrade --no-install-recommends libisal2; \
      ;; \
    *) \
      echo "No additional packages to install"; \
      ;; \
  esac && \
  apt-get clean && \
  echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
  locale-gen en_US.UTF-8 && \
  rm -rf /var/lib/apt/lists/* && \
  ln -s libcrypto.so.3 "/usr/lib/$(uname -m)-linux-gnu/libcrypto.so" && \
  ldconfig
ARG java_version=8
RUN --mount=type=bind,from=hadoop-downloads,source=/dists,target=/dists set -eux; \
    BINARY_DIST="/dists/$java_version/$TARGETPLATFORM/jdk.tgz" && \
    DEBUG_DIST="/dists/$java_version/$TARGETPLATFORM/jdk-debugimage.tgz"; \
    install -d /opt/java/openjdk && \
    tar xzf "${BINARY_DIST}" --strip-components=1 -C '/opt/java/openjdk' && \
    tar xzf "${DEBUG_DIST}" --strip-components=2 -C '/opt/java/openjdk'
ENV JAVA_HOME=/opt/java/openjdk \
    PATH="/opt/java/openjdk/bin:$PATH"
COPY --from=hadoop-dist /hadoop /hadoop
ENV HADOOP_HOME="/hadoop" \
  PATH="/hadoop/bin:/hadoop/sbin:${PATH}"
COPY --chown=root:root ./hadoop-base/docker-entrypoint.sh /docker-entrypoint.sh
COPY --chown=root:root ./hadoop-base/environment /etc/environment
RUN useradd -ms /bin/bash sandbox && \
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
   DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-upgrade --no-install-recommends openssh-server && \
   apt-get clean && \
   rm -rf /var/lib/apt/lists/* && \
   install -d -o root -g root -m 755 /run/sshd && \
   rm /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub && \
   mv /etc/ssh /etc/ssh.in
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
