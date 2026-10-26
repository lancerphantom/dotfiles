DESCRIPTION = "Collide: two waves rush in from opposite ends in complementary colours and burst white where they meet"
import importlib.util, math, pathlib
_s = importlib.util.spec_from_file_location("_punch", pathlib.Path(__file__).with_name("_punch.py"))
P = importlib.util.module_from_spec(_s); _s.loader.exec_module(P); H = P.H

PERIOD = 1.2       # seconds per collision cycle (was 1.8)
TRAVEL = 0.5       # share of the cycle spent rushing in
BURST = 0.28       # share of the cycle the burst lasts
BG = 0.04


def _p(i, n, ring):
    """0..1 along the path: line = end to end; ring = from the top round either side to the bottom."""
    if ring:
        return min(i, n - i) / (n / 2.0)
    return i / (n - 1)


def frame(t, base, n):
    a, b = P.palette(base, (0, 180))
    u = (t / PERIOD) % 1.0
    if n == 1:
        if u < TRAVEL:
            f = u / TRAVEL
            col = P.scale(a, H._lvl(0.25 + 0.6 * f)) if int(t / PERIOD) % 2 == 0 else P.scale(b, H._lvl(0.25 + 0.6 * f))
            return [P.finish(*col)]
        g = math.exp(-(u - TRAVEL) / BURST * 3.0)
        return [P.finish(*[a[c] * 0.4 * g + b[c] * 0.4 * g + 255 * 0.5 * g + a[c] * H._lvl(BG) for c in range(3)])]
    ring = H._is_ring(n)
    span = (n / 2.0) if ring else (n - 1)                # path length in LEDs
    bg = H._lvl(BG)
    out = []
    for i in range(n):
        p = _p(i, n, ring)
        r, g_, bl = a[0] * bg, a[1] * bg, a[2] * bg
        if u < TRAVEL:
            f = u / TRAVEL                               # fronts at f*0.5 and 1 - f*0.5
            for front, col, behind in ((f * 0.5, a, p < f * 0.5), (1 - f * 0.5, b, p > 1 - f * 0.5)):
                w = H._w(abs(p - front) * span, 1.4)
                lv = max(w, 0.35 if behind else 0.0)     # lit wake behind each front
                r += col[0] * lv; g_ += col[1] * lv; bl += col[2] * lv
        else:
            age = (u - TRAVEL) / BURST
            if age < 1.0:
                radius = age * 0.6                       # white shockwave expanding from the middle
                w = H._w(abs(abs(p - 0.5) - radius) * span, 1.6) * (1 - age)
                fade = H._lvl(max(0.0, 1 - age * 1.4))
                r += 255 * w + (a[0] + b[0]) * 0.5 * fade
                g_ += 255 * w + (a[1] + b[1]) * 0.5 * fade
                bl += 255 * w + (a[2] + b[2]) * 0.5 * fade
        out.append(P.finish(r, g_, bl))
    return out
