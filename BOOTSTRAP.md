# Bootstrap

Restoring this setup on a fresh Arch install. Order matters — several steps
break if run early.

Assumes: base Arch installed, network up, non-root user created, `git` and
`base-devel` present.

**Read `SETUP.md` before starting.** It carries the hardware facts that aren't
in any config file — most importantly that this GPU is Pascal and cannot use
the repo `nvidia*` packages. Getting that wrong costs you the graphical
session and an evening.

---

## 1. AUR helper

Chicken-and-egg: `aur-packages.txt` can't be restored without a helper, and the
helper is itself in the AUR. Build it manually once.

```bash
sudo pacman -S --needed base-devel git
git clone https://aur.archlinux.org/paru.git /tmp/paru
cd /tmp/paru && makepkg -si
```

## 2. Clone dotfiles

```bash
git clone git@github.com:lancerphantom/dotfiles.git ~/dotfiles
```

SSH clone needs keys already set up. If not, clone over HTTPS and switch the
remote later.

## 3. pacman.conf — before installing anything

`etc/pacman.conf` carries an `IgnorePkg` pin. Restore it *first*, or step 4
installs the exact package you were holding back and you won't notice.

```bash
sudo cp ~/dotfiles/etc/pacman.conf /etc/pacman.conf
sudo cp -r ~/dotfiles/etc/pacman.d/hooks /etc/pacman.d/ 2>/dev/null || true
```

Diff before overwriting if the fresh install's default has moved on:

```bash
diff /etc/pacman.conf ~/dotfiles/etc/pacman.conf
```

## 4. Packages

```bash
cd ~/dotfiles
sudo pacman -S --needed - < packages.txt
paru -S --needed - < aur-packages.txt
```

Expect failures — package names change and AUR entries get dropped. Note what
fails and move on; nothing here blocks later steps.

**Watch:** `nvidia-580xx-dkms` and `lib32-nvidia-580xx-utils` are the correct
drivers for the GT 1030 — Pascal is frozen on the 580 branch, which is why
these live in the AUR rather than the repos. Arch moved the repo `nvidia`
packages to the open kernel modules, which do not support Pascal at all. See
`SETUP.md` before substituting anything.

If the GPU ever changes, these become wrong and should be swapped for whatever
that card needs.

Also stale: `neofetch` (discontinued upstream, fastfetch replaces it),
`snapd`/`yay-debug` if they reappear.

## 5. Remaining /etc files

Everything else in `etc/`. These are copies, not symlinks — `/etc` can't be
stowed.

```bash
cd ~/dotfiles/etc
sudo cp -a modprobe.d sysctl.d /etc/ 2>/dev/null || true
sudo cp -a conf.d/pacman-contrib /etc/conf.d/ 2>/dev/null || true
sudo cp -a my.cnf.d/server.cnf /etc/my.cnf.d/ 2>/dev/null || true
sudo cp -a mkinitcpio.conf /etc/mkinitcpio.conf
sudo mkinitcpio -P
```

**Check `/etc/modprobe.d/` by hand.** If it contains a `nouveau` blacklist and
the GPU has changed, that blacklist will silently kill the driver you actually
want. Blacklists you wrote survive package removal; the ones the package
shipped don't.

`state/etc-modified.txt` and `state/etc-unowned.txt` list everything that was
changed on the old machine, including files not copied into the repo. Skim
them for anything this step misses.

## 6. Oh-My-Zsh — before stowing zsh

`.zshrc` sources OMZ, so it must exist first. But the OMZ installer writes its
own `.zshrc`, which will block `stow zsh`.

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
rm -f ~/.zshrc          # remove the installer's version
```

Then set the login shell:

```bash
chsh -s /usr/bin/zsh
```

## 7. Stow

```bash
cd ~/dotfiles
stow --simulate zsh     # dry run first, always
stow zsh git kitty fastfetch scripts konsole
```

Conflicts mean a real file exists where a symlink should go. Move it aside
(`mv ~/.foo ~/.foo.bak`) and re-run.

`scripts` symlinks into `~/bin/` — make sure that's on `PATH` (it's set in
`.zprofile`, which stow just placed, so this resolves after a re-login).

**Do not stow `kde`, `kde-configs`, `sddm`, or `etc`.** Those are copy-based.

## 8. KDE configs — timing is critical

KDE rewrites its config files atomically and does so on logout. Restoring while
Plasma is running means the session overwrites your restored files on the way
out.

1. Log into Plasma once, so the config directories exist.
2. Log out to a TTY (`Ctrl+Alt+F3`) — or run the restore from SDDM before
   logging in.
3. Run the restore:

```bash
~/bin/kde-restore.sh
```

4. Reboot.

**Verify before relying on this:** `kde-restore.sh` should mirror everything
`kde-save.sh` writes — the `.config` file list, `Kvantum/`, `environment.d/`,
`kde-material-you-colors/`, `systemd/user/`, and
`.local/share/plasma/desktoptheme/DarkMinimal/`. The two scripts can drift.
Diff their file lists before trusting the restore.

### kde-configs/

Snapshots (`baseline`, `pre-phase2`), not deployment targets. Nothing to
restore from here — reference only.

## 9. SDDM

```bash
cd ~/dotfiles/sddm
sudo ./install.sh
```

Needs `sddm-astronaut-theme` from the AUR installed first (should have come in
with step 4). Writes to `/etc/`, hence sudo.

## 10. Services — nothing enables these for you

Installing a package does not switch it on. `state/services-system.txt` and
`state/services-user.txt` are the record of what was actually running.

```bash
less ~/dotfiles/state/services-system.txt
less ~/dotfiles/state/services-user.txt
```

Enable what's listed. The two that change visible behaviour:

```bash
systemctl --user enable --now kde-material-you-colors.service
systemctl enable paccache.timer          # keeps root from filling up
# plus the SDDM sub-theme cycling service, installed in step 9
```

Neither of the first two errors when absent — KDE just stops recolouring and
the login screen stops cycling. Easy to lose for weeks without noticing.

Anything listed as `masked` was switched off on purpose. Leave it that way.

## 11. Assets — not in this repo

Deliberately excluded, and several things stay broken until these are back:

- **Wallpapers** — panel and desktop config reference paths that won't resolve.
- **`~/Pictures/fastfetch/`** — the random-image cycling has nothing to cycle,
  and the pywal cache can't be built.

Restore from backup, then regenerate the pywal cache:

```bash
# per-image color schemes, consumed by ~/bin/kitty-launch.sh
for img in ~/Pictures/fastfetch/*; do wal -n -s -t -i "$img"; done
```

> **Unresolved:** the working note for `kitty-launch.sh` says `-s` must be
> **omitted** for colours to apply. That contradicts the line above. Test both
> against one image and diff `~/.cache/wal/image-colors/` before trusting
> either. See `SETUP.md`.

Check `~/.cache/wal/image-colors/` afterwards — `kitty-launch.sh` reads from
there and silently falls back if it's empty.

## 12. Secrets

Never committed. Recreate by hand:

```bash
mkdir -p ~/.config/secrets
printf 'GEMINI_API_KEY=...\n' > ~/.config/secrets/gemini.env
chmod 600 ~/.config/secrets/gemini.env
```

`fixcmd` (and the `fix` zsh function) stay broken until this exists.

## 13. Verify

```bash
fastfetch                    # random image + pywal colors
fix                          # needs the secrets file
cd <partial-name>            # zoxide
# Alt+C                      # fzf directory jump
# Meta+`                     # kitty-launch.sh, absolute path in the shortcut

dkms status                  # nvidia module built for the running kernel
grep -n IgnorePkg /etc/pacman.conf
systemctl --user is-enabled kde-material-you-colors.service
df -h /                      # compare against state/boot.md
```

Reboot once more and confirm SDDM picks a random astronaut sub-theme.

## 14. Re-arm the capture

The state files are only useful if they stay current.

```bash
~/bin/capture-system-state.sh
cd ~/dotfiles && git add state etc && git commit -m "state: refresh"
```

Run it after any deliberate system change, not on a schedule.

---

## Reference, not restore

`state/boot.md` records the old machine's partition layout, boot entries,
`fstab` and `mkinitcpio` settings. Every UUID and PARTUUID in it belongs to
the old disk. Read it to understand the layout; do not paste it into a fresh
install.

---

## Open gaps

Things to confirm rather than assume:

- `konsole/` — `konsole/.config/` is empty. Check whether the package holds
  anything at all, or is a leftover directory that should be dropped.
- `kde-restore.sh` coverage vs `kde-save.sh` (see step 8).
- `.zshrc` may still carry Hyprland-era aliases (`mood`, `hyprlogout`) that do
  nothing under KDE.
- The pywal `-s` contradiction in step 11.
- `~/projects` is not backed up anywhere. ChessLens, raudioviz, the subtitle
  app and the Kerala dashboard live on one disk with no snapshots. Nothing in
  this document helps with that.
