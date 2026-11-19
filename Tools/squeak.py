"""A squeaky hinge as a Lid Sound pack, sung like "IIIIIIiiiiiiiuuuuu": a high, bright
squeal while the lid moves that sinks and darkens to an "u" as it stops. Made from nothing
but numbers.

The hinge sticks and slips a thousand-odd times a second: a tone with every harmonic of that
rate up to 12 kHz. Its colour is a vowel: "i" lifts the harmonics round 2.6 and 3.3 kHz,
"u" round 0.8 kHz. On top, the hinge grabs about 40 times a second, a light roughness.

Start: the hinge breaking loose, a few slow clicks speeding up into the bright "I". Middle: the "i" held, its
pitch wandering a little along a curve that comes back to where it began, a whole number of
cycles of everything round the loop, so it has no seam. End: from where the middle begins,
the pitch falls and the vowel slides to "u" as it fades.

Knobs: --pitch (Hz of the held squeal), --fall (how far the end sinks, as a fraction),
--rough (grab depth), --wander (pitch wander, as a fraction), --start/--middle/--end
(lengths in seconds), --seed."""
import argparse, wave, numpy as np

p = argparse.ArgumentParser()
p.add_argument("pack")
p.add_argument("--pitch", type=float, default=1150)
p.add_argument("--fall", type=float, default=0.38)
p.add_argument("--rough", type=float, default=0.25)
p.add_argument("--wander", type=float, default=0.03)
p.add_argument("--start", type=float, default=0.45)
p.add_argument("--middle", type=float, default=2.0)
p.add_argument("--end", type=float, default=0.8)
p.add_argument("--seed", type=int, default=3)
p.add_argument("--catch", type=float, default=14, help="clicks a second as the start begins")
a = p.parse_args()
SR, TOP = 48000, 12000
rng = np.random.default_rng(a.seed)

ns, nm, ne = (int(v * SR) for v in (a.start, a.middle, a.end))
def curve(n, terms, seed):
    r = np.random.default_rng(seed); t = np.arange(n) / n; v = np.zeros(n)
    for k in range(1, terms + 1):
        c, s = r.normal(size=2) / k
        v += c * np.cos(2 * np.pi * k * t) + s * np.sin(2 * np.pi * k * t)
    return v / (np.abs(v).max() + 1e-12)
ease = lambda u: u * u * (3 - 2 * u)

# --- the middle: held "i", pitch wandering round the loop
f_mid = a.pitch * np.exp(a.wander * curve(nm, 4, a.seed))
f_mid *= np.round(f_mid.sum() / SR) / (f_mid.sum() / SR)        # whole cycles
v_mid = np.zeros(nm)                                            # vowel: 0 = "i", 1 = "u"
amp_mid = 1 + 0.08 * curve(nm, 3, a.seed + 1)
f0 = f_mid[0]
# --- the start: the hinge breaking loose, a few slow clicks speeding up into the squeal
# ("k-k-k-kIII"): the stick-slip rate climbs from a few a second to the pitch
u = np.arange(ns) / ns
f_start = np.exp(np.log(a.catch) + (np.log(f0) - np.log(a.catch)) * u ** 1.6)
v_start = np.zeros(ns)
amp_start = amp_mid[0] * (0.55 + 0.45 * ease(u))
# --- the end: from the middle's beginning, falling and darkening to "u", fading
u = np.arange(ne) / ne
f_end = f0 * (1 - a.fall * ease(u))
v_end = ease(np.minimum(1, u / 0.7))
amp_end = amp_mid[0] * (1 - ease(np.maximum(0, (u - 0.35) / 0.65)))

f = np.concatenate([f_start, f_mid, f_end])
vowel = np.concatenate([v_start, v_mid, v_end])
amp = np.concatenate([amp_start, amp_mid, amp_end])
# half a cycle in: the first click comes a moment after the start, not cut in half at it
phase = 2 * np.pi * np.cumsum(f) / SR + np.pi

# the hinge's grabs: ~40 a second, each a little different, whole cycles round the middle
g_rate = np.full(len(f), 40.0)
g_mid = g_rate[ns:ns + nm]; g_rate[ns:ns + nm] *= np.round(g_mid.sum() / SR) / (g_mid.sum() / SR)
grab = np.cumsum(g_rate) / SR
grab -= grab[ns]                                                # whole grabs from the middle's start
cycles = int(round(g_rate[ns:ns + nm].sum() / SR))
strength = np.exp(0.4 * rng.normal(size=cycles))
idx = np.floor(grab + 0.5).astype(int) % cycles
spike = (0.5 + 0.5 * np.cos(2 * np.pi * grab)) ** 4
spike = (spike - spike.mean()) / spike.std()
# the start's slow clicks are the grabs themselves; the roughness comes in as they turn
# into the squeal
depth = np.ones(len(f)); depth[:ns] = ease(np.arange(ns) / ns)
rough = np.maximum(0, 1 + a.rough * depth * spike * strength[idx] / strength.mean())

# the vowel as a colour on the harmonics: peaks in log frequency
def colour(freq, vw):
    i_peaks = [(320, 0.6, 0.5), (2600, 1.0, 0.18), (3300, 0.7, 0.15)]
    u_peaks = [(320, 0.8, 0.5), (800, 1.0, 0.25), (2300, 0.25, 0.2)]
    gain = np.full_like(freq, 0.06)
    for (fi, gi, wi), (fu, gu, wu) in zip(i_peaks, u_peaks):
        fc = np.exp((1 - vw) * np.log(fi) + vw * np.log(fu))
        g_ = (1 - vw) * gi + vw * gu; w_ = (1 - vw) * wi + vw * wu
        gain += g_ * np.exp(-0.5 * (np.log(freq / fc) / w_) ** 2)
    return gain

out = np.zeros(len(f))
# every harmonic of the stick-slip rate up to the top, a stretch at a time (the slow clicks
# at the start need hundreds of them, the squeal a dozen)
for lo in range(0, len(f), 4800):
    sl = slice(lo, lo + 4800)
    for h in range(1, int(TOP / (f[sl].min() * 0.95)) + 1):
        hf = h * f[sl]
        fade = np.clip((TOP - hf) / 1500, 0, 1)                 # harmonics leave softly at the top
        if not fade.any(): continue
        out[sl] += fade * colour(hf, vowel[sl]) / h ** 0.7 * np.sin(h * phase[sl])
out *= amp * rough
out += rng.normal(size=len(out)) * 0.004 * amp                  # a breath of hiss

out[:240] *= np.linspace(0, 1, 240)                            # 5 ms in from silence
start, middle, end = out[:ns], out[ns:ns + nm], out[ns + nm:]
peak = np.abs(out).max()
for name, v in (("start", start), ("middle", middle), ("end", end)):
    v = 0.89 * v / peak
    w = wave.open(f"{a.pack}/{name}.wav", "wb"); w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((v * 32767).astype(np.int16).tobytes()); w.close()

m = 0.89 * middle / peak; s = 0.89 * start / peak; e = 0.89 * end / peak; st = np.abs(np.diff(m))
print(f"pitch: start {f_start[0]:.0f}→{f0:.0f} Hz, middle {f_mid.min():.0f}–{f_mid.max():.0f} Hz, end {f0:.0f}→{f_end[-1]:.0f} Hz")
print(f"seam jump {abs(m[-1]-m[0]):.3f}, start→middle {abs(s[-1]-m[0]):.3f}, middle→end {abs(m[-1]-e[0]):.3f}; "
      f"typical step {st.mean():.3f}, 99th pct {np.percentile(st, 99):.3f}")
def bright(v):
    S = np.abs(np.fft.rfft(v * np.hanning(len(v)))); F = np.fft.rfftfreq(len(v), 1 / SR)
    return (S * F).sum() / S.sum()
print(f"brightness (spectral centre): middle {bright(m):.0f} Hz, end's last half {bright(e[len(e)//2:]):.0f} Hz")
