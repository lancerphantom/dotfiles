DESCRIPTION = "Slow fade in and out of your colour"
import math

def frame(t, base, n):
    k = 0.05 + 0.95 * (0.5 - 0.5 * math.cos(t * 2))
    return [tuple(int(c * k) for c in base)] * n
