param(
  [string]$Distro = "Ubuntu",
  [string]$BuildDir = "/root/live-os-build",
  [string]$IsoName = "ai-live-debian-trixie-amd64.iso",
  [switch]$SkipApt
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LiveOsDir = Join-Path $RootDir "live os"
$IsoDir = Join-Path $RootDir "iso"
$BuildScript = Join-Path $LiveOsDir "build.sh"

if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
  throw "WSL is not installed or wsl.exe is not on PATH."
}

if (-not (Test-Path -LiteralPath $BuildScript)) {
  throw "Could not find live OS build script: $BuildScript"
}

function ConvertTo-BashSingleQuoted {
  param([Parameter(Mandatory = $true)][string]$Value)
  return "'" + $Value.Replace("'", "'\''") + "'"
}

function Invoke-WslRoot {
  param([Parameter(Mandatory = $true)][string]$Command)

  & wsl.exe -d $Distro -u root -- bash -lc $Command
  if ($LASTEXITCODE -ne 0) {
    throw "WSL command failed with exit code $LASTEXITCODE."
  }
}

function ConvertTo-WslPath {
  param([Parameter(Mandatory = $true)][string]$WindowsPath)

  $WslPathInput = $WindowsPath.Replace('\', '/')
  $ConvertedPath = & wsl.exe -d $Distro -u root -- wslpath -a $WslPathInput
  if ($LASTEXITCODE -ne 0 -or -not $ConvertedPath) {
    throw "Could not convert Windows path to WSL path: $WindowsPath"
  }

  return $ConvertedPath.Trim()
}

$Distros = @(& wsl.exe --list --quiet | ForEach-Object {
  $_.Trim([char]0).Trim()
} | Where-Object {
  $_
})

if ($Distros -notcontains $Distro) {
  $Available = if ($Distros.Count -gt 0) { $Distros -join ", " } else { "none" }
  throw "WSL distro '$Distro' was not found. Available distros: $Available"
}

$WslLiveOsDir = ConvertTo-WslPath $LiveOsDir

$QuotedLiveOsDir = ConvertTo-BashSingleQuoted $WslLiveOsDir
$QuotedBuildDir = ConvertTo-BashSingleQuoted $BuildDir

New-Item -ItemType Directory -Path $IsoDir -Force | Out-Null
$WslIsoDir = ConvertTo-WslPath $IsoDir

$QuotedOutputIso = ConvertTo-BashSingleQuoted "$WslIsoDir/$IsoName"

if (-not $SkipApt) {
  Invoke-WslRoot "apt-get update"
  Invoke-WslRoot "DEBIAN_FRONTEND=noninteractive apt-get install -y live-build xorriso isolinux syslinux-common syslinux-utils squashfs-tools debootstrap debian-archive-keyring cpio genisoimage rsync zstd"
}

Invoke-WslRoot "rm -rf $QuotedBuildDir && mkdir -p $QuotedBuildDir && rsync -a --exclude '*.iso' $QuotedLiveOsDir/ $QuotedBuildDir/"

Invoke-WslRoot "cd $QuotedBuildDir && chmod +x build.sh && find config/hooks -type f -exec chmod +x {} + && ./build.sh"

$CopyIsoCommand = @"
set -e
cd $QuotedBuildDir
iso=""
for candidate in binary.hybrid.iso binary.iso chroot/binary.hybrid.iso; do
  if [ -f "`$candidate" ]; then
    iso="`$candidate"
    break
  fi
done
if [ -z "`$iso" ]; then
  iso=`$(find . -maxdepth 3 -type f -name '*.iso' | head -n 1)
fi
if [ -z "`$iso" ]; then
  echo 'No ISO file was produced.'
  exit 1
fi
cp -f "`$iso" $QuotedOutputIso
sha256sum $QuotedOutputIso
"@

$TmpWinPath = Join-Path ([System.IO.Path]::GetTempPath()) "copy_iso_$(Get-Random).sh"
[System.IO.File]::WriteAllText($TmpWinPath, $CopyIsoCommand.Replace("`r`n", "`n"), [System.Text.Encoding]::ASCII)
$TmpWinPathRegex = $TmpWinPath.Replace('\', '/')
$TmpWslPath = (& wsl.exe -d $Distro -u root -- wslpath -a $TmpWinPathRegex).Trim()
try {
  Invoke-WslRoot "bash '$TmpWslPath'"
} finally {
  Remove-Item -Path $TmpWinPath -ErrorAction SilentlyContinue
}

$OutputIso = Join-Path $IsoDir $IsoName
$OutputFile = Get-Item -LiteralPath $OutputIso

Write-Host ""
Write-Host "Built ISO:" $OutputFile.FullName
Write-Host "Size:" ([math]::Round($OutputFile.Length / 1MB, 2)) "MB"
