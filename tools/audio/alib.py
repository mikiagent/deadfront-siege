"""Shared ffmpeg helpers for the DEADFRONT audio build. Runs ffmpeg as a subprocess only.
Downloaded files are only ever read as audio data by ffmpeg; nothing from them is executed.
"""
import json, os, re, subprocess

FF = "/opt/homebrew/bin/ffmpeg"
FP = "/opt/homebrew/bin/ffprobe"


def run(args, check=True):
    p = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if check and p.returncode != 0:
        raise RuntimeError("cmd failed: %s\n%s" % (" ".join(args), p.stderr[-2500:]))
    return p


def probe(path):
    p = run([FP, "-v", "error", "-show_entries", "format=duration:stream=channels,sample_rate",
             "-of", "json", path])
    d = json.loads(p.stdout)
    s = (d.get("streams") or [{}])[0]
    return float(d["format"]["duration"]), int(s.get("channels", 1)), int(s.get("sample_rate", 44100))


def volume(path, af=None):
    args = [FF, "-hide_banner", "-nostats", "-i", path, "-af", (af + "," if af else "") + "volumedetect", "-f", "null", "-"]
    e = run(args).stderr
    mx = re.search(r"max_volume: (-?[\d.]+) dB", e)
    mn = re.search(r"mean_volume: (-?[\d.]+) dB", e)
    return (float(mx.group(1)) if mx else -99.0, float(mn.group(1)) if mn else -99.0)


def segments(path, rel_db=28.0, min_sil=0.06, af=None):
    """Non-silent regions [(start, end)] with the threshold rel_db below the file peak."""
    mx, _ = volume(path, af)
    thr = mx - rel_db
    chain = (af + "," if af else "") + "silencedetect=n=%.1fdB:d=%.3f" % (thr, min_sil)
    e = run([FF, "-hide_banner", "-nostats", "-i", path, "-af", chain, "-f", "null", "-"]).stderr
    dur = probe(path)[0]
    starts = [float(x) for x in re.findall(r"silence_start: (-?[\d.]+)", e)]
    ends = [float(x) for x in re.findall(r"silence_end: (-?[\d.]+)", e)]
    segs, cur = [], 0.0
    # silence intervals alternate start/end; sound lives between an end and the next start
    events = sorted([(s, "s") for s in starts] + [(t, "e") for t in ends])
    in_sil = False
    for t, kind in events:
        if kind == "s" and not in_sil:
            if t - cur > 0.02:
                segs.append((max(0.0, cur), t))
            in_sil = True
        elif kind == "e" and in_sil:
            cur = t
            in_sil = False
    if not in_sil and dur - cur > 0.02:
        segs.append((cur, dur))
    return segs


def lufs(path, loop_to=None):
    """Integrated loudness (LUFS). Short clips are looped to loop_to seconds so the 400 ms gate can measure them."""
    af = "ebur128=framelog=quiet"
    if loop_to:
        af = "aloop=loop=-1:size=2e9,atrim=0:%.2f,%s" % (loop_to, af)
    e = run([FF, "-hide_banner", "-nostats", "-i", path, "-af", af, "-f", "null", "-"]).stderr
    m = re.findall(r"I:\s+(-?[\d.]+) LUFS", e)
    return float(m[-1]) if m else -70.0


def loudness(path, loop_to=None):
    """(integrated LUFS, true peak dBTP) of a file, measured as shipped. ebur128 true peak is 4x oversampled."""
    af = "ebur128=framelog=quiet:peak=true"
    if loop_to:
        af = "aloop=loop=-1:size=2e9,atrim=0:%.2f,%s" % (loop_to, af)
    e = run([FF, "-hide_banner", "-nostats", "-i", path, "-af", af, "-f", "null", "-"]).stderr
    i = re.findall(r"I:\s+(-?[\d.]+) LUFS", e)
    tp = re.findall(r"Peak:\s+(-?[\d.]+|-inf) dBFS", e)
    return (float(i[-1]) if i else -70.0), (float(tp[-1]) if tp and tp[-1] != "-inf" else -99.0)
