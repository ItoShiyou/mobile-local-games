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


def save(name, b, gain=0.9):
    peak = max(1e-9, max(abs(x) for x in b))
    k = gain / peak if peak > gain else 1.0
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, x * k)) * 32000)) for x in b))


BELL = ((1, 1.0), (2, 0.35), (3.01, 0.12), (4.2, 0.05))
SOFT = ((1, 1.0), (2, 0.15))

def note(m):
    return 440.0 * 2 ** ((m - 69) / 12)

# --- effects ---------------------------------------------------------------
b = buf(.07); add_noise(b, 0, .06, .35, .012, .25); add_tone(b, 0, 180, .06, .25, decay=.015); save('step', b, .45)
b = buf(.16); add_tone(b, 0, 620, .14, .6, decay=.05, harm=SOFT, sweep=980); save('pickup', b, .7)
b = buf(.6); add_tone(b, 0, note(84), .5, .5, decay=.15, harm=BELL); add_tone(b, .09, note(88), .5, .5, decay=.18, harm=BELL); save('serve', b, .75)
b = buf(.22); add_tone(b, 0, 420, .2, .6, decay=.06, harm=SOFT, sweep=190); add_noise(b, .02, .1, .2, .03); save('drop', b, .7)
b = buf(.3); add_noise(b, 0, .26, .5, .12, .08); add_tone(b, .02, 500, .24, .3, decay=.1, harm=SOFT, sweep=900); add_tone(b, .12, 900, .14, .25, decay=.06, harm=SOFT, sweep=520); save('flip', b, .6)
b = buf(.12); add_tone(b, 0, 120, .11, .8, decay=.035, harm=((1, 1), (2, .3))); add_noise(b, 0, .05, .2, .015, .15); save('bump', b, .6)
b = buf(1.6)
for k, m in enumerate([72, 76, 79, 84]):
    add_tone(b, k * .11, note(m), 1.2, .45, decay=.35, harm=BELL)
add_tone(b, .44, note(88), 1.1, .35, decay=.4, harm=BELL); add_tone(b, .44, note(60), 1.1, .25, decay=.5, harm=SOFT)
save('clear', b, .8)
b = buf(.1); add_tone(b, 0, 760, .08, .5, decay=.03, harm=SOFT, sweep=520); save('undo', b, .5)
b = buf(.04); add_tone(b, 0, 1250, .03, .5, decay=.008); save('tap', b, .35)

# --- background music: a slow music-box loop (seamless) -----------------------
BPM = 76
beat = 60 / BPM
bars = 8
total = bars * 4 * beat
b = buf(total)
# I - vi - IV - V  (C major, pentatonic melody)
chords = [[48, 55, 64], [45, 52, 60], [41, 48, 57], [43, 50, 59]] * 2
melody = [
    [(0, 76, 1), (1, 79, 1), (2, 81, 1.5), (3.5, 79, .5)],
    [(0, 76, 2), (2, 72, 1), (3, 74, 1)],
    [(0, 72, 1), (1, 69, 1), (2, 72, 1.5), (3.5, 74, .5)],
    [(0, 74, 3), (3, 67, 1)],
    [(0, 76, 1), (1, 79, 1), (2, 84, 1.5), (3.5, 81, .5)],
    [(0, 79, 2), (2, 76, 1), (3, 72, 1)],
    [(0, 74, 1), (1, 76, 1), (2, 72, 1), (3, 69, 1)],
    [(0, 72, 3.5)],
]
for bar in range(bars):
    t0 = bar * 4 * beat
    for m in chords[bar]:
        add_tone(b, t0, note(m), 4 * beat, .07, attack=.35, decay=3.0, harm=SOFT, wrap=True)
    for k in range(4):  # soft arpeggio
        m = chords[bar][k % 3] + 12
        add_tone(b, t0 + k * beat + beat / 2, note(m), 1.2, .05, decay=.35, harm=BELL, wrap=True)
    for (at, m, d) in melody[bar]:
        add_tone(b, t0 + at * beat, note(m), max(1.4, d * beat + .8), .16, decay=.45 + d * .15, harm=BELL, wrap=True)
save('bgm', b, .55)
print('ok')
