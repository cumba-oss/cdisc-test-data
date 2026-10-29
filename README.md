# cdisc-test-data

Test data in CDISC standards (SEND, SDTM, ADaM) in several file formats, and in
several sizes for performance and volume testing.

Every file is also available for download from
**<https://files.cumba.net/cdisc-test-data/>**, which additionally carries the
large sizes that do not fit in a Git repository.

## Layout

```
<size>/<source>/<study>/<standard>/<format>/
```

| level | meaning |
|---|---|
| `<size>` | scale factor: `x1` is the data as published by its source; `x10`, `x100`, … contain every subject that many times |
| `<source>` | the repository the data was published in |
| `<study>` | the study |
| `<standard>` | `adam`, `sdtm` or `send` |
| `<format>` | `xpt` (SAS V5 transport), `json` (Dataset-JSON 1.1), `ndjson` (Dataset-JSON NDJSON), `dsjc` (compressed Dataset-JSON) |

Each format folder holds the datasets, a `define.xml` describing them, the
documents the define links to, and a `SHA256SUMS`. Open the `define.xml` to get
the whole study.

### Studies in `x1`

| source | study | standards | formats |
|---|---|---|---|
| `DataExchange-DatasetJson` | `cdiscpilot01` | `adam`, `sdtm` | `xpt`, `json`, `ndjson`, `dsjc` |
| `DataExchange-DatasetJson` | `CBER-POC-Pilot-Study1-Vaccine` | `send` | `xpt`, `json`, `ndjson`, `dsjc` |
| `DataExchange-DatasetJson` | `i18n` | `sdtm` | `json` (one dataset with Japanese characters) |
| `phuse-scripts` | `TDF-cdiscpilot01` | `adam`, `sdtm` | `xpt` |
| `phuse-scripts` | `CBER-POC-Pilot-Study1-Vaccine` | `send` | `xpt` |
| `phuse-scripts` | `cdiscpilot-update1` | `adam` | `xpt` (`x1` only) |

### Scaled sizes

A scaled study (`x10`, `x100`, …) keeps its datasets and copies every record
*k* times; only the subject identifier gets the suffix `-k`. Sizes are chosen per
study, up to about 10 GB per XPT file or 20 million records per dataset.

This repository holds `x1` and the first scaled size of each study (every file
below 100 MB). The larger sizes are on <https://files.cumba.net/cdisc-test-data/>
only; download them with the scripts below.

## Downloading a package

A **package** is one `<size>/<source>/<study>/<standard>/<format>/` folder. Each
package carries a `SHA256SUMS`; the index of all packages is `packages.txt`.

```bash
./download.sh --list --size x50                       # what is there
./download.sh --size x50 --source DataExchange-DatasetJson --standard adam --format xpt
```

```powershell
.\download.ps1 -List -Size x50
.\download.ps1 -Size x50 -Source DataExchange-DatasetJson -Standard adam -Format xpt
```

- `--study` / `-Study` is needed only when a source has several studies for the
  same standard (the script lists them).
- The files land in `<size>/<source>/<study>/<standard>/<format>/` below the
  current directory (`--dest` / `-Destination`), so run the script in a clone to
  complete it.
- Every file is transferred gzip-compressed (XPT files shrink up to ~30×),
  decompressed on arrival and checked against `SHA256SUMS`. Re-running the script
  skips files that are already correct, so an interrupted download just resumes.
- `download.sh` needs bash, curl and `sha256sum` (or `shasum`); `download.ps1`
  runs on Windows PowerShell 5.1 and PowerShell 7.

Without the scripts: the download server sends every file gzip-compressed to a
client that asks for it (`curl --compressed`, all browsers). For the large sizes
the JSON, NDJSON and SAS7BDAT files are stored only compressed and are listed as
`<file>.gz`; request them by their plain name to have them decompressed on the
fly, or download the `.gz` and decompress it locally.

## Sources and licences

| source | upstream | licence |
|---|---|---|
| `DataExchange-DatasetJson` | [cdisc-org/DataExchange-DatasetJson](https://github.com/cdisc-org/DataExchange-DatasetJson), `examples/` (commit `a379f49a`) | MIT, © 2022 CDISC |
| `phuse-scripts` | [phuse-org/phuse-scripts](https://github.com/phuse-org/phuse-scripts), `data/` (commit `398a6d33`) | MIT |

- The `x1` data files are byte-identical to upstream.
- The `define.xml` in each `xpt` folder is the upstream file unchanged. The ones
  in the `json`, `ndjson` and `dsjc` folders differ from it only in the dataset
  links (`xlink:href` and `def:title`), which name the folder's format instead of
  `.xpt`.
- The `phuse-scripts` TDF data (`TDF_ADaM_v1.0`, `TDF_SDTM_v1.0`) was created by
  the PhUSE Test Data Factory project, which modified datasets of the CDISC
  SDTM/ADaM pilot study (CDISCPILOT01); it is published by PhUSE under MIT.
- `cdiscpilot-update1` is PhUSE's `data/adam/cdiscpilot_update1.zip`, an earlier
  state of `TDF_ADaM_v1.0`: in `adlbc`, `adlbcpv`, `adlbh` and `adlbhpv` its
  `TRTSDT`, `TRTEDT` and `ADT` agree with ADSL and SDTM (2012–2015), where
  `TDF_ADaM_v1.0` has them 10 years later; `adcibc.AWHI` is filled. Three
  document links of its define point into the original submission package and
  do not resolve. It is provided as published, in `x1` only.
- Validation reports of the upstream repositories are not included.

The example data is for illustration and testing only and may not conform to
regulatory health authorities' requirements or guidance.

Everything not taken from an upstream repository (the layout, the adapted
`define.xml` files, the scaled sizes, the scripts) is licensed under the MIT licence in
[`LICENSE`](LICENSE).
