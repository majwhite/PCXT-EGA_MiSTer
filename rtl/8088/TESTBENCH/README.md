# 8088 CPU regressions

`i8088_bda_tail_tb.v` is a self-checking, bus-level regression for the exact
keyboard-tail update used by the PC3086 BIOS:

```asm
mov bx, [041Ch]
inc bx
inc bx
mov [041Ch], bx
```

It runs four fixtures: the minimum four-instruction sequence, the exact byte
sequence at PC3086 `F000:11AC` through `F000:11DD`, the real external
`INTR`/`INTA`/IRQ1/IRET path with a controlled translation result, and the
complete PC3086 ROM IRQ1 path. The full-ROM fixture injects set-1 scan code
`1E` at port `60h`, uses the ROM's actual translation tables, and requires the
actual maximum-mode write bus transactions to change the BDA tail from `001E`
to `0020`. All fixtures emit a VCD waveform and a short bus log.
This is deliberately independent of the PC3086 debug overlay, so it does not
infer a transaction from a later retained "last write" register.

Run it from the repository root:

```bash
scripts/test-i8088-bda-tail.sh
```

The script needs Icarus Verilog (`iverilog` and `vvp`). It copies the CPU
microcode image beside the simulator executable, as required by `eu_rom.v`.
Generated files live in `.test-output/i8088-bda-tail/`, which is ignored by
Git.

## CPU bus through SDRAM regression

`rtl/KFPC-XT/TESTBENCH/bus_ram_bda_tail_tb.sv` replays the two maximum-mode
MEMW cycles that commit the PC3086 keyboard-tail update (`041Ch = 20h`,
`041Dh = 00h`).  It uses the real normal-speed `XT_CE_Generator`, `KF8288`,
`BUS_ARBITER`, `RAM`, and `KFSDRAM` modules.  The test poisons the CPU address
and data bus immediately after MEMW is released, then requires both bytes
observed at RAM acceptance and on the SDRAM issue side to remain correct.
It includes the CPU address-latch process from `PCXT-EGA.sv`, so it drives the
raw multiplexed CPU address rather than bypassing the motherboard boundary.
It sweeps all four synthesised CPU clock selections (`CLKSEL=0..3`) in one
run, resetting the trace state and SDRAM initialisation sequence between them.
DMA is inactive for this CPU-owned access; the testbench substitutes the
otherwise idle 8237 with a no-request stub because Icarus cannot elaborate
unpacked-array operations in the production DMA core. This regression uses
Verilator (plus a C++ compiler) instead.

Run it from the repository root:

```bash
scripts/test-pc3086-bus-ram.sh
```

The generated waveform and simulator files are under
`.test-output/pc3086-bus-ram/`.

The companion RAM refresh/write-retention gate can be run with:

```bash
scripts/test-ram-refresh-collision.sh
```

## PC3086 RTC index/data regression

`scripts/test-pc3086-rtc-index-data.sh` checks the existing RTC's index/data
contract used by the PC3086-only `70h/71h` compatibility routing. It verifies
the fixed RTC register-D value and reads/writes the exact CMOS checksum span
(`0Eh..15h`) used by the PC3086 ROS. This is simulator-only and does not
invoke Quartus or create an RBF.
