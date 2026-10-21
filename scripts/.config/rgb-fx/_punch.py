"""Shared helpers for the punchy effects (hidden from lists: starts with _).
Reuses the research effects' colour/geometry helpers via comet.py."""
import importlib.util, math, pathlib

_DIR = pathlib.Path(__file__).resolve().parent


def load(name):
    """Load a sibling effect file as its own private copy (so overrides don't leak)."""
    spec = importlib.util.spec_from_file_location(f"_punch_{name}", _DIR / f"{name}.py")
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


H = load("comet")      # _oklch, _lch, _w, _dist, _is_ring, _lvl, _point, _h, _noise, _c8
_vivid_cache = {}


def hue(base, default=0.0):
    """Base colour's hue in OKLCH degrees; greys/whites fall back to a default hue."""
    L, C, h = H._lch(tuple(base))
    return h if C >= 0.04 else default


def vivid(h, L=0.72):
    """Most saturated colour of hue h that fits sRGB (cached)."""
    key = (round(h % 360.0, 1), L)
    if key not in _vivid_cache:
        _vivid_cache[key] = H._oklch(L, 0.37, h)
    return _vivid_cache[key]


def palette(base, offsets):
    h0 = hue(base)
    return [vivid(h0 + o) for o in offsets]


def scale(c, k):
    return (c[0] * k, c[1] * k, c[2] * k)


def finish(r, g, b):
    """Hue-preserving soft clip to 0..255 ints."""
    peak = max(r, g, b)
    s = 255.0 / peak if peak > 255.0 else 1.0
    return (H._c8(r * s), H._c8(g * s), H._c8(b * s))
