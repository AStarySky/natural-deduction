#!/usr/bin/env python3
"""Generate the original 8-bit background loop used by the game.

Usage:
    python -I tools/generate_bgm.py build/deduction_loop.wav

The result is a 40-bar, 120 BPM (80-second) chiptune loop in C major with
seventh, ninth and sus chord colors. The arrangement builds through sparse
lead, an independent counter-melody entering halfway through the intro, a
half-time breakdown with a snare build, an eight-bar counter-melody cadenza
where the lead rests, and an octave-doubled climax. All voices are synthesized
here (square lead, counter-melody, pulse arpeggio, triangle bass, noise drums).
The counter-melody is a composed alto line with its own rhythm and contour,
not a pad of sustained chord tones; it is panned right in the duet and brought
toward the center for the cadenza, while the arpeggio sits left and the lead
stays centered. Both melodies share a rising-three-note + falling-response
motive: the counter states it in transposition/inversion at its entrance, and
each cadenza bar states it before answering with a sixteenth-note flourish.
Suspensions at the breakdown/cadenza seams, pickups into the cadenza and
climax, and drum fills/crashes keep the section transitions from cutting
abruptly. Every melodic and chord voice has a four-stage ADSR envelope
(attack, decay, sustain, release); drum hits use their own percussive decays.
The lead is deliberately thinner and quieter than before, and the counter uses
a broader pulse/triangle timbre so the two simultaneous melodies remain
distinguishable. A parallel bitcrush/sample-hold path, decorrelated stereo
hardware hiss and sparse panned crackle keep the mix from sounding too clean.
The track contains no third-party samples or melodies.
"""

from __future__ import annotations

import math
import random
import struct
import sys
import wave

SAMPLE_RATE = 44100
BPM = 120.0
BEAT = 60.0 / BPM
BAR = 4.0 * BEAT
EIGHTH = BEAT / 2.0
SIXTEENTH = BEAT / 4.0
BARS = 40
DURATION = BARS * BAR
SAMPLE_COUNT = int(round(DURATION * SAMPLE_RATE))

NOTE_INDEX = {
    "C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6,
    "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11,
}

# Lo-fi character: parallel 5–6 bit crush, ~14.7 kHz sample-and-hold, a quiet
# hardware hiss and sparse crackle. The dry mix stays dominant for clarity.
CRUSH_STEPS = 48
SAMPLE_HOLD_RATE = 16000.0
CRUSH_MIX = 0.40
HISS_LEVEL = 0.0065
CRACKLE_PER_SECOND = 1.1


class StereoBuffer:
    """Two-channel mix buffer; panning is applied per voice as it is added."""

    def __init__(self):
        self.left = [0.0] * SAMPLE_COUNT
        self.right = [0.0] * SAMPLE_COUNT


def note(name: str) -> int:
    """Convert a note name such as E5 to a MIDI number."""
    pitch = name[:-1]
    octave = int(name[-1])
    return 12 * (octave + 1) + NOTE_INDEX[pitch]


def frequency(midi: int) -> float:
    return 440.0 * (2.0 ** ((midi - 69) / 12.0))


def pan_gains(pan: float) -> tuple[float, float]:
    """Constant-power pan; 0.0 gives equal level to both channels."""
    angle = (max(-1.0, min(1.0, pan)) + 1.0) * math.pi * 0.25
    return math.cos(angle), math.sin(angle)


def adsr_stages(duration, attack, decay, sustain, release):
    """Fit an ADSR shape into a note while keeping all four stages present."""
    attack = max(0.0, min(attack, duration * 0.35))
    release = max(0.0, min(release, duration * 0.35))
    decay = max(0.0, min(decay, max(0.0, duration - attack - release)))
    hold = max(0.0, duration - attack - decay - release)
    return attack, decay, hold, release, max(0.0, min(1.0, sustain))


def add_square(
    out,
    start,
    duration,
    midi,
    gain,
    duty=0.5,
    attack=0.006,
    decay=0.06,
    sustain=0.65,
    release=0.04,
    vibrato=0.0,
    pan=0.0,
):
    begin = max(0, int(start * SAMPLE_RATE))
    end = min(SAMPLE_COUNT, int((start + duration) * SAMPLE_RATE))
    if end <= begin:
        return
    freq = frequency(midi)
    gain_l, gain_r = pan_gains(pan)
    left, right = out.left, out.right
    attack, decay, hold, release, sustain = adsr_stages(
        duration, attack, decay, sustain, release
    )
    release_start = attack + decay + hold
    phase = 0.0
    for i in range(begin, end):
        t = (i - begin) / SAMPLE_RATE
        current = freq
        if vibrato:
            current *= 1.0 + vibrato * math.sin(2.0 * math.pi * 5.2 * t)
        phase = (phase + current / SAMPLE_RATE) % 1.0
        if t < attack:
            envelope = t / attack
        elif t < attack + decay:
            envelope = 1.0 - (1.0 - sustain) * ((t - attack) / decay)
        elif t < release_start:
            envelope = sustain
        elif release > 0.0:
            envelope = sustain * max(0.0, (duration - t) / release)
        else:
            envelope = 0.0
        sample = gain * envelope * (1.0 if phase < duty else -1.0)
        left[i] += sample * gain_l
        right[i] += sample * gain_r


def add_triangle(
    out,
    start,
    duration,
    midi,
    gain,
    attack=0.008,
    decay=0.08,
    sustain=0.72,
    release=0.05,
    pan=0.0,
):
    begin = max(0, int(start * SAMPLE_RATE))
    end = min(SAMPLE_COUNT, int((start + duration) * SAMPLE_RATE))
    if end <= begin:
        return
    freq = frequency(midi)
    gain_l, gain_r = pan_gains(pan)
    left, right = out.left, out.right
    attack, decay, hold, release, sustain = adsr_stages(
        duration, attack, decay, sustain, release
    )
    release_start = attack + decay + hold
    phase = 0.0
    for i in range(begin, end):
        t = (i - begin) / SAMPLE_RATE
        phase = (phase + freq / SAMPLE_RATE) % 1.0
        if t < attack:
            envelope = t / attack
        elif t < attack + decay:
            envelope = 1.0 - (1.0 - sustain) * ((t - attack) / decay)
        elif t < release_start:
            envelope = sustain
        elif release > 0.0:
            envelope = sustain * max(0.0, (duration - t) / release)
        else:
            envelope = 0.0
        sample = gain * envelope * (4.0 * abs(phase - 0.5) - 1.0)
        left[i] += sample * gain_l
        right[i] += sample * gain_r


def add_kick(out, start, gain=0.32, pan=0.0):
    begin = max(0, int(start * SAMPLE_RATE))
    end = min(SAMPLE_COUNT, int((start + 0.16) * SAMPLE_RATE))
    gain_l, gain_r = pan_gains(pan)
    left, right = out.left, out.right
    phase = 0.0
    for i in range(begin, end):
        t = (i - begin) / SAMPLE_RATE
        freq = 42.0 + 105.0 * math.exp(-t * 24.0)
        phase = (phase + freq / SAMPLE_RATE) % 1.0
        envelope = math.exp(-t * 18.0)
        sample = gain * envelope * math.sin(2.0 * math.pi * phase)
        left[i] += sample * gain_l
        right[i] += sample * gain_r


def add_noise(out, start, duration, gain, decay, highpass=0.0, seed=0, pan=0.0):
    begin = max(0, int(start * SAMPLE_RATE))
    end = min(SAMPLE_COUNT, int((start + duration) * SAMPLE_RATE))
    if end <= begin:
        return
    rng = random.Random(seed)
    gain_l, gain_r = pan_gains(pan)
    left, right = out.left, out.right
    previous = 0.0
    for i in range(begin, end):
        t = (i - begin) / SAMPLE_RATE
        value = rng.uniform(-1.0, 1.0)
        if highpass:
            value, previous = value - previous * highpass, value
        # Tiny attack removes the click when a noise drum starts a loop.
        envelope = min(1.0, t / 0.003) * math.exp(-decay * t)
        sample = gain * envelope * value
        left[i] += sample * gain_l
        right[i] += sample * gain_r


def add_drums(out):
    for bar in range(BARS):
        bar_start = bar * BAR
        section = bar // 8

        # Breakdown: half-time drums, then a snare build in the last bar.
        if section == 2:
            level = 0.62 + 0.012 * (bar - 16)
            if bar == 16:
                add_noise(
                    out, bar_start, 0.42, 0.035, 9.0, 0.92, 900 + bar,
                    pan=-0.32
                )
            add_kick(out, bar_start + 0.0 * BEAT, 0.32 * level)
            add_kick(out, bar_start + 2.5 * BEAT, 0.18 * level)
            add_noise(
                out,
                bar_start + 2.0 * BEAT,
                0.16,
                0.10 * level,
                30.0,
                0.65,
                300 + bar,
            )
            for eighth in range(8):
                accent = 0.032 if eighth % 2 == 0 else 0.022
                add_noise(
                    out,
                    bar_start + eighth * EIGHTH,
                    0.045,
                    accent * level,
                    110.0,
                    0.9,
                    bar * 16 + eighth,
                    pan=0.24,
                )
            if bar == 23:
                for step in range(8):
                    add_noise(
                        out,
                        bar_start + 3.0 * BEAT + step * SIXTEENTH * 0.5,
                        0.06,
                        0.020 + step * 0.009,
                        45.0,
                        0.7,
                        2300 + step,
                        pan=-0.28 if step % 2 == 0 else 0.28,
                    )
            continue

        level = [0.82, 1.0, 1.0, 0.88, 1.12][section]
        add_kick(out, bar_start + 0.0 * BEAT, 0.32 * level)
        add_kick(out, bar_start + 2.0 * BEAT, 0.32 * level)
        if bar % 4 == 3:
            add_kick(out, bar_start + 3.5 * BEAT, 0.20 * level)
        add_noise(
            out, bar_start + 1.0 * BEAT, 0.14, 0.11 * level, 34.0, 0.65, 100 + bar
        )
        add_noise(
            out, bar_start + 3.0 * BEAT, 0.14, 0.11 * level, 34.0, 0.65, 200 + bar
        )
        for eighth in range(8):
            accent = (0.060 if eighth % 2 == 0 else 0.040) * level
            add_noise(
                out,
                bar_start + eighth * EIGHTH,
                0.045,
                accent,
                95.0,
                0.9,
                bar * 16 + eighth,
                pan=0.26,
            )
        # Open hat and ghost snare lift the second half of each phrase.
        if section >= 1:
            add_noise(
                out, bar_start + 3.5 * BEAT, 0.16, 0.028 * level, 22.0, 0.88,
                400 + bar, pan=0.32
            )
        if section >= 1 and bar % 4 in (1, 3):
            add_noise(
                out, bar_start + 2.75 * BEAT, 0.07, 0.032 * level, 52.0, 0.7,
                500 + bar, pan=-0.22
            )
        if bar in (0, 8, 24, 32):
            add_noise(
                out, bar_start, 0.42, 0.045 * level, 9.0, 0.92, 900 + bar,
                pan=-0.32
            )

    # Short fills lead into the next section and the loop restart.
    for bar in (7, 15, 31, 39):
        level = [0.82, 1.0, 1.0, 0.88, 1.12][bar // 8]
        fill_start = bar * BAR + 3.5 * BEAT
        for index in range(4):
            add_noise(
                out,
                fill_start + index * SIXTEENTH,
                0.08,
                0.09 * level,
                50.0,
                0.7,
                1500 + bar * 4 + index,
                pan=-0.30 if index % 2 == 0 else 0.30,
            )


# Chords are (bass root, [four-note arpeggio voicing]) in MIDI numbers.
# Sevenths, ninths and sus colors replace the earlier plain triads.
CHORDS = {
    "Cmaj7": (48, [64, 67, 71, 72]),
    "Em7": (52, [64, 67, 71, 74]),
    "Am7": (45, [64, 67, 69, 72]),
    "Fmaj7": (53, [65, 69, 72, 76]),
    "Dm7": (50, [62, 65, 69, 72]),
    "G7": (43, [62, 65, 67, 71]),
    "C/E": (52, [64, 67, 72, 76]),
    "G7sus": (43, [62, 67, 72, 74]),
    "Am9": (45, [64, 67, 71, 72]),
    "G6": (43, [62, 64, 67, 71]),
    "Dm9": (50, [65, 69, 72, 76]),
    "E7": (52, [64, 68, 71, 74]),
    "E7sus": (52, [64, 69, 71, 74]),
    "Fmaj9": (53, [65, 69, 72, 79]),
    "G13": (43, [67, 71, 74, 76]),
}
PROGRESSION = [
    "Cmaj7", "Em7", "Am7", "Fmaj7", "Dm7", "G7", "C/E", "G7sus",
    "Fmaj7", "G7", "Em7", "Am7", "Dm7", "G7", "Cmaj7", "G7sus",
    "Am9", "Fmaj7", "Cmaj7", "G6", "Am7", "Dm9", "E7", "E7sus",
    # Bars 24-31: cadenza harmony, a vi-ii-V-I-IV-ii-V(sus) cycle.
    "Am7", "Dm7", "G7", "Cmaj7", "Fmaj7", "Dm7", "E7", "G7sus",
    # Bars 32-39: the climax progression returns.
    "Fmaj9", "G13", "Em7", "Am9", "Dm7", "G7", "Cmaj7", "G7sus",
]

# Lead events are (start_eighth, length_eighths, note); rests are omitted.
# The long notes and rests create phrases instead of a constant eighth-note run.
MELODY = [
    [(0, 1, "E5"), (1, 1, "G5"), (2, 2, "B5"), (4, 1, "G5"), (5, 1, "E5"), (6, 2, "D5")],
    [(0, 1, "D5"), (1, 1, "E5"), (2, 2, "G5"), (4, 2, "B5"), (6, 1, "A5"), (7, 1, "G5")],
    [(0, 1, "C5"), (1, 1, "E5"), (2, 2, "G5"), (4, 2, "C6"), (6, 1, "A5"), (7, 1, "E5")],
    [(0, 1, "F5"), (1, 1, "A5"), (2, 1, "C6"), (3, 1, "E6"), (4, 2, "D6"), (6, 2, "C6")],
    [(0, 2, "A4"), (2, 1, "C5"), (3, 1, "D5"), (4, 2, "F5"), (6, 2, "E5")],
    [(0, 1, "B4"), (1, 1, "D5"), (2, 2, "F5"), (4, 1, "G5"), (5, 1, "B5"), (6, 2, "A5")],
    [(0, 2, "E5"), (2, 1, "G5"), (3, 2, "C6"), (5, 1, "B5"), (6, 2, "G5")],
    [(0, 1, "D5"), (1, 1, "F5"), (2, 1, "G5"), (3, 1, "B5"), (4, 2, "D6"), (6, 2, "B5")],
    [(0, 1, "C6"), (1, 1, "A5"), (2, 2, "F5"), (4, 2, "A5"), (6, 2, "G5")],
    [(0, 1, "B5"), (1, 1, "G5"), (2, 2, "D5"), (4, 2, "A5"), (6, 2, "G5")],
    [(0, 1, "E5"), (1, 1, "G5"), (2, 2, "B5"), (4, 2, "D6"), (6, 1, "B5"), (7, 1, "G5")],
    [(0, 1, "C6"), (1, 1, "B5"), (2, 2, "A5"), (4, 2, "E5"), (6, 2, "G5")],
    [(0, 1, "D5"), (1, 1, "F5"), (2, 2, "A5"), (4, 2, "C6"), (6, 1, "A5"), (7, 1, "F5")],
    [(0, 1, "B5"), (1, 1, "D6"), (2, 2, "F6"), (4, 2, "D6"), (6, 2, "B5")],
    [(1, 1, "E6"), (2, 1, "D6"), (3, 2, "C6"), (5, 3, "G5")],
    [(0, 1, "D5"), (1, 1, "G5"), (2, 2, "C6"), (4, 2, "D6"), (6, 4, "B5")],
    [(2, 2, "E5"), (4, 2, "G5"), (6, 2, "B5")],
    [(0, 4, "A5"), (4, 2, "C6"), (6, 2, "E6")],
    [(0, 2, "G5"), (2, 2, "C6"), (4, 3, "E6")],
    [(0, 2, "B5"), (2, 2, "D6"), (4, 3, "E6")],
    [(2, 2, "C6"), (4, 2, "E6"), (6, 2, "G6")],
    [(0, 2, "F5"), (2, 2, "A5"), (4, 2, "C6"), (6, 2, "E6")],
    [(0, 2, "G#5"), (2, 2, "B5"), (4, 2, "D6"), (6, 2, "E6")],
    [(0, 4, "B5"), (4, 2, "A5"), (6, 4, "E6")],
    # Bars 24-31: cadenza — the lead rests except for a two-note motif pickup
    # in the final bar, which hands the melody back to the climax.
    [], [], [], [], [], [], [], [(6, 1, "E5"), (7, 1, "G5")],
    # Bars 32-39: the lead returns over the climax.
    [(0, 1, "A5"), (1, 1, "C6"), (2, 2, "E6"), (4, 2, "G6"), (6, 1, "E6"), (7, 1, "C6")],
    [(0, 1, "B5"), (1, 1, "D6"), (2, 2, "F6"), (4, 2, "A6"), (6, 1, "F6"), (7, 1, "D6")],
    [(0, 1, "G5"), (1, 1, "B5"), (2, 2, "D6"), (4, 2, "E6"), (6, 1, "D6"), (7, 1, "B5")],
    [(0, 1, "A5"), (1, 1, "C6"), (2, 2, "E6"), (4, 2, "B5"), (6, 1, "A5"), (7, 1, "E6")],
    [(0, 1, "F5"), (1, 1, "A5"), (2, 2, "C6"), (4, 2, "D6"), (6, 1, "C6"), (7, 1, "A5")],
    [(0, 1, "G5"), (1, 1, "B5"), (2, 2, "D6"), (4, 2, "F6"), (6, 1, "D6"), (7, 1, "B5")],
    [(0, 1, "E6"), (1, 1, "G6"), (2, 2, "C6"), (4, 2, "B5"), (6, 1, "G5"), (7, 1, "E6")],
    [(0, 2, "D6"), (2, 2, "F6"), (4, 2, "G6"), (6, 2, "B5")],
]

# A composed alto counter-melody previews in the intro, then answers the lead
# with its own rhythms and contour through the remaining sections. Slots and
# lengths are in eighth notes; 0.5 values are sixteenth-note cadenza runs.
COUNTER = [
    [], [], [], [],
    # Bars 4-7: the counter-melody previews in the second half of the intro.
    [(0, 2, "F4"), (2, 2, "A4"), (4, 2, "D5"), (6, 2, "C5")],
    [(0, 2, "G4"), (2, 2, "D5"), (4, 2, "B4"), (6, 2, "A4")],
    [(0, 2, "G4"), (2, 2, "E4"), (4, 2, "G4"), (6, 2, "C5")],
    [(0, 2, "D4"), (2, 2, "B4"), (4, 4, "G4")],
    # Bars 8-15: the counter-melody proper; its phrases answer the lead.
    [(0, 1, "F4"), (1, 1, "A4"), (2, 2, "C5"), (4, 1, "D5"), (5, 1, "C5"), (6, 2, "G4")],
    [(0, 2, "B4"), (2, 1, "D5"), (3, 1, "B4"), (4, 2, "A4"), (6, 2, "G4")],
    [(0, 3, "G4"), (3, 1, "B4"), (4, 2, "D5"), (6, 2, "B4")],
    [(0, 1, "A4"), (1, 1, "C5"), (2, 2, "E5"), (4, 2, "C5"), (6, 2, "B4")],
    [(0, 3, "F4"), (3, 1, "A4"), (4, 2, "F4"), (6, 2, "A4")],
    [(0, 2, "B4"), (2, 2, "D5"), (4, 1, "B4"), (5, 1, "A4"), (6, 2, "G4")],
    [(0, 3, "G4"), (3, 1, "E4"), (4, 1, "G4"), (5, 1, "B4"), (6, 2, "C5")],
    [(0, 2, "D4"), (2, 2, "F4"), (4, 2, "G4"), (6, 2, "B4")],
    # Bars 16-23: breakdown; the counter keeps moving under the long lead notes.
    [(0, 2, "A4"), (2, 2, "C5"), (4, 2, "E5"), (6, 2, "D5")],
    [(0, 2, "F4"), (2, 1, "A4"), (3, 1, "C5"), (4, 2, "E5"), (6, 2, "C5")],
    [(0, 1, "G4"), (1, 1, "E4"), (2, 2, "G4"), (4, 1, "C5"), (5, 1, "B4"), (6, 2, "G4")],
    [(0, 2, "B4"), (2, 2, "D5"), (4, 2, "E5"), (6, 2, "B4")],
    [(0, 2, "A4"), (2, 2, "C5"), (4, 2, "E5"), (6, 2, "B4")],
    [(0, 2, "F4"), (2, 1, "A4"), (3, 1, "C5"), (4, 2, "E5"), (6, 2, "C5")],
    [(0, 2, "E4"), (2, 1, "G#4"), (3, 1, "B4"), (4, 2, "D5"), (6, 2, "B4")],
    [(0, 2, "E4"), (2, 2, "B4"), (4, 2, "A4"), (6, 1, "B4"), (7, 1, "C5")],
    # Bars 24-31: cadenza. Each bar states the lead's rising-triad motif
    # (M1: eighth-eighth-quarter, transposed/inverted) in its first half,
    # then answers with a faster sixteenth-note flourish in the second half.
    [(0, 1, "A4"), (1, 1, "C5"), (2, 2, "E5"),
     (4, 0.5, "A5"), (4.5, 0.5, "G5"), (5, 0.5, "E5"), (5.5, 0.5, "D5"),
     (6, 1, "C5"), (7, 1, "B4")],
    [(0, 1, "D5"), (1, 1, "F5"), (2, 2, "A5"),
     (4, 0.5, "D6"), (4.5, 0.5, "C6"), (5, 0.5, "A5"), (5.5, 0.5, "G5"),
     (6, 1, "F5"), (7, 1, "E5")],
    [(0, 1, "G4"), (1, 1, "B4"), (2, 2, "D5"),
     (4, 0.5, "G5"), (4.5, 0.5, "F5"), (5, 0.5, "D5"), (5.5, 0.5, "C5"),
     (6, 1, "B4"), (7, 1, "A4")],
    [(0, 1, "C5"), (1, 1, "E5"), (2, 2, "G5"),
     (4, 0.5, "C6"), (4.5, 0.5, "B5"), (5, 0.5, "G5"), (5.5, 0.5, "F5"),
     (6, 1, "E5"), (7, 1, "D5")],
    [(0, 1, "F5"), (1, 1, "C5"), (2, 2, "A4"),
     (4, 0.5, "F4"), (4.5, 0.5, "A4"), (5, 0.5, "C5"), (5.5, 0.5, "F5"),
     (6, 1, "E5"), (7, 1, "D5")],
    [(0, 1, "D5"), (1, 1, "F5"), (2, 2, "A5"),
     (4, 0.5, "D6"), (4.5, 0.5, "C6"), (5, 0.5, "A5"), (5.5, 0.5, "G5"),
     (6, 1, "E5"), (7, 1, "D5")],
    [(0, 1, "E5"), (1, 1, "G#5"), (2, 2, "B5"),
     (4, 0.5, "D6"), (4.5, 0.5, "B5"), (5, 0.5, "G#5"), (5.5, 0.5, "E5"),
     (6, 1, "D5"), (7, 1, "B4")],
    [(0, 1, "G4"), (1, 1, "B4"), (2, 2, "D5"),
     (4, 1, "F5"), (5, 1, "G5"), (6, 1, "A5"), (7, 1, "C6")],
    # Bars 32-39: climax; a new counter phrase runs under the lead's variation.
    [(0, 1, "A4"), (1, 1, "C5"), (2, 2, "E5"), (4, 1, "D5"), (5, 1, "C5"), (6, 2, "A4")],
    [(0, 1, "B4"), (1, 1, "D5"), (2, 2, "F5"), (4, 1, "E5"), (5, 1, "C5"), (6, 2, "D5")],
    [(0, 1, "G4"), (1, 1, "B4"), (2, 2, "D5"), (4, 1, "E5"), (5, 1, "A4"), (6, 2, "B4")],
    [(0, 1, "A4"), (1, 1, "C5"), (2, 2, "E5"), (4, 1, "D5"), (5, 1, "B4"), (6, 2, "C5")],
    [(0, 1, "F4"), (1, 1, "A4"), (2, 2, "C5"), (4, 1, "D5"), (5, 1, "A4"), (6, 2, "C5")],
    [(0, 1, "B4"), (1, 1, "D5"), (2, 2, "B4"), (4, 2, "D5"), (6, 2, "G4")],
    [(0, 2, "E4"), (2, 2, "G4"), (4, 1, "E5"), (5, 1, "D5"), (6, 2, "G4")],
    [(0, 2, "F4"), (2, 2, "A4"), (4, 2, "G4"), (6, 2, "B4")],
]


def add_harmony(out):
    for bar in range(BARS):
        bar_start = bar * BAR
        section = bar // 8
        root, chord = CHORDS[PROGRESSION[bar]]

        # Bass: bouncing eighths normally, half-time quarters in the breakdown.
        if section == 2:
            bass_gain = 0.135 + 0.005 * (bar - 16)
            for slot, offset in [(0, 0), (2, 7), (4, 12), (6, 7)]:
                add_triangle(
                    out,
                    bar_start + slot * EIGHTH,
                    EIGHTH * 1.85,
                    root + offset,
                    bass_gain,
                    attack=0.010,
                    decay=0.12,
                    sustain=0.78,
                    release=0.06,
                )
        else:
            if section == 3:
                bass_gain = 0.17 + 0.004 * (bar - 24)
            else:
                bass_gain = [0.16, 0.20, 0.0, 0.0, 0.21][section]
            offsets = [0, 12, 7, 12, 0, 7, 12, 7]
            for index, offset in enumerate(offsets):
                add_triangle(
                    out,
                    bar_start + index * EIGHTH,
                    0.21,
                    root + offset,
                    bass_gain,
                    attack=0.004,
                    decay=0.06,
                    sustain=0.38,
                    release=0.035,
                )

        # Sixteenth-note arpeggio over all four chord tones (7th/9th included).
        # It sits to the left so its chord movement stays audible under the lead.
        if section == 2:
            arp_gain = 0.041 + 0.0032 * (bar - 16)
        elif section == 3:
            arp_gain = 0.035 + 0.002 * (bar - 24)
        else:
            arp_gain = [
                0.052,
                0.081,
                0.0,
                0.0,
                0.099 + 0.0016 * (bar - 32),
            ][section]
        pattern = [0, 1, 2, 3, 2, 1, 2, 3]
        for step in range(16):
            add_square(
                out,
                bar_start + step * SIXTEENTH,
                SIXTEENTH * 0.82,
                chord[pattern[step % len(pattern)]],
                arp_gain,
                0.125,
                attack=0.003,
                decay=0.050,
                sustain=0.20,
                release=0.030,
                pan=-0.55,
            )

        # Lead: longer phrases, rests and a crescendo in the final section.
        # A thinner pulse with less level leaves room for the arpeggio and
        # counter-voice instead of covering them.
        if section == 2:
            lead_gain = 0.083 + 0.0014 * (bar - 16)
            lead_attack, lead_decay, lead_sustain, lead_release = (
                0.025, 0.20, 0.82, 0.12
            )
        else:
            lead_gain = [
                0.086,
                0.099,
                0.0,
                0.0,
                0.099 + 0.0023 * (bar - 32),
            ][section]
            lead_attack, lead_decay, lead_sustain, lead_release = (
                0.006, 0.14, 0.60, 0.08
            )
        for slot, length, name in MELODY[bar]:
            midi = note(name)
            duration = length * EIGHTH * 0.90
            add_square(
                out,
                bar_start + slot * EIGHTH,
                duration,
                midi,
                lead_gain,
                0.125,
                attack=lead_attack,
                decay=lead_decay,
                sustain=lead_sustain,
                release=lead_release,
                vibrato=0.0035,
            )
            # The final section doubles the lead an octave down for weight;
            # the double is offset to the right and kept well below the lead.
            if section == 4:
                add_square(
                    out,
                    bar_start + slot * EIGHTH,
                    duration * 0.94,
                    midi - 12,
                    0.030 + 0.0014 * (bar - 32),
                    0.125,
                    attack=0.004,
                    decay=0.06,
                    sustain=0.38,
                    release=0.05,
                    pan=0.30,
                )

        # Independent counter-melody: warm triangle in the intro and breakdown,
        # a brighter centered 25% pulse in the cadenza, then a broader 25% pulse
        # in the main sections and climax. Panning and timbre keep it distinct
        # from the lead; it enters halfway through the intro to break up the solo.
        if bar >= 4:
            if section == 0:
                counter_gain = 0.052 + 0.0023 * (bar - 4)
            elif section == 2:
                counter_gain = 0.094 + 0.0028 * (bar - 16)
            elif section == 3:
                counter_gain = 0.110 + 0.004 * (bar - 24)
            else:
                counter_gain = [
                    0.082,
                    0.0,
                    0.0,
                    0.093 + 0.0029 * (bar - 32),
                ][section - 1]
            for slot, length, name in COUNTER[bar]:
                midi = note(name)
                duration = length * EIGHTH * 0.92
                if section == 3:
                    add_square(
                        out,
                        bar_start + slot * EIGHTH,
                        duration,
                        midi,
                        counter_gain,
                        0.25,
                        attack=0.004,
                        decay=0.08,
                        sustain=0.62,
                        release=0.06,
                        vibrato=0.003,
                        pan=0.20,
                    )
                elif section in (1, 4):
                    add_square(
                        out,
                        bar_start + slot * EIGHTH,
                        duration,
                        midi,
                        counter_gain,
                        0.25,
                        attack=0.005,
                        decay=0.10,
                        sustain=0.58,
                        release=0.08,
                        pan=0.55,
                    )
                else:
                    add_triangle(
                        out,
                        bar_start + slot * EIGHTH,
                        duration,
                        midi,
                        counter_gain,
                        attack=0.018,
                        decay=0.12 if section == 2 else 0.10,
                        sustain=0.78 if section == 2 else 0.72,
                        release=0.12 if section == 2 else 0.10,
                        pan=0.55,
                    )


def dc_block(out):
    """One-pole DC blocker per channel; keeps the loop centered."""
    for channel in (out.left, out.right):
        previous_input = 0.0
        previous_output = 0.0
        for index in range(SAMPLE_COUNT):
            value = channel[index]
            sample_out = value - previous_input + 0.995 * previous_output
            previous_input = value
            previous_output = sample_out
            channel[index] = sample_out


def add_lofi_character(out):
    """Add the console/tape grit that keeps the chiptune from sounding clean."""
    hold = max(1, int(round(SAMPLE_RATE / SAMPLE_HOLD_RATE)))
    # Crush each channel independently so the stereo placement is preserved.
    for channel in (out.left, out.right):
        held = 0.0
        for index in range(SAMPLE_COUNT):
            if index % hold == 0:
                held = channel[index]
            crushed = round(held * CRUSH_STEPS) / CRUSH_STEPS
            channel[index] = (
                channel[index] * (1.0 - CRUSH_MIX) + crushed * CRUSH_MIX
            )

    # Decorrelated hardware hiss; the two sides breathe together but do not
    # share the same noise, which widens the mix without adding a loud layer.
    rng_left = random.Random(0xB16B00B5)
    rng_right = random.Random(0xB16B00B6)
    previous_left = 0.0
    previous_right = 0.0
    for index in range(SAMPLE_COUNT):
        white_left = rng_left.uniform(-1.0, 1.0)
        white_right = rng_right.uniform(-1.0, 1.0)
        bright_left = white_left - previous_left * 0.55
        bright_right = white_right - previous_right * 0.55
        previous_left = white_left
        previous_right = white_right
        breathe = 0.85 + 0.15 * math.sin(2.0 * math.pi * index / SAMPLE_RATE / 11.0)
        out.left[index] += HISS_LEVEL * breathe * bright_left
        out.right[index] += HISS_LEVEL * breathe * bright_right

    # Sparse crackle, kept away from the loop seam and scattered in the field.
    rng = random.Random(0x51F7A11)
    crackles = int(DURATION * CRACKLE_PER_SECOND)
    for _ in range(crackles):
        start = int(rng.uniform(0.10, DURATION - 0.20) * SAMPLE_RATE)
        amplitude = rng.uniform(0.010, 0.040)
        if rng.random() < 0.5:
            amplitude = -amplitude
        gain_l, gain_r = pan_gains(rng.uniform(-0.65, 0.65))
        for offset in range(rng.randint(2, 8)):
            position = start + offset
            sample = amplitude * math.exp(-offset / 2.5)
            out.left[position] += sample * gain_l
            out.right[position] += sample * gain_r


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: python -I tools/generate_bgm.py output.wav")
    output = sys.argv[1]
    out = StereoBuffer()
    add_harmony(out)
    add_drums(out)
    dc_block(out)
    add_lofi_character(out)

    # The counter-melody is panned right and the arpeggio left; trim the two
    # channels to equal RMS so that panning does not pull the whole mix sideways.
    left_energy = sum(value * value for value in out.left)
    right_energy = sum(value * value for value in out.right)
    if left_energy > 0.0 and right_energy > 0.0:
        trim = math.sqrt(right_energy / left_energy)
        left_trim = math.sqrt(trim)
        right_trim = 1.0 / left_trim
        for index in range(SAMPLE_COUNT):
            out.left[index] *= left_trim
            out.right[index] *= right_trim

    peak = max(
        max(abs(value) for value in out.left),
        max(abs(value) for value in out.right),
    )
    if peak <= 0.0:
        raise SystemExit("generated silence")
    scale = 0.50 / peak
    frames = bytearray()
    for index in range(SAMPLE_COUNT):
        left = int(max(-1.0, min(1.0, out.left[index] * scale)) * 32767)
        right = int(max(-1.0, min(1.0, out.right[index] * scale)) * 32767)
        frames += struct.pack("<hh", left, right)
    with wave.open(output, "wb") as handle:
        handle.setnchannels(2)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(frames)
    print(f"wrote {output}: {DURATION:.2f}s stereo, peak normalized from {peak:.3f}")


if __name__ == "__main__":
    main()
