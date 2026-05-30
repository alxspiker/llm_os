#!/usr/bin/env bash
set -euo pipefail

if ! command -v lb >/dev/null 2>&1; then
  echo "Missing live-build. Install: sudo apt install live-build xorriso isolinux syslinux-common syslinux-utils squashfs-tools"
  exit 1
fi

rm -rf .build binary binary.* chroot chroot.* config/binary config/bootstrap config/chroot config/common config/source local

lb config \
  --mode debian \
  --distribution trixie \
  --archive-areas "main contrib non-free non-free-firmware" \
  --security false \
  --firmware-chroot false \
  --firmware-binary false \
  --binary-images iso-hybrid \
  --debian-installer false \
  --initsystem systemd \
  --memtest none \
  --apt-recommends false \
  --bootappend-live "boot=live components username=live hostname=ai-live locales=en_US.UTF-8 keyboard-layouts=us"

if [ -d /usr/share/live/build/bootloaders/isolinux ]; then
  mkdir -p config/bootloaders
  rm -rf config/bootloaders/isolinux
  cp -a /usr/share/live/build/bootloaders/isolinux config/bootloaders/isolinux

  for module in ldlinux.c32 libcom32.c32 libutil.c32; do
    if [ -e "/usr/lib/syslinux/modules/bios/${module}" ]; then
      cp -L "/usr/lib/syslinux/modules/bios/${module}" config/bootloaders/isolinux/
    fi
  done

  if [ ! -e config/bootloaders/isolinux/bootlogo ]; then
    tmpdir="$(mktemp -d)"
    (cd "$tmpdir" && find . | cpio --quiet -o -H newc) > config/bootloaders/isolinux/bootlogo
    rm -rf "$tmpdir"
  fi
fi

lb build
