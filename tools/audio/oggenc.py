"""Encode a float WAV to Ogg Vorbis through Homebrew libsndfile (ffmpeg here has no libvorbis).
Usage: python3 -I oggenc.py in.wav out.ogg [quality 0..1]
"""
import ctypes, sys

lib = ctypes.CDLL("/opt/homebrew/lib/libsndfile.dylib")

class SF_INFO(ctypes.Structure):
    _fields_ = [("frames", ctypes.c_int64), ("samplerate", ctypes.c_int), ("channels", ctypes.c_int),
                ("format", ctypes.c_int), ("sections", ctypes.c_int), ("seekable", ctypes.c_int)]

lib.sf_open.restype = ctypes.c_void_p
lib.sf_open.argtypes = [ctypes.c_char_p, ctypes.c_int, ctypes.POINTER(SF_INFO)]
lib.sf_readf_float.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_float), ctypes.c_int64]
lib.sf_readf_float.restype = ctypes.c_int64
lib.sf_writef_float.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_float), ctypes.c_int64]
lib.sf_writef_float.restype = ctypes.c_int64
lib.sf_command.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p, ctypes.c_int]
lib.sf_close.argtypes = [ctypes.c_void_p]
lib.sf_strerror.restype = ctypes.c_char_p
lib.sf_strerror.argtypes = [ctypes.c_void_p]

SFM_READ, SFM_WRITE = 0x10, 0x20
SF_FORMAT_OGG, SF_FORMAT_VORBIS = 0x200000, 0x0060
SFC_SET_VBR_ENCODING_QUALITY = 0x1300


def encode(src: str, dst: str, quality: float) -> None:
    info = SF_INFO()
    fin = lib.sf_open(src.encode(), SFM_READ, ctypes.byref(info))
    if not fin:
        raise SystemExit("read failed %s: %s" % (src, lib.sf_strerror(None)))
    out = SF_INFO(0, info.samplerate, info.channels, SF_FORMAT_OGG | SF_FORMAT_VORBIS, 0, 0)
    fout = lib.sf_open(dst.encode(), SFM_WRITE, ctypes.byref(out))
    if not fout:
        raise SystemExit("write failed %s: %s" % (dst, lib.sf_strerror(None)))
    q = ctypes.c_double(quality)
    lib.sf_command(fout, SFC_SET_VBR_ENCODING_QUALITY, ctypes.byref(q), ctypes.sizeof(q))
    n = 4096
    buf = (ctypes.c_float * (n * info.channels))()
    while True:
        got = lib.sf_readf_float(fin, buf, n)
        if got <= 0:
            break
        lib.sf_writef_float(fout, buf, got)
    lib.sf_close(fin)
    lib.sf_close(fout)


if __name__ == "__main__":
    encode(sys.argv[1], sys.argv[2], float(sys.argv[3]) if len(sys.argv) > 3 else 0.4)
