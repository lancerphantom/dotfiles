# Setup notes

Things about *this hardware* that no config file records. BOOTSTRAP.md tells
you what to run; this tells you why it's like that and what breaks if you
forget.

Read this before a rebuild, not during.

---

## Hardware

| | |
|---|---|
| Host | rdiolab |
| CPU | AMD Ryzen 5 5600F (`amd-ucode`) |
| GPU | NVIDIA GT 1030 — **Pascal** |
| Boot | systemd-boot, UEFI, **Secure Boot with custom keys**, dual-boot with Windows 11 |
| Kernel | `linux-lts` |
| DE | KDE Plasma 6 on Wayland |

The GPU architecture and the Secure Boot setup are the two facts that can leave
you without a working display.

---

## GPU — read this first

**The GT 1030 is Pascal, and Pascal is off the mainline NVIDIA driver.**

NVIDIA's 580 branch is the last to support Maxwell, Pascal and Volta. In
December 2025 Arch acted on that: `nvidia` was replaced with `nvidia-open`,
`nvidia-dkms` with `nvidia-open-dkms`, and `nvidia-lts` with `nvidia-lts-open`.
The open kernel modules **do not work on Pascal**. Installing them gives you a
driver that fails to load and, typically, no graphical session.

Correct packages for this machine:

```
nvidia-580xx-dkms
lib32-nvidia-580xx-utils
```

Both from the AUR. This is not a preference — installing the repo `nvidia*`
packages on this card is a black screen.

**Failure mode to recognise:** you finish a rebuild, everything looks fine, you
reboot, and SDDM never appears. Drop to a TTY and check `dkms status` and
`lsmod | grep nvidia` before touching anything else.

**Long-term risk.** Legacy AUR branches get orphaned. If `nvidia-580xx-dkms`
ever fails to build or disappears, don't substitute the first similarly-named
package you find — check the Arch wiki's NVIDIA page for the current
Pascal-supporting name first. If the GPU is ever replaced, every line in this
section becomes wrong.

## Kernel and DKMS

- After any kernel update, **reboot before debugging module problems.** Half of
  "the driver broke" is a running kernel that no longer matches the modules on
  disk.
- `dkms status` is the first command, always.
- On `linux-lts`, `linux-lts-headers` must be installed or DKMS silently has
  nothing to build against.

## modprobe.d

Five files here, all yours. `state/etc-unowned.txt` and `etc/modprobe.d/` have
the current contents.

| file | what it does |
|---|---|
| `nvidia-drm.conf` | DRM modesetting — load-bearing for Wayland |
| `realtek-blacklist.conf` | blacklists a Realtek driver |
| `usb-autosuspend.conf` | `options usbcore autosuspend=-1` |
| `cfg80211.conf` | wifi stack options |
| `alsa-base.conf` | audio |

**The blacklist is the hazard.** Removing an out-of-tree driver does not remove
a blacklist you wrote by hand. A leftover `blacklist` line will kill the
in-kernel driver just as effectively as it killed the one you meant, with no
error pointing at the cause. Package-shipped blacklists live in
`/usr/lib/modprobe.d/` and go away with the package; yours don't. Check this
directory any time a device stops being detected for no reason.

---

## Secure Boot

Managed with **sbctl**. Keys live in `/var/lib/sbctl/keys/`. Secure Boot is
enabled, firmware is out of Setup Mode, and `Vendor Keys: microsoft` — your own
keys are enrolled alongside Microsoft's.

**Signing is automatic.** `zz-sbctl.hook` in `/usr/share/libalpm/hooks/` re-signs
the bootloader and kernel on every relevant pacman transaction. Nothing to
remember during normal use.

**Module signing does not apply here.** Signature enforcement comes from kernel
lockdown, and lockdown is inactive on this machine
(`/sys/kernel/security/lockdown` reads `[none]`). Unsigned DKMS modules load
fine. If that ever changes, an unsigned nvidia module fails to load with a
symptom identical to having the wrong driver — no display, `dkms status` showing
a clean build.

**The keys are not in this repo and never will be.** The capture script refuses
to copy them. They need their own offline backup. Without them you cannot sign
anything, and re-enrolling means putting the firmware back into Setup Mode.

### On a rebuild

The `--microsoft` flag is not optional on this machine:

```bash
sbctl create-keys          # or restore /var/lib/sbctl from backup
sbctl enroll-keys --microsoft
sbctl sign-all
sbctl verify
```

Enrolling **without** `--microsoft` removes Microsoft's certificates from db.
Windows will no longer boot, and on some firmware the option ROMs stop
validating too — which can leave the machine unable to POST properly and needing
a CMOS reset. This is the single most expensive mistake available in this
document.

### Stale key set

`/etc/secureboot/keys/` also exists, with its own PK/KEK/db. sbctl does not use
that path, so it is almost certainly left over from an earlier manual
`sbsigntools` attempt. Two key directories and no label saying which is enrolled
is exactly the confusion you don't want mid-rebuild.

Confirm which set is live, then remove the other (after backing it up):

```bash
cat /var/lib/sbctl/GUID        # compare against sbctl status Owner GUID
```

---

## Dual-boot

Two separate problems that are easy to confuse.

**Windows Fast Startup.** Windows hibernates rather than shutting down, leaving
filesystems in a claimed state. Symptom: NTFS partitions refuse to mount or
mount read-only. Appears *only after a Windows session*. Turn it off in Windows
power settings; Windows updates have been known to turn it back on.

**USB autosuspend.** Separate issue, already fixed at the driver level —
`/etc/modprobe.d/usb-autosuspend.conf` sets `options usbcore autosuspend=-1`.
Symptom without it: peripherals dropping out when idle, at any time,
independent of Windows. If that file goes missing on a rebuild the problem
comes back and will look like failing hardware.

**The ESP is shared.** Windows updates can rewrite boot order. `bootctl status`
and `efibootmgr` are the diagnostic pair. `state/boot.md` has the last-known-good
layout.

---

## Disk

Check `df -h` in `state/boot.md` for current figures. Two habits:

- `paccache.timer` is enabled — keep it. Without it the pacman cache eats the
  root partition over months, quietly.
- Large model files go elsewhere. For ollama: set `OLLAMA_MODELS` before
  pulling anything, or you'll be moving gigabytes later.

---

## Services

Full list in `state/services-system.txt` and `state/services-user.txt`.
Installing a package doesn't turn it on. The two that break visible behaviour
without erroring:

```bash
# (kde-material-you-colors.service — retired 2026-10-26)
# sddm-theme-cycle.service — installed by sddm/install.sh, hooked into
# halt/reboot/shutdown targets
```

Also enabled and easy to forget: `ollama`, `tailscaled`, `libvirtd`,
`waydroid-container`, `fstrim.timer`, `paccache.timer`, and the user units
`organize-downloads.timer` and the three `overcast-*` units.

---

## Known problems, not yet fixed

Recorded so they don't get rediscovered as new.

> **Recheck before acting on the next two.** The 2026-08-27 capture
> (`state/services-system.txt`) shows neither `iwd.service` nor `snapd` as
> enabled — only NetworkManager and wpa_supplicant. Either they were fixed
> after this section was written, or the capture is stale. Re-run
> `capture-system-state.sh` and update or delete these entries.

**Wifi stack contention.** `iwd.service`, `wpa_supplicant.service` and
`NetworkManager.service` are all enabled simultaneously. These contend for the
same radio and it's a known source of flakiness. Pick one backend — the usual
answer is NetworkManager with either iwd *or* wpa_supplicant as its backend,
not both as standalone services.

**HyDE-era leftovers.** From an earlier Hyprland setup, now dead weight on a
systemd-boot machine:

- `/etc/default/grub.hyde.bkp` and `grub-theme-rotate.service` — rotating a GRUB
  theme on a system that doesn't use GRUB
- `/etc/pacman.conf.hyde.bkp`
- `.zshrc` may still carry `mood`, `hyprlogout` and similar aliases

**`snapd` is enabled** (`snapd.socket`, `snapd.apparmor.service`), but
BOOTSTRAP.md lists it as stale and to be dropped. One of those is wrong.

**Typo'd filename.** `/etc/plymouth/plymouthd.confe` — plymouth isn't reading
that file. Whatever was configured in it isn't taking effect.

**`/etc/passwd.OLD`** exists. Probably a leftover; check before deleting.

**Eight pending `.pacnew`/`.pacsave` files.** See `state/etc-pending-merges.txt`.
`mkinitcpio.conf.pacnew` and `sshd_config.pacnew` are the two worth reading —
they mean your config has diverged from upstream defaults that have since moved.

---

## Confirmed

- **sshd is `disabled`** — which is also Arch's default. Nothing was deliberately
  turned off, so there is nothing here to restore.

- **`vhost_vsock`** — confirmed by `/etc/modules-load.d/vhost_vsock.conf`. The
  module is loaded at boot deliberately. If the virtiofsd symlink
  (`/usr/lib` → `/usr/bin`) is also part of this, add the detail here.

## Still to confirm

- [ ] **ESP rebuild from live USB** — if this happened, write the recovery steps
      down while they're still recallable.
- [ ] **MariaDB** — `/etc/my.cnf.d/server.cnf` doesn't exist on this machine, so
      the note about binding it to loopback describes something else. Drop it or
      correct it.

---

## Overcast (icon theme, dock widget, Plasma style)

Lives in its own project at `~/projects/claudeCode/kdeCons`, installed by
`overcast-restore.sh` (BOOTSTRAP §9). Three facts that break things if
forgotten:

- **The dock widget is version-locked to Plasma.** "Overcast Tasks" is a
  patched copy of Plasma's task manager, compiled against the exact installed
  Plasma version. After a Plasma upgrade the old build may not load and the
  dock is empty until `overcast-tasks-check.service` rebuilds it at the next
  login (network needed). It looks like Plasma broke; it's this.
- **Plasma only finds the widget through `QT_PLUGIN_PATH`**, set by
  `~/.config/plasma-workspace/env/overcast-tasks.sh`. That file is read at
  session start, so adding it needs a re-login.
- **Panel configs depend on Overcast, not the other way round.** Restoring
  `plasmarc` / the panel layout before Overcast is built gives Breeze with
  opaque panels and a "widget not found" dock. `kde-restore.sh` refuses to run
  in that state.

Change panels with plasmashell stopped or through its scripting API — a
running plasmashell rewrites its config on exit.

## kitty and pywal

New kitty windows (menu, Meta+`) start `~/bin/kitty-launch.sh`, not plain
kitty: it picks a random image from `~/Pictures/fastfetch/`, builds that
image's colours with `wal -n -i <image> -q` (no `-s`) on first use, caches them
in `~/.cache/wal/image-colors/`, and starts kitty with them. Two launchers
route there — `kitty.desktop` (overrides the system one) and
`net.local.bash.desktop` (the Meta+` shortcut); both are in
`kde/manifest.txt`. Lose either and kitty still opens, just without the image
and colours, so it looks like a pywal problem when it isn't.

## Credentials that must never enter the repo

**`~/.config/gh/`** — the GitHub CLI stored its token in
`~/.config/gh/hosts.yml` in **plain text**, because no keyring (KWallet /
Secret Service) was reachable when `gh auth login` ran. Anyone who can read
that file can act as you on GitHub, including the private Overcast repo.

Guards in place:

- no stow package contains `.config/gh`, and `kde/manifest.txt` can't list it
  (`kde-save.sh` / `kde-restore.sh` refuse credential paths);
- `.gitignore` excludes `.config/gh/`, `gh/hosts.yml`, `.config/secrets/`,
  `.ssh/`, `.gnupg/`;
- `githooks/pre-commit` blocks those paths and anything that looks like a
  GitHub token or private key (enable per clone:
  `git config core.hooksPath githooks`);
- `capture-system-state.sh` scans the whole repo for tokens and warns if
  `~/.config` or `~/.config/gh` resolves into the repo through a folded stow
  symlink.

Don't `stow --adopt`. To get the token out of plain text once a keyring
works: `gh auth logout`, then `gh auth login` (gh prefers the keyring when it
can reach one) and check `gh auth status`.

Same rule for `~/.config/secrets/` (API keys, BOOTSTRAP §15).

## Secure Boot key backup

`/var/lib/sbctl/` archived and GPG symmetric-encrypted (AES256). Not in this
repo. Without it you cannot sign anything, and re-enrolling requires putting
the firmware back into Setup Mode.

- Location: Google Drive
- Passphrase: <where you recorded it — not the passphrase itself>
- Verified by round-trip download: 2026-08-27
