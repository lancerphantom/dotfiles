DESCRIPTION = "Lightning Relay: each strike jumps keyboard -> mouse -> fans -> RAM like a chain of sparks"
import math

# When the strike reaches each device (seconds after it hits the keyboard)
HOPS = {"keyboard": 0.00, "mouse": 0.10, "logo": 0.10, "fans": 0.20, "ram": 0.30}
SLOT = 1.8          # seconds per possible strike (keeps every device under 3 flashes/s)
CHANCE = 0.85       # chance a slot has a strike
BG = 0.08
GLOW_HUE_FALLBACK = (40, 60, 255)   # storm glow if your colour is white/grey
BOLT = (225.0, 235.0, 255.0)
GAMMA = 2.2


def _lvl(p):
    return 0.0 if p <= 0 else (1.0 if p >= 1 else p ** GAMMA)


def _h(a, b=0):
    x = (a * 374761393 + b * 668265263) & 0xFFFFFFFF
    x = ((x ^ (x >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((x ^ (x >> 16)) & 0xFFFFFF) / float(0x1000000)


def _strike(age):
    """Double flash: bright, brief dip, second flash, then fade."""
    if age < 0:
        return 0.0
    if age < 0.06:
        return 1.0
    if age < 0.12:
        return 0.15
    if age < 0.19:
        return 0.8
    return max(0.0, 0.8 * math.exp(-(age - 0.19) * 9.0))


def frame_dev(device, t, base, n):
    glow = base if max(base) - min(base) > 30 else GLOW_HUE_FALLBACK
    k = math.floor(t / SLOT)
    level, centre, size = 0.0, 0.0, 1.0
    if _h(k, 21) < CHANCE:
        level = _strike(t - k * SLOT - 0.1 - HOPS.get(device, 0.0))
        dev_id = {"keyboard": 1, "mouse": 2, "logo": 2, "fans": 3, "ram": 4}.get(device, 5)
        centre = _h(k, 30 + dev_id) * n
        size = 1.2 + _h(k, 40 + dev_id) * n * 0.4
    ring = device == "fans"
    bg = _lvl(BG + 0.04 * math.sin(t * 0.7) ** 2)
    out = []
    for i in range(n):
        r, g, b = glow[0] * bg, glow[1] * bg, glow[2] * bg
        if level:
            d = abs(i - centre)
            if ring:
                d = min(d, n - d)
            w = 1.0 if n == 1 else max(0.0, 1.0 - d / size)
            w = max(w, 0.2) * _lvl(level)
            r += BOLT[0] * w; g += BOLT[1] * w; b += BOLT[2] * w
        peak = max(r, g, b); s = 255.0 / peak if peak > 255 else 1.0
        out.append((int(r * s), int(g * s), int(b * s)))
    return out


def frame(t, base, n):          # without device info: strike everything at once
    return frame_dev("keyboard", t, base, n)
