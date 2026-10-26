DESCRIPTION = "Lightning: dark storm glow with sudden double-flash strikes on random spots (under 3 flashes/s)"
import importlib.util, math, pathlib
_s = importlib.util.spec_from_file_location("_punch", pathlib.Path(__file__).with_name("_punch.py"))
P = importlib.util.module_from_spec(_s); _s.loader.exec_module(P); H = P.H

SLOT = 1.6          # seconds per possible strike (keeps it under 3 flashes/s)
CHANCE = 0.85       # chance a slot has a strike
BG = 0.12


def _strike(age):
    """Classic double flash: bright, brief dip, second flash, then fade."""
    if age < 0:
        return 0.0
    if age < 0.06:
        return 1.0
    if age < 0.13:
        return 0.15
    if age < 0.2:
        return 0.85
    return max(0.0, 0.85 * math.exp(-(age - 0.2) * 9.0))


def frame(t, base, n):
    glow = P.vivid(P.hue(base, 260.0), L=0.55)
    bolt = (225.0, 235.0, 255.0)
    k = math.floor(t / SLOT)
    level, centre, size = 0.0, 0.0, 0.0
    for kk in (k, k - 1):
        if H._h(kk, 21) < CHANCE:
            start = kk * SLOT + H._h(kk, 22) * SLOT * 0.25
            lv = _strike(t - start)
            if lv > level:
                level, centre, size = lv, H._h(kk, 23) * n, 1.0 + H._h(kk, 24) * n * 0.5
    ring = H._is_ring(n)
    bg = H._lvl(BG + 0.04 * math.sin(t * 0.7) ** 2)
    out = []
    for i in range(n):
        r, g, b = glow[0] * bg, glow[1] * bg, glow[2] * bg
        if level:
            w = 1.0 if n == 1 else H._w(H._dist(i, centre, n, ring), size)
            w = max(w, 0.18) * H._lvl(level)                  # whole device lights a little
            r += bolt[0] * w; g += bolt[1] * w; b += bolt[2] * w
        out.append(P.finish(r, g, b))
    return out
