DESCRIPTION = "Plasma Neon: fast plasma split into your colour and its complement, with dark gaps between"
import importlib.util, math, pathlib
_s = importlib.util.spec_from_file_location("_punch", pathlib.Path(__file__).with_name("_punch.py"))
P = importlib.util.module_from_spec(_s); _s.loader.exec_module(P); H = P.H

SPEED = 2.2
GAP = 0.15          # dark band between the two colours (higher = more contrast)


def frame(t, base, n):
    a, b = P.palette(base, (0, 180))
    tt = t * SPEED
    out = []
    for i in range(n):
        x, y = H._point(i, n, ring_radius=0.8, line_half=1.4)
        v = (math.sin(2.1 * x + 0.9 * tt) + math.sin(2.7 * y - 0.7 * tt)
             + math.sin(1.6 * (x + y) + 0.5 * tt)
             + math.sin(3.0 * math.hypot(x + 0.5 * math.sin(0.3 * tt), y + 0.5 * math.cos(0.4 * tt)) - tt)) / 4.0
        la = H._lvl(min(1.0, max(0.0, (v - GAP) / 0.45)))
        lb = H._lvl(min(1.0, max(0.0, (-v - GAP) / 0.45)))
        out.append(P.finish(a[0] * la + b[0] * lb, a[1] * la + b[1] * lb, a[2] * la + b[2] * lb))
    return out
