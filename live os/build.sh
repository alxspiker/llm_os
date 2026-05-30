#!/usr/bin/env bash
set -euo pipefail

if ! command -v lb >/dev/null 2>&1; then
  echo "Missing live-build. Install: sudo apt install live-build xorriso isolinux syslinux-common squashfs-tools"
  exit 1
fi

rm -rf .build binary binary.* cache chroot chroot.* config/binary config/bootstrap config/chroot config/common config/source local

lb config \
  --mode debian \
  --distribution trixie \
  --archive-areas "main contrib non-free non-free-firmware" \
  --binary-images iso-hybrid \
  --debian-installer none \
  --memtest none \
  --apt-recommends false \
  --bootappend-live "boot=live components username=live hostname=ai-live locales=en_US.UTF-8 keyboard-layouts=us"

lb build
