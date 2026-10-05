#!/usr/bin/env bash
# Fails unless an image really holds arm64 code (ADR-0027). The image's label is not proof: an image built on an amd64 base and
# labelled arm64 passes `docker image inspect`, and runs only under emulation. This looks at the code itself: every ELF
# executable and shared library in the image must be aarch64, and there must be at least one (an empty export proves nothing).
#
#   usage: check-image-arch.sh <image>             an image the local Docker can see
#          check-image-arch.sh --dir <rootfs-dir>   an already-exported filesystem (what the tests use)
#
# Works for images with no shell (distroless, chiseled): it reads the exported files, it never runs the image.
set -euo pipefail

scan_dir() {
  local dir="$1" listing elf bad
  listing="$(find "$dir" -type f \( -perm -u+x -o -name '*.so' -o -name '*.so.*' \) -print0 | xargs -0 file 2>/dev/null || true)"
  elf="$(printf '%s\n' "$listing" | grep -c 'ELF' || true)"
  bad="$(printf '%s\n' "$listing" | grep 'ELF' | grep -v 'ARM aarch64' || true)"
  if [ "$elf" -eq 0 ]; then
    echo "FAIL: no ELF files found, so nothing proves the architecture"
    return 1
  fi
  if [ -n "$bad" ]; then
    echo "FAIL: $(printf '%s\n' "$bad" | wc -l | tr -d ' ') of $elf ELF files are not aarch64, for example:"
    # Show paths relative to the image, with the padding `file` adds collapsed.
    printf '%s\n' "$bad" | head -5 | sed "s#^$dir##; s/:  */: /" | cut -c1-160 | sed 's/^/  /'
    return 1
  fi
  echo "ok: all $elf ELF files are aarch64"
}

if [ "${1:-}" = "--dir" ]; then
  scan_dir "${2:?usage: check-image-arch.sh --dir <rootfs-dir>}"
  exit $?
fi

image="${1:?usage: check-image-arch.sh <image> | --dir <rootfs-dir>}"
label="$(docker image inspect --format '{{.Architecture}}' "$image")"
if [ "$label" != "arm64" ]; then
  echo "FAIL: $image is labelled $label, not arm64"
  exit 1
fi

work="$(mktemp -d)"
cid="$(docker create "$image")"
trap 'docker rm -f "$cid" >/dev/null 2>&1; rm -rf "$work"' EXIT
# Device nodes cannot be created without root and do not matter here.
docker export "$cid" | tar -x -f - -C "$work" 2>/dev/null || true
echo "$image: label arm64"
scan_dir "$work"
