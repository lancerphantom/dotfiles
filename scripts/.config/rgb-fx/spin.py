DESCRIPTION = "Bright dot with a fading tail circling the ring"

def frame(t, base, n):
    out = []
    for i in range(n):
        k = max(0.0, 1 - ((i - t * n) % n) / 3) ** 2
        out.append(tuple(int(c * k) for c in base))
    return out
