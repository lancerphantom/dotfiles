DESCRIPTION = "Red/blue police flasher"

def frame(t, base, n):
    return [(255, 0, 0) if int(t * 4) % 2 else (0, 0, 255)] * n
