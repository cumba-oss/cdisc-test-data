#!/usr/bin/env bash
# Writes the checksum lists the download scripts read.
#
#   scripts/make-manifests.sh <root>
#
# <root> holds <size>/<source>/<study>/<standard>/<format>/ folders (the
# repository root, or the download folder on the server). For every format
# folder it writes SHA256SUMS: one "<sha256>  <file>" line per file of the
# package, sorted, in the format sha256sum -c reads. A file stored only
# compressed (<file>.gz without <file>, the big sizes) is listed under its
# plain name with the checksum of its DECOMPRESSED content - that is what a
# download receives. A <file>.gz beside its <file> is a transfer copy, not a
# package file, and is not listed.
#
# It also writes <root>/packages.txt: one line per package,
#   <size>/<source>/<study>/<standard>/<format> <files> <bytes>
# (<bytes> = the decompressed size), sorted.
#
# Run it after every change to a package, before committing or uploading.
set -euo pipefail

ROOT="${1:?usage: make-manifests.sh <root>}"
ROOT="${ROOT%/}"
[ -d "$ROOT" ] || { echo "make-manifests: not a directory: $ROOT" >&2; exit 2; }

if command -v sha256sum >/dev/null 2>&1; then sha() { sha256sum | cut -d' ' -f1; }
else sha() { shasum -a 256 | cut -d' ' -f1; }; fi

index="$ROOT/packages.txt.tmp.$$"
: > "$index"
count=0
# exactly five levels below the root: <size>/<source>/<study>/<standard>/<format>
while IFS= read -r -d '' dir; do
  rel="${dir#"$ROOT"/}"
  case "$rel" in .*|*/.*) continue ;; esac
  sums="$dir/SHA256SUMS.tmp.$$"
  : > "$sums"
  files=0; bytes=0
  while IFS= read -r -d '' f; do
    name="${f#"$dir"/}"
    case "$name" in
      SHA256SUMS|SHA256SUMS.tmp.*) continue ;;
      *.gz)
        plain="${f%.gz}"
        [ -e "$plain" ] && continue                 # transfer copy of a listed file
        printf '%s  %s\n' "$(gzip -dc -- "$f" | sha)" "${name%.gz}" >> "$sums"
        size=$(gzip -dc -- "$f" | wc -c) ;;
      *)
        printf '%s  %s\n' "$(sha < "$f")" "$name" >> "$sums"
        size=$(wc -c < "$f") ;;
    esac
    files=$((files + 1)); bytes=$((bytes + size))
  done < <(find "$dir" -type f -print0)
  LC_ALL=C sort -k2 -o "$sums" "$sums"
  mv -f "$sums" "$dir/SHA256SUMS"
  printf '%s %s %s\n' "$rel" "$files" "$bytes" >> "$index"
  count=$((count + 1))
done < <(find "$ROOT" -mindepth 5 -maxdepth 5 -type d -print0)

LC_ALL=C sort -o "$index" "$index"
mv -f "$index" "$ROOT/packages.txt"
echo "make-manifests: $count packages"
