DESCRIPTION = "Ripple Relay: a ripple spreads across the keyboard, carries on round the mouse and fans, and rises up the RAM"
import colorsys, math
import importlib.util as _iu, pathlib as _pl
_ws = _iu.spec_from_file_location("_wallpal", _pl.Path(__file__).with_name("_wallpal.py"))
W = _iu.module_from_spec(_ws); _ws.loader.exec_module(W)

# (start, duration) of the ripple on each device, in seconds within one cycle
ROUTE = {"keyboard": (0.00, 0.55), "mouse": (0.45, 0.35), "logo": (0.55, 0.3),
         "fans": (0.75, 0.55), "ram": (1.20, 0.65)}
PERIOD = 2.3        # one relay; each relay uses the next colour of a triad built from yours
WIDTH = 1.3         # wavefront thickness in LEDs
WAKE = 0.25         # faint glow left behind the front
GAMMA = 2.2


def _lvl(p):
    return 0.0 if p <= 0 else (1.0 if p >= 1 else p ** GAMMA)


def _colour(base, k):
    w = W.pick(3)
    if w:
        return w[k % 3]
    r, g, b = (c / 255.0 for c in base)
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if s < 0.15:
        h, s = 0.58, 1.0                       # white/grey base -> start from blue
    h = (h + (k % 3) / 3.0) % 1.0
    return tuple(c * 255 for c in colorsys.hsv_to_rgb(h, 1.0, 1.0))


def frame_dev(device, t, base, n):
    k = math.floor(t / PERIOD)
    u = t - k * PERIOD
    start, run = ROUTE.get(device, (0.0, 0.55))
    f = (u - start) / run                      # 0..1 while the ripple crosses this device
    col = _colour(base, k)
    if f < 0 or f > 1.6:
        return [(0, 0, 0)] * n
    fade = _lvl(max(0.0, 1.0 - max(0.0, f - 0.6)))
    if n == 1:                                 # logo: one swell
        k1 = _lvl(max(0.0, 1.0 - abs(f - 0.5) * 2))
        return [tuple(int(c * k1) for c in col)]
    out = []
    for i in range(n):
        if device == "fans":                   # spreads both ways round the ring from LED 0
            pos = min(i, n - i) / (n / 2.0)
        else:                                  # keyboard/mouse left->right, RAM bottom->top
            pos = i / (n - 1)
        span = (n / 2.0) if device == "fans" else (n - 1)
        d = (min(f, 1.0) - pos) * span
        if -WIDTH < d < WIDTH:
            w = math.cos(0.5 * math.pi * abs(d) / WIDTH) ** 2
        elif d >= WIDTH:
            w = WAKE
        else:
            w = 0.0
        w *= fade
        out.append(tuple(int(max(0, min(255, c * w))) for c in col))
    return out


def frame(t, base, n):
    return frame_dev("keyboard", t, base, n)
