"""Source-filter model of a creak: per 5 ms frame a resonance envelope (LPC) and the
stick-slip pulses found in the LPC residual, plus the residual's leftover noise level.
Resynthesis drives the same envelopes with clean impulses and noise, so every part of it
(pulse rate, resonances, loudness, length) can be changed."""
import numpy as np, librosa, scipy.signal as sg

SR, HOP, WIN, ORDER = 48000, 240, 1024, 36

def analyze(y):
    n = len(y); frames = n // HOP + 1
    win = np.hanning(WIN)
    pad = np.pad(y, (WIN // 2, WIN // 2))
    A = np.zeros((frames, ORDER + 1)); A[:, 0] = 1
    for i in range(frames):
        seg = pad[i * HOP:i * HOP + WIN] * win
        if np.sqrt(np.mean(seg ** 2)) > 1e-5:
            a = librosa.lpc(seg + 1e-9 * np.random.default_rng(i).normal(size=WIN), order=ORDER)
            if np.all(np.abs(np.roots(a)) < 0.999): A[i] = a
    # residual, frame by frame with the filter state carried over
    e = np.zeros(n); zi = np.zeros(ORDER)
    for i in range(frames):
        s, t = i * HOP, min(n, (i + 1) * HOP)
        if s >= n: break
        e[s:t], zi = sg.lfilter(A[i], [1], y[s:t], zi=zi)
    # pulses: residual peaks well above the local level, at least 0.6 ms apart
    level = np.sqrt(np.maximum(sg.convolve(e ** 2, np.ones(480) / 480, "same"), 0)) + 1e-9
    peaks, _ = sg.find_peaks(np.abs(e), height=3.0 * level, distance=29)
    amps = e[peaks]
    # the pulses' common shape in the residual, a millisecond around each, sign aligned
    k = 24
    good = peaks[(peaks > k) & (peaks < n - k)]
    shape = np.mean([e[p - k:p + k] * np.sign(e[p]) / abs(e[p]) for p in good], axis=0) if len(good) else np.eye(1, 2 * k, k)[0]
    # leftover noise: residual without the pulses, as an rms per frame
    rest = e.copy()
    for p in peaks: rest[max(0, p - 3):p + 4] = 0
    noise = np.array([np.sqrt(np.mean(rest[i * HOP:(i + 1) * HOP] ** 2)) if i * HOP < n else 0 for i in range(frames)])
    rms = librosa.feature.rms(y=y, frame_length=2 * HOP, hop_length=HOP)[0][:frames]
    return dict(A=A, pulses=peaks, amps=amps, noise=noise, n=n, rms=rms, shape=shape)

def synth(m, rng=None, noise_gain=1.0, pulse_gain=1.0, shaped=True):
    rng = rng or np.random.default_rng(1)
    n = m["n"]; x = np.zeros(n)
    x[m["pulses"]] = m["amps"] * pulse_gain
    if shaped:
        x = np.convolve(x, m["shape"], 'same')
    f = np.repeat(m["noise"], HOP)[:n] * noise_gain
    x += rng.normal(size=n) * f
    # overlap-add: each frame's excitation, Hann-windowed over two hops, rings through that
    # frame's own resonances from rest, so changing filters never blow up
    out = np.zeros(n + 4096); w = np.hanning(2 * HOP + 1)[:-1]
    for i in range(len(m["A"])):
        s = i * HOP - HOP
        seg = np.zeros(2 * HOP)
        lo, hi = max(0, s), min(n, s + 2 * HOP)
        if hi <= lo: continue
        seg[lo - s:hi - s] = x[lo:hi]
        if not seg.any(): continue
        r = sg.lfilter([1], m["A"][i], np.concatenate([seg * w, np.zeros(4096 - 2 * HOP)]))
        out[max(0, s):max(0, s) + 4096 - (lo - s)] += r[lo - s:]
    out = out[:n]
    # loudness: frame by frame back to the recording's, the pulses' own ringing aside
    have = librosa.feature.rms(y=out, frame_length=2 * HOP, hop_length=HOP)[0][:len(m["rms"])]
    g = m["rms"] / (have + 1e-9)
    g = np.convolve(g, np.ones(3) / 3, 'same')
    return out * np.interp(np.arange(n), np.arange(len(g)) * HOP, g)

def compare(a, b):
    """How alike two sounds are to the ear: log-mel spectrogram correlation and the mean
    difference in dB, plus how alike their loudness over time is."""
    k = dict(sr=SR, n_fft=2048, hop_length=HOP, n_mels=64)
    A = librosa.power_to_db(librosa.feature.melspectrogram(y=a, **k), ref=1.0, top_db=None)
    B = librosa.power_to_db(librosa.feature.melspectrogram(y=b, **k), ref=1.0, top_db=None)
    loud = A.max(axis=0) > A.max() - 50
    corr = np.corrcoef(A[:, loud].ravel(), B[:, loud].ravel())[0, 1]
    diff = np.abs(A[:, loud] - B[:, loud]).mean()
    ra, rb = librosa.feature.rms(y=a, hop_length=HOP)[0], librosa.feature.rms(y=b, hop_length=HOP)[0]
    return corr, diff, np.corrcoef(ra, rb)[0, 1]
