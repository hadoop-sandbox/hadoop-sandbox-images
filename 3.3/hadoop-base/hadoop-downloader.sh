#!/usr/bin/env bash
set -Eeo pipefail

readonly PREFIX=$1

[ -z "${PREFIX}" ] && exit 1

readonly DIST_DIR='hadoop-3.3.1'
readonly AMD64_DOWNLOAD_URL='https://dlcdn.apache.org/hadoop/common/hadoop-3.3.1/hadoop-3.3.1.tar.gz'
readonly AMD64_CHECKSUM='2fd0bf74852c797dc864f373ec82ffaa1e98706b309b30d1effa91ac399b477e1accc1ee74d4ccbb1db7da1c5c541b72e4a834f131a99f2814b030fbd043df66'
readonly AARCH64_DOWNLOAD_URL='https://dlcdn.apache.org/hadoop/common/hadoop-3.3.1/hadoop-3.3.1-aarch64.tar.gz'
readonly AARCH64_CHECKSUM='68549f14d97b519e6afbac5511afd330f3d271dfc6772cb1f8c0412e975e9fa364267ade697f1b0e69ca0cae3b5e43301ae0f899e7d7b3d6bf5ad4ec6f721ff3'

ARCH=$(uname -m)
case "${ARCH}" in
    x86_64)
	readonly DOWNLOAD_URL="${AMD64_DOWNLOAD_URL}"
	readonly CHECKSUM="${AMD64_CHECKSUM}"
	;;
    aarch64)
	readonly DOWNLOAD_URL="${AARCH64_DOWNLOAD_URL}"
	readonly CHECKSUM="${AARCH64_CHECKSUM}"
	;;
    *)
	echo "Unsupported architecture ${ARCH}"
	exit 1
	;;
esac

curl -fsSLo "hadoop.tgz" "${DOWNLOAD_URL}"
echo "SHA512 (hadoop.tgz) = ${CHECKSUM}" | sha512sum -c
tar -C "${PREFIX}" -xzf hadoop.tgz
mv "${PREFIX}/${DIST_DIR}" "${PREFIX}/hadoop"
chown -R root:root "${PREFIX}/hadoop"
chmod -R g-w,o-w "${PREFIX}/hadoop"
install -d -o root -g root -m 1777 "${PREFIX}/hadoop/logs"
rm -rf "${PREFIX}/hadoop/etc/hadoop"
rm -rf "${PREFIX}/hadoop/share/doc"
install -d -o root -g root -m 755 "${PREFIX}/hadoop/etc/hadoop"
rm hadoop.tgz
