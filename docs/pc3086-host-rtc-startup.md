# PC3086 host RTC startup

The `PC3086_LEGACY_RTC` build seeds its RTC once per FPGA configuration from
MiSTer's current local host date/time. Other builds retain their existing
RTC startup behavior.

## Behavior

- A fresh core load initializes the RTC before BIOS POST.
- Guest changes to DATE/TIME remain effective while the core runs.
- Soft reboots and reset-button/OSD resets do not reseed the RTC.
- A full core reload replaces guest-set time with current host time. This is
  not file-backed CMOS persistence.
- The PC3086 machine remains in reset until a valid host calendar arrives;
  there is no default-time timeout fallback.
- Century is fixed at BCD `20`, supporting dates in 2000–2099.

## Implementation

`PCXT-EGA.sv` connects `hps_io.RTC`, instantiates `pc3086_host_rtc`, routes the
management bus through it, and adds `!rtc_init_done` to the stretched machine
reset input. The loader has no guest-reset input: its initialized state is
one-shot per FPGA configuration.

Main_MiSTer's `user_io.cpp` `send_rtc()` supplies BCD seconds, minutes, hours,
day, month and year in bytes 0–5, binary weekday in byte 6 (Sunday=0), and flags
in byte 7. `hps_io` toggles bit 64 after receipt. The loader accepts the first
BCD/range-valid packet and converts weekday to the RTC backend's 1–7 range.
Later host packets are ignored.

The existing F4xx management interface receives 18 writes:

- Status B=`02`: BCD, 24-hour mode, interrupts disabled.
- Status A=`26`: normal divider/rate.
- Live seconds/minutes/hours/weekday/day/month/year registers.
- PC3086 shadow minutes/hours/weekday/day/month/year/century at `0E`–`14`.
- Backend century at `32` (also read at `37`).
- Raw-BCD sum of `0E`–`14`, modulo 256, at checksum byte `15`.

The mux passes HPS management traffic while waiting and after completion.
During the 18-clock startup burst it owns the bus and suppresses HPS traffic;
there is no buffering/replay of coincident traffic. The CPU is held in reset,
and disk requests are inactive during this phase. The final checksum commits
on the same edge that sets `done`, before the normal reset stretch releases
execution.

`Peripherals.sv`, `Chipset.sv`, `rtc.v`, and `hps_ext.v` need no functional
changes. The existing management decode writes both clock registers and CMOS
RAM even during reset.

### Required Quartus setting

`PCXT-EGA-PC3086.qsf` overrides `ALLOW_POWER_UP_DONT_CARE` to OFF. With the
shared project's ON setting, Quartus 17 optimized this one-shot to an
already-completed state, eliminating startup writes despite passing RTL
simulation. OFF preserves declared configuration-time initial states. This
is a revision-wide setting; non-PC3086 revisions retain their existing value.

## Validation

Run the focused integration bench or the full chipset suite:

```sh
bash rtl/KFPC-XT/TESTBENCH/run_tests.sh pc3086_host_rtc
bash rtl/KFPC-XT/TESTBENCH/run_tests.sh
```

The integration bench uses Verilator because Icarus rejects existing forward
references in `rtc.v`. It checks invalid/uncommitted packets, update toggles,
a stable captured snapshot, the exact write sequence, checksum overflow,
CPU reset hold, real RTC/CMOS indexed readback, century aliases, guest edits,
reset persistence, and management-bus arbitration.

Hardware startup tracing established that MiSTer's standard CMOS management
initialization preceded the loader. The loader then wrote all 18 bytes while
reset was held, and the BIOS read the seeded PC3086 shadow and valid checksum.
The diagnostic circuitry and DOS utilities used for that investigation are
not required by, or included in, this change.

The normal non-trace PC3086 RBF was subsequently verified on MiSTer:

1. Fresh core load: BIOS and DOS show current host date/time.
2. Guest-set time survives a BIOS-vector soft reboot (`g=ffff:0000`).
3. Guest-set time does not revert to host time while running.

Quartus synthesis/merge/fit/STA/assembly completed successfully. Timing
requirements remain unmet; the tested build's worst setup slack was
-28.383 ns and worst hold slack -0.450 ns. Functional RTC validation does not
establish timing closure of the overall core.
