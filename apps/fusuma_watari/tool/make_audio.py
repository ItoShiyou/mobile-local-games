"""Synthesises every sound in assets/audio (no third-party samples).

    python3 tool/make_audio.py
"""
import math, random, struct, wave, os

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')
random.seed(7)


def buf(sec):
    return [0.0] * int(SR * sec)


def add_tone(b, t0, freq, dur, amp, attack=0.004, decay=None, harm=((1, 1.0),), sweep=None, wrap=False):
    n0 = int(t0 * SR)
    n = int(dur * SR)
    decay = decay or dur / 4
    ph = [0.0] * len(harm)
    for i in range(n):
        t = i / SR
        f = freq if sweep is None else freq + (sweep - freq) * (i / n)
        env = min(1.0, t / attack) * math.exp(-t / decay)
        env *= min(1.0, (n - i) / (SR * 0.004))  # click-free tail
        s = 0.0
        for k, (mul, a) in enumerate(harm):
            ph[k] += 2 * math.pi * f * mul / SR
            s += a * math.sin(ph[k])
        j = n0 + i
        if wrap:
            j %= len(b)
        elif j >= len(b):
            break
        b[j] += amp * env * s


def add_noise(b, t0, dur, amp, decay, lp=0.3):
    n0 = int(t0 * SR)
    y = 0.0
    for i in range(int(dur * SR)):
        t = i / SR
        y += lp * (random.uniform(-1, 1) - y)
        if n0 + i < len(b):
            b[n0 + i] += amp * y * math.exp(-t / decay) * min(1.0, (int(dur * SR) - i) / (SR * .004))


def lowpass(b, cutoff, passes=2):
    """Gentle one-pole low-pass: rounds off the bright edges that tire the ear."""
    a = 1 - math.exp(-2 * math.pi * cutoff / SR)
    for _ in range(passes):
        y = 0.0
        for i, x in enumerate(b):
            y += a * (x - y)
            b[i] = y
    return b


def save(name, b, gain=0.9, cutoff=2600):
    lowpass(b, cutoff)
    peak = max(1e-9, max(abs(x) for x in b))
    k = gain / peak
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, x * k)) * 32000)) for x in b))


# Warm timbres only: a wooden marimba-ish tone and a felt-piano-ish tone.
# No inharmonic bell partials, which are what made the old sounds shrill.
WOOD = ((1, 1.0), (4, 0.06))
FELT = ((1, 1.0), (2, 0.18), (3, 0.04))
PURE = ((1, 1.0),)

def note(m):
    return 440.0 * 2 ** ((m - 69) / 12)

# --- effects -----------------------------------------------------------------
# Peaks stay low (0.12-0.35) so frequent sounds sit well under the music.
b = buf(.08); add_tone(b, 0, 150, .07, .6, attack=.006, decay=.018, harm=PURE); add_noise(b, 0, .05, .12, .01, .12); save('step', b, .12, 900)
# a fusuma sliding: a soft paper-and-wood swish ending in a light knock
b = buf(.26); add_noise(b, 0, .22, .35, .12, .04); add_tone(b, .18, 170, .07, .5, attack=.004, decay=.02, harm=PURE); save('slide', b, .22, 1200)
b = buf(.7); add_tone(b, 0, note(72), .6, .5, attack=.008, decay=.18, harm=FELT); add_tone(b, .1, note(76), .6, .5, attack=.008, decay=.22, harm=FELT); save('serve', b, .32, 2200)
# a revolving shoji: a longer swish with a low creak rising
b = buf(.36); add_noise(b, 0, .32, .3, .16, .035); add_tone(b, .02, 120, .3, .25, attack=.03, decay=.12, harm=WOOD, sweep=160); save('swing', b, .22, 1000)
# picking up the key: two small, soft bell notes
b = buf(.4); add_tone(b, 0, note(79), .3, .4, attack=.006, decay=.09, harm=FELT); add_tone(b, .08, note(84), .3, .35, attack=.006, decay=.1, harm=FELT); save('key', b, .2, 2400)
b = buf(.14); add_tone(b, 0, 110, .13, .8, attack=.008, decay=.04, harm=PURE); save('bump', b, .3, 700)
b = buf(1.8)
for k, m in enumerate([60, 64, 67, 72]):
    add_tone(b, k * .13, note(m), 1.3, .45, attack=.01, decay=.4, harm=FELT)
add_tone(b, .52, note(76), 1.2, .3, attack=.012, decay=.45, harm=FELT); add_tone(b, .52, note(48), 1.2, .3, attack=.02, decay=.55, harm=PURE)
save('clear', b, .35, 2200)
b = buf(.12); add_tone(b, 0, note(69), .1, .5, attack=.006, decay=.03, harm=WOOD, sweep=note(64)); save('undo', b, .18, 1600)
b = buf(.06); add_tone(b, 0, note(74), .05, .5, attack=.004, decay=.014, harm=WOOD); save('tap', b, .14, 1800)

# --- background music: a slow music-box loop (seamless) -----------------------
BPM = 70
beat = 60 / BPM
bars = 8
total = bars * 4 * beat
b = buf(total)
# an evening at the inn: F major pentatonic, IV - I - vi - V
chords = [[46, 53, 62], [41, 48, 57], [38, 45, 53], [36, 43, 52]] * 2
melody = [
    [(0, 72, 1.5), (1.5, 69, .5), (2, 67, 2)],
    [(0, 65, 1), (1, 67, 1), (2, 69, 2)],
    [(0, 72, 1), (1, 74, 1), (2, 72, 1.5), (3.5, 69, .5)],
    [(0, 67, 3), (3, 65, 1)],
    [(0, 69, 1.5), (1.5, 72, .5), (2, 74, 2)],
    [(0, 72, 1), (1, 69, 1), (2, 67, 2)],
    [(0, 65, 1), (1, 67, 1), (2, 69, 1), (3, 67, 1)],
    [(0, 65, 3.5)],
]
for bar in range(bars):
    t0 = bar * 4 * beat
    for m in chords[bar]:
        add_tone(b, t0, note(m), 4 * beat, .06, attack=.35, decay=3.0, harm=PURE, wrap=True)
    for k in range(4):  # soft arpeggio
        m = chords[bar][k % 3] + 12
        add_tone(b, t0 + k * beat + beat / 2, note(m - 12), 1.2, .045, attack=.02, decay=.35, harm=FELT, wrap=True)
    for (at, m, d) in melody[bar]:
        add_tone(b, t0 + at * beat, note(m - 12), max(1.4, d * beat + .8), .16, attack=.015, decay=.45 + d * .15, harm=FELT, wrap=True)
save('bgm', b, .5, 1500)
print('ok')
