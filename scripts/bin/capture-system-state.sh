#!/usr/bin/env bash
#
# capture-system-state.sh
#
# Records what packages.txt and the stow packages don't: what's running, what's
# been changed under /etc, and how the box boots.
#
# Place at:  ~/dotfiles/scripts/bin/capture-system-state.sh
# Then:      cd ~/dotfiles && stow scripts

set -euo pipefail

REPO="${DOTFILES_REPO:-$HOME/dotfiles}"
STATE="$REPO/state"

[[ -d "$REPO/.git" ]] || { echo "error: $REPO is not a git repo" >&2; exit 1; }
mkdir -p "$STATE" "$REPO/etc"

echo "==> writing to $STATE"

# ---------------------------------------------------------------------------
# Secrets deny-list. Nothing matching this is copied into the repo, no matter
# what ETC_FILES says. The copy loop checks every path against it, and a second
# pass sweeps anything that slipped in inside a copied directory.
#
#   NetworkManager/system-connections  wifi PSKs in plaintext
#   secureboot/keys                    Secure Boot private keys (sbctl)
#   ssh/ssh_host_*_key                 host private keys
#   pacman.d/gnupg                     pacman keyring private keys
#   cups/ssl                           printer TLS keys
# ---------------------------------------------------------------------------
SECRET_DENY='(NetworkManager/system-connections|secureboot/keys|ssh/ssh_host_.*_key$|pacman\.d/gnupg|cups/ssl|shadow|gshadow|\.key$|brlapi)'

# ---------------------------------------------------------------------------
# 0. Package lists
#
# Native and foreign (AUR) packages go to separate files: pacman -S aborts the
# whole transaction on one name it can't find, so packages.txt must not list
# AUR packages. -debug split packages are dropped (they aren't in the AUR).
# Only explicitly installed packages are listed; something you need that came
# in as a dependency (python-pillow, librsvg, ...) disappears from the list
# unless you mark it: sudo pacman -D --asexplicit <pkg>
# ---------------------------------------------------------------------------
echo "--> package lists"
regen_list() {   # regen_list FILE PACMAN_FLAGS
    local file="$1" flags="$2" before
    before=$(git -C "$REPO" show "HEAD:${file#"$REPO/"}" 2>/dev/null || true)
    pacman "$flags" | grep -v -- '-debug$' > "$file" || true
    if [[ -n "$before" ]]; then
        local dropped
        dropped=$(comm -23 <(sort -u <<< "$before") <(sort -u "$file") | tr '\n' ' ')
        [[ -z "$dropped" ]] || echo "    dropped from ${file##*/} since last commit: $dropped
    (uninstalled, or now only a dependency — 'sudo pacman -D --asexplicit <pkg>' keeps it listed)"
    fi
}
regen_list "$REPO/packages.txt" -Qqen
regen_list "$REPO/aur-packages.txt" -Qqem
if command -v flatpak > /dev/null; then
    flatpak list --app --columns=application | sort > "$REPO/flatpak-apps.txt"
    echo "    flatpak apps: $(wc -l < "$REPO/flatpak-apps.txt")"
fi

# ---------------------------------------------------------------------------
# 1. Services
# ---------------------------------------------------------------------------
echo "--> services"
systemctl list-unit-files --state=enabled,masked --no-pager \
    > "$STATE/services-system.txt"
systemctl --user list-unit-files --state=enabled,masked --no-pager \
    > "$STATE/services-user.txt"
systemctl list-units --type=service --state=running --no-pager \
    > "$STATE/services-running.txt"

# ---------------------------------------------------------------------------
# 2. Package-owned /etc files you've edited
# ---------------------------------------------------------------------------
echo "--> modified package configs (slow, reads every package)"
pacman -Qii | awk '/^MODIFIED/ {print $2}' | sort \
    > "$STATE/etc-modified.txt"

# ---------------------------------------------------------------------------
# 3. /etc files no package owns
#
# The prune drops three categories: generated caches (rebuilt on any install),
# package-shipped symlink farms, and key material. What survives should be
# decisions you actually made.
# ---------------------------------------------------------------------------
echo "--> unowned /etc files"

PRUNE='^/etc/(ca-certificates/|ssl/certs/|pacman\.d/gnupg/|fonts/conf\.d/|texmf/|xml/catalog|dbeaver/|cups/(ssl|ppd)/|printcap|secureboot/keys/|NetworkManager/system-connections/|systemd/(system|user)/[^/]+\.(wants|requires)/|udev/hwdb\.bin|ld\.so\.cache|machine-id|localtime|os-release|mtab|resolv\.conf|\.updated|\.pwd\.lock|brlapi\.key|ssh/ssh_host_|(passwd|group|shadow|gshadow|subuid|subgid)-$)'

comm -23 \
    <(sudo find /etc \( -type f -o -type l \) 2>/dev/null | sort) \
    <(pacman -Qlq | grep '^/etc/.*[^/]$' | sort) \
    | grep -vE "$PRUNE" \
    > "$STATE/etc-unowned.txt"

echo "    $(wc -l < "$STATE/etc-unowned.txt") unowned files after pruning"

# ---------------------------------------------------------------------------
# 4. Unmerged .pacnew / .pacsave
#
# Maintenance debt. A .pacnew means an upstream default moved and your edit has
# diverged from it; a .pacsave means a package was removed and left config
# behind. Neither is recorded anywhere else.
# ---------------------------------------------------------------------------
echo "--> pending pacnew/pacsave"
sudo find /etc \( -name '*.pacnew' -o -name '*.pacsave' \) 2>/dev/null | sort \
    > "$STATE/etc-pending-merges.txt"
echo "    $(wc -l < "$STATE/etc-pending-merges.txt") pending"

# ---------------------------------------------------------------------------
# 5. Boot
#
# Reference only. Every UUID below belongs to this disk.
# ---------------------------------------------------------------------------
echo "--> boot state"
{
    echo "# Boot state — captured $(date -Is)"
    echo
    echo "REFERENCE ONLY. UUIDs belong to this disk. Read to understand the"
    echo "layout; do not paste into a fresh install."
    echo
    echo "## bootctl status"
    echo '```'; bootctl status 2>&1 || echo "(failed)"; echo '```'
    echo
    echo "## boot entries"
    echo '```'; bootctl list 2>&1 || echo "(failed)"; echo '```'
    echo
    echo "## loader.conf"
    echo '```'; sudo cat /boot/loader/loader.conf 2>/dev/null || echo "(absent)"; echo '```'
    echo
    echo "## entries/"
    for e in /boot/loader/entries/*.conf; do
        [[ -e "$e" ]] || continue
        echo "### ${e##*/}"
        echo '```'; sudo cat "$e"; echo '```'
    done
    echo
    echo "## secure boot"
    echo '```'
    sbctl status 2>/dev/null || echo "(sbctl not installed)"
    echo
    echo "signed files:"
    sbctl list-files 2>/dev/null | head -40 || true
    echo '```'
    echo
    echo "## block devices"
    echo '```'; lsblk -f; echo '```'
    echo
    echo "## mounts"
    echo '```'; findmnt --real; echo '```'
    echo
    echo "## disk usage"
    echo '```'; df -h; echo '```'
    echo
    echo "## fstab"
    echo '```'; cat /etc/fstab; echo '```'
    echo
    echo "## mkinitcpio.conf"
    echo '```'; grep -vE '^\s*(#|$)' /etc/mkinitcpio.conf; echo '```'
    echo
    echo "## kernels"
    echo '```'; pacman -Q | grep -E '^linux(-lts|-zen|-hardened)?\s' || true; echo '```'
    echo
    echo "## dkms"
    echo '```'; dkms status 2>/dev/null || echo "(dkms not installed)"; echo '```'
} > "$STATE/boot.md"

# ---------------------------------------------------------------------------
# 6. Copy the /etc files that matter
#
# Explicit allowlist. Grow it from etc-unowned.txt as you find things.
# ---------------------------------------------------------------------------
ETC_FILES=(
    # pacman
    /etc/pacman.conf
    /etc/pacman.d/hooks
    /etc/conf.d/pacman-contrib

    # identity / locale
    /etc/hostname
    /etc/locale.conf
    /etc/vconsole.conf
    /etc/environment

    # kernel / modules / initramfs
    /etc/mkinitcpio.conf
    /etc/mkinitcpio.d
    /etc/modprobe.d
    /etc/modules-load.d
    /etc/sysctl.d

    # display stack
    /etc/X11/xorg.conf.d
    /etc/sddm.conf
    /etc/sddm.conf.d
    /etc/plymouth/theme-cycle.conf

    # your own systemd units
    /etc/systemd/zram-generator.conf
    /etc/systemd/system.conf.d
    /etc/systemd/system/sddm-theme-cycle.service
    /etc/systemd/system/plymouth-theme-rotate.service
    /etc/systemd/system/plymouth-theme-rotate-boot.service
    /etc/systemd/system/plymouth-quit.service.d

    # network
    /etc/NetworkManager/conf.d
    /etc/iwd/main.conf

    # virt
    /etc/libvirt/storage
    /etc/libvirt/qemu/networks

)

echo "--> copying /etc files"
for f in "${ETC_FILES[@]}"; do
    if ! sudo test -e "$f"; then
        echo "    skip (absent): $f"
        continue
    fi
    if [[ "$f" =~ $SECRET_DENY ]]; then
        echo "    REFUSED (secret): $f"
        continue
    fi
    dest="$REPO/etc${f#/etc}"
    if sudo test -d "$f"; then
        # Copy the directory's contents. "cp -a dir dest" into an existing dest
        # nests a second copy (etc/modprobe.d/modprobe.d/...).
        mkdir -p "$dest"
        sudo cp -a "$f/." "$dest/"
    else
        mkdir -p "$(dirname "$dest")"
        sudo cp -a "$f" "$dest"
    fi
    echo "    $f"
done

sudo chown -R "$(id -u):$(id -g)" "$REPO/etc"

# Sweep anything that slipped in inside a copied directory.
while IFS= read -r leaked; do
    echo "    REMOVED from repo (secret): $leaked"
    rm -f "$leaked"
done < <(find "$REPO/etc" -type f 2>/dev/null | grep -E "$SECRET_DENY" || true)

# ---------------------------------------------------------------------------
# 7. Pre-commit check
# ---------------------------------------------------------------------------
echo
echo "==> secret scan"
grep -rInE '(password|passwd|secret|token|psk=|api[_-]?key|BEGIN [A-Z ]*PRIVATE KEY)' \
    "$REPO/etc" || echo "    clean"

# Whole repo, not just etc/: GitHub tokens or private keys anywhere tracked or
# about to be. gh keeps its token in ~/.config/gh/hosts.yml when no keyring is
# reachable; it must never end up here.
oauth='oauth''_token:'
leaks=$(cd "$REPO" && git ls-files -co --exclude-standard -z \
        | xargs -0 grep -lIE "(gh[pousr]_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,}|$oauth|BEGIN [A-Z ]*PRIVATE KEY)" 2>/dev/null || true)
if [[ -n "$leaks" ]]; then
    echo "    WARNING: possible credentials in the repo:"; sed 's/^/      /' <<< "$leaks"
fi
# A stow package folded over one of these dirs would make anything written
# there (gh's token, for one) land inside the repo.
for p in .config .config/gh .local .local/share; do
    t=$(readlink -f "$HOME/$p" 2>/dev/null || true)
    if [[ "$t" == "$REPO"/* ]]; then
        echo "    WARNING: ~/$p resolves into the repo ($t) — files written there land in git"
    fi
done
[[ "$(git -C "$REPO" config core.hooksPath)" == githooks ]] ||
    echo "    note: commit guard off — git -C \"$REPO\" config core.hooksPath githooks"
echo
echo
git -C "$REPO" status --short state etc packages.txt aur-packages.txt flatpak-apps.txt 2>/dev/null || true
