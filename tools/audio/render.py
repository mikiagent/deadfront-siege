"""Render engine for the DEADFRONT audio build: layer, pitch, filter, trim, loop, normalise, encode.
ffmpeg reads the downloads as audio data only; nothing from a download is executed.
"""
import hashlib, json, os, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import alib, env, oggenc, srcs

FF = "/opt/homebrew/bin/ffmpeg"
SR = 48000
OUT_SR = 44100
TMP = os.environ.get("AUDIO_TMP", "/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/audio-build-tmp")
os.makedirs(TMP, exist_ok=True)

_banks = {}


def bank(key, rel=20.0, lo=0.1, hi=2.0, n=12, gap=0.12):
    """Time-ordered loud regions of a source: [(start, end, peak)]."""
    k = (key, rel, lo, hi, n, gap)
    if k not in _banks:
        _banks[k] = sorted(env.calls(srcs.src(key)["path"], rel, lo, hi, gap=gap, n=n))
        if not _banks[k]:
            d = alib.probe(srcs.src(key)["path"])[0]
            _banks[k] = [(0.0, min(d, hi), 0.0)]
    return _banks[k]


def call(key, i, **kw):
    """(start, length) of the i-th region of a source bank (wraps)."""
    b = bank(key, **kw)
    s, e, _ = b[i % len(b)]
    return s, e - s


def L(key, ss=0.0, t=None, rate=1.0, gain=0.0, delay=0.0, af=None, loop=False):
    return {"key": key, "ss": float(ss), "t": t, "rate": float(rate), "gain": float(gain),
            "delay": float(delay), "af": af, "loop": loop}


def C(key, i, rate=1.0, gain=0.0, delay=0.0, af=None, maxt=None, **kw):
    """Layer taken from the i-th call of a source bank."""
    s, t = call(key, i, **kw)
    if maxt:
        t = min(t, maxt)
    return L(key, s, t, rate, gain, delay, af)


def _graph(layers, ch, length=None):
    args, chains = [], []
    layout = "mono" if ch == 1 else "stereo"
    for i, l in enumerate(layers):
        p = srcs.src(l["key"])["path"]
        if l["loop"]:
            args += ["-stream_loop", "-1"]
        if l["ss"] > 0:
            args += ["-ss", "%.3f" % l["ss"]]
        if l["t"]:
            args += ["-t", "%.3f" % (l["t"])]
        elif length:
            args += ["-t", "%.3f" % (length / l["rate"] + 1.0)]
        args += ["-i", p]
        f = ["aresample=%d" % SR, "aformat=sample_fmts=fltp:channel_layouts=%s" % layout]
        if abs(l["rate"] - 1.0) > 1e-4:
            f += ["asetrate=%d" % int(SR * l["rate"]), "aresample=%d" % SR]
        if l["af"]:
            f.append(l["af"])
        if l["gain"]:
            f.append("volume=%.2fdB" % l["gain"])
        if l["delay"] > 0:
            f.append("adelay=delays=%d:all=1" % int(l["delay"] * 1000))
        chains.append("[%d:a]%s[l%d]" % (i, ",".join(f), i))
    if len(layers) > 1:
        mix = "".join("[l%d]" % i for i in range(len(layers)))
        chains.append("%samix=inputs=%d:normalize=0:duration=longest:dropout_transition=0[m]" % (mix, len(layers)))
    else:
        chains.append("[l0]anull[m]")
    return args, chains


def _run(args):
    p = subprocess.run([FF, "-y", "-v", "error"] + args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if p.returncode != 0:
        raise RuntimeError("ffmpeg failed: %s\n%s" % (" ".join(args)[-600:], p.stderr[-1500:]))


def _finish(wav, out_path, lufs, ch, q, peak_db=-1.0):
    d = alib.probe(wav)[0]
    meas = alib.lufs(wav, loop_to=3.0 if d < 3.0 else None)
    gain = max(-30.0, min(40.0, lufs - meas))  # quiet field recordings need up to +40 dB
    fin = wav[:-4] + "_n.wav"
    lim = 10 ** (peak_db / 20.0)
    _run(["-i", wav, "-af", "volume=%.2fdB,alimiter=limit=%.4f:level=0:attack=2:release=60" % (gain, lim),
          "-ac", str(ch), "-ar", str(OUT_SR), "-c:a", "pcm_f32le", fin])
    final = alib.lufs(fin, loop_to=3.0 if d < 3.0 else None)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    oggenc.encode(fin, out_path, q)
    return final, alib.probe(fin)[0]


def _hash(obj):
    return hashlib.sha1(json.dumps(obj, sort_keys=True).encode()).hexdigest()[:16]


def render(out_path, layers, lufs, ch=1, post=None, max_len=None, fade=0.04, trim=True, q=0.35, cache=True):
    """One-shot: mix layers, post filters, trim leading silence, cap length, fade the tail, normalise."""
    recipe = {"layers": layers, "post": post, "max_len": max_len, "fade": fade, "trim": trim, "lufs": lufs, "ch": ch, "q": q, "v": 4}
    h = _hash(recipe)
    stamp = os.path.join(TMP, _hash(out_path) + ".json")
    if cache and os.path.exists(out_path) and os.path.exists(stamp):
        st = json.load(open(stamp))
        if st.get("hash") == h:
            return st["lufs"], st["dur"]
    args, chains = _graph(layers, ch)
    f = list(post or [])
    if trim:
        f.append("silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.004")
    if max_len:
        f.append("atrim=0:%.3f" % max_len)
    if fade:
        f += ["areverse", "afade=t=in:d=%.3f:curve=qsin" % fade, "areverse"]
    chains.append("[m]%s[o]" % (",".join(f) if f else "anull"))
    wav = os.path.join(TMP, _hash(out_path) + ".wav")
    _run(args + ["-filter_complex", ";".join(chains), "-map", "[o]", "-c:a", "pcm_f32le", wav])
    res = _finish(wav, out_path, lufs, ch, q)
    json.dump({"hash": h, "lufs": res[0], "dur": res[1]}, open(stamp, "w"))
    return res


def render_loop(out_path, layers, lufs, length, xfade=3.0, ch=2, post=None, q=0.15, cache=True):
    """Seamless loop of `length` s: the head is an equal-power crossfade with the tail past `length`."""
    recipe = {"layers": layers, "post": post, "len": length, "x": xfade, "lufs": lufs, "ch": ch, "q": q, "v": 4}
    h = _hash(recipe)
    stamp = os.path.join(TMP, _hash(out_path) + ".json")
    if cache and os.path.exists(out_path) and os.path.exists(stamp):
        st = json.load(open(stamp))
        if st.get("hash") == h:
            return st["lufs"], st["dur"]
    total = length + xfade
    args, chains = _graph(layers, ch, total)
    f = list(post or []) + ["atrim=0:%.3f" % total, "asetpts=PTS-STARTPTS"]
    chains.append("[m]%s,asplit=3[a][b][c]" % ",".join(f))
    chains.append("[a]atrim=0:%.3f,afade=t=in:d=%.3f:curve=qsin[h1]" % (xfade, xfade))
    chains.append("[b]atrim=%.3f:%.3f,asetpts=PTS-STARTPTS,afade=t=out:st=0:d=%.3f:curve=qsin[h2]" % (length, total, xfade))
    chains.append("[h1][h2]amix=inputs=2:normalize=0:duration=longest[h]")
    chains.append("[c]atrim=%.3f:%.3f,asetpts=PTS-STARTPTS[body]" % (xfade, length))
    chains.append("[h][body]concat=n=2:v=0:a=1[o]")
    wav = os.path.join(TMP, _hash(out_path) + ".wav")
    _run(args + ["-filter_complex", ";".join(chains), "-map", "[o]", "-c:a", "pcm_f32le", wav])
    res = _finish(wav, out_path, lufs, ch, q)
    json.dump({"hash": h, "lufs": res[0], "dur": res[1]}, open(stamp, "w"))
    return res
