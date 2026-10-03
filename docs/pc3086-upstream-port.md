# PC3086 port onto updated upstream

## Branches and scope

`pc3086-upstream` starts at upstream `c6b4dc8`. The original `pc3086` branch
(`f49145b`, known to boot DOS on hardware) is retained unchanged as a reference.
This is a functional port, not a merge of the old experimental/debug snapshot.

The port carries:

- PC3086 PPI reset directions, Status-1/Status-2 ports at 64h/65h, and RTC
  index/data routing at 70h/71h. Normal builds retain their historical PPI aliases.
- Real PIT channel-2 OUT on PPI PC5 and mode-4 count rollover past terminal count.
- PC3086's early parallel-status gate, restricted to its compatibility revision
  rather than changing the ordinary PCXT build.
- FDC seek/busy completion and successful result CHRN from the sector actually
  transferred. Persistent disk-change indication remains PC3086-only.
- A functional `PCXT-EGA-PC3086` Quartus revision based on current shared source
  lists, with one compilation worker.
- The historical focused ROM regressions adapted to the rewritten CPU, with
  passive simulator probes instead of synthesised debug ports. The bus/SDRAM
  regression likewise observes production state only from the testbench.

The old BIU write-data latch patch is **not** carried: all four keyboard-tail
fixtures pass on the rewritten CPU without it. No old CPU source is restored.
The old debug overlay, trace-driven CPU stop logic and stale debug QSF are not
ported. ROM binaries, host-specific Quartus settings, stale documentation and
FreeDOS launchers are not copied from the old branch.

## Reproduction

The sibling build-tools repository is also on `pc3086-upstream`. Its CPU runners
support both old and rewritten CPUs and find locally held ROMs in the source
checkout or build-tools repository. `PC3086_ROM` overrides the mirrored system
ROM input. No ROM needs to be committed here.

```bash
export PCXT_PROJECT_DIR=/path/to/PCXT-EGA_MiSTer
cd /path/to/PCXT-EGA_MiSTer-builds
bash scripts/test-pc3086.sh
bash scripts/quartus-container.sh build --project-dir "$PCXT_PROJECT_DIR" pc3086
```

Generated simulations live under the build-tools repository's `.test-output/`.
Quartus output lives under this checkout's `output_files/`. Always verify the
RBF timestamp, size and SHA-256 after a complete map/merge/fit/STA/assembler run;
a pre-existing RBF is not evidence that a new build succeeded.

## Simulation results (2026-10-04)

- Reference branch: all four keyboard-tail fixtures and the FPGA-side floppy
  boot-path gate pass before porting.
- Port: complete `test-pc3086.sh` gate passes. This includes PC3086/normal I/O
  decode, peripheral PIT/status/RTC checks, four keyboard-tail fixtures,
  motherboard-to-SDRAM replay at all four CLKSEL settings, refresh collisions,
  real-ROM PIT/status POST, foreground INT19 handoff, IRQ6, HPS mount/FDC command
  checks and consecutive 512-byte sector-1/sector-8 reads returning AH=00.
- Upstream CPU suite: 7 passed; chipset suite: 17 passed. Four testbench-only
  declaration-order fixes were needed for this host's Icarus elaborator; they
  do not change stimulus or production RTL.
- Video (Verilator): 30 passed, one failed, one did not build. The timing bench
  reports line/frame-total mismatches; the cursor-render bench hits a generated
  C++ `std::process` build error. Both exceptions reproduce on untouched
  upstream `c6b4dc8`. Video RTL is unchanged by this port. The Icarus backend
  also rejects upstream forward declarations in the video RTL on this host.
- Sound: all eight benches pass after recompiling generated C++ with
  `OPT_FAST='-Os -Wno-error=logical-op'` and matching `OPT_SLOW`. The ordinary
  runner initially hits GCC warnings-as-errors in Verilator-generated code;
  neither sound RTL nor its runner was modified for this port.

These are focused simulations, not proof of a complete BIOS/OS boot on an FPGA.
The CPU ROM fixtures intentionally use 8088 mode with Fake 286 FLAGS disabled;
the upstream CPU suite separately exercises the 8086 path.

## FPGA validation

The one-worker map/merge/fit/STA/assembler run completed with exit 0. The
fitter, timing-analyzer and assembler reports all confirm stage completion.
The fresh bitstream is:

```text
output_files/PCXT-EGA-PC3086.rbf
mtime: 2026-10-04 10:11:25 +1100
size:  4,047,532 bytes
SHA256: 0a41fdc1087434ccc74d418f5e42bb655cb843955532cb48489dd920fea100be
```

**Experimental only: timing is not closed.** TimeQuest reports worst-case setup
slack -27.851 ns, hold slack -0.431 ns and recovery slack -5.703 ns, plus
incomplete setup/hold constraints. Stage completion does not imply meeting
hardware timing. The worst setup group is the video PLL's general[0] output;
the main core clock also has negative setup slack. Quartus additionally reports
mixed-clock EGA RAM read-during-write warnings. These are not yet classified as
pre-existing versus port-induced: unlike the video simulation exceptions, no
vanilla-upstream FPGA build was run for comparison.

The next engineering gate is to inspect detailed failing paths and compare a
vanilla upstream build with the same toolchain. Distinguish real critical paths
from justified CDC/clock-exclusivity constraints; do not hide violations with
blanket false paths. Retain this RBF as an experimental artifact, not a validated
replacement for the old hardware-tested core.

Once the timing/constraint issues have been reviewed, hardware follow-up is:

1. Select IBM PCXT / 8088, load the mirrored PC3086 system ROM and a known-good
   EGA option ROM, and begin with normal XT speed.
2. Check timer/status POST, keyboard input, and the foreground boot prompt.
3. Repeat the established manual floppy unmount/reset/quick-remount sequence
   with the verified 720 KiB DOS system image. Mount/reset lifecycle remains an
   existing hardware caveat, not solved by this port.
4. Require a DOS prompt, then repeated directory/file reads and a warm reboot.
5. Only after the baseline works, repeat across CPU speeds and investigate
   selectable 8086/Fake 286 settings independently.

Keep the old branch and RBF as fallbacks until hardware checks pass. Port the
large debug overlay only if a demonstrated failure requires it, preferably as
separate observer modules and a thin revision sharing the functional QSF.
