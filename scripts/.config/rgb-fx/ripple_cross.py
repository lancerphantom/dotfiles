DESCRIPTION = "Ripple Cross: frequent triadic ripples that flash white wherever two wavefronts cross"
import importlib.util, math, pathlib
_s = importlib.util.spec_from_file_location("_punch", pathlib.Path(__file__).with_name("_punch.py"))
P = importlib.util.module_from_spec(_s); _s.loader.exec_module(P); H = P.H

PERIOD = 0.55      # seconds between drops
LIFE = 1.4         # how long each ripple lives (several overlap at once)
REACH = 0.6        # seconds for a front to cross the device
WIDTH = 1.0
BG = 0.04


def frame(t, base, n):
    cols = P.palette(base, (0, 120, 240))
    ring = H._is_ring(n)
    k0 = math.floor(t / PERIOD)
    drops = []
    for k in range(k0, k0 - int(LIFE / PERIOD) - 1, -1):
        age = t - k * PERIOD
        if 0.0 <= age < LIFE:
            amp = (0.95 * math.exp(-1.4 * age)) ** 1.3 * min(1.0, age / 0.06)
            span = (n / 2.0 if ring else max(n - 1, 1)) / REACH
            origin = H._h(k, 11) * (n if ring else max(n - 1, 0))
            drops.append((age * span, origin, amp, cols[int(H._h(k, 12) * 3)]))
    bg = H._lvl(BG)
    out = []
    for i in range(n):
        r, g, b = cols[0][0] * bg, cols[0][1] * bg, cols[0][2] * bg
        hits = []
        for radius, origin, amp, col in drops:
            w = (1.0 if n == 1 else H._w(abs(H._dist(i, origin, n, ring) - radius), WIDTH)) * amp
            if w > 0.05:
                hits.append(w)
                r += col[0] * w; g += col[1] * w; b += col[2] * w
        if len(hits) >= 2 and n > 1:                  # two fronts on one LED -> white spark
            s = sorted(hits)[-2] * 255
            r += s; g += s; b += s
        out.append(P.finish(r, g, b))
    return out
