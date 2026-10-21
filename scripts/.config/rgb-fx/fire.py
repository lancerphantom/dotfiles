DESCRIPTION = "Flickering fire (ignores your colour)"
import math
def frame(t, base, n):
    out = []
    for i in range(n):
        k = 0.45 + 0.55 * abs(math.sin(t * 5 + i * 2.1) * math.sin(t * 2.3 + i * 0.7))
        out.append((255 * k, 70 * k * k, 0))
    return out
