# Copy this file to NAME.py to make a new effect (files starting with _ are ignored).
#   frame(t, base, n) is called ~30 times a second:
#     t    — seconds since start (already multiplied by the speed setting)
#     base — your current colour as (r, g, b), 0–255
#     n    — LEDs per fan (6); all fans mirror this
#   return a list of n (r, g, b) tuples. Normal colours — the engine fixes the fan channel order.
DESCRIPTION = "Describe the effect here"

def frame(t, base, n):
    return [base] * n
