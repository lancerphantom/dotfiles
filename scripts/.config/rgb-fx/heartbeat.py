DESCRIPTION = "Double-pulse heartbeat in your colour"
import math
def frame(t, base, n):
    p = t % 1.2
    k = math.exp(-((p - 0.1) / 0.05) ** 2) + 0.6 * math.exp(-((p - 0.3) / 0.06) ** 2)
    k = 0.05 + 0.95 * min(1, k)
    return [tuple(c * k for c in base)] * n
