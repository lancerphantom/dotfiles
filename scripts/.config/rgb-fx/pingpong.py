DESCRIPTION = "Dot bouncing back and forth"
import math
def frame(t, base, n):
    pos = (n - 1) * (0.5 - 0.5 * math.cos(t * 2))
    return [tuple(c * max(0, 1 - abs(i - pos)) ** 2 for c in base) for i in range(n)]
