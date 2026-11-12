"""Builds a Lid Sound pack from the model of a recorded creak: the recording's attack as the
start, its steady creak as a seamless middle loop, its dying away as the end. Knobs:
  --rate   stick-slip pulses closer together (>1) or further apart (<1); the creak's 'trrr'
  --bright resonances moved up (>1) or down (<1)
  --rough  how much of the noise between pulses (1 = as recorded)"""
import sys, argparse, wave, numpy as np, librosa
sys.path.insert(0, sys.argv[0].rsplit('/', 1)[0])
from model import *

p = argparse.ArgumentParser()
p.add_argument("recording"); p.add_argument("pack")
p.add_argument("--rate", type=float, default=1.0)
p.add_argument("--bright", type=float, default=1.0)
p.add_argument("--rough", type=float, default=1.0)
p.add_argument("--cuts", default="0.03,0.40,1.00,1.30", help="start, middle from, middle to, end, in seconds")
a = p.parse_args()

y, _ = librosa.load(a.recording, sr=SR, mono=True)
m = analyze(y)
if a.rate != 1.0:
    # pulses respaced around their own times; the envelopes stay where they are
    t = m["pulses"].astype(float)
    order = np.argsort(t); t = t[order]
    gaps = np.diff(t, prepend=t[0]) / a.rate
    m["pulses"] = np.clip(np.round(t[0] + np.cumsum(gaps) - gaps[0]), 0, m["n"] - 1).astype(int)
    m["amps"] = m["amps"][order]
if a.bright != 1.0:
    # move every resonance (pole angle) by the factor, keeping its sharpness
    for i, row in enumerate(m["A"]):
        r = np.roots(row)
        if len(r) == 0: continue
        r = np.abs(r) * np.exp(1j * np.clip(np.angle(r) * a.bright, -np.pi * 0.98, np.pi * 0.98))
        m["A"][i] = np.real(np.poly(r))
out = synth(m, noise_gain=a.rough, shaped=False)
print("fidelity to the recording: mel corr %.3f, mean diff %.1f dB, loudness corr %.3f" % compare(y, out))

s0, s1, s2, s3 = (int(float(v) * SR) for v in a.cuts.split(","))
start, middle, end = out[s0:s1].copy(), out[s1:s2].copy(), out[s2:s3].copy()
# the middle loops: its last 60 ms cross into what came just before it, so its end runs
# straight into its own beginning, the same way the start runs into it
X = int(0.06 * SR); w = np.sin(np.linspace(0, np.pi / 2, X)) ** 2
middle[-X:] = middle[-X:] * (1 - w) + out[s1 - X:s1] * w
start[:int(0.01 * SR)] *= np.linspace(0, 1, int(0.01 * SR))
end[-int(0.05 * SR):] *= np.linspace(1, 0, int(0.05 * SR))
peak = max(np.abs(x).max() for x in (start, middle, end))
for name, x in (("start", start), ("middle", middle), ("end", end)):
    x = 0.89 * x / peak
    f = wave.open(f"{a.pack}/{name}.wav", "wb"); f.setnchannels(1); f.setsampwidth(2); f.setframerate(SR)
    f.writeframes((x * 32767).astype(np.int16).tobytes()); f.close()
mm = 0.89 * middle / peak; ss = 0.89 * start / peak
step = np.abs(np.diff(mm))
print("loop seam jump %.3f, start→middle %.3f, typical step %.3f, 99th pct %.3f" %
      (abs(mm[-1] - mm[0]), abs(ss[-1] - mm[0]), step.mean(), np.percentile(step, 99)))
