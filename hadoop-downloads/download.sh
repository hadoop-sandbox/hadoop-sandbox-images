#! /usr/bin/env bash

set -Eeu -o pipefail

args=$(getopt d:j:p: $*)
rc=$?
if [ $rc -ne 0 ]; then
  exit 2
fi

set -- $args

json=
dest=

while :; do
  case "$1" in
  -d)
    dest="$2"
    shift
    shift
    ;;
  --)
    shift
    break
    ;;
  esac
done

function bail_out() {
    exitcode="$1"
    msg="$2"
    echo "$msg" >&2
    exit "$exitcode"
}

[ $# -ne 1 ] && bail_out 3 "dependency file argument missing"

json=$1

[ -z "$json" ] && bail_out 4 "dependency file argument empty"
[ -z "$dest" ] && bail_out 5 "dest argument empty"

echo "json: $json, dest: $dest"

function fetch_source() {
  dep="$1"
  json="$2"
  jq -c ".[\"$dep\"] | (if length != 1 then halt_error(1) else . end)[0]" "$json"
}

function extract_prop() {
  doc="$1"
  prop="$2"
  jq -r ".[\"$prop\"]" <<<"$doc"
}

function determine_checksum_command() {
    checksum="$1"
    case "${#checksum}" in
    64)
      echo "sha256sum";;
    128)
      echo "sha512sum";;
    esac
}

function download() {
    filepath="$1"
    url="$2"
    checksum="$3"

    cksumcmd=$(determine_checksum_command "$checksum")
    [ -z "$cksumcmd" ] && return 1

    destdir=$(dirname "$filepath")
    install -d -m 755 "$destdir"
    curl -fsSLo "$filepath" "$url"
    [ "$?" -ne 0 ] && return 1
    "$cksumcmd" -c <<<"$checksum *$filepath"
    [ "$?" -ne 0 ] && return 2
    return 0
}

for dependency in $(jq -r '. | keys[]' "$json"); do
  echo "Downloading $dependency"
  source=$(fetch_source "$dependency" "$json")
  url=$(extract_prop "$source" "url")
  checksum=$(extract_prop "$source" "checksum")
  filepath="$dest/$dependency"
  download "$filepath" "$url" "$checksum"
  rc=$?
  case "$rc" in
  0)
    echo "successfully downloaded and verified $dependency to $filepath";;
  *)
    bail_out 9 "download failed for $dependency (url: $url)";;
  esac
done
