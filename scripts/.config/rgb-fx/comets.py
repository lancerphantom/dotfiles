DESCRIPTION = "Comets: three triadic comets racing at different speeds and directions, colours mix where they cross"
import importlib.util, math, pathlib
_s = importlib.util.spec_from_file_location("_punch", pathlib.Path(__file__).with_name("_punch.py"))
P = importlib.util.module_from_spec(_s); _s.loader.exec_module(P); H = P.H

RING_SPEEDS = (0.95, -0.70, 0.55)   # laps per second (negative = other way round)
LINE_FREQS = (0.42, 0.31, 0.23)     # back-and-forth sweeps per second (RAM-safe)
TRAIL = 0.35                        # seconds of tail
SAMPLES = 8
BG = 0.03


def _pos(t, j, n, ring):
    if ring:
        return (t * RING_SPEEDS[j] * n + j * n / 3.0) % n
    return (n - 1) * (0.5 + 0.5 * math.sin(2 * math.pi * LINE_FREQS[j] * t + 2.1 * j))


def frame(t, base, n):
    cols = P.palette(base, (0, 120, 240))
    if n == 1:                                           # one soft pulse per comet, rotating colour
        k, ph = int(t / 0.8) % 3, (t / 0.8) % 1.0
        return [P.finish(*P.scale(cols[k], H._lvl(max(BG, math.exp(-ph * 3.5)))))]
    ring = H._is_ring(n)
    bg = H._lvl(BG)
    acc = [list(P.scale(cols[0], bg)) for _ in range(n)]
    dt = TRAIL / (SAMPLES - 1)
    for j in range(3):
        best = [0.0] * n
        for k in range(SAMPLES):
            pos = _pos(t - k * dt, j, n, ring)
            lv = H._lvl(1.0 - k / SAMPLES)
            for i in range(n):
                w = H._w(H._dist(i, pos, n, ring)) * lv
                if w > best[i]:
                    best[i] = w
        for i in range(n):
            if best[i]:
                for c in range(3):
                    acc[i][c] += cols[j][c] * best[i]
    return [P.finish(*px) for px in acc]
