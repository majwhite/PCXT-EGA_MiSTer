# PC3086 CPU regressions

The PC3086 fixtures run the production maximum-mode CPU against selected
sequences from the real system ROM. `pc3086_test_cpu.sv` is a simulation-only
facade around `wrappers/i8088.sv`: it fixes the guest configuration to 8088,
disables Fake 286 FLAGS and word accesses, and observes internal state without
adding trace ports or feedback to synthesised RTL. Memory writes are checked
on the bus, not inferred from diagnostic registers.

The build/test runners live in the sibling `PCXT-EGA_MiSTer-builds` repository:

```bash
export PCXT_PROJECT_DIR=/path/to/PCXT-EGA_MiSTer
cd /path/to/PCXT-EGA_MiSTer-builds
bash scripts/test-pc3086.sh
```

The runners accept the original `.v` CPU on the reference `pc3086` branch as
well as the rewritten `.sv` CPU. They stage the matching microcode and ROM in
that repository's `.test-output/`, not in this checkout. ROM tests use the
mirrored system ROM from the source checkout or build-tools repository; set
`PC3086_ROM` to supply another local 64 KiB image.

| Runner | Contract |
| --- | --- |
| `test-i8088-bda-tail.sh` | Four fixtures: minimal tail increment, exact ROM handler bytes, external IRQ1/IRET, and full-ROM scan-code translation; requires ordered tail/queue writes |
| `test-i8088-pc3086-pit-post.sh` | Real ROM timer POST against the production PIT |
| `test-i8088-pc3086-system-status.sh` | Real ROM at FC00:0277: all Status-1/Status-2 patterns and final PIT OUT2 check |
| `test-i8088-pc3086-postkey-boot.sh` | Foreground key return proceeds through INT 16h / INT 10h to INT 19h |
| `test-i8088-pc3086-fdc-irq.sh` | Production FDC interrupt reaches the ROM's IRQ6 handler and releases its wait loop |
| `test-i8088-pc3086-int13-read.sh` | Consecutive sector-1 and sector-8 reads each transfer 512 bytes and return AH=00 |
| `test-pc3086-bus-ram.sh` | Replays first-key stores through the real clock generator, motherboard latch, 8288, bus arbiter, RAM and SDRAM controller at all four clock selections |

The new mouse-coordinate regression has a standalone runner in this checkout
and requires the rewritten `.sv` CPU:

```bash
PC3086_ROM=/path/to/pc3086-system-mirrored.rom \
  bash rtl/8088/TESTBENCH/run_mouse_post.sh
```

It runs normal/PC3086 decoder qualification checks and the actual ROM POST at
FC00:0483 against the production stationary-mouse decoder. Output is staged
under this checkout's `.test-output/pc3086-mouse-post/`. This checks zero
coordinates only, not Amstrad mouse movement support.

The bus/RAM fixture substitutes only an idle DMA controller. Passive probes in
the testbench count RAM acceptance and SDRAM issue independently, use baselines
to reject stale POST writes, and poison the buses when MEMW releases. It does
not require the old synthesised RAM trace ports.

The companion peripheral tests cover PC3086 and ordinary-PCXT I/O decoding,
PIT mode 4, PPI reset/status, RTC index/data, host floppy mounting, FDC command
results and RAM refresh collision. Icarus Verilog, Verilator and a C++ compiler
are required; Quartus is not.

The upstream CPU and chipset suites remain available via their own
`TESTBENCH/run_tests.sh` scripts. See `docs/pc3086-upstream-port.md` for the port
status, limitations and hardware follow-up.
