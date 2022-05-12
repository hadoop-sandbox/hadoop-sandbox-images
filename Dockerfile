# syntax=docker/dockerfile:1.3
ARG java_version=8

FROM ubuntu:focal AS hadoop-downloads
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

RUN apt-get -q update && \
  DEBIAN_FRONTEND=noninteractive apt-get -q install --yes --no-upgrade --no-install-recommends tzdata curl ca-certificates locales && \
  echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
  locale-gen en_US.UTF-8 && \
  rm -rf /var/lib/apt/lists/*
RUN install -d /dists
RUN echo "Downloading spotbugs" && \
  curl -fsSLo "/dists/spotbugs.tgz" \
    "https://github.com/spotbugs/spotbugs/releases/download/4.2.2/spotbugs-4.2.2.tgz" && \
  echo "4967c72396e34b86b9458d0c34c5ed185770a009d357df8e63951ee2844f769f */dists/spotbugs.tgz" | sha256sum -c
RUN echo "Downloading protobuf" && \
  curl -fsSLo "/dists/protobuf-java.tar.gz" \
    "https://github.com/protocolbuffers/protobuf/releases/download/v3.7.1/protobuf-java-3.7.1.tar.gz" && \
  echo "8d1479b233d2c5c68b6c7e22ec9a7bb84d8cfe0b1d9c491377d50c3df80a162f */dists/protobuf-java.tar.gz" | sha256sum -c
RUN echo "Downloading Temurin 8 JDK Binaries" && \
  ARCH="$(dpkg --print-architecture)" && \
  case "${ARCH}" in \
    aarch64|arm64) \
      ESUM='d10efb2afad3ed3d7bac9d3249cea77928aca6acb973cac0f90a2dd3606a3533' && \
      BINARY_URL='https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u332-b09/OpenJDK8U-jdk_aarch64_linux_hotspot_8u332b09.tar.gz'; \
      ;; \
    amd64|i386:x86-64) \
      ESUM='adc13a0a0540d77f0a3481b48f10d61eb203e5ad4914507d489c2de3bd3d83da' && \
      BINARY_URL='https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u332-b09/OpenJDK8U-jdk_x64_linux_hotspot_8u332b09.tar.gz'; \
      ;; \
    *) \
      echo "Unsupported arch: ${ARCH}" && \
      exit 1; \
      ;; \
  esac && \
  curl -fsSLo "/dists/openjdk8.tar.gz" "${BINARY_URL}" && \
  echo "${ESUM} */dists/openjdk8.tar.gz" | sha256sum -c -
RUN echo "Downloading Temurin 8 JDK Debug Symbols" && \
  ARCH="$(dpkg --print-architecture)" && \
  case "${ARCH}" in \
    aarch64|arm64) \
      ESUM='1dc4b63632274ccaf5fad0f561b99144ac576cebaf05fac2c29eec1bd3d7db8a' && \
      BINARY_URL='https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u332-b09/OpenJDK8U-debugimage_aarch64_linux_hotspot_8u332b09.tar.gz'; \
      ;; \
    amd64|i386:x86-64) \
      ESUM='a49350197e5b7166ebc42feed6b56152a68768fccf53a31799b5d80502ff41df'; \
      BINARY_URL='https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u332-b09/OpenJDK8U-debugimage_x64_linux_hotspot_8u332b09.tar.gz'; \
      ;; \
    *) \
      echo "Unsupported arch: ${ARCH}" && \
      exit 1; \
      ;; \
  esac && \
  curl -fsSLo "/dists/openjdk8-debugimage.tar.gz" "${BINARY_URL}" && \
  echo "${ESUM} */dists/openjdk8-debugimage.tar.gz" | sha256sum -c -
RUN echo "Downloading Temurin 11 JDK Binaries" && \
  ARCH="$(dpkg --print-architecture)" && \
  case "${ARCH}" in \
    aarch64|arm64) \
      ESUM='999fbd90b070f9896142f0eb28354abbeb367cbe49fd86885c626e2999189e0a' && \
      BINARY_URL='https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.15%2B10/OpenJDK11U-jdk_aarch64_linux_hotspot_11.0.15_10.tar.gz'; \
      ;; \
    amd64|i386:x86-64) \
      ESUM='5fdb4d5a1662f0cca73fec30f99e67662350b1fa61460fa72e91eb9f66b54d0b' && \
      BINARY_URL='https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.15%2B10/OpenJDK11U-jdk_x64_linux_hotspot_11.0.15_10.tar.gz'; \
      ;; \
    *) \
      echo "Unsupported arch: ${ARCH}" && \
      exit 1; \
      ;; \
  esac && \
  curl -fsSLo "/dists/openjdk11.tar.gz" "${BINARY_URL}" && \
  echo "${ESUM} */dists/openjdk11.tar.gz" | sha256sum -c -
RUN echo "Downloading Temurin 11 JDK Debug Symbols" && \
  ARCH="$(dpkg --print-architecture)" && \
  case "${ARCH}" in \
    aarch64|arm64) \
      ESUM='3cb9bcd7652b90d65157df28852a9f2b3a1d68600790935f19f16c6af1d93873' && \
      BINARY_URL='https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.15%2B10/OpenJDK11U-debugimage_aarch64_linux_hotspot_11.0.15_10.tar.gz'; \
      ;; \
    amd64|i386:x86-64) \
      ESUM='720961b79712a7c108ea060f0f491e428099013d249ad25d2dd31fda6dc2ee66'; \
      BINARY_URL='https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.15%2B10/OpenJDK11U-debugimage_x64_linux_hotspot_11.0.15_10.tar.gz'; \
      ;; \
    *) \
      echo "Unsupported arch: ${ARCH}" && \
      exit 1; \
      ;; \
  esac && \
  curl -fsSLo "/dists/openjdk11-debugimage.tar.gz" "${BINARY_URL}" && \
  echo "${ESUM} */dists/openjdk11-debugimage.tar.gz" | sha256sum -c -
RUN echo "Downloading Hadoop sources" && \
  curl -fsSLo "/dists/hadoop-src.tar.gz" "https://dlcdn.apache.org/hadoop/common/hadoop-3.3.2/hadoop-3.3.2-src.tar.gz" && \
  echo "96c7bb6b0205a5f87dea1bad0b09e70017064439552d632d87abad56b0b2a68fccd62dff38132e2a5c3c60f4c6a34cc69cdbed6510b85b193fb7050f35ac05b8 */dists/hadoop-src.tar.gz" | sha512sum -c -


FROM ubuntu:focal AS hadoop-dist
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
RUN --mount=type=bind,from=hadoop-downloads,source=/dists,target=/dists install -d "/opt/spotbugs" && \
  tar xzf "/dists/spotbugs.tgz" --strip-components 1 -C "/opt/spotbugs" && \
  chown -R root:root /opt/spotbugs && \
  find /opt/spotbugs -type d -print0 | xargs -r0 chmod 755 && \
  find /opt/spotbugs -type f -print0 | xargs -r0 chmod 644 && \
  find /opt/spotbugs/bin -type f -print0 | xargs -r0 chmod 755
ENV SPOTBUGS_HOME="/opt/spotbugs"


######
# Install Google Protobuf 3.7.1 (3.6.1 ships with Focal)
######
RUN --mount=type=bind,from=hadoop-downloads,source=/dists,target=/dists --mount=type=cache,target=/root/.m2 install -d "/opt/protobuf-src" && \
  tar xzf "/dists/protobuf-java.tar.gz" --strip-components 1 -C "/opt/protobuf-src" && \
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
RUN --mount=type=bind,from=hadoop-downloads,source=/dists,target=/dists --mount=type=cache,target=/root/.m2 install -d "/opt/hadoop-src" && \
  tar xzf "/dists/hadoop-src.tar.gz" --strip-components 1 -C "/opt/hadoop-src" && \
  cd "/opt/hadoop-src" && \
  export JAVA_HOME=$(echo /usr/lib/jvm/temurin-8-jdk*) && \
  mvn dependency:go-offline -Pdist,native -DskipTests -Dtar -Dmaven.javadoc.skip=true && \
  mvn package -Pdist,native -DskipTests -Dtar -Dmaven.javadoc.skip=true && \
  install -d -m 755 -o root -g root "/hadoop" && \
  tar xzf "/opt/hadoop-src/hadoop-dist/target/hadoop-3.3.2.tar.gz" --strip-components 1 -C "/hadoop" && \
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

FROM ubuntu:focal AS hadoop-base
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'
RUN apt-get -q update && \
  DEBIAN_FRONTEND=noninteractive apt-get -q install --yes --no-upgrade --no-install-recommends tzdata curl ca-certificates fontconfig locales libsnappy1v5 libzstd1 zlib1g libbz2-1.0 libssl1.1 libc6-dbg tini gosu && \
  ARCH="$(dpkg --print-architecture)" && \
  case "${ARCH}" in \
    amd64|i386:x86-64) \
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
  ln -s libcrypto.so.1.1 "/usr/lib/$(uname -m)-linux-gnu/libcrypto.so" && \
  ldconfig
ARG java_version=8
RUN --mount=type=bind,from=hadoop-downloads,source=/dists,target=/dists set -eux; \
    case "${java_version}" in \
       8) \
         BINARY_DIST='/dists/openjdk8.tar.gz' && \
         DEBUG_DIST='/dists/openjdk8-debugimage.tar.gz'; \
         ;; \
       11) \
         BINARY_DIST='/dists/openjdk11.tar.gz' && \
         DEBUG_DIST='/dists/openjdk11-debugimage.tar.gz'; \
         ;; \
       *) \
         echo "Unsupported java version: ${java_version}"; \
         exit 1; \
         ;; \
    esac && \
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
ENTRYPOINT ["/usr/bin/tini", "--", "/docker-entrypoint.sh"]

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
