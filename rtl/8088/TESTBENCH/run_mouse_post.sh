#!/usr/bin/env bash
# Focused production-decoder and real-ROM PC3086 stationary-mouse regression.
set -euo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
build_dir="$repo_dir/.test-output/pc3086-mouse-post"
rom="${PC3086_ROM:-$repo_dir/pc3086-system-mirrored.rom}"
[[ -f "$rom" ]] || { echo "Set PC3086_ROM to the mirrored 64 KiB system ROM" >&2; exit 2; }
mkdir -p "$build_dir"
od -An -v -tx1 "$rom" > "$build_dir/pc3086-system-mirrored.hex"
cp "$repo_dir/rtl/8088/mcl86_ucode.mem" "$build_dir/"
cd "$build_dir"
bench="$repo_dir/rtl/8088/TESTBENCH/i8088_pc3086_mouse_post_tb.v"
peripherals="$repo_dir/rtl/KFPC-XT/HDL/Peripherals.sv"
for mode in normal compat; do
  flags=()
  [[ "$mode" == normal ]] || flags=(-DPC3086_LEGACY_PPI=1)
  iverilog -g2012 "${flags[@]}" -s pc3086_mouse_decode_tb \
    -o "$mode.vvp" "$peripherals" "$bench"
  vvp "$mode.vvp"
done
iverilog -g2012 -DPC3086_LEGACY_PPI=1 -s i8088_pc3086_mouse_post_tb \
  -o rom.vvp "$peripherals" "$bench" \
  "$repo_dir/rtl/8088/mcl86_ucode.sv" \
  "$repo_dir/rtl/8088/mcl86_adder.sv" \
  "$repo_dir/rtl/8088/mcl86_eu_core.sv" \
  "$repo_dir/rtl/8088/mcl86_biu_max.sv" \
  "$repo_dir/rtl/8088/wrappers/i8088.sv" \
  "$repo_dir/rtl/8088/TESTBENCH/pc3086_test_cpu.sv"
vvp rom.vvp
