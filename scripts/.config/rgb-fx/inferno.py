DESCRIPTION = "Inferno: faster, higher-contrast fire with occasional white-hot flares"
import importlib.util, math, pathlib
_s = importlib.util.spec_from_file_location("_punch", pathlib.Path(__file__).with_name("_punch.py"))
P = importlib.util.module_from_spec(_s); _s.loader.exec_module(P); H = P.H

F = P.load("fire")
F.RISE = 3.4
F.MIN_HEAT = 0.03
FLARE_EVERY = 2.3     # seconds between flare chances
FLARE_CHANCE = 0.55


def frame(t, base, n):
    out = F.frame(t * 1.6, base, n)
    k = math.floor(t / FLARE_EVERY)
    if H._h(k, 3) < FLARE_CHANCE:
        age = t - k * FLARE_EVERY
        g = math.exp(-age * 5.0) * 0.7
        out = [P.finish(c[0] + 255 * g, c[1] + 190 * g, c[2] + 110 * g) for c in out]
    return out
