#!/usr/bin/env bash
# Tests for check-image-arch.sh on exported filesystems, with minimal hand-made ELF files so no Docker is needed.
set -euo pipefail

script="$(cd "$(dirname "$0")" && pwd)/check-image-arch.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# A 64-byte ELF64 header for the given machine number (62 = x86-64, 183 = aarch64): enough for `file` to name the architecture.
make_elf() { # path, machine
  python3 - "$1" "$2" <<'PY'
import struct, sys
path, machine = sys.argv[1], int(sys.argv[2])
ident = b"\x7fELF" + bytes([2, 1, 1, 0]) + bytes(8)
header = ident + struct.pack("<HHIQQQIHHHHHH", 2, machine, 1, 0, 64, 0, 0, 64, 56, 0, 64, 0, 0)
open(path, "wb").write(header)
PY
  chmod +x "$1"
}

failures=0
expect() { # name, expected exit code, directory
  local name="$1" want="$2" dir="$3" out rc=0
  out="$(bash "$script" --dir "$dir" 2>&1)" || rc=$?
  if [ "$rc" -eq "$want" ]; then echo "ok   - $name"; else echo "FAIL - $name (exit $rc, wanted $want)"; echo "$out" | sed 's/^/       /'; failures=$((failures + 1)); fi
}

mkdir -p "$tmp/arm/usr/bin" "$tmp/arm/lib"
make_elf "$tmp/arm/usr/bin/server" 183
make_elf "$tmp/arm/lib/libx.so.1" 183
expect "all-aarch64 image passes" 0 "$tmp/arm"

mkdir -p "$tmp/mixed/usr/bin" "$tmp/mixed/lib"
make_elf "$tmp/mixed/usr/bin/server" 183
make_elf "$tmp/mixed/lib/libwheel.so" 62
expect "one x86-64 shared library fails the image" 1 "$tmp/mixed"

mkdir -p "$tmp/amd/usr/local/bin"
make_elf "$tmp/amd/usr/local/bin/python3" 62
expect "an x86-64 interpreter (the mislabelled Python case) fails" 1 "$tmp/amd"

mkdir -p "$tmp/empty/etc"
echo "no code here" > "$tmp/empty/etc/motd"
expect "an export with no ELF files proves nothing and fails" 1 "$tmp/empty"

mkdir -p "$tmp/scripts/usr/bin"
make_elf "$tmp/scripts/usr/bin/server" 183
printf '#!/bin/sh\necho hi\n' > "$tmp/scripts/usr/bin/run.sh"; chmod +x "$tmp/scripts/usr/bin/run.sh"
expect "shell scripts beside aarch64 code are ignored" 0 "$tmp/scripts"

[ "$failures" -eq 0 ] || { echo "$failures failure(s)"; exit 1; }
