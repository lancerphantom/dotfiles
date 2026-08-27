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
| Boot | systemd-boot, UEFI, dual-boot with Windows 11 |
| Kernel | `linux-lts` |
| DE | KDE Plasma 6 on Wayland |

The GPU architecture is the single most consequential fact on this page.

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

**Failure mode to recognise:** you finish a rebuild, everything looks fine,
you reboot, and SDDM never appears. Drop to a TTY and check `dkms status` and
`lsmod | grep nvidia` before touching anything else.

**Long-term risk.** Legacy AUR branches get orphaned. If `nvidia-580xx-dkms`
ever fails to build or disappears, do not substitute the first similarly-named
package you find — check the Arch wiki's NVIDIA page for the current
Pascal-supporting package name first. If the GPU is ever replaced, every line
in this section becomes wrong.

## Kernel and DKMS

- After any kernel update, **reboot before debugging module problems.** Half
  of "the driver broke" is a running kernel that no longer matches the modules
  on disk.
- `dkms status` is the first command, always. It tells you whether the module
  was built for the kernel you're actually running.
- On `linux-lts`, `linux-lts-headers` must be installed or DKMS silently has
  nothing to build against.

## modprobe.d

Removing an out-of-tree driver does **not** remove blacklists you wrote by
hand. A leftover `blacklist nouveau` in `/etc/modprobe.d/` will kill the
in-kernel driver just as effectively as it killed it on purpose, with no error
message pointing at the cause.

Package-shipped blacklists live in `/usr/lib/modprobe.d/` and go away with the
package. Yours don't. Check `/etc/modprobe.d/` when a GPU changes hands.

---

## Dual-boot

**Windows Fast Startup.** Windows doesn't fully shut down with Fast Startup
enabled — it hibernates the kernel. Symptoms on the Linux side after a Windows
session:

- NTFS partitions refuse to mount, or mount read-only (the classic case)
- devices left in a claimed state — USB oddities are plausible here but less
  universal, so don't stop at this explanation if disabling it doesn't help

Turn it off in Windows power settings. Windows updates have been known to turn
it back on.

**The ESP is shared.** Windows updates can rewrite boot order. `bootctl status`
and `efibootmgr` are the diagnostic pair. `state/boot.md` has the last-known-good
layout.

---

## Disk

Root partition is small — check `df -h /` in `state/boot.md` for the current
figure. Two habits keep it survivable:

- `paccache -rk1` on a timer. Without it the pacman cache eats the partition
  over months, quietly.
- Anything with large model files goes elsewhere. For ollama:
  `OLLAMA_MODELS=/path/on/bigger/disk` — set it before pulling anything, or
  you'll be moving gigabytes later.

---

## Services that must be enabled by hand

`packages.txt` installs these; nothing turns them on. Full list in
`state/services-system.txt` and `state/services-user.txt`, but the two that
break visible behaviour:

```bash
systemctl --user enable --now kde-material-you-colors.service
# SDDM astronaut sub-theme cycling service — see sddm/install.sh
```

Neither errors when missing. They just don't happen, which is why they're easy
to lose for weeks.

---

## /etc deviations

Captured in `etc/`, discovered via `state/etc-modified.txt` and
`state/etc-unowned.txt`. The ones with teeth:

- **`/etc/pacman.conf`** — carries an `IgnorePkg` pin. If this doesn't come
  back, the very next `paru`/`yay` run updates the package you deliberately
  held. Silent.
- **`/etc/my.cnf.d/server.cnf`** — MariaDB bind address. This is a config file,
  not a service setting; enabling/disabling `mariadb.service` has nothing to do
  with it. Confirm the bind line before assuming it's still loopback.
- **`/etc/modprobe.d/`** — see above.

---

## Unverified — confirm before trusting

These came from notes rather than from a reproduction. Check them once and
either promote them into the sections above or delete them.

- [ ] **sshd** — was it ever actually enabled and then disabled? Arch does not
      enable `sshd.service` on install, so if it's simply never been turned on,
      there is no decision here to preserve and nothing to restore.
- [ ] **Cowork / `vhost_vsock` / virtiofsd symlink (`/usr/lib` → `/usr/bin`)** —
      not general Arch knowledge and not confirmed. If this came out of your own
      debugging session, write down the symptom that led to it. If it came from a
      model, verify before relying on it during a rebuild.
- [ ] **ESP rebuild from live USB** — if this happened, the recovery steps are
      worth writing down here while they're still recallable.

---

## Known inconsistency

BOOTSTRAP.md §8 regenerates the pywal cache with `wal -n -s -t -i "$img"`.
The working note for `kitty-launch.sh` says the `-s` flag must be **omitted**
for colours to apply correctly. These disagree, and the bootstrap path is the
one you'd be trusting on a fresh machine.

Resolve it by running both forms against one image and diffing
`~/.cache/wal/image-colors/`, then correct whichever document is wrong.
