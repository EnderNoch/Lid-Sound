"""Lid Sound pack recreated from the squeal in a recording: nothing of the recording is
played, only what was measured in it.

The squeal is a handful of steady whistling tones (in the door recorded here about 1.1, 1.7,
2.1 and 2.7 kHz, each standing 10 to 20 dB above the hiss around it) over a hiss with the
door's colour. Measured: each tone's pitch and loudness every 5 ms, and the colour of the
hiss. Recreated: new tones with those pitches and loudnesses, and new hiss through that
colour.

What makes it a squeal and not a whistle is the hinge grabbing and letting go: every tone's
loudness flutters with it, about 40 times a second in this door, deep and spiky, each grab a
little different. Measured per tone and recreated with one shared rhythm.

The middle is built on a circle. Every tone's pitch and loudness wander within what was
measured along curves that come back to where they began, and every tone fits a whole
number of cycles into the loop; the hiss is shaped on the whole loop at once. So the loop has
no seam. The start is the loop's last stretch fading in, the end its first stretch fading out.

Knobs: --pitch (all tones higher > 1), --tones (how many), --lowest (no tones below, Hz),
--hiss (hiss under the tones; 1 = as loud as in the recording, the default 0.1 leaves the
whistle almost bare), --wander (how much pitch and loudness move, 1 = as measured), --length, --seed,
--from/--to (the stretch of the recording), --rough-depth / --rough-rate (the flutter),
--spike (how sharp each grab), --uneven (how much the grabs differ)."""
import argparse, wave, numpy as np, librosa, scipy.signal as sg

p = argparse.ArgumentParser()
p.add_argument("recording"); p.add_argument("pack")
p.add_argument("--from", dest="a", type=float, default=0.30)
p.add_argument("--to", dest="b", type=float, default=0.80)
p.add_argument("--length", type=float, default=3.0)
p.add_argument("--pitch", type=float, default=1.0)
p.add_argument("--tones", type=int, default=12)
p.add_argument("--lowest", type=float, default=1000, help="tones below this (Hz) are left out")
p.add_argument("--hiss", type=float, default=0.1, help="hiss under the tones, 1 = as recorded")
p.add_argument("--wander", type=float, default=1.0)
p.add_argument("--start", type=float, default=0.25)
p.add_argument("--end", type=float, default=0.45)
p.add_argument("--seed", type=int, default=5)
p.add_argument("--rough-depth", dest="rough_depth", type=float, default=1.0, help="flutter depth, 1 = as recorded")
p.add_argument("--rough-rate", dest="rate_rough", type=float, default=1.0, help="flutter speed, 1 = as recorded")
p.add_argument("--spike", type=float, default=6.0, help="how sharp each grab is")
p.add_argument("--uneven", type=float, default=0.5, help="how much the grabs differ in strength")
a = p.parse_args()
SR, NFFT, HOP = 48000, 4096, 240
rng = np.random.default_rng(a.seed)

y, _ = librosa.load(a.recording, sr=SR, mono=True)
src = y[int(a.a * SR):int(a.b * SR)]
n = len(src)

# --- measure: the spectrum every 5 ms, and in it the peaks standing out of the hiss
X = librosa.stft(src, n_fft=NFFT, hop_length=HOP, window="hann", center=True)
mag = np.abs(X); freqs = librosa.fft_frequencies(sr=SR, n_fft=NFFT)
db = 20 * np.log10(mag + 1e-12)
floor = np.array([sg.medfilt(db[:, i], 151) for i in range(db.shape[1])]).T
# the tones: frequencies where peaks stand out again and again
hist = np.zeros(len(freqs))
for i in range(db.shape[1]):
    pk, pr = sg.find_peaks(db[:, i] - floor[:, i], prominence=8, distance=10)
    hist[pk] += (db[pk, i] - floor[pk, i])
hist = np.convolve(hist, np.ones(9), "same")
centers, _ = sg.find_peaks(hist, distance=int(60 / (SR / NFFT)))
centers = centers[freqs[centers] > a.lowest]            # the squeal, not the door's thump
centers = centers[np.argsort(hist[centers])[::-1][:a.tones]]
tracks = []
for c in sorted(centers):
    lo, hi = int(c * 0.97), int(c * 1.03) + 1
    f_t, a_t = [], []
    for i in range(mag.shape[1]):
        k = lo + np.argmax(mag[lo:hi, i])
        # parabolic interpolation for the exact frequency
        if 0 < k < len(freqs) - 1:
            l, m_, r = db[k - 1, i], db[k, i], db[k + 1, i]
            d = 0.5 * (l - r) / (l - 2 * m_ + r + 1e-12)
        else: d = 0
        f_t.append((k + d) * SR / NFFT); a_t.append(mag[k, i])
    f_t, a_t = np.array(f_t), np.array(a_t)
    stand = np.median(db[c, :] - floor[c, :])
    tracks.append(dict(f=np.median(f_t), fsd=np.std(np.log(f_t)), a=np.median(a_t),
                       asd=np.std(np.log(a_t + 1e-12)), stand=stand))
# two windows can land on the same tone; keep each tone once, the louder find
kept = []
for tr in sorted(tracks, key=lambda t: -t["a"]):
    if all(abs(np.log(tr["f"] / k["f"])) > 0.03 for k in kept): kept.append(tr)
tracks = sorted(kept, key=lambda t: t["f"])
for t in tracks:
    print(f"tone {t['f']:6.0f} Hz, wobble ±{t['fsd']*100:.1f}%, loudness ±{t['asd']*8.7:.1f} dB, stands {t['stand']:+.0f} dB above the hiss")
# the squeal's roughness: each tone's loudness flutters as the hinge grabs and lets go,
# measured in a narrow band round the tone: how deep, how spiky, and how fast
flutter_rates = []
for tr in tracks:
    band = sg.sosfiltfilt(sg.butter(4, [tr["f"] * 0.96, tr["f"] * 1.04], "bp", fs=SR, output="sos"), src)
    env = sg.decimate(np.abs(sg.hilbert(band)), 24); fs_env = SR / 24
    tr["depth"] = np.std(env) / np.mean(env)
    tr["spike"] = env.max() / env.mean()
    seg = (env - env.mean()) * np.hanning(len(env))
    ff, PP = sg.periodogram(seg, fs=fs_env, nfft=16384); kk = (ff >= 30) & (ff <= 500)
    flutter_rates.append(ff[kk][np.argmax(PP[kk])])
# the loudest tones carry the squeal; their flutter is the hinge's rhythm
loudest = np.argsort([-t["a"] for t in tracks])[:4]
flutter = np.median(np.array(flutter_rates)[loudest])
print(f"flutter: {flutter:.0f} times a second; depth " + ", ".join(f"{t['f']:.0f} Hz {t['depth']:.2f}" for t in tracks))

# the hiss: the spectrum with the tones taken out, its average colour
hiss_db = floor.mean(axis=1)

# --- recreate on a circle
T = int(a.length * SR); t = np.arange(T) / T
def curve(terms, seed):
    r = np.random.default_rng(seed); v = np.zeros(T)
    for k in range(1, terms + 1):
        c, s = r.normal(size=2) / k
        v += c * np.cos(2 * np.pi * k * t) + s * np.sin(2 * np.pi * k * t)
    return v / (np.std(v) + 1e-12)
# STFT magnitudes are window sums; turn them into sine amplitudes
win_sum = np.hanning(NFFT).sum() / 2
# one grab-and-let-go rhythm for all tones, as one hinge makes them: pulses at the measured
# rate, drifting a little along a curve that comes back to where it began, whole cycles round
# the loop; each pulse a sharp swell, each tone fluttering as deep as it did
fl = flutter * a.rate_rough * np.exp(0.08 * curve(3, a.seed + 7))
fl *= np.round(fl.sum() / SR) / (fl.sum() / SR)
grab = np.cumsum(fl) / SR
pulse = (0.5 + 0.5 * np.cos(2 * np.pi * grab)) ** a.spike
# no two grabs alike: each one stronger or weaker at random, as the recording's are
grabs = int(round(grab[-1]))
strength = np.exp(a.uneven * rng.normal(size=grabs))
pulse = pulse * strength[np.floor(grab + 0.5).astype(int) % grabs]
pulse = (pulse - pulse.mean()) / pulse.std()
tones = np.zeros(T)
for j, tr in enumerate(tracks):
    f = tr["f"] * a.pitch * np.exp(a.wander * tr["fsd"] * 0.5 * curve(4, a.seed * 100 + j))
    cycles = f.sum() / SR
    f *= np.round(cycles) / cycles                       # whole cycles round the loop
    amp = tr["a"] / win_sum * np.exp(a.wander * tr["asd"] * 0.5 * curve(5, a.seed * 100 + 50 + j))
    phase = 2 * np.pi * np.cumsum(f) / SR + rng.uniform(0, 2 * np.pi)
    am = np.maximum(0, 1 + a.rough_depth * tr["depth"] * pulse)
    tones += amp * am * np.sin(phase)
# hiss: white noise coloured on the whole loop at once (circular, so no seam)
H = np.fft.rfft(rng.normal(size=T))
fH = np.fft.rfftfreq(T, 1 / SR)
colour = 10 ** (np.interp(fH, freqs * a.pitch, hiss_db) / 20)
noise = np.fft.irfft(H * colour, n=T)
noise /= np.std(noise) + 1e-12
def avg_db(v):
    M = np.abs(librosa.stft(v, n_fft=NFFT, hop_length=HOP)); return 20 * np.log10(M.mean(axis=1) + 1e-12)
A1 = avg_db(src); band = (freqs > 300) & (freqs < 12000)
# how loud the hiss is against the tones: whatever makes the average spectrum closest to the
# recording's, so the tones stand out of it as much as they did there
best = None
for level in np.geomspace(0.002, 0.5, 40):
    c = np.corrcoef(A1[band], avg_db((tones + level * noise)[:max(n, NFFT)])[band])[0, 1]
    if best is None or c > best[0]: best = (c, level)
loop = tones + a.hiss * best[1] * noise

# --- pack
fade_in = np.sin(np.linspace(0, np.pi / 2, int(a.start * SR))) ** 2
fade_out = np.cos(np.linspace(0, np.pi / 2, int(a.end * SR))) ** 2
start = loop[T - len(fade_in):] * fade_in
end = loop[:len(fade_out)] * fade_out
peak = max(np.abs(v).max() for v in (start, loop, end))
for name, v in (("start", start), ("middle", loop), ("end", end)):
    v = 0.89 * v / peak
    f_ = wave.open(f"{a.pack}/{name}.wav", "wb"); f_.setnchannels(1); f_.setsampwidth(2); f_.setframerate(SR)
    f_.writeframes((v * 32767).astype(np.int16).tobytes()); f_.close()

# --- check
m = 0.89 * loop / peak; s = 0.89 * start / peak; step = np.abs(np.diff(m))
print(f"seam jump {abs(m[-1]-m[0]):.3f}, start→middle {abs(s[-1]-m[0]):.3f}, typical step {step.mean():.3f}, 99th pct {np.percentile(step, 99):.3f}")
A2 = avg_db(loop[:max(n, NFFT)])
print(f"average spectrum vs the recorded squeal (0.3–12 kHz): corr {np.corrcoef(A1[band], A2[band])[0,1]:.3f}")
# whistle check: how far each measured tone stands out of its surroundings, both sounds
for tr in tracks:
    k = int(round(tr["f"] * a.pitch * NFFT / SR))
    def stand(A): return A[k - 2:k + 3].max() - np.median(A[max(0, k - 80):k + 80])
    print(f"  tone {tr['f']*a.pitch:6.0f} Hz stands out: recording {stand(A1):+.0f} dB, recreation {stand(A2):+.0f} dB")

for tr in tracks:
    def band_env(v):
        b_ = sg.sosfiltfilt(sg.butter(4, [tr["f"] * a.pitch * 0.96, tr["f"] * a.pitch * 1.04], "bp", fs=SR, output="sos"), v)
        e_ = sg.decimate(np.abs(sg.hilbert(b_)), 24); return np.std(e_) / np.mean(e_), e_.max() / e_.mean()
    d1, s1 = band_env(src); d2, s2 = band_env(loop[:n])
    print(f"  {tr['f']*a.pitch:6.0f} Hz flutter depth: recording {d1:.2f}, recreation {d2:.2f}; spikiness {s1:.1f} vs {s2:.1f}")
