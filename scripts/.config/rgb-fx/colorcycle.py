DESCRIPTION = "Whole fan slowly cycles through all colours"
import colorsys
def frame(t, base, n):
    return [tuple(c * 255 for c in colorsys.hsv_to_rgb((t * 0.1) % 1, 1, 1))] * n
