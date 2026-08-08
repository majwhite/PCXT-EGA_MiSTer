# Amstrad PC3086 system-ROM experiment

`fc00.bin` is a 16 KiB system ROM decoded at physical `FC000h` on a real
PC3086.  The PCXT-EGA system-ROM upload is a 64 KiB image decoded at `F0000h`.

Build the correctly positioned test image from a locally obtained PC3086 dump:

```sh
python3 make_pc3086_system_rom.py /path/to/fc00.bin pc3086-system.rom
```

Upload `pc3086-system.rom` through **System & BIOS -> PCXT BIOS**, then reset.
The expected known input SHA-1 is
`98c344831cc4dc59ebb39bbb1961964a8d39fe20`.

## Paradise VGA option-ROM experiment

The PC3086's matching `c000.bin` is a 32 KiB Paradise PVGA1A VGA dump. Its
header declares a 24 KiB option ROM, but the remaining 8 KiB contains nonblank
Paradise data and must be retained. Upload the original **full 32 KiB** file
through **System & BIOS -> EGA BIOS**; this maps it at `C0000h`, where the
PC3086 expects its video ROM. This is an experimental compatibility test:
PCXT-EGA implements standard EGA/VGA rather than Paradise PVGA1A extensions,
so a black screen after this pairing is useful evidence of a hardware
dependency rather than a malformed ROM image.

`c800.bin` is a Western Digital IDE option ROM and is not mapped by the core.
