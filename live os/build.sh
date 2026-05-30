#!/usr/bin/env bash
set -euo pipefail

if ! command -v lb >/dev/null 2>&1; then
  echo "Missing live-build. Install: sudo apt install live-build xorriso isolinux syslinux-common squashfs-tools"
  exit 1
fi

sudo lb clean --purge || true
lb config
sudo lb build
