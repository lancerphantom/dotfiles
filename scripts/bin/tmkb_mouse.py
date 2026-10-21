"""Direct control of the TMKB M1SE (Instant chip 30fa:1440) lighting via hidraw.
   Odd colour slots are zones: 1,3,5,9,B = arc left->right, 7 = logo (in mode 0xB1).
   Even slots 0..A are the palette used by 'breathing-multi'."""
import fcntl, glob, os

ARC, LOGO, PALETTE = [0x1, 0x3, 0x5, 0x9, 0xB], 0x7, [0x0, 0x2, 0x4, 0x6, 0x8, 0xA]
MODES = {"zones": 0xB1, "breathing-multi": 0x01, "spectrum": 0x06, "wave": 0x07, "breathing": 0x08,
         "breathing2": 0x09, "flicker": 0xB8, "startrek": 0xB9, "ripple": 0xBA, "enraptured": 0xBB,
         "direct": 0x0A, "off": 0xFF}

def find_device():
    for p in sorted(glob.glob("/sys/class/hidraw/hidraw*")):
        try:
            if "000030FA:00001440" not in open(p + "/device/uevent").read().upper():
                continue
            if open(os.path.realpath(p + "/device") + "/../bInterfaceNumber").read().strip() == "01":
                return "/dev/" + os.path.basename(p)
        except OSError:
            continue
    return None

class Mouse:
    def __init__(self):
        path = find_device()
        if not path:
            raise OSError("TMKB mouse not found")
        self.fd = os.open(path, os.O_RDWR)
        self.cache = {}

    def _send(self, p):
        fcntl.ioctl(self.fd, (3 << 30) | (len(p) << 16) | (ord('H') << 8) | 0x06, bytes(p))

    def slot(self, s, rgb, force=False):
        R, G, B = (0xF - int(max(0, min(255, c))) // 16 for c in rgb)
        key = (R, G, B)
        if not force and self.cache.get(s) == key:
            return
        self.cache[s] = key
        self._send([0x07, 0x14, (s << 4) | G, (R << 4) | B, 0, 0, 0, 0])

    def mode(self, m, speed=2, bright=7):
        self._send([0x07, 0x13, 0xFF, (m << 4 & 0xF0) | speed, 0x0B, 0xF - bright, m & 0xF0, 0])
        self.cache.clear()

    def zones(self, cols):
        """cols: 6 colours = arc left->right (5) + logo; fewer values repeat."""
        cols = [cols[i % len(cols)] for i in range(6)]
        for s, c in zip(ARC + [LOGO], cols):
            self.slot(s, c)
