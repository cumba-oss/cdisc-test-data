#!/usr/bin/env bash
# Downloads one package of cdisc-test-data from files.cumba.net.
#
#   ./download.sh --size x50 --source DataExchange-DatasetJson --standard adam --format xpt
#   ./download.sh --list [--size x50] [--source ...] [--study ...] [--standard ...] [--format ...]
#
# A package is one <size>/<source>/<study>/<standard>/<format>/ folder: the
# datasets, their define.xml and the documents it links to. --study may be left
# out when only one study matches. The files land in
# <dest>/<size>/<source>/<study>/<standard>/<format>/ (--dest, default: the
# current directory), so a download completes a clone of this repository.
#
# Every file is requested gzip-compressed and decompressed on arrival (the
# server keeps a compressed copy of every large text and XPT file), and checked
# against the package's SHA256SUMS. A file already present with the right
# checksum is not downloaded again, so an interrupted run can simply be repeated.
#
# Needs: bash, curl, and sha256sum or shasum.
set -euo pipefail

BASE_URL="${CDISC_TEST_DATA_URL:-https://files.cumba.net/cdisc-test-data}"
SIZE="" SOURCE="" STUDY="" STANDARD="" FORMAT="" DEST="." LIST=0

usage() {
  sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'
  cat <<EOF

Options:
  --size <x1|x5|...>     scale factor
  --source <name>        e.g. DataExchange-DatasetJson, phuse-scripts
  --study <name>         optional when only one study matches
  --standard <name>      adam, sdtm or send
  --format <name>        xpt, json, ndjson, dsjc, ...
  --dest <dir>           where the <size>/... tree is created (default: .)
  --base-url <url>       default: $BASE_URL (or \$CDISC_TEST_DATA_URL)
  --list                 list the packages matching the given options and exit
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --size) SIZE="${2:?--size needs a value}"; shift 2 ;;
    --source) SOURCE="${2:?--source needs a value}"; shift 2 ;;
    --study) STUDY="${2:?--study needs a value}"; shift 2 ;;
    --standard) STANDARD="${2:?--standard needs a value}"; shift 2 ;;
    --format) FORMAT="${2:?--format needs a value}"; shift 2 ;;
    --dest) DEST="${2:?--dest needs a value}"; shift 2 ;;
    --base-url) BASE_URL="${2:?--base-url needs a value}"; shift 2 ;;
    --list) LIST=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "download: unknown option: $1 (see --help)" >&2; exit 2 ;;
  esac
done
BASE_URL="${BASE_URL%/}"

if command -v sha256sum >/dev/null 2>&1; then sha() { sha256sum < "$1" | cut -d' ' -f1; }
else sha() { shasum -a 256 < "$1" | cut -d' ' -f1; }; fi

fetch() {   # <url> <file>: gzip-compressed transfer, decompressed on arrival
  curl --fail --silent --show-error --location --globoff --compressed --retry 3 -o "$2" "$1"
}
urlpath() { printf '%s' "$1" | sed -e 's/%/%25/g' -e 's/ /%20/g' -e 's/#/%23/g' -e 's/?/%3F/g'; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fetch "$BASE_URL/packages.txt" "$TMP/packages.txt" \
  || { echo "download: cannot read the package index $BASE_URL/packages.txt" >&2; exit 1; }

# packages matching every given option (an empty option matches anything)
matches="$(awk -v sz="$SIZE" -v so="$SOURCE" -v st="$STUDY" -v sd="$STANDARD" -v fm="$FORMAT" '
  { n = split($1, p, "/") }
  n == 5 && (sz == "" || p[1] == sz) && (so == "" || p[2] == so) && (st == "" || p[3] == st) \
         && (sd == "" || p[4] == sd) && (fm == "" || p[5] == fm)' "$TMP/packages.txt")"

if [ "$LIST" -eq 1 ]; then
  [ -n "$matches" ] || { echo "download: no package matches" >&2; exit 1; }
  printf '%s\n' "$matches" | awk '{ printf "%-80s %5d files %10.1f MB\n", $1, $2, $3 / 1e6 }'
  exit 0
fi

for opt in SIZE SOURCE STANDARD FORMAT; do
  [ -n "${!opt}" ] || { echo "download: --$(echo "$opt" | tr 'A-Z' 'a-z') is required (or use --list)" >&2; exit 2; }
done
n="$( [ -z "$matches" ] && echo 0 || printf '%s\n' "$matches" | wc -l | tr -d ' ')"
if [ "$n" -eq 0 ]; then
  echo "download: no package matches; the packages of this source:" >&2
  awk -v so="$SOURCE" '{ split($1, p, "/") } p[2] == so { print "  " $1; n++ } END { if (!n) print "  (no package of source " so "; try --list)" }' \
    "$TMP/packages.txt" >&2
  exit 1
fi
if [ "$n" -gt 1 ]; then
  echo "download: $n packages match - choose one with --study:" >&2
  printf '%s\n' "$matches" | awk '{ print "  " $1 }' >&2
  exit 2
fi

read -r PKG FILES BYTES <<<"$matches"
OUT="$DEST/$PKG"
echo "package $PKG: $FILES files, $(awk -v b="$BYTES" 'BEGIN { printf "%.1f MB", b / 1e6 }')"
mkdir -p "$OUT"
fetch "$BASE_URL/$(urlpath "$PKG")/SHA256SUMS" "$OUT/SHA256SUMS"

got=0; kept=0; failed=0
while read -r want name; do
  [ -n "$name" ] || continue
  case "$name" in /*|*..*) echo "download: refusing path $name" >&2; failed=$((failed + 1)); continue ;; esac
  f="$OUT/$name"
  if [ -f "$f" ] && [ "$(sha "$f")" = "$want" ]; then kept=$((kept + 1)); continue; fi
  mkdir -p "$(dirname "$f")"
  if fetch "$BASE_URL/$(urlpath "$PKG/$name")" "$f.part" && [ "$(sha "$f.part")" = "$want" ]; then
    mv -f "$f.part" "$f"; got=$((got + 1)); echo "  $name"
  else
    rm -f "$f.part"; failed=$((failed + 1)); echo "  FAILED $name" >&2
  fi
done < "$OUT/SHA256SUMS"

echo "done: $got downloaded, $kept already present, $failed failed -> $OUT"
[ "$failed" -eq 0 ]
