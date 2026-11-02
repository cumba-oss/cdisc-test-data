<#
.SYNOPSIS
Downloads packages of cdisc-test-data from files.cumba.net.

.DESCRIPTION
A package is one <size>/<source>/<study>/<standard>/<format>/ folder: the
datasets, their define.xml and the documents it links to. Every parameter
selects; one left out matches anything, and every matching package is
downloaded. When more than one matches, the script names the count and total
size and asks first (-Yes / -y answers yes). The files land in
<Destination>/<size>/<source>/<study>/<standard>/<format>/ (default: the
current directory), so a download completes a clone of this repository.

Every file is requested gzip-compressed and decompressed on arrival (the server
keeps a compressed copy of every large text and XPT file), and checked against
the package's SHA256SUMS. A file already present with the right checksum is not
downloaded again, so an interrupted run can simply be repeated.

Runs on Windows PowerShell 5.1 and PowerShell 7.

.EXAMPLE
.\download.ps1 -Size x50 -Source DataExchange-DatasetJson -Standard adam -Format xpt

.EXAMPLE
.\download.ps1 -Format xpt -Standard sdtm -Yes

Every SDTM package in XPT, without asking.

.EXAMPLE
.\download.ps1 -List -Size x50
#>
[CmdletBinding()]
param(
    [string]$Size = '',
    [string]$Source = '',
    [string]$Study = '',
    [string]$Standard = '',
    [string]$Format = '',
    [string]$Destination = '.',
    [string]$BaseUrl = $(if ($env:CDISC_TEST_DATA_URL) { $env:CDISC_TEST_DATA_URL } else { 'https://files.cumba.net/cdisc-test-data' }),
    [switch]$List,
    [Alias('y')][switch]$Yes
)
$ErrorActionPreference = 'Stop'
$BaseUrl = $BaseUrl.TrimEnd('/')

Add-Type -AssemblyName System.Net.Http
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$handler = New-Object System.Net.Http.HttpClientHandler
# gzip-compressed transfer, decompressed on arrival
$handler.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip
$client = New-Object System.Net.Http.HttpClient($handler)
$client.Timeout = [TimeSpan]::FromHours(6)

function Get-UrlPath([string]$Path) {
    ($Path -split '/' | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
}

function Save-Url([string]$Url, [string]$File) {
    $attempt = 0
    while ($true) {
        $attempt++
        try {
            $response = $client.GetAsync($Url, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
            try {
                if (-not $response.IsSuccessStatusCode) { throw "HTTP $([int]$response.StatusCode) for $Url" }
                $in = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
                $out = [System.IO.File]::Create($File)
                try { $in.CopyTo($out, 1MB) } finally { $out.Dispose(); $in.Dispose() }
            } finally { $response.Dispose() }
            return
        } catch {
            if ($attempt -ge 3) { throw }
            Start-Sleep -Seconds (2 * $attempt)
        }
    }
}

function Get-Sha256([string]$File) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $stream = [System.IO.File]::OpenRead($File)
    try { -join ($sha.ComputeHash($stream) | ForEach-Object { $_.ToString('x2') }) }
    finally { $stream.Dispose(); $sha.Dispose() }
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("cdisc-test-data-" + [Guid]::NewGuid())
try {
    try { Save-Url "$BaseUrl/packages.txt" $tmp }
    catch { throw "cannot read the package index $BaseUrl/packages.txt ($($_.Exception.Message))" }
    $packages = Get-Content -LiteralPath $tmp | Where-Object { $_.Trim() } | ForEach-Object {
        $f = $_ -split '\s+'
        $p = $f[0] -split '/'
        if ($p.Count -eq 5) {
            [pscustomobject]@{ Path = $f[0]; Files = [int]$f[1]; Bytes = [long]$f[2]
                               Size = $p[0]; Source = $p[1]; Study = $p[2]; Standard = $p[3]; Format = $p[4] }
        }
    }
} finally { Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue }

$matching = @($packages | Where-Object {
    (-not $Size -or $_.Size -eq $Size) -and (-not $Source -or $_.Source -eq $Source) -and
    (-not $Study -or $_.Study -eq $Study) -and (-not $Standard -or $_.Standard -eq $Standard) -and
    (-not $Format -or $_.Format -eq $Format) })

if ($List) {
    if ($matching.Count -eq 0) { Write-Error 'no package matches'; exit 1 }
    $matching | ForEach-Object { '{0,-80} {1,5} files {2,10:N1} MB' -f $_.Path, $_.Files, ($_.Bytes / 1e6) }
    exit 0
}

if ($matching.Count -eq 0) {
    if ($Source) {
        Write-Host "no package matches; the packages of source ${Source}:"
        $ofSource = @($packages | Where-Object { $_.Source -eq $Source })
        if ($ofSource.Count -eq 0) { Write-Host '  (none; try -List)' }
        $ofSource | ForEach-Object { "  $($_.Path)" }
    } else { Write-Host 'no package matches (try -List)' }
    exit 1
}
$totalFiles = ($matching | Measure-Object -Property Files -Sum).Sum
$totalBytes = ($matching | Measure-Object -Property Bytes -Sum).Sum
$total = '{0} files, {1:N1} MB' -f $totalFiles, ($totalBytes / 1e6)
if ($matching.Count -gt 1 -and -not $Yes) {
    $matching | ForEach-Object { '  {0,-78} {1,10:N1} MB' -f $_.Path, ($_.Bytes / 1e6) }
    # without an interactive console (redirected input, a scheduled task) refuse rather than block
    if ([Console]::IsInputRedirected -or -not [Environment]::UserInteractive) {
        Write-Host "$($matching.Count) packages match ($total) - pass -Yes to download them all, or narrow the selection"
        exit 2
    }
    $answer = Read-Host "Download these $($matching.Count) packages ($total)? [y/N]"
    if ($answer -notmatch '^(y|yes)$') { 'nothing downloaded'; exit 1 }
}

# one package into <Destination>/<package>; returns $true when every file arrived
function Save-Package($pkg) {
    $out = Join-Path $Destination $pkg.Path
    'package {0}: {1} files, {2:N1} MB' -f $pkg.Path, $pkg.Files, ($pkg.Bytes / 1e6) | Write-Host
    New-Item -ItemType Directory -Force -Path $out | Out-Null
    $sums = Join-Path $out 'SHA256SUMS'
    try { Save-Url "$BaseUrl/$(Get-UrlPath $pkg.Path)/SHA256SUMS" $sums }
    catch { Write-Warning "FAILED SHA256SUMS ($($_.Exception.Message))"; Write-Host "done: package not downloaded -> $out"; return $false }

    $got = 0; $kept = 0; $failed = 0
    foreach ($line in Get-Content -LiteralPath $sums) {
        if ($line -notmatch '^([0-9a-f]{64})  (.+)$') { continue }
        $want = $Matches[1]; $name = $Matches[2]
        if ($name.StartsWith('/') -or $name.Contains('..')) { Write-Warning "refusing path $name"; $failed++; continue }
        $file = Join-Path $out $name
        if ((Test-Path -LiteralPath $file -PathType Leaf) -and (Get-Sha256 $file) -eq $want) { $kept++; continue }
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $file) | Out-Null
        $part = "$file.part"
        try {
            Save-Url "$BaseUrl/$(Get-UrlPath "$($pkg.Path)/$name")" $part
            if ((Get-Sha256 $part) -ne $want) { throw 'checksum mismatch' }
            Move-Item -LiteralPath $part -Destination $file -Force
            $got++; Write-Host "  $name"
        } catch {
            Remove-Item -LiteralPath $part -ErrorAction SilentlyContinue
            $failed++; Write-Warning "FAILED $name ($($_.Exception.Message))"
        }
    }
    Write-Host "done: $got downloaded, $kept already present, $failed failed -> $out"
    return ($failed -eq 0)
}

$bad = 0
foreach ($pkg in $matching) { if (-not (Save-Package $pkg)) { $bad++ } }
$client.Dispose()
if ($matching.Count -gt 1) {
    "all done: $($matching.Count) packages ($total), $($matching.Count - $bad) complete, $bad with failures"
}
if ($bad -gt 0) { exit 1 }
