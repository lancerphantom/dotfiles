DESCRIPTION = "Pulse Relay: a bright pulse runs up the RAM, across the keyboard, round the fans and onto the mouse"
import importlib.util, math, pathlib
_s = importlib.util.spec_from_file_location("_punch", pathlib.Path(__file__).with_name("_punch.py"))
P = importlib.util.module_from_spec(_s); _s.loader.exec_module(P); H = P.H

# Per-device time offsets (seconds), read by the effects engine:
DELAYS = {"ram": 0.0, "keyboard": 0.45, "fans": 0.9, "mouse": 1.25}
PERIOD = 2.2        # one relay per 2.2 s
RUN = 0.45          # time for the pulse to cross one device
WIDTH = 1.3
BG = 0.06


def frame(t, base, n):
    a, b = P.palette(base, (0, 180))
    u = t % PERIOD
    ring = H._is_ring(n)
    bg = H._lvl(BG)
    out = []
    for i in range(n):
        r, g, bl = a[0] * bg, a[1] * bg, a[2] * bg
        if 0.0 <= u < RUN + 0.3:
            f = u / RUN
            if n == 1:
                w = math.exp(-u * 7.0)
            else:
                pos = f * (n if ring else n - 1)
                w = H._w(H._dist(i, pos, n, ring), WIDTH) if f <= 1.0 else 0.0
                behind = (pos - i) if not ring else (pos - i) % n
                if 0 < behind < 3.0 and f <= 1.0:
                    w = max(w, 0.45 * (1 - behind / 3.0))
            col = [a[c] * (1 - min(1.0, f)) + b[c] * min(1.0, f) for c in range(3)]
            r += col[0] * w + 80 * w; g += col[1] * w + 80 * w; bl += col[2] * w + 80 * w
        out.append(P.finish(r, g, bl))
    return out
