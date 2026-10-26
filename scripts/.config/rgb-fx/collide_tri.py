DESCRIPTION = "Collide Tri: two triadic waves rush together and burst in the third triadic colour"
import importlib.util, math, pathlib
_s = importlib.util.spec_from_file_location("_punch", pathlib.Path(__file__).with_name("_punch.py"))
P = importlib.util.module_from_spec(_s); _s.loader.exec_module(P); H = P.H
C = P.load("collide")


def frame(t, base, n):
    a, b, c = P.palette(base, (0, 120, 240))
    C.P.palette = lambda base_, offs: [a, b] if len(offs) == 2 else P.palette(base_, offs)
    out = C.frame(t, base, n)
    # recolour the white burst toward the third colour
    res = []
    for r, g, bl in out:
        w = min(r, g, bl) / 255.0                     # whiteness = burst strength
        res.append(P.finish(r - 255 * w + c[0] * w * 1.4, g - 255 * w + c[1] * w * 1.4, bl - 255 * w + c[2] * w * 1.4))
    return res
