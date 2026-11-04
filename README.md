# Garmin Aviation Database Manager on Linux

Unofficial launcher for running [Garmin Aviation Database Manager](https://fly.garmin.com/fly-garmin/garmin-aviation-database-manager/) (GADM), a Windows application, under Wine on Linux. It finds an SD card, mounts it, and maps that card to a Wine drive so Database Manager can update it.

This is not a Garmin product. It is not affiliated with, endorsed by, or supported by Garmin Ltd. or its affiliates. Garmin names and product names are trademarks of their owners. Database subscriptions, accounts, and the Windows installer still come from Garmin. You use this at your own risk.

## Tested setup

This launcher was exercised on:

- Debian 13 (trixie)
- KDE Plasma on Wayland
- Wine 10.0 from the Debian repositories
- Wine prefix at `~/garmin-gadm`
- A USB SD card reader

The dialogs use `kdialog`, which is part of that Plasma desktop. The same `kdialog` package works on GNOME if you install it. See [Dialogs on GNOME](#dialogs-on-gnome).

## What the launcher does

`gadm` is a bash script. Each time you start it:

1. It looks at `lsblk` for partitions (and whole disks that have a filesystem) that are removable (`RM=1`), hot-plugged (`HOTPLUG=1`), or named `/dev/mmcblk*`. A USB card reader often shows up as hot-plug even when the kernel does not mark it removable. Built-in MMC slots show up as `mmcblk`.
2. If a candidate is not mounted, it mounts it with `udisksctl mount --no-user-interaction`.
3. If nothing mounted is found, a dialog says **No SD card found** and offers **Try again**, **Open without card**, or cancel (which quits).
4. When a card is found, a dialog shows its size and device node and asks you to **Start** or **Cancel**.
5. It points Wine drive `A:` at that card. `dosdevices/a:` is a symlink to the mountpoint. There is no `a::` symlink to the raw device. It sets the Wine registry value `HKLM\Software\Wine\Drives` / `a:` to `floppy`, then runs `wineserver -k` and `wineserver -w`. Mountmgr reads drive types only at startup, and it honors `floppy` (DRIVE_REMOVABLE) for `A:` and `B:` only. `C:` and later are downgraded to a fixed disk, which Database Manager ignores.
6. It starts `Garmin Aviation Database Manager.exe` from the prefix, with that directory as the working directory. That start is a new wineserver, so it sees the `floppy` value.
7. After the app exits, if the card is still mounted, it asks whether to eject. Eject unmounts the partition with `udisksctl` and then powers the device off. A desktop notification is shown when that succeeds.

A log is appended to `~/.cache/gadm-launch.log`.

Wine's udisks2 support may also auto-create another letter for the same card, often `H:`. That letter is a fixed disk. In Database Manager, use `A:` and ignore the extra one.

Opening without a card still starts Database Manager, and clears the `A:` mapping so a stale card is not left behind. Restarting wineserver closes any other Wine programs that use this prefix.

## Prerequisites

GADM is a 32-bit Windows program. It installs under `Program Files (x86)`. Wine needs the i386 architecture and the 32-bit loader, even on a 64-bit machine.

### Debian and Ubuntu

Enable i386, then install Wine, the font helper, the disk manager, and the dialog program:

```bash
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install wine wine32 wine64 winetricks cabextract udisks2 kdialog
```

`udisks2` provides `udisksctl`. `cabextract` is what `winetricks corefonts` uses to unpack the Microsoft core fonts. If `apt` cannot find `wine32`, check that i386 is enabled:

```bash
dpkg --print-foreign-architectures
```

That should print `i386`.

Those commands install your distribution's Wine packages. The tested machine used Wine 10.0 from Debian 13. Ubuntu 24.04's archive has Wine 9.0. `wine32` is the 32-bit loader; GADM installs into `Program Files (x86)` and needs it.

### Core fonts in the prefix

Create the prefix first (next section), then install the core fonts into it. Some Windows installers and text rendering look wrong without them:

```bash
export WINEPREFIX="$HOME/garmin-gadm"
winetricks -q corefonts
```

`winetricks` downloads those fonts from the network. Run it in a graphical session so any leftover prompts are visible.

### Dialogs on GNOME

The script calls `kdialog` for the card prompt, the start prompt, errors, and the eject prompt. Install the `kdialog` package on GNOME; you do not need a full Plasma session.

Replacing those calls with `zenity` is possible if you would rather not install `kdialog`, but it is an edit to `gadm`, not a switch. The missing-card dialog has three results (Try again, Open without card, and cancel). A two-button `zenity --question` cannot represent that by itself.

## Step by step

### 1. Create the Wine prefix

Leave `WINEARCH` unset so Wine creates its usual 64-bit prefix. 32-bit GADM still runs there when `wine32` is installed.

```bash
export WINEPREFIX="$HOME/garmin-gadm"
wineboot --init
winetricks -q corefonts
```

The first `wineboot` may offer to download Mono and Gecko. Those are optional Wine components. You can cancel both prompts and continue.

Keep using this same `WINEPREFIX` for every Wine command below. If it is unset, Wine uses `~/.wine` and will not see this install.

### 2. Install Database Manager from Garmin

Garmin only publishes Windows and macOS builds. Download the **Windows** installer from Garmin's page:

https://fly.garmin.com/fly-garmin/garmin-aviation-database-manager/

Use the Download button on that page. This repository does not redistribute Garmin's installer.

Run the file you downloaded (the name varies by release):

```bash
export WINEPREFIX="$HOME/garmin-gadm"
wine ~/Downloads/the-installer-you-downloaded.exe
```

Finish the installer normally. When it is done, this file should exist:

```text
~/garmin-gadm/drive_c/Program Files (x86)/Garmin/Garmin Aviation Database Manager/Garmin Aviation Database Manager.exe
```

The launcher looks for that path. If the installer offers to launch the app immediately, you can close it; the card will not be mapped to `A:` until you use `gadm`.

### 3. Install the launcher

From this repository:

```bash
./install.sh
```

That script:

- copies `gadm` to `~/.local/bin/gadm`
- writes `~/.local/share/applications/gadm.desktop`, with `@HOME@` replaced by your home directory (a `.desktop` `Exec` line does not expand `~`)
- runs `update-desktop-database` and, when it exists, `kbuildsycoca6`, so the menu picks up the new entry
- checks that `wine`, `udisksctl`, and `kdialog` are on `PATH`, and prints the apt command above if one is missing

The menu name is **Garmin Aviation Database Manager**. The icon is the theme's removable-drive icon.

Log out and back in if a terminal cannot find `gadm`. Many desktops add `~/.local/bin` to `PATH` only at login, and only if that directory already existed. The menu entry uses the full path, so it does not depend on that.

### 4. Daily use

1. Insert the aviation SD card into the reader. Wait a moment so the kernel sees it.
2. Open **Garmin Aviation Database Manager** from the application menu, or run `~/.local/bin/gadm`.
3. If the card is detected, confirm the popup. It shows the size and the device (for example `59.5G, /dev/sdb1`). Choose **Start**.
4. In Database Manager the card appears as drive **A:**. Wine may also list the same card as another letter, often **H:**. Ignore that one and select **A:**. Update databases the way you would on Windows.
5. Quit Database Manager. The launcher then asks **Safely eject the SD card now?** Choose yes to unmount and power off. When the notification says the card was ejected, remove it.

If the card is not in the reader yet, the **No SD card found** dialog can **Try again** after you insert it, or **Open without card** when you only need the app itself (account, calendar, downloads). Cancel closes the launcher and does not start Wine.

`udisksctl` mounts the card as your desktop user. Start the launcher from the menu in a local graphical session. A mount from an SSH session is often denied by polkit; the denial is written to the log.

## Environment variables

| Variable | Default | Meaning |
| --- | --- | --- |
| `WINEPREFIX` | `~/garmin-gadm` | Prefix that contains the GADM install |
| `GADM_DRIVE` | `a` | Drive letter Database Manager should see. Only `a` and `b` are reported as removable. |

The menu entry uses the defaults. `B:` is the other letter Wine will report as removable:

```bash
GADM_DRIVE=b ~/.local/bin/gadm
```

Any other letter is logged and shown in a warning dialog. Database Manager will not see that drive. `C:` and `Z:` are rejected. Wine uses `C:` for the prefix and `Z:` for the Linux filesystem.

To change the menu entry, edit `~/.local/share/applications/gadm.desktop` and set `Exec` to something like:

```ini
Exec=env GADM_DRIVE=b /home/you/.local/bin/gadm
```

Then run `update-desktop-database ~/.local/share/applications` or log out and back in.

## Uninstall the launcher

```bash
./uninstall.sh
```

This removes `~/.local/bin/gadm` and `~/.local/share/applications/gadm.desktop`. It does not delete the Wine prefix or the log.

To remove the Windows install as well, delete the prefix after you are sure nothing from it is running:

```bash
WINEPREFIX="$HOME/garmin-gadm" wineserver -k
rm -rf "$HOME/garmin-gadm"
```

You can also delete `~/.cache/gadm-launch.log`.

## Troubleshooting

### The card is not detected

The **No SD card found** dialog means no candidate partition was mounted. Check what the kernel sees:

```bash
lsblk -o NAME,RM,HOTPLUG,TYPE,FSTYPE,SIZE,TRAN,MOUNTPOINT
```

A usable card has a filesystem (`FSTYPE` is not empty) and one of: `RM=1`, `HOTPLUG=1`, or a name starting with `mmcblk`. An empty card with no filesystem is ignored; Garmin cards are normally FAT. Another disk that is not removable and not hot-plug is ignored on purpose, so the launcher does not grab an internal drive.

Then read the log:

```bash
less ~/.cache/gadm-launch.log
```

Mount failures from `udisksctl` are appended there (polkit denial, unsupported filesystem, device busy). You can retry the mount by hand, using the device from `lsblk`:

```bash
udisksctl mount -b /dev/sdb1
```

If that succeeds, start the launcher again. If several removable devices are plugged in, the launcher uses the first one that is mounted. Unplug the extra device and try again.

If the reader never shows `RM`, `HOTPLUG`, or `mmcblk`, the script will keep skipping it. That is visible in the `lsblk` columns above.

### Database Manager does not see the card

The start dialog can confirm the card while Database Manager still shows no removable drive. GADM's native core (`AvdbUpdaterCore.dll`) enumerates drives with `GetLogicalDrives` and `GetDriveTypeW` and only accepts `DRIVE_REMOVABLE`.

On Wine 10.0, mountmgr honors the registry type `floppy` only for **A:** and **B:**. For **C:** and later it silently downgrades the drive to a hard disk, so a card mapped to `G:` comes back as DriveType 3 (fixed) and GADM ignores it. Wine's udisks2 automount does the same: it may create **H:** for the card, and that letter is also DriveType 3. Ignore `H:` (or whichever extra letter appears) and use **A:**.

The mapping that works is:

- `dosdevices/a:` points at the card mountpoint
- `dosdevices/a::` does not exist (a raw-device symlink made mountmgr treat `A:` oddly)
- `HKLM\Software\Wine\Drives` value `a:` is `floppy`
- wineserver was restarted after that write, so mountmgr read it at startup

A non-root user cannot read `/dev/sdX`. With a raw-device symlink in place, Wine may report NTFS or a bogus volume serial. That did not stop GADM once `A:` was actually removable, and the launcher does not create `a::`.

Check the types Wine is reporting, with this prefix:

```bash
export WINEPREFIX="$HOME/garmin-gadm"
wine wmic logicaldisk get name,drivetype
```

DriveType 2 means removable. `A:` should be 2. A duplicate letter (often `H:`) may be 3; ignore it inside Database Manager.

If `A:` is not 2, confirm the registry value and that the raw-device symlink is absent:

```bash
WINEPREFIX="$HOME/garmin-gadm" wine reg query 'HKLM\Software\Wine\Drives' /v a:
ls -l "$WINEPREFIX/dosdevices/a:" "$WINEPREFIX/dosdevices/a::"
```

`a:` should be `floppy` and should point at the mountpoint (often under `/media` or `/run/media`). `a::` should be missing (`ls` will say so). Start the launcher again so it rewrites the registry and restarts wineserver.

An older copy of this launcher mapped the card to `G:`. Those links are not used anymore:

```bash
rm -f "$WINEPREFIX/dosdevices/g:" "$WINEPREFIX/dosdevices/g::"
```

### The app is already running

Each launch with a card runs `wineserver -k` in this prefix before Database Manager starts, so mountmgr reloads drive types. That also closes every other Wine program using `~/garmin-gadm`.

Database Manager, or a Wine process left behind from a previous launch, can refuse a second start or can hold the card open so eject fails. This only affects programs inside the GADM prefix:

```bash
WINEPREFIX="$HOME/garmin-gadm" wineserver -k
```

`wineserver -k` stops every program running in that prefix. It does not stop Wine programs that use a different prefix. After it returns, start `gadm` again.

### GADM not found

The error dialog prints the directory it expected. Confirm `WINEPREFIX` and that the installer really wrote:

```text
$WINEPREFIX/drive_c/Program Files (x86)/Garmin/Garmin Aviation Database Manager/Garmin Aviation Database Manager.exe
```

A prefix created without `WINEPREFIX` set lives in `~/.wine`, not in `~/garmin-gadm`.

### Eject failed

If something still has a file open on the card, `udisksctl unmount` fails and a dialog says so. Close Database Manager (and any file manager window on that card) and eject from the file manager, or unmount by hand:

```bash
udisksctl unmount -b /dev/sdb1
udisksctl power-off -b /dev/sdb1
```

Use the device node from the start dialog or from the log, not a guess.

### Wine problems

Launcher output, Wine output, and the `reg add` that marks the drive removable all go to `~/.cache/gadm-launch.log`. Scroll to the latest timestamp.

Confirm the drive mapping after a start, while the app is still open:

```bash
ls -l "$WINEPREFIX/dosdevices/a:"
```

`a:` should point at the card's mountpoint (often under `/media` or `/run/media`). There should be no `a::`. Drive types are covered in [Database Manager does not see the card](#database-manager-does-not-see-the-card).

## Files

| File | Role |
| --- | --- |
| `gadm` | Launcher script |
| `gadm.desktop` | Menu entry template (`@HOME@` is replaced by `install.sh`) |
| `install.sh` | Installs the script and menu entry, then checks dependencies |
| `uninstall.sh` | Removes the script and menu entry |
| `README.md` | This guide |
