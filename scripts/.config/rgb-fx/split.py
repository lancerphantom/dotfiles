DESCRIPTION = "Half your colour, half its opposite, rotating"

def frame(t, base, n):
    opp = tuple(255 - c for c in base)
    return [base if ((i + int(t * 3)) % n) < n // 2 else opp for i in range(n)]
