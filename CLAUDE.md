# Dotfiles repo — rdiolab

Personal Arch Linux dotfiles for host `rdiolab`. Remote: github.com/lancerphantom/dotfiles.
Goal: a fully reproducible system rebuild from this repo alone.
BOOTSTRAP.md is the step-by-step rebuild guide (order matters); SETUP.md holds hardware facts.
Read both before changing install order, drivers, boot or /etc config.

## System
- Ryzen 5 5600F; NVIDIA GT 1030 (Pascal) → needs nvidia-580xx-dkms from the AUR. Repo nvidia* packages do NOT support Pascal.
- linux-lts, systemd-boot, Secure Boot via sbctl, dual-boot with Windows 11, ext4
- KDE Plasma 6 on Wayland; zsh + Oh-My-Zsh; kitty; paru/yay

## How the repo is wired
- Stow packages: zsh, git, kitty, fastfetch, scripts, konsole. These are symlinked, so editing them in the repo edits the live config.
- NOT stowed: kde, kde-configs, overcast, githooks, sddm, systemd, etc. These are copy-based or repo-only.
- systemd/user/ holds user units, installed as copies (BOOTSTRAP step 13). Never stow or symlink a unit: `systemctl disable` deletes a unit file that is a symlink pointing outside the search path.
- KDE configs are copies because KDE writes files atomically and breaks symlinks. kde/manifest.txt lists them.
  kde-save.sh copies live → repo. kde-restore.sh copies repo → live and must run from a TTY with Plasma stopped.
- /etc files live under etc/ as copies. Installing them needs sudo: give me the command, don't run sudo yourself.
- Package lists: packages.txt (pacman -Qqe), aur-packages.txt (pacman -Qqm), flatpak-apps.txt. Regenerated manually.
- capture-system-state.sh writes state/*.txt and copies an /etc allowlist, with a deny-list for secrets.

## Linked projects
- Overcast (~/projects/claudeCode/kdeCons: icon theme, dock widget, Nothing-Floating Plasma style) is pinned in overcast/overcast.conf and installed by overcast-restore.sh.
  kitty.conf, .zshrc and kdeglobals/kwinrc/kwinrulesrc/kcminputrc/ksplashrc/appletsrc reference Overcast component names.
  Renaming anything in Overcast means updating these. kde-restore.sh --no-overcast is the fallback for a machine without it.
- rgb-lights (~/projects/claudeCode/rgb-lights: rgb*, ramfx, mousefx, ~/.config/rgb-fx, openrgb/rgb-* user units) is an optional module,
  pinned in rgb/rgb.conf and set up by its own install.sh. .zshrc:149 sources its shell/rgb.zsh.
- Never commit files owned by those repos. Stow with --no-folding (rgb-lights also links into ~/bin).

## Rules
- Never commit secrets: ~/.config/secrets/, ~/.config/gh, ~/.ssh, ~/.gnupg stay out. The commit guard in githooks/ enforces this.
  `git config core.hooksPath` must be `githooks`. Never use --no-verify.
- Never `stow --adopt`. Always `stow --simulate` first.
- `readlink -f ~/.config ~/.config/gh` must never point into this repo.
- Plasma constantly rewrites plasma-org.kde.plasma.desktop-appletsrc (icon positions, IDs). Don't commit changes to it that are only reordering.
- Show me the diff and the commit message before committing. Keep commits small and grouped by topic.

## Open issues (as of Sep 2026, check whether they're still true)
- 8 pending .pacnew merges
- Leftover HyDE-era configs
- iwd, wpa_supplicant and NetworkManager all enabled at once (wifi flakiness)
- Typo in a Plymouth config filename
- snapd is enabled but BOOTSTRAP lists it as stale
