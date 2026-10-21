"""scene_rise_sweep — one energy pulse that travels across the whole PC.

Timeline per CYCLE (effect-seconds):
  lines (n=10) 0.0-1.5  : a bright front fills from LED 0 -> end
                          (RAM rises bottom->top, keyboard sweeps left->right)
  fans  (n=6)  1.5-3.1  : the ring blooms, then a complementary comet spins out
                          and decelerates
  mouse (n=1)  2.6-3.6  : a soft swell lands on the mouse
  otherwise             : dim idle glow
frame() only knows n, so RAM and keyboard (both 10) move together by default.
To chain them (RAM first, then keyboard), have the engine call this effect
with per-device time offsets — format unchanged:

    DELAYS = {"ram": 0.0, "keyboard": 1.5, "fans": 1.5, "mouse": 1.5}
    colours = effect.frame(t - DELAYS.get(device, 0.0), base, n)

(For the WiZ bulb, call it with t + ~0.35 to cancel its network latency.)
"""
DESCRIPTION = "Scene: energy rises up the RAM, sweeps the keyboard, bursts through the fans, lands on the mouse"

import math

CYCLE = 5.2           # use >= 6.7 if you apply the DELAYS below
LINE_START, LINE_DUR = 0.0, 1.5   # >= 1.5 s keeps the front < 0.75 LED per 15 Hz RAM frame
FAN_START, FAN_DUR = 1.5, 1.6
MOUSE_START, MOUSE_DUR = 2.6, 1.0
IDLE = 0.14
FADE_TAU = 0.55        # how fast a filled line fades after the sweep
ACCENT_HUE = 180.0     # comet colour on the fans (complementary)

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


def _cols(base):
    def build():
        L, C, h = _lch(base)
        lb = _oklab(base)
        return (_rgb(_mix(lb, _oklab((255, 255, 255)), 0.4)),   # hot leading edge
                _oklch(L, C, h + ACCENT_HUE))
    return _cached(_cache, base, build)


def _ease_out(u):
    u = min(1.0, max(0.0, u))
    return 1.0 - (1.0 - u) ** 3


def _line(i, n, tc, base, edge):
    u = (tc - LINE_START) / LINE_DUR
    if u < 0.0:
        return _scale(base, _lvl(IDLE))
    front = _smooth(u) * (n + 1.0) - 1.0                   # -1 .. n
    behind = front - i
    fade = math.exp(-max(0.0, tc - LINE_START - LINE_DUR) / FADE_TAU)
    if behind < 0.0:                                       # not reached yet
        # leading edge: AA weight is applied in linear PWM (not gamma'd), so the
        # front glides between LEDs instead of popping on.
        pwm = _w(-behind, 2.0) * _lvl(fade)
        idle = _lvl(IDLE)
        return _scale(edge, pwm) if pwm > idle else _scale(base, idle)
    body = (0.55 + 0.45 * math.exp(-behind / 1.5)) * fade
    f = _smooth(behind / 1.6)                             # edge colour melts into base
    col = tuple(edge[k] + (base[k] - edge[k]) * f for k in range(3))
    return _scale(col, _lvl(max(IDLE, body)))


def _ring(n, tc, base, accent):
    tf = tc - FAN_START
    bg = _lvl(IDLE)
    if tf < 0.0 or tf > FAN_DUR + 1.0:
        return [_scale(base, bg)] * n
    bloom = _lvl(_smooth(tf / 0.15) * math.exp(-max(0.0, tf - 0.15) / 0.5))
    head = _ease_out(tf / FAN_DUR) * 2.0 * n               # two laps, decelerating
    clv = _lvl(max(0.0, 1.0 - tf / (FAN_DUR + 0.6)))
    out = []
    for i in range(n):
        w = _w(_dist(i, head % n, n, True), 1.3) * clv
        r = base[0] * max(bg, bloom) + accent[0] * w
        g = base[1] * max(bg, bloom) + accent[1] * w
        b = base[2] * max(bg, bloom) + accent[2] * w
        peak = max(r, g, b)
        s = 255.0 / peak if peak > 255.0 else 1.0
        out.append((_c8(r * s), _c8(g * s), _c8(b * s)))
    return out


def frame(t, base, n):
    base = tuple(base)
    edge, accent = _cols(base)
    tc = t % CYCLE
    if n == 1:
        tm = tc - MOUSE_START
        lv = IDLE
        if 0.0 <= tm <= MOUSE_DUR:
            lv = max(IDLE, _smooth(tm / 0.15) * math.exp(-max(0.0, tm - 0.15) / 0.4))
        return [_scale(base, _lvl(lv))]
    if _is_ring(n):
        return _ring(n, tc, base, accent)
    return [_line(i, n, tc, base, edge) for i in range(n)]
