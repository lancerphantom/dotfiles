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

Custom keys live in `/etc/secureboot/keys/` — PK, KEK and db, each with a
`.key` private half.

**The private keys are not in this repo and never will be.** The capture script
refuses to copy them. They need their own offline backup. Without them you
cannot sign anything, and re-enrolling means putting the firmware back into
Setup Mode.

**Confirm which tooling you used.** `sbctl` keeps its keys under
`/var/lib/sbctl/` by default, so `/etc/secureboot/keys/` suggests a manual
`sbsigntools` setup following the Arch wiki instead. That distinction decides
whether re-signing after an update is automatic (sbctl ships a pacman hook) or
something you have to remember to do. Check `pacman -Qs sbctl` and
`ls /var/lib/sbctl` before assuming.

**What definitely must be signed:** the systemd-boot EFI binary and the kernel.
An unsigned bootloader after `bootctl update` means the firmware refuses to
boot it, and the symptom is a machine that goes straight to the boot menu or to
Windows.

**What may or may not need signing:** DKMS kernel modules. Module signature
enforcement comes from kernel lockdown, not from Secure Boot directly, and
Arch's stock kernels generally don't enable the Secure-Boot-triggered lockdown
— so unsigned modules usually still load. Verify rather than assume:

```bash
dmesg | grep -i lockdown
cat /sys/kernel/security/lockdown 2>/dev/null
```

If lockdown is inactive, the nvidia DKMS module loads unsigned and this is a
non-issue. If it's active, an unsigned module fails to load and the symptom is
**identical to having the wrong driver** — no display, `dkms status` showing a
successful build. Knowing which case you're in is worth five minutes now.

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
systemctl --user enable --now kde-material-you-colors.service
# sddm-theme-cycle.service — installed by sddm/install.sh, hooked into
# halt/reboot/shutdown targets
```

Also enabled and easy to forget: `ollama`, `tailscaled`, `libvirtd`,
`waydroid-container`, `fstrim.timer`, `paccache.timer`.

---

## Known problems, not yet fixed

Recorded so they don't get rediscovered as new.

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

- **`vhost_vsock`** — confirmed by `/etc/modules-load.d/vhost_vsock.conf`. The
  module is loaded at boot deliberately. If the virtiofsd symlink
  (`/usr/lib` → `/usr/bin`) is also part of this, add the detail here.

## Still to confirm

- [ ] **sshd** — `systemctl is-enabled sshd`. Arch doesn't enable it on install,
      so if it was never turned on there's no decision here to preserve.
      `sshd_config.pacnew` exists, so openssh is at least installed.
- [ ] **ESP rebuild from live USB** — if this happened, write the recovery steps
      down while they're still recallable.
- [ ] **MariaDB** — `/etc/my.cnf.d/server.cnf` doesn't exist on this machine, so
      the note about binding it to loopback describes something else. Drop it or
      correct it.

---

## Known inconsistency

BOOTSTRAP.md §11 regenerates the pywal cache with `wal -n -s -t -i "$img"`, but
the working note for `kitty-launch.sh` says `-s` must be **omitted** for colours
to apply. These disagree, and the bootstrap path is the one you'd be trusting on
a fresh machine.

Resolve by running both forms against one image and diffing
`~/.cache/wal/image-colors/`, then correct whichever document is wrong.
