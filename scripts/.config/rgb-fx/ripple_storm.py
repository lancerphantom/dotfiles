DESCRIPTION = "Ripple Storm: fast vivid droplets in three triadic colours, crossing and overlapping"
import importlib.util, pathlib
_s = importlib.util.spec_from_file_location("_punch", pathlib.Path(__file__).with_name("_punch.py"))
P = importlib.util.module_from_spec(_s); _s.loader.exec_module(P)

R = P.load("ripple")
R.PERIOD = 0.75        # a drop every 0.75 s (was 1.8)
R.LIFE = 1.2           # must stay <= 2 x PERIOD
R.REACH = 0.55
R.WIDTH = 1.0
R.BG = 0.04
R._cols = lambda base: P.palette(base, (0, 120, 240))


def frame(t, base, n):
    return R.frame(t, base, n)
