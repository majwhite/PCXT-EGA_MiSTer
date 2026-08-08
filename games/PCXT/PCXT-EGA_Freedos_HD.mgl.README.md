# FreeDOS launcher

`PCXT-EGA_Freedos_HD.mgl` launches the `PCXT-EGA` core and mounts
`Freedos_HD.vhd` directly into the core's `IDE 0-0` slot (MiSTer mount slot 2).

Copy this `.mgl` file to `/media/fat/_PCXT/`, then launch it from the `PCXT`
entry in MiSTer's main menu. Keep `Freedos_HD.vhd` in
`/media/fat/games/PCXT/`. It is an explicit mount test: it avoids the OSD's
image-selection path and uses an absolute VHD path.

If the installed RBF has a different filename, change the `rbf` element to
match it without the `.rbf` suffix. If the VHD is stored elsewhere, update its
absolute path in the `file` element.
