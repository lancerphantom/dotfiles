DESCRIPTION = "Rainbow rotating around each fan"
import colorsys

def frame(t, base, n):
    return [tuple(int(c * 255) for c in colorsys.hsv_to_rgb((i / n + t * 0.3) % 1, 1, 1)) for i in range(n)]
