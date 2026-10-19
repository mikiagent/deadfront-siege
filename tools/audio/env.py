"""Energy envelope and call extraction. Downloads are decoded by ffmpeg to raw PCM; nothing is executed.
Usage: python3 -I env.py [--rel 22] [--min 0.15] [--max 4] [--n 8] files...
"""
import array, math, os, subprocess, sys

FF = "/opt/homebrew/bin/ffmpeg"
RATE = 8000
HOP = 160  # 20 ms
_cache = {}


def envelope(path):
    """Per-20ms RMS in dBFS of the mono downmix."""
    if path in _cache:
        return _cache[path]
    p = subprocess.run([FF, "-v", "error", "-i", path, "-ac", "1", "-ar", str(RATE), "-f", "s16le", "-"],
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
    a = array.array("h")
    a.frombytes(p.stdout[: len(p.stdout) // 2 * 2])
    out = []
    for i in range(0, len(a) - HOP + 1, HOP):
        s = 0
        for v in a[i:i + HOP]:
            s += v * v
        rms = math.sqrt(s / HOP) / 32768.0
        out.append(20.0 * math.log10(max(rms, 1e-6)))
    _cache[path] = out
    return out


def calls(path, rel=22.0, lo=0.15, hi=4.0, gap=0.12, n=8, pre=0.03, post=0.10):
    """Loud regions [(start, end, peak_db)] sorted by peak, threshold rel dB under the 98th percentile."""
    e = envelope(path)
    if not e:
        return []
    srt = sorted(e)
    ref = srt[int(len(srt) * 0.98) - 1 if len(srt) > 1 else 0]
    thr = ref - rel
    regions, cur = [], None
    for i, v in enumerate(e):
        if v >= thr:
            if cur is None:
                cur = [i, i]
            elif (i - cur[1]) * HOP / RATE <= gap:
                cur[1] = i
            else:
                regions.append(cur)
                cur = [i, i]
            cur[1] = i
    if cur:
        regions.append(cur)
    dur = len(e) * HOP / RATE
    out = []
    for a, b in regions:
        s = max(0.0, a * HOP / RATE - pre)
        t = min(dur, (b + 1) * HOP / RATE + post)
        if t - s < lo:
            continue
        if t - s > hi:
            t = s + hi
        pk = max(e[a:b + 1])
        out.append((round(s, 3), round(t, 3), round(pk, 1)))
    out.sort(key=lambda r: -r[2])
    return out[:n]


if __name__ == "__main__":
    args = sys.argv[1:]
    opts = {"--rel": 22.0, "--min": 0.15, "--max": 4.0, "--n": 8}
    while args and args[0] in opts:
        opts[args[0]] = float(args[1])
        args = args[2:]
    for f in args:
        c = calls(f, opts["--rel"], opts["--min"], opts["--max"], n=int(opts["--n"]))
        print(os.path.basename(f), " ".join("%.2f-%.2f(%.0f)" % r for r in sorted(c)))
