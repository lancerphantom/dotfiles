DESCRIPTION = "Juggle Pop: fast vivid triadic dots weaving and colliding (punchy juggle)"
import importlib.util, pathlib
_s = importlib.util.spec_from_file_location("_punch", pathlib.Path(__file__).with_name("_punch.py"))
P = importlib.util.module_from_spec(_s); _s.loader.exec_module(P)

J = P.load("juggle")
J.RING_SPEEDS = (0.90, -0.62, 0.44)
J.LINE_FREQS = (0.55, 0.41, 0.30)     # faster, still about 1 LED per RAM frame at most
J.WIDTH = 1.0
J.BG = 0.03
J._cols = lambda base: P.palette(base, (0, 120, 240))   # full-saturation triad


def frame(t, base, n):
    return J.frame(t, base, n)
