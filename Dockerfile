ARG java_version=8


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
RUN mkdir -p "/opt/spotbugs" && \
  curl -fsSLo "/opt/spotbugs.tgz" \
    "https://github.com/spotbugs/spotbugs/releases/download/4.2.2/spotbugs-4.2.2.tgz" && \
  echo "4967c72396e34b86b9458d0c34c5ed185770a009d357df8e63951ee2844f769f */opt/spotbugs.tgz" | sha256sum -c && \
  tar xzf "/opt/spotbugs.tgz" --strip-components 1 -C "/opt/spotbugs" && \
  rm "/opt/spotbugs.tgz" && \
  chown -R root:root /opt/spotbugs && \
  find /opt/spotbugs -type d -print0 | xargs -r0 chmod 755 && \
  find /opt/spotbugs -type f -print0 | xargs -r0 chmod 644 && \
  find /opt/spotbugs/bin -type f -print0 | xargs -r0 chmod 755
ENV SPOTBUGS_HOME="/opt/spotbugs"


######
# Install Google Protobuf 3.7.1 (3.6.1 ships with Focal)
######
RUN mkdir -p "/opt/protobuf-src" && \
  curl -fsSLo "/opt/protobuf.tar.gz" \
    "https://github.com/protocolbuffers/protobuf/releases/download/v3.7.1/protobuf-java-3.7.1.tar.gz" && \
  echo "8d1479b233d2c5c68b6c7e22ec9a7bb84d8cfe0b1d9c491377d50c3df80a162f */opt/protobuf.tar.gz" | sha256sum -c && \
  tar xzf "/opt/protobuf.tar.gz" --strip-components 1 -C "/opt/protobuf-src" && \
  rm "/opt/protobuf.tar.gz" && \
  cd /opt/protobuf-src && \
  ./configure --prefix="/opt/protobuf" && \
  make -j$(nproc) && \
  make install && \
  cd /root && \
  rm -rf "/opt/protobuf-src" && \
  rm -rf "${HOME}/.m2"
ENV PROTOBUF_HOME="/opt/protobuf" \
  PATH="${PATH}:/opt/protobuf/bin"

######
# Build Hadoop
######
RUN install -d "/opt/hadoop-src" && \
  curl -fsSLo "/opt/hadoop-src.tar.gz" "https://dlcdn.apache.org/hadoop/common/hadoop-3.3.2/hadoop-3.3.2-src.tar.gz" && \
  echo "96c7bb6b0205a5f87dea1bad0b09e70017064439552d632d87abad56b0b2a68fccd62dff38132e2a5c3c60f4c6a34cc69cdbed6510b85b193fb7050f35ac05b8 */opt/hadoop-src.tar.gz" | sha512sum -c && \
  tar xzf "/opt/hadoop-src.tar.gz" --strip-components 1 -C "/opt/hadoop-src" && \
  rm "/opt/hadoop-src.tar.gz" && \
  cd "/opt/hadoop-src" && \
  export JAVA_HOME=$(echo /usr/lib/jvm/temurin-8-jdk*) && \
  mvn package -Pdist,native -DskipTests -Dtar -Dmaven.javadoc.skip=true && \
  rm -rf "${HOME}/.m2" && \
  install -d -m 755 -o root -g root "/hadoop" && \
  tar xzf "/opt/hadoop-src/hadoop-dist/target/hadoop-3.3.2.tar.gz" --strip-components 1 -C "/hadoop" && \
  chown -R root:root "/hadoop" && \
  find "/hadoop" -type d -print0 | xargs -r0 chmod 755 && \
  find "/hadoop" -type f -print0 | xargs -r0 chmod 644 && \
  find "/hadoop/sbin" -type f -print0 | xargs -r0 chmod 755 && \
  find "/hadoop/bin" -type f -print0 | xargs -r0 chmod 755 && \
  find "/hadoop" -type f -name \*.cmd -print0 | xargs -r0 rm && \
  cd "/root" && \
  rm -rf "/opt/hadoop-src"


FROM eclipse-temurin:${java_version}-jdk-focal AS hadoop-base
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
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
  chmod 755 /docker-entrypoint.sh && \
  apt-get -q update && \
  DEBIAN_FRONTEND=noninteractive apt-get -q install --yes --no-upgrade --no-install-recommends libsnappy1v5 libzstd1 zlib1g libbz2-1.0 libssl1.1 tini gosu && \
  if [ "$(uname -m)" == "x86_64" ]; then DEBIAN_FRONTEND=noninteractive apt-get -q install --yes --no-upgrade --no-install-recommends libisal2 ; fi && \
  ldconfig && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*
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
