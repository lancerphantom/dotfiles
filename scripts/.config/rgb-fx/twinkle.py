"""twinkle — TwinkleFOX-style stateless twinkles over a dim base glow.

Technique (after Mark Kriegsman's TwinkleFOX): every LED follows the same
attack/decay waveform but runs on its own hashed clock (speed + phase), and a
hash of (LED, cycle) decides whether this cycle twinkles and which colour it
uses. Nothing is stored, so it is safe when one module drives several devices.
Colours are drawn from your base: itself, a tint toward white, and two
analogous neighbours. Attack >= ~0.3 s keeps it smooth on the 15 Hz RAM.
"""
DESCRIPTION = "Twinkle: stateless holiday-light twinkles in tints and analogous shades of your colour"

import math

CYCLE = 2.6        # seconds per twinkle cycle (each LED gets 0.7x..1.3x)
DENSITY = 0.55     # chance an LED twinkles in a given cycle
ATTACK = 0.15      # fraction of the cycle spent rising
BG = 0.14          # perceptual background glow
SALT = 0           # change to re-roll the pattern

# ---------------------------------------------------------------- helpers
# (Each effect file is self-contained; this block is shared verbatim.)
GAMMA = 2.2   # perceptual level -> LED PWM. Set 1.0 if your engine already gamma-corrects.


def _c8(x):
    return 0 if x <= 0 else (255 if x >= 255 else int(x + 0.5))


def _scale(c, k):
    """Scale an sRGB colour by a PWM multiplier (keeps hue on a linear LED)."""
    return (_c8(c[0] * k), _c8(c[1] * k), _c8(c[2] * k))


def _lvl(p):
    """Perceptual brightness 0..1 -> PWM multiplier (Adafruit-style gamma)."""
    return 0.0 if p <= 0 else (1.0 if p >= 1 else p ** GAMMA)


def _smooth(u):
    u = 0.0 if u < 0 else (1.0 if u > 1 else u)
    return u * u * (3.0 - 2.0 * u)


# --- OKLab / OKLCH (Bjorn Ottosson 2020) for perceptual blending + harmonies
def _to_lin(v):
    v /= 255.0
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def _from_lin(x):
    if x <= 0.0:
        return 0.0
    if x >= 1.0:
        return 255.0
    return 255.0 * (12.92 * x if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055)


def _oklab(rgb):
    r, g, b = (_to_lin(float(v)) for v in rgb)
    l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ** (1 / 3)
    m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ** (1 / 3)
    s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ** (1 / 3)
    return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


def _lab_lin(L, a, b):
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    return (4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)


def _rgb(lab):
    r, g, b = _lab_lin(*lab)
    return (_from_lin(r), _from_lin(g), _from_lin(b))


def _mix(p, q, f):
    """Linear interpolation of two OKLab triples."""
    return (p[0] + (q[0] - p[0]) * f, p[1] + (q[1] - p[1]) * f, p[2] + (q[2] - p[2]) * f)


def _lch(rgb):
    L, a, b = _oklab(rgb)
    return L, math.hypot(a, b), math.degrees(math.atan2(b, a))


def _oklch(L, C, h):
    """OKLCH -> sRGB floats; chroma is reduced until the colour fits sRGB."""
    L = min(max(L, 0.0), 1.0)
    ca, sa = math.cos(math.radians(h)), math.sin(math.radians(h))

    def inside(c):
        r, g, b = _lab_lin(L, c * ca, c * sa)
        return min(r, g, b) >= -1e-4 and max(r, g, b) <= 1.0001

    if not inside(C):
        lo, hi = 0.0, C
        for _ in range(12):
            mid = 0.5 * (lo + hi)
            if inside(mid):
                lo = mid
            else:
                hi = mid
        C = lo
    return _rgb((L, C * ca, C * sa))


# --- geometry: n == 6 is the fan ring, anything else > 1 is a line
def _is_ring(n):
    return n == 6


def _pos(i, n):
    """Ring: 0..1 around the circle. Line: 0 at LED 0 (RAM bottom / keyboard left) .. 1 at the far end."""
    if n <= 1:
        return 0.0
    return i / n if _is_ring(n) else i / (n - 1)


def _dist(a, b, n, ring):
    d = abs(a - b)
    return min(d, n - d) if ring else d


def _w(d, width=1.0):
    """cos^2 anti-aliasing bump. At width 1 neighbouring weights always sum to 1,
    so a dot between two LEDs keeps constant total light (no 'beating')."""
    if d >= width:
        return 0.0
    c = math.cos(0.5 * math.pi * d / width)
    return c * c


def _point(i, n, ring_radius=0.6, line_half=1.5):
    """Map an LED to a 2-D point so noise/plasma fields wrap seamlessly on rings."""
    if n <= 1:
        return 0.0, 0.0
    p = _pos(i, n)
    if _is_ring(n):
        a = 2 * math.pi * p
        return ring_radius * math.cos(a), ring_radius * math.sin(a)
    return (2 * p - 1) * line_half, 0.0


def _h(a, b=0):
    """Stateless integer hash -> [0, 1). Same inputs always give the same value."""
    x = (a * 0x9E3779B1 + b * 0x85EBCA77 + 0x165667B1) & 0xFFFFFFFF
    x ^= x >> 15
    x = (x * 0x2C1B3C6D) & 0xFFFFFFFF
    x ^= x >> 12
    x = (x * 0x297A2D39) & 0xFFFFFFFF
    x ^= x >> 15
    return x / 4294967296.0


def _noise(x, y, seed=0):
    """2-D gradient (Perlin-style) noise with Perlin's 2002 quintic fade. ~[-1, 1]."""
    ix, iy = math.floor(x), math.floor(y)
    fx, fy = x - ix, y - iy

    def g(cx, cy, dx, dy):
        a = _h(cx * 73856093 + seed, cy * 19349663 - seed) * 6.283185307
        return math.cos(a) * dx + math.sin(a) * dy

    u = fx * fx * fx * (fx * (fx * 6 - 15) + 10)
    v = fy * fy * fy * (fy * (fy * 6 - 15) + 10)
    n00, n10 = g(ix, iy, fx, fy), g(ix + 1, iy, fx - 1, fy)
    n01, n11 = g(ix, iy + 1, fx, fy - 1), g(ix + 1, iy + 1, fx - 1, fy - 1)
    a = n00 + (n10 - n00) * u
    b = n01 + (n11 - n01) * u
    return 1.4 * (a + (b - a) * v)


def _cached(cache, key, build):
    v = cache.get(key)
    if v is None:
        if len(cache) > 64:
            cache.clear()
        v = cache[key] = build()
    return v
# ------------------------------------------------------------ end helpers

_cache = {}


def _palette(base):
    def build():
        L, C, h = _lch(base)
        lb = _oklab(base)
        return [base,
                _rgb(_mix(lb, _oklab((255, 255, 255)), 0.35)),
                _oklch(L, C, h + 25.0),
                _oklch(L, C, h - 25.0)]
    return _cached(_cache, base, build)


def _wave(f):
    if f < ATTACK:
        return _smooth(f / ATTACK)
    u = (f - ATTACK) / (1.0 - ATTACK)
    return (1.0 - u) ** 2                       # long, soft decay


def frame(t, base, n):
    base = tuple(base)
    pal = _palette(base)
    bg = _lvl(BG)
    out = []
    for i in range(n):
        speed = 0.7 + 0.6 * _h(i, 101 + SALT)
        local = t * speed / CYCLE + _h(i, 202 + SALT)
        k = math.floor(local)
        if _h(i * 7919 + k, 303 + SALT) < DENSITY:
            lv = BG + (1.0 - BG) * _wave(local - k)
            col = pal[int(_h(i * 104729 + k, 404 + SALT) * len(pal))]
            out.append(_scale(col, _lvl(lv)))
        else:
            out.append(_scale(base, bg))
    return out
