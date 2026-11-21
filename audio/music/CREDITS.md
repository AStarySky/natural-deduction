# Music Credits

## `deduction_loop.ogg`

Original composition created for this project. No third-party samples,
recordings or melodies are used.

- Style: 8-bit / chiptune with seventh, ninth and sus chord colors
- Length: 80 seconds, seamless loop
- Tempo: 120 BPM, 40 bars, C major
- Voices: square lead, independent counter-melody, four-note pulse
  arpeggio, triangle bass, noise drums
- Counterpoint: the counter-melody is a composed alto line with its own
  rhythm and contour, not sustained chord tones; it enters at bar 5 and
  answers the lead through the loop, then takes an eight-bar leadless cadenza
  (bars 25-32, with bass/arpeggio/drums still supporting) before the lead
  returns for the climax
- Motive: the lead and counter share a rising-three-note + falling-response
  cell. The counter states it in transposition/inversion at its entrance; each
  cadenza bar states it in the first half and answers with a sixteenth-note
  flourish in the second half
- Transitions: suspensions at bars 16 and 24, counter/lead pickups at bars 24
  and 32, and snare build/fill + crash at section changes keep the seams from
  cutting abruptly
- Envelopes: every melodic and chord voice uses a four-stage ADSR envelope
  (attack, decay, sustain, release); drum hits use their own percussive decays
- Mix: stereo — arpeggio panned left, counter-melody right in the duet and
  near center for the cadenza, lead/bass/drums centered; the lead uses a
  thinner 12.5% pulse and the counter uses a broader 25% pulse (triangle in
  the intro/breakdown) so the two lines stay timbrally distinct
- Arrangement: five 8-bar sections — sparse lead, counter-voice entrance,
  half-time breakdown with a snare build, counter cadenza, then the
  octave-doubled climax
- Character: parallel 48-step bitcrush (40% wet), ~16 kHz sample-and-hold,
  decorrelated stereo hardware hiss and sparse panned crackle
- Generator: `tools/generate_bgm.py`

Regenerate the WAV (then encode to OGG if desired):

```bash
python -I tools/generate_bgm.py build/deduction_loop.wav
ffmpeg -i build/deduction_loop.wav -c:a libvorbis -q:a 6 audio/music/deduction_loop.ogg
```
