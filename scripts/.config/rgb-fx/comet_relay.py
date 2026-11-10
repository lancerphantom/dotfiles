DESCRIPTION = "Comet Relay: one comet runs across the keyboard, round the mouse arc, through the fans and up the RAM"
import math

# The engine starts each device's copy of the effect this many seconds later,
# so the comet hands over from one device to the next:
#   keyboard (left -> right) -> mouse arc (left -> right) -> fans (one lap) -> RAM (bottom -> top)
RUN = {"keyboard": 0.60, "mouse": 0.35, "fans": 0.60, "ram": 0.65}
DELAYS = {"keyboard": 0.0, "mouse": 0.55, "fans": 0.85, "ram": 1.40}
PERIOD = 2.6            # one full relay, then it starts again on the keyboard
TRAIL = 2.5             # tail length in LEDs
HEAD_WHITE = 0.35       # head tinted toward white ("hot" core)
GAMMA = 2.2


def _lvl(p):
    return 0.0 if p <= 0 else (1.0 if p >= 1 else p ** GAMMA)


def _device(n):
    """Which device a call is for, from its LED count (the engine passes 6 fans, 5 mouse arc, 1 logo, 10 kb/RAM)."""
    return {6: "fans", 5: "mouse", 1: "mouse"}.get(n, "line")


def frame(t, base, n):
    u = t % PERIOD
    kind = _device(n)
    run = RUN["fans"] if kind == "fans" else RUN["mouse"] if kind == "mouse" else RUN["keyboard"]
    head_col = tuple(c + (255 - c) * HEAD_WHITE for c in base)
    if n == 1:                                          # mouse logo: flash as the comet passes
        k = _lvl(max(0.0, 1 - abs(u - run * 0.5) / (run * 0.6)))
        return [tuple(int(c * k) for c in head_col)]
    if u > run + 0.5:
        return [(0, 0, 0)] * n
    f = u / run                                         # 0..1 while crossing this device
    ring = kind == "fans"
    head = f * n if ring else f * (n - 1 + TRAIL)       # lines: run past the end so the tail leaves too
    out = []
    for i in range(n):
        d = head - i
        if ring:
            if f > 1.0:
                out.append((0, 0, 0)); continue
            d = d % n
        if d < -0.5 or d > TRAIL:
            out.append((0, 0, 0)); continue
        if d < 0.5:                                     # the head
            k = 1.0 - abs(d)
            col = head_col
        else:                                           # the tail fades out behind it
            k = _lvl(1.0 - (d - 0.5) / TRAIL)
            col = base
        out.append(tuple(int(max(0, min(255, c * k))) for c in col))
    return out
