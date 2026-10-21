DESCRIPTION = "Colour follows CPU temperature: blue cool → red hot"
from pathlib import Path
_STOPS = [(40, (0, 80, 255)), (60, (0, 255, 0)), (75, (255, 120, 0)), (85, (255, 0, 0))]
_path = next((h / "temp1_input" for h in Path("/sys/class/hwmon").iterdir()
              if (h / "name").read_text().strip() == "k10temp"), None)
def frame(t, base, n):
    c = int(_path.read_text()) / 1000 if _path else 50
    if c <= _STOPS[0][0]: col = _STOPS[0][1]
    elif c >= _STOPS[-1][0]: col = _STOPS[-1][1]
    else:
        for (t0, c0), (t1, c1) in zip(_STOPS, _STOPS[1:]):
            if t0 <= c <= t1:
                f = (c - t0) / (t1 - t0)
                col = tuple(a + (b - a) * f for a, b in zip(c0, c1)); break
    return [col] * n
