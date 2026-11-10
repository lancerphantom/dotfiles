DESCRIPTION = "Collide Relay: one wave runs keyboard -> mouse, another runs down the RAM, and they crash together on the fans"
import colorsys, math
import importlib.util as _iu, pathlib as _pl
_ws = _iu.spec_from_file_location("_wallpal", _pl.Path(__file__).with_name("_wallpal.py"))
W = _iu.module_from_spec(_ws); _ws.loader.exec_module(W)

PERIOD = 2.6
# wave A: your colour, keyboard (left->right) then mouse arc (left->right)
KB = (0.00, 0.55)
MOUSE = (0.55, 0.35)
# wave B: complementary colour, RAM top->bottom, timed to arrive with wave A
RAM = (0.30, 0.60)
# both meet on the fans: they rush round from opposite sides and burst white
FANS = (0.90, 0.30)
BURST = 0.45
TRAIL = 2.0
GAMMA = 2.2


def _lvl(p):
    return 0.0 if p <= 0 else (1.0 if p >= 1 else p ** GAMMA)


def _pair(base):
    w = W.pick(2)
    if w:
        return w[0], w[1]
    r, g, b = (c / 255.0 for c in base)
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if s < 0.15:
        h = 0.58
    a = tuple(c * 255 for c in colorsys.hsv_to_rgb(h, 1.0, 1.0))
    bb = tuple(c * 255 for c in colorsys.hsv_to_rgb((h + 0.5) % 1.0, 1.0, 1.0))
    return a, bb


def _sweep(f, n, col, reverse=False):
    head = f * (n - 1 + TRAIL)
    out = []
    for i in range(n):
        p = (n - 1 - i) if reverse else i
        d = head - p
        if -0.6 < d < 0.6:
            k = 1.0 - abs(d) / 0.6 * 0.4
        elif 0.6 <= d < TRAIL:
            k = _lvl(1.0 - (d - 0.6) / TRAIL)
        else:
            k = 0.0
        out.append(tuple(int(c * k) for c in col))
    return out


def frame_dev(device, t, base, n):
    a, b = _pair(base)
    u = t % PERIOD
    if device in ("keyboard", "mouse", "ram"):
        start, run = {"keyboard": KB, "mouse": MOUSE, "ram": RAM}[device]
        f = (u - start) / run
        if f < 0 or f > 1.4:
            return [(0, 0, 0)] * n
        return _sweep(f, n, b if device == "ram" else a, reverse=(device == "ram"))
    if device == "logo":
        f = (u - MOUSE[0]) / MOUSE[1]
        k = _lvl(max(0.0, 1.0 - abs(f - 0.8) * 2.5))
        return [tuple(int(c * k) for c in a)]
    # fans: wave A comes round one side, wave B the other, meeting opposite LED 0, then burst
    start, run = FANS
    f = (u - start) / run
    if f < 0 or f > 1.0 + BURST / run + 0.5:
        return [(0, 0, 0)] * n
    out = []
    half = n / 2.0
    for i in range(n):
        side_a = i <= half                       # LEDs 0..3 belong to A, 3..5 to B
        reach = min(i, n - i) / half             # 0 at LED 0, 1 opposite
        r = g = bl = 0.0
        if f <= 1.0:
            f2 = min(1.0, f * 1.2)              # fronts reach the far side just before the burst
            if reach <= f2:
                k = _lvl(0.35 + 0.65 * (1.0 - (f2 - reach)))
                col = a if side_a else b
                r, g, bl = col[0] * k, col[1] * k, col[2] * k
        else:
            age = (f - 1.0) * run / BURST        # 0..1 during the burst
            w = _lvl(max(0.0, 1.0 - age)) * (1.0 - 0.6 * (1.0 - reach))
            mix = tuple((x + y) * 0.5 for x, y in zip(a, b))
            r, g, bl = (255 * w + mix[0] * 0.4 * w, 255 * w + mix[1] * 0.4 * w, 255 * w + mix[2] * 0.4 * w)
        peak = max(r, g, bl); s = 255.0 / peak if peak > 255 else 1.0
        out.append((int(r * s), int(g * s), int(bl * s)))
    return out


def frame(t, base, n):
    return frame_dev("keyboard", t, base, n)
