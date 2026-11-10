"""Wallpaper colours for effects (hidden: starts with _).
   Settings live in ~/.config/rgb-fx/settings.conf:
     colour  = wallpaper | chosen     main colour effects use
     palette = wallpaper | harmony    extra colours of multi-colour effects
   rgb-wallpaper writes ~/.cache/rgb-wall (main colour) and ~/.cache/rgb-wall-palette (left->right colours)."""
import pathlib, time

HOME = pathlib.Path.home()
SETTINGS = HOME / ".config/rgb-fx/settings.conf"
WALL, WALL_PAL = HOME / ".cache/rgb-wall", HOME / ".cache/rgb-wall-palette"
_cache = {"t": -10.0, "set": None, "pal": None}


def _hex(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def settings():
    now = time.monotonic()
    if now - _cache["t"] < 1.0 and _cache["set"] is not None:
        return _cache["set"]
    s = {"colour": "chosen", "palette": "harmony"}
    try:
        for line in SETTINGS.read_text().splitlines():
            line = line.split("#")[0]
            if "=" in line:
                k, v = line.split("=", 1)
                s[k.strip().lower()] = v.strip().lower()
    except OSError:
        pass
    pal = None
    if s["palette"] == "wallpaper":
        try:
            pal = [_hex(h) for h in WALL_PAL.read_text().strip().split(",") if len(h) == 6] or None
        except (OSError, ValueError):
            pal = None
    _cache.update(t=now, set=s, pal=pal)
    return s


def main_colour():
    """Wallpaper's main colour when colour = wallpaper, else None."""
    if settings()["colour"] != "wallpaper":
        return None
    try:
        return _hex(WALL.read_text().strip())
    except (OSError, ValueError):
        return None


def pick(k):
    """k well-separated wallpaper colours (most vivid first) when palette = wallpaper, else None."""
    settings()
    p = _cache["pal"]
    if not p:
        return None
    chosen = [max(p, key=lambda c: max(c) - min(c))]
    while len(chosen) < k:
        chosen.append(max(p, key=lambda c: min(sum((a - b) ** 2 for a, b in zip(c, o)) for o in chosen)))
    return [tuple(float(x) for x in c) for c in chosen]
