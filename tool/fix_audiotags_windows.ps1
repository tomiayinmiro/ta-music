# Works around a Windows-only build failure in the audiotags plugin (v1.4.5
# as of writing): its windows/CMakeLists.txt extracts a bundled windows.tar.gz
# into CMAKE_CURRENT_SOURCE_DIR, but Flutter builds Windows plugins through a
# symlink (windows/flutter/ephemeral/.plugin_symlinks/audiotags), and
# libarchive refuses to extract through a symlink ("Cannot extract through
# symlink"). The plugin's own CMake script skips extraction if audiotags.dll
# already exists, so pre-extracting it once here — directly in the real,
# non-symlinked pub-cache path — sidesteps the problem permanently for this
# machine's pub cache.
#
# Run this once after `flutter pub get` on a fresh machine/pub cache, before
# `flutter build windows` or `flutter run -d windows`.

$ErrorActionPreference = "Stop"

$pubCache = if ($env:PUB_CACHE) { $env:PUB_CACHE } else { "$env:LOCALAPPDATA\Pub\Cache" }
$audiotagsDir = Get-ChildItem "$pubCache\hosted\pub.dev" -Directory -Filter "audiotags-*" |
    Sort-Object Name -Descending | Select-Object -First 1

if (-not $audiotagsDir) {
    Write-Error "Could not find an audiotags-* package in $pubCache\hosted\pub.dev. Run 'flutter pub get' first."
}

$windowsDir = Join-Path $audiotagsDir.FullName "windows"
$dllPath = Join-Path $windowsDir "audiotags.dll"
$archivePath = Join-Path $windowsDir "windows.tar.gz"

if (Test-Path $dllPath) {
    Write-Output "audiotags.dll already present at $dllPath — nothing to do."
    exit 0
}

if (-not (Test-Path $archivePath)) {
    Write-Output "windows.tar.gz not found yet at $archivePath — it's downloaded on first CMake configure. Run 'flutter build windows' once (it will fail on the symlink step), then re-run this script."
    exit 1
}

Push-Location $windowsDir
try {
    tar -xzf windows.tar.gz
    Write-Output "Extracted audiotags.dll to $windowsDir"
} finally {
    Pop-Location
}
