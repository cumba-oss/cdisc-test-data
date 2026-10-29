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
| `<format>` | one file per dataset: `xpt` (SAS V5 transport), `sas7bdat` (SAS dataset), `json` (Dataset-JSON 1.1), `ndjson` (Dataset-JSON NDJSON), `dsjc` (compressed Dataset-JSON), `rds` (R), `xlsx` (Excel) — or all datasets in one file: `xpt-lib`, `xlsx-lib`, `rda` |

Each format folder holds the datasets, a `define.xml` describing them, the
documents the define links to, and a `SHA256SUMS`. Open the `define.xml` to get
the whole study. In the library formats (`xpt-lib`, `xlsx-lib`, `rda`) all
datasets are members of one file `<standard>.<ext>` (`sdtm.xpt`, `adam.xlsx`,
`send.rda`), and the define points at each one as `<file>#<MEMBER>`, e.g.
`sdtm.xpt#DM` — the member name as the file holds it (R object names are
case-sensitive).

### Studies in `x1`

| source | study | standards | formats |
|---|---|---|---|
| `DataExchange-DatasetJson` | `cdiscpilot01` | `adam`, `sdtm` | all (upstream: `xpt`, `json`, `ndjson`, `dsjc`) |
| `DataExchange-DatasetJson` | `CBER-POC-Pilot-Study1-Vaccine` | `send` | all (upstream: `xpt`, `json`, `ndjson`, `dsjc`) |
| `DataExchange-DatasetJson` | `i18n` | `sdtm` | `json` (one dataset with Japanese characters) |
| `phuse-scripts` | `TDF-cdiscpilot01` | `adam`, `sdtm` | `xpt` (upstream) + the converted ones |
| `phuse-scripts` | `CBER-POC-Pilot-Study1-Vaccine` | `send` | `xpt` (upstream) + the converted ones |
| `phuse-scripts` | `cdiscpilot-update1` | `adam` | `xpt` (upstream) + the converted ones |

"All" / "the converted ones" = `sas7bdat`, `rds`, `xlsx`, `xpt-lib`, `xlsx-lib`, `rda`,
converted from the upstream XPT by the cumba data browser's export: values
identical (checked with ReadStat and pyreadr), SAS lengths as declared.

### Scaled sizes

A scaled study (`x5`, `x10`, …) keeps its datasets and copies every record of a
subject-level dataset *k* times; only `USUBJID` changes: it gets a 4-digit copy
number appended (`01-701-1015` → `01-701-10150001` … `01-701-10150500`). Trial
design datasets (no `USUBJID`) are copied unchanged. The scaled files are written
by the cumba data browser's own export, in the format of their `x1` source; each
`define.xml` is the `x1` one with `Length` raised where the written length is
larger (mainly `USUBJID`, 4 characters longer).

Sizes are chosen per study, up to about 10 GB per XPT file or 20 million records
per dataset:

| package (`<source>/<study>/<standard>`) | sizes | formats |
|---|---|---|
| `DataExchange-DatasetJson/cdiscpilot01/adam` | `x5`, `x50`, `x500` | `xpt`, `sas7bdat`, `json`, `ndjson`, `dsjc`, `rds` |
| `DataExchange-DatasetJson/cdiscpilot01/sdtm` | `x10`, `x100`, `x1000` | `xpt`, `sas7bdat`, `json`, `ndjson`, `dsjc`, `rds` |
| `DataExchange-DatasetJson/CBER-POC-Pilot-Study1-Vaccine/send` | `x200`, `x1000`, `x5000` | `xpt`, `sas7bdat`, `json`, `ndjson`, `dsjc`, `rds` |
| `phuse-scripts/TDF-cdiscpilot01/sdtm` | `x5`, `x20`, `x200` | `xpt`, `sas7bdat`, `rds` |

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
- `phuse-scripts` TDF SDTM `ts.xpt` holds the windows-1252 character `’` (byte
  `0x92`) in TSVAL; every other upstream XPT is plain ASCII. The XPT sources are
  therefore read as windows-1252 for the conversions, and the library XPT and the
  SAS7BDAT files are written in windows-1252 too.
- Validation reports of the upstream repositories are not included.

The example data is for illustration and testing only and may not conform to
regulatory health authorities' requirements or guidance.

Everything not taken from an upstream repository (the layout, the adapted
`define.xml` files, the scaled sizes, the scripts) is licensed under the MIT licence in
[`LICENSE`](LICENSE).
