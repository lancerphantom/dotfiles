DESCRIPTION = "Inferno Tint: fast fire recoloured toward your colour (blue/purple fire) with frequent flares"
import importlib.util, math, pathlib
_s = importlib.util.spec_from_file_location("_punch", pathlib.Path(__file__).with_name("_punch.py"))
P = importlib.util.module_from_spec(_s); _s.loader.exec_module(P); H = P.H
I = P.load("inferno")
I.F.TINT_BY_BASE = True
I.FLARE_EVERY = 1.4
I.FLARE_CHANCE = 0.7


def frame(t, base, n):
    return I.frame(t, base, n)
