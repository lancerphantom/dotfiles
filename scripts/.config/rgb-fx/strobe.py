DESCRIPTION = "Fast white strobe (careful if light-sensitive)"
def frame(t, base, n):
    return [(255, 255, 255) if (t * 10) % 1 < 0.15 else (0, 0, 0)] * n
