DESCRIPTION = "Ripple Storm: fast vivid droplets in three triadic colours, crossing and overlapping"
import importlib.util, pathlib
_s = importlib.util.spec_from_file_location("_punch", pathlib.Path(__file__).with_name("_punch.py"))
P = importlib.util.module_from_spec(_s); _s.loader.exec_module(P)

R = P.load("ripple")
R.PERIOD = 0.5         # a drop every 0.5 s (research: 1.8)
R.LIFE = 0.95          # must stay <= 2 x PERIOD
R.REACH = 0.55
R.WIDTH = 1.0
R.BG = 0.04
R.GAMMA = 1.3        # brighter, longer-lasting wavefronts (research default 2.2)
R._cols = lambda base: P.palette(base, (0, 120, 240))


def frame(t, base, n):
    return R.frame(t, base, n)
