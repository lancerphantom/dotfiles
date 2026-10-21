DESCRIPTION = "Dim colour with random white sparkles"
import random
_sparks = {}
def frame(t, base, n):
    out = []
    for i in range(n):
        if random.random() < 0.02:
            _sparks[i] = t + 0.15
        out.append((255, 255, 255) if _sparks.get(i, 0) > t else tuple(c * 0.25 for c in base))
    return out
