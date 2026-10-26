DESCRIPTION = "Meteor Shower: many short bright streaks in triadic colours, each from a random spot and direction"
import importlib.util, math, pathlib
_s = importlib.util.spec_from_file_location("_punch", pathlib.Path(__file__).with_name("_punch.py"))
P = importlib.util.module_from_spec(_s); _s.loader.exec_module(P); H = P.H

SPAWN = 0.22        # seconds between new meteors
LIFE = 0.9
SPEED = 9.0         # LEDs per second (RAM-safe: under 15)
TRAIL = 2.2         # tail length in LEDs
BG = 0.03


def frame(t, base, n):
    cols = P.palette(base, (0, 120, 240))
    ring = H._is_ring(n)
    small = 1 < n < 6                                     # mouse arc: fewer, slower meteors
    spawn = SPAWN * (2.5 if small else 1.0)
    speed = SPEED * (0.55 if small else 1.0)
    k0 = math.floor(t / spawn)
    bg = H._lvl(BG)
    acc = [[cols[0][c] * bg for c in range(3)] for _ in range(n)]
    for k in range(k0, k0 - int(LIFE / spawn) - 1, -1):
        age = t - k * spawn
        if not 0.0 <= age < LIFE:
            continue
        col = cols[int(H._h(k, 31) * 3)]
        fade = H._lvl(1.0 - age / LIFE)
        if n == 1:
            w = math.sin(math.pi * age / LIFE) * 0.45        # smooth swell per meteor (no strobing)
            for c in range(3):
                acc[0][c] += col[c] * w
            continue
        d = 1 if H._h(k, 32) < 0.5 else -1
        start = H._h(k, 33) * n
        head = start + d * speed * age
        for i in range(n):
            behind = (head - i) * d                          # >0 means LED is behind the head
            if ring:
                behind = behind % n
            if -0.6 < behind < TRAIL:
                w = (1.0 - max(0.0, behind) / TRAIL) ** 2 if behind >= 0 else H._w(-behind, 0.6)
                w *= fade
                if not ring and not (0 <= head < n + TRAIL) and not (-TRAIL < head < n):
                    continue
                for c in range(3):
                    acc[i][c] += col[c] * w
    return [P.finish(*px) for px in acc]
