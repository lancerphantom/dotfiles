DESCRIPTION = "Two comets chasing — your colour and its opposite"
def frame(t, base, n):
    opp = tuple(255 - c for c in base)
    out = []
    for i in range(n):
        k1 = max(0, 1 - ((i - t * n) % n) / 2) ** 2
        k2 = max(0, 1 - ((i - t * n - n / 2) % n) / 2) ** 2
        out.append(tuple(a * k1 + b * k2 for a, b in zip(base, opp)))
    return out
