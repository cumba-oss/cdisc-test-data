# Maintainer scripts

- `make-manifests.sh <root>` writes every package's `SHA256SUMS` and the index
  `packages.txt`. Run it on the repository after changing a package, and on the
  download folder of files.cumba.net after every upload (before the server's
  `files-precompress.sh`): a package stored only compressed (`<file>.gz`) is
  listed under its plain name with the checksum of its decompressed content.
