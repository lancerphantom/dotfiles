# Bootstrap

Restoring this setup on a fresh Arch install. Order matters — several steps
break if run early.

Assumes: base Arch installed, network up, non-root user created, `git` and
`base-devel` present.

**Read `SETUP.md` before starting.** It carries the hardware facts that aren't
in any config file — most importantly that this GPU is Pascal and cannot use
the repo `nvidia*` packages. Getting that wrong costs you the graphical
session and an evening.

The short version of the desktop order, because it's the part that breaks
quietly: **packages → stow → log into Plasma once → log out to a TTY →
`overcast-restore.sh` → `kde-restore.sh` → log in.** Steps 8–10 explain why.

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

Turn on the commit guard (refuses commits containing GitHub tokens, private
keys, or files from `~/.config/gh`, `~/.config/secrets`, `~/.ssh`, `~/.gnupg`):

```bash
git -C ~/dotfiles config core.hooksPath githooks
```

The Overcast project (icon theme, dock widget, Plasma style) is a separate
repo; `overcast-restore.sh` clones it in step 9.

## 3. pacman.conf and hooks — before installing anything

`etc/pacman.conf` carries an `IgnorePkg` pin. Restore it *first*, or step 4
installs the exact package you were holding back and you won't notice.

```bash
sudo cp ~/dotfiles/etc/pacman.conf /etc/pacman.conf
sudo install -Dm644 -t /etc/pacman.d/hooks ~/dotfiles/etc/pacman.d/hooks/*.hook
```

The only hook in the repo is `overcast-plasma-update.hook`, which prints a
reminder after a Plasma upgrade (see "After every Plasma update"). Secure Boot
signing comes from `zz-sbctl.hook`, which the `sbctl` package ships.

Diff before overwriting if the fresh install's default has moved on:

```bash
diff /etc/pacman.conf ~/dotfiles/etc/pacman.conf
```

## 4. Packages

`packages.txt` is meant to hold repo packages and `aur-packages.txt` AUR
packages. Lists captured before 2026-10 put every AUR package in *both*, and
`pacman -S` aborts the whole transaction on the first name it can't find — so
filter, which stays harmless once the lists are clean:

```bash
cd ~/dotfiles
comm -23 <(sort packages.txt) <(sort aur-packages.txt) | sudo pacman -S --needed -
grep -v -- '-debug$' aur-packages.txt | paru -S --needed -
```

(`-debug` entries are split debug packages; they aren't in the AUR and paru
aborts on them too.)

Expect a few failures — package names change and AUR entries get dropped.
Remove the failing name, re-run, and move on.

Flatpak apps, if `flatpak-apps.txt` exists (the capture script writes it):

```bash
xargs -r flatpak install -y flathub < flatpak-apps.txt
```

**Watch:** `nvidia-580xx-dkms` and `lib32-nvidia-580xx-utils` are the correct
drivers for the GT 1030 — Pascal is frozen on the 580 branch, which is why
these live in the AUR rather than the repos. Arch moved the repo `nvidia`
packages to the open kernel modules, which do not support Pascal at all. See
`SETUP.md` before substituting anything.

If the GPU ever changes, these become wrong and should be swapped for whatever
that card needs.

Overcast's build needs `extra-cmake-modules`, `librsvg`, `python-pillow` and
`python-lxml` (now in `packages.txt`) plus `cmake`, `git`, `base-devel` and the
Plasma/KF6 packages from `plasma-meta`. On the old machine the first four were
installed as dependencies, so `pacman -Qqe` never listed them. Mark them
explicit there so future captures keep them:
`sudo pacman -D --asexplicit extra-cmake-modules librsvg python-pillow python-lxml`.

Also stale: `neofetch` (discontinued upstream, fastfetch replaces it),
`snapd`/`yay-debug` if they reappear.

## 5. Remaining /etc files

These are copies, not symlinks — `/etc` can't be stowed. Copy files, not
directories: captures before 2026-10 nested a second copy of each directory
inside itself (`etc/modprobe.d/modprobe.d/…`), and `cp -a dir /etc/` would
carry that junk across. The `*.conf` globs below take only the top level.

```bash
cd ~/dotfiles/etc
sudo install -Dm644 -t /etc/modprobe.d               modprobe.d/*.conf
sudo install -Dm644 -t /etc/modules-load.d           modules-load.d/*.conf
sudo install -Dm644 -t /etc/X11/xorg.conf.d          X11/xorg.conf.d/*.conf
sudo install -Dm644 -t /etc/NetworkManager/conf.d    NetworkManager/conf.d/*.conf
sudo install -Dm644 -t /etc/systemd/system.conf.d    systemd/system.conf.d/*.conf
sudo install -Dm644 systemd/zram-generator.conf      /etc/systemd/zram-generator.conf
sudo install -Dm644 conf.d/pacman-contrib            /etc/conf.d/pacman-contrib
sudo install -Dm644 environment                      /etc/environment
sudo install -Dm644 mkinitcpio.conf                  /etc/mkinitcpio.conf
sudo install -Dm644 mkinitcpio.d/linux-lts.preset    /etc/mkinitcpio.d/linux-lts.preset
sudo mkinitcpio -P
```

Not copied on purpose:

- `hostname`, `locale.conf`, `vconsole.conf` — set these during the install;
  diff against the repo copies if unsure.
- `iwd/main.conf` — only if you keep iwd as NetworkManager's backend (see
  SETUP "Wifi stack contention").
- `mkinitcpio.d/linux.preset.pacsave` — leftover from the removed `linux`
  kernel.
- `libvirt/` — restore after `libvirt` is set up, if you want the storage
  pools back.
- SDDM and Plymouth files — steps 11 and 12.

There is no `sysctl.d` or `my.cnf.d` content in the repo; earlier versions of
this step copied them.

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
`.zprofile`, which stow just placed, so this resolves after a re-login). After
adding a script to `scripts/bin/` later, re-run `stow -R scripts` if `~/bin`
isn't a single symlink to the repo directory.

**Do not stow `kde`, `kde-configs`, `overcast`, `githooks`, `sddm`, or `etc`.**
Those are copy-based or repo-only.

Never use `stow --adopt` here: it moves existing files from `$HOME` into the
repo. And make sure stow didn't fold a whole directory: `readlink -f
~/.config ~/.config/gh` must not point into `~/dotfiles`, or anything written
there — including gh's plain-text token — lands in git. `capture-system-state.sh`
checks this.

## 8. First Plasma login

1. Log into Plasma once, so the config directories exist. The panels look
   wrong at this point; that's expected.
2. *Optional.* The **Nothing** Plasma style (by jomada, LGPL) is vendored in
   the Overcast project at `plasma-style/vendor/Nothing/`, and step 9 installs
   it from there. Install it from the KDE Store only if you want the Store's
   current version: System Settings → Colors & Themes → Plasma Style → Get
   New… → "Nothing". Install the *Plasma Style* only — applying the "Nothing"
   *Global Theme* can replace the panel layout. (`kdeglobals` names `Nothing`
   as the global theme; if it isn't installed, System Settings just shows none
   selected.)
3. Log out to a TTY (`Ctrl+Alt+F3`) and log in there. Steps 9 and 10 run with
   Plasma stopped.

## 9. Overcast — before the KDE configs

Overcast is the custom icon theme, the "Overcast Tasks" dock widget and the
"Nothing Floating" Plasma style. The KDE configs in step 10 point at all three,
so they must exist first:

- `plasmarc` names `Nothing-Floating`. If it doesn't exist, Plasma falls back
  to Breeze with opaque panels.
- the panel layout runs `org.kde.plasma.overcasttasks`. If it isn't built, the
  dock shows a "widget not found" placeholder.
- that widget lives in `~/.local/lib/plugins`, which Plasma only searches if
  `~/.config/plasma-workspace/env/overcast-tasks.sh` sets `QT_PLUGIN_PATH`
  before the session starts. Without it the dock is empty.

```bash
~/bin/overcast-restore.sh
```

What it does, in order (see the script header):

1. checks the build dependencies (step 4);
2. clones Overcast to `~/projects/claudeCode/kdeCons` at the commit pinned in
   `overcast/overcast.conf` — the systemd units expect that path;
3. installs the Nothing style from the checkout's vendored copy, unless it's
   already installed;
4. generates Nothing-Floating, builds the icon theme (default or pinned
   palette — it recolours from the wallpaper at the first login) and builds the
   dock widget. **The dock build clones plasma-desktop for the installed Plasma
   version, so it needs network** and takes a few minutes;
5. installs the `plasma-workspace/env` script from the checkout;
6. installs and enables `overcast-refresh.path`, `overcast-refresh.service`
   and `overcast-tasks-check.service`;
7. sets folder icons (`.directory`), launcher icons (`.desktop` `Icon=`) and
   the Places icon from `overcast/*.tsv`;
8. runs `kbuildsycoca6`.

It's idempotent. Launchers for apps that aren't installed yet (Burp Suite,
Antigravity, Bully) are skipped with a note — install them, then re-run
`overcast-restore.sh --no-build` to set their icons. A Burp Suite update can
rewrite its launcher; the same command puts the icon back.

## 10. KDE configs — timing is critical

KDE rewrites its config files atomically and does so on logout. Restoring while
Plasma is running means the session overwrites your restored files on the way
out.

Still in the TTY from step 8:

```bash
~/bin/kde-restore.sh --check   # read-only
~/bin/kde-restore.sh
```

Then reboot (or log in).

`kde-save.sh` and `kde-restore.sh` read the same list, `kde/manifest.txt`, so
they can't drift. The restore:

- refuses to run while `plasmashell` is running;
- refuses if the icon theme, Plasma style or Overcast Tasks widget the
  restored files name isn't there — run step 9 first;
- warns about other missing widgets, the global theme and the cursor theme;
- backs up any live file it replaces to `~/.local/state/kde-restore/<time>/`.

`--force` skips the checks if you know better.

The panel files (`plasmashellrc`, `plasma-org.kde.plasma.desktop-appletsrc`)
use containment and applet IDs and screen numbers from this machine. Restored
together on the same screen setup they work; on a different monitor layout,
expect to fix panels by hand (see "Open question" at the end).

### kde-configs/

Snapshots (`baseline`, `pre-phase2`), not deployment targets. Nothing to
restore from here — reference only.

## 11. SDDM

```bash
cd ~/dotfiles/sddm
sudo ./install.sh
sudo install -Dm644 -t /etc/sddm.conf.d ~/dotfiles/etc/sddm.conf.d/*.conf
```

Needs `sddm-astronaut-theme` installed first. **It is not in either package
list** — install it from the AUR (`paru -S sddm-astronaut-theme`) or however
it was installed originally. Writes to `/etc/`, hence sudo.

## 12. Plymouth

`etc/plymouth/theme-cycle.conf` lists the themes to rotate (`circle_alt`,
`colorful_sliced`, `glitch`), and `plymouth-theme-rotate-boot.service` /
`plymouth-theme-rotate.service` run `/usr/local/bin/plymouth-theme-rotate`.
**That script and the themes are not in this repo or the package lists**, so
rotation can't be restored yet (see "Open gaps"). Copy the units only once the
script exists:

```bash
sudo install -Dm644 ~/dotfiles/etc/plymouth/theme-cycle.conf /etc/plymouth/theme-cycle.conf
sudo install -Dm644 -t /etc/systemd/system ~/dotfiles/etc/systemd/system/plymouth-theme-rotate*.service
sudo install -Dm644 -t /etc/systemd/system/plymouth-quit.service.d ~/dotfiles/etc/systemd/system/plymouth-quit.service.d/override.conf
sudo systemctl daemon-reload && sudo systemctl enable plymouth-theme-rotate-boot.service
```

## 13. Services — nothing enables these for you

Installing a package does not switch it on. `state/services-system.txt` and
`state/services-user.txt` are the record of what was actually enabled.

```bash
less ~/dotfiles/state/services-system.txt
less ~/dotfiles/state/services-user.txt
```

Enable what's listed. The ones that change visible behaviour without erroring
when absent:

```bash
systemctl enable paccache.timer                    # keeps root from filling up
systemctl --user enable organize-downloads.timer
# sddm-theme-cycle.service — enabled by sddm/install.sh (step 11)
# overcast-refresh.path/.service, overcast-tasks-check.service — enabled by
#   overcast-restore.sh (step 9)
```

Without the Overcast units the icons stop following the wallpaper and the dock
goes empty after the next Plasma update — both silently.

`kde-material-you-colors` is retired (2026-10-26): no longer saved, restored
or enabled.

Anything listed as `masked` was switched off on purpose. Leave it that way.

## 14. Assets — not in this repo

Deliberately excluded, and several things stay broken until these are back:

- **Wallpapers** — the desktop now uses Plasma's picture-of-the-day plugin
  (Simon Stålenhag), which downloads its own images, but `plasmarc` still
  lists old wallpaper paths under `~/Pictures/Wallpapers/`.
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

> **Missing:** `kitty-launch.sh` is not in the repo, and neither is the
> custom-shortcut launcher `~/.local/share/applications/net.local.bash.desktop`
> that `kglobalshortcutsrc` binds to Meta+backtick. Both need adding, or that
> shortcut and the pywal kitty colours don't survive a rebuild.

## 15. Secrets

Never committed. Recreate by hand:

```bash
mkdir -p ~/.config/secrets
printf 'GEMINI_API_KEY=...\n' > ~/.config/secrets/gemini.env
chmod 600 ~/.config/secrets/gemini.env
```

`fixcmd` (and the `fix` zsh function) stay broken until this exists.

## 16. Verify

```bash
fastfetch                    # random image + pywal colors
fix                          # needs the secrets file
cd <partial-name>            # zoxide
# Alt+C                      # fzf directory jump
# Meta+`                     # kitty-launch.sh, via net.local.bash.desktop

dkms status                  # nvidia module built for the running kernel
grep -n IgnorePkg /etc/pacman.conf
df -h /                      # compare against state/boot.md
```

Overcast, after logging into Plasma:

```bash
kreadconfig6 --file kdeglobals --group Icons --key Theme      # Overcast
kreadconfig6 --file plasmarc --group Theme --key name         # Nothing-Floating
plasmashell --version; cat ~/.local/share/overcast-tasks/built-for   # same version
systemctl --user is-enabled overcast-refresh.path overcast-refresh.service overcast-tasks-check.service
systemctl --user status overcast-refresh.service overcast-tasks-check.service --no-pager
cat ~/.local/state/overcast/last-build.json                  # palette built from the wallpaper
overcast-save.sh             # warns if units/env script drifted from the project
```

By eye: the dock shows app icons (not an empty panel or a "widget not found"
box), a running app's icon is the lit variant, panels are invisible, folders
in Dolphin show Overcast icons and no content previews.

Reboot once more and confirm SDDM picks a random astronaut sub-theme.

## 17. Re-arm the capture

The state files are only useful if they stay current.

```bash
~/bin/capture-system-state.sh      # also regenerates the package lists
~/bin/kde-save.sh
~/bin/overcast-save.sh             # folder/launcher icons, Overcast commit pin
cd ~/dotfiles && git status && git diff --stat
```

Commit, then **push** — commits that only exist on this disk don't help a
rebuild.

Run it after any deliberate system change, not on a schedule.
`capture-system-state.sh` reports packages that dropped off the lists since
the last commit; if one of them is still needed, mark it explicit
(`sudo pacman -D --asexplicit <pkg>`) and re-run.

---

## After every Plasma update

Overcast Tasks is compiled against the exact installed Plasma version. After a
Plasma upgrade the old build may not load, and the dock stays empty until it's
rebuilt.

- `overcast-tasks-check.service` rebuilds it at the next login and restarts the
  panel. It needs network and takes a minute or two; the dock is empty until
  then.
- `overcast-plasma-update.hook` (step 3) prints a reminder at the end of the
  pacman transaction.
- By hand: `~/projects/claudeCode/kdeCons/overcast-tasks/build.sh && systemctl --user restart plasma-plasmashell`.
  Never copy over the installed `.so` while plasmashell runs — `build.sh`
  swaps it atomically.
- Check: `journalctl --user -u overcast-tasks-check.service -b`.

---

## Reference, not restore

`state/boot.md` records the old machine's partition layout, boot entries,
`fstab` and `mkinitcpio` settings. Every UUID and PARTUUID in it belongs to
the old disk. Read it to understand the layout; do not paste it into a fresh
install.

---

## Open gaps

Things to confirm rather than assume:

- `konsole/` — the stow package has only an empty `.local/share/konsole/`.
  Check whether it should hold anything, or drop it.
- `.zshrc` may still carry Hyprland-era aliases (`mood`, `hyprlogout`) that do
  nothing under KDE.
- The pywal `-s` contradiction, `kitty-launch.sh` and
  `net.local.bash.desktop` (step 14).
- `/usr/local/bin/plymouth-theme-rotate` and the three Plymouth themes aren't
  captured anywhere (step 12).
- `sddm-astronaut-theme`, `zoxide`, `openrgb` and the Bibata cursor theme aren't in either package list. Some may have been
  installed another way; the `rgb*` scripts need OpenRGB and the shell needs
  zoxide.
- Hyprland/HyDE-era packages are still listed (`waybar`, `wlogout`, `fuzzel`,
  `foot`, `grim`, `slurp`, `cliphist`, `grub`, `grub2-theme-preview`).
- `~/projects` is not backed up anywhere. Overcast is covered once it's
  pushed to GitHub; ChessLens, raudioviz, the subtitle app and the Kerala
  dashboard still live on one disk with no snapshots.

## Decided (2026-10-26)

- **kde-material-you-colors** — retired. Config, unit and the `kde-configs/`
  copies removed. `scripts/bin/wal-hook.sh` was its on-change hook and is now
  unused.
- **DarkMinimal Plasma style, KvDarkMinimal Kvantum theme** — dropped from the
  manifest and the repo. Kvantum stays on its default theme.
- **Vendored themes** — none in this repo now; the Nothing style is vendored
  in the Overcast project with its licence (`plasma-style/vendor/VENDOR.md`).
- **`__pycache__`** — untracked; `.gitignore` covers it.
- **Nested `etc/` duplicates** — confirmed byte-for-byte identical, removed.

## Open question

- **Panel layout as a script** — the copied panel files are tied to these
  screens. A Plasma layout script (`qdbus6 org.kde.plasmashell /PlasmaShell
  org.kde.PlasmaShell.evaluateScript`) would rebuild the launcher / dock /
  tray panels on any screen setup. Worth writing once the layout settles; it
  needs testing on the live session.
