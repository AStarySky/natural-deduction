# SFX Credits / CC0 Manifest

All files below are **CC0 1.0** and are processed derivatives of the listed
sources. The physical card material is paper/card foley; marimba notes are used
only for tonal feedback.

| File | Source pack | Original / action | Processing |
|---|---|---|---|
| `card_slide.wav` | Kenney Casino Audio (CC0) | `cardSlide5.ogg` | mono 44.1k, 0.26 s trim, fades |
| `card_slide_short.wav` | Kenney Casino Audio (CC0) | `cardSlide5.ogg` | 0.07 s trim, +24 dB, fades |
| `card_lift.wav` | Kenney Casino Audio (CC0) | `cardTakeOutPackage1.ogg` | mono 44.1k, 0.22 s trim |
| `card_place.wav` | Kenney Casino Audio (CC0) | `cardPlace2.ogg` | 0.24 s trim, fades |
| `card_place_soft.wav` | Kenney Casino Audio (CC0) | `cardPlace2.ogg` | softer 0.18 s, +10 dB |
| `ui_click.wav` | Kenney Casino Audio (CC0) | `cardPlace2.ogg` | 0.10 s paper tap |
| `card_fan.wav` | Kenney Casino Audio (CC0) | `cardFan1.ogg` | 0.34 s trim |
| `card_shuffle.wav` | Kenney Casino Audio (CC0) | `cardShuffle.ogg` | 0.52 s trim |
| `card_open.wav` | Kenney Casino Audio (CC0) | `cardOpenPackage1.ogg` | 0.42 s trim |
| `page_whoosh.wav` | Kenney Casino Audio (CC0) | `cardSlide6.ogg` | 0.30 s page swipe |
| `page_back.wav` | Kenney Casino Audio (CC0) | reverse of `page_whoosh` | reversed + fades |
| `paper_sweep.wav` | Kenney Casino Audio (CC0) | `cardSlide7.ogg` | 0.36 s sweep |
| `trash_hover.wav` | Kenney Casino Audio (CC0) | `cardFan1.ogg` | 0.11 s quiet hover, +20 dB |
| `trash_delete.wav` | Kenney Casino Audio (CC0) | `cardShuffle.ogg` | paper crumple/shuffle |
| `scope_delete.wav` | Kenney Casino Audio (CC0) | `cardShuffle.ogg` | paper delete |
| `builder_open.wav` | Kenney Casino Audio (CC0) | `cardOpenPackage1.ogg` | paper unfold |
| `scope_open.wav` | layered CC0 | `cardOpenPackage1.ogg` + VSCO marimba C5 | paper + soft tonal rise |
| `scope_minimize.wav` | layered CC0 | `cardFan1.ogg` + VSCO marimba C4 | paper fold + soft tonal fall |
| `copy.wav` | Kenney Casino Audio (CC0) | two delayed `cardPlace2.ogg` taps | paper stamp ×2 |
| `socket_snap.wav` | layered CC0 | `cardPlace1.ogg` + VSCO marimba C5 | paper tab snap + tonal click |
| `error_soft.wav` | Kenney Interface Sounds (CC0) | `error_004.wav` | softened, mono 44.1k |
| `marimba_c4.wav` | VSCO 2 Community Edition (CC0) | `Percussion/Marimba/Marimba_hit_Outrigger_C4_loud_01.wav` | mono 44.1k, 0.9 s, +18 dB |
| `marimba_e4.wav`, `marimba_g4.wav`, `marimba_c5.wav` | VSCO 2 CE (CC0) | pitched derivatives of the C4 marimba | `asetrate` pitch, mono 44.1k |
| `confirm_two.wav` | layered CC0 | marimba C4 + E4 | delayed two-note confirmation |
| `goal_valid.wav` | layered CC0 | marimba C4 + E4 + G4 | delayed three-note rise |
| `level_complete.wav` | layered CC0 | marimba C4 + E4 + G4 + C5 | delayed completion chime |

## Paper variation pool (`paper/`)

`audio/sfx.gd` draws from several alternate takes so repeated lifts, drops and
hovers never replay one identical recording. Each file is a mono 44.1 kHz
16-bit derivative with short fades; the peak is normalized as listed below and
the runtime applies small per-take dB offsets to keep the pool balanced.
Takes are also length-filtered per action (0.75x–1.30x of the base take), so a
long delete never gets replaced by a short tap.

| File | Source | Trim (s) | Peak |
|---|---|---|---|
| `lift_a.wav` | `cardTakeOutPackage2.ogg` | 0.00–0.26 | -3 dB |
| `lift_b.wav` | `cardFan2.ogg` | 0.10–0.32 | -5 dB |
| `place_a.wav` | `cardPlace1.ogg` | 0.06–0.32 | -3 dB |
| `place_b.wav` | `cardPlace3.ogg` | 0.18–0.44 | -3 dB |
| `place_c.wav` | `cardPlace4.ogg` | 0.00–0.24 | -3 dB |
| `soft_a.wav` | `cardPlace3.ogg` | 0.18–0.36 | -9 dB |
| `soft_b.wav` | `cardPlace4.ogg` | 0.00–0.16 | -10 dB |
| `slide_a.wav` | `cardSlide1.ogg` | 0.08–0.26 | -4 dB |
| `slide_b.wav` | `cardSlide2.ogg` | 0.00–0.20 | -4 dB |
| `slide_c.wav` | `cardSlide4.ogg` | 0.00–0.20 | -4 dB |
| `hover_a.wav` | `cardSlide8.ogg` | 0.00–0.06 | -9 dB |
| `hover_b.wav` | `cardSlide2.ogg` | 0.05–0.11 | -10 dB |
| `hover_c.wav` | `cardFan2.ogg` | 0.15–0.23 | -9 dB |
| `snap_a.wav` | `cardPlace1.ogg` | 0.06–0.18 | -3 dB |
| `snap_b.wav` | `cardPlace4.ogg` | 0.12–0.22 | -4 dB |
| `open_a.wav` | `cardOpenPackage2.ogg` | 0.00–0.40 | -4 dB |
| `open_b.wav` | `cardOpenPackage1.ogg` | 0.30–0.70 | -4 dB |
| `fan_a.wav` | `cardFan2.ogg` | 0.10–0.42 | -6 dB |
| `sweep_a.wav` | `cardSlide6.ogg` | 0.00–0.30 | -4 dB |
| `sweep_b.wav` | `cardSlide8.ogg` | 0.00–0.32 | -4 dB |
| `shuffle_a.wav` | `cardShuffle.ogg` | 0.60–1.00 | -5 dB |
| `shove_a.wav` | `cardShove2.ogg` | 0.00–0.24 | -4 dB |
| `shove_b.wav` | `cardShove3.ogg` | 0.03–0.27 | -4 dB |
| `tap_a.wav` | `cardPlace2.ogg` | 0.00–0.08 | -6 dB |
| `slide_long_a.wav` | `cardSlide1.ogg` | 0.06–0.32 | -4 dB |
| `slide_long_b.wav` | `cardSlide2.ogg` | 0.00–0.25 | -4 dB |
| `crumple_a.wav` | `cardShuffle.ogg` | 1.40–1.84 | -5 dB |
| `crumple_b.wav` | `cardShuffle.ogg` | 2.10–2.56 | -5 dB |
| `hover_d.wav` | `cardSlide2.ogg` | 0.04–0.14 | -9 dB |

## UI button pool (`ui/`)

Crisp UI clicks and quiet hover ticks for real buttons, kept separate from the
paper-card foley pools. Source: **Kenney Interface Sounds (CC0)**.
Mono 44.1 kHz 16-bit, 70 Hz high-pass, short fades, peak-normalized.

| File | Source | Trim (s) | Peak |
|---|---|---|---|
| `button_click_a.wav` | `click_001.wav` | 0.000–0.090 | -6 dB |
| `button_click_b.wav` | `tick_004.wav` | 0.000–0.055 | -6 dB |
| `button_click_c.wav` | `click_004.wav` | 0.000–0.022 | -6 dB |
| `button_hover_a.wav` | `tick_001.wav` | 0.000–0.045 | -10 dB |
| `button_hover_b.wav` | `tick_002.wav` | 0.000–0.023 | -10 dB |

## Keyboard typing pool (`typing/`)

Real single-key recordings used while typing in the Formula Builder.
Source: **"Single Key Press Sounds" by eklee** (recordings) and **qubodup**
(single-key extraction), published on OpenGameArt.
**License: CC-BY 3.0 — attribution required.**
Full license text: `audio/licenses/EKLEE_KEYPRESSES_CCBY.txt`.

Each file is mono 44.1 kHz 16-bit, trimmed to the first 160 ms, high-passed at
55 Hz, with a 1 ms fade-in and 12 ms fade-out, then peak-normalized to -6 dB.
The runtime applies per-take dB offsets and random pitch/gain variation.

| File | Source | Trim (s) | Peak |
|---|---|---|---|
| `key_a.wav` | `eklee-KeyPressMac01.wav` | 0.00–0.16 | -6 dB |
| `key_b.wav` | `eklee-KeyPressMac02.wav` | 0.00–0.16 | -6 dB |
| `key_c.wav` | `eklee-KeyPressMac03.wav` | 0.00–0.16 | -6 dB |
| `key_d.wav` | `eklee-KeyPressMac04.wav` | 0.00–0.16 | -6 dB |
| `key_e.wav` | `eklee-KeyPressMac05.wav` | 0.00–0.16 | -6 dB |
| `key_f.wav` | `eklee-KeyPressMac06.wav` | 0.00–0.16 | -6 dB |
| `key_g.wav` | `eklee-KeyPressMac07.wav` | 0.00–0.16 | -6 dB |

## Sources

- Kenney Casino Audio — https://kenney.nl/assets/casino-audio (CC0; mirrored at
  https://github.com/ETdoFresh/kenney.nl/tree/master/kenney_casinoaudio)
- Kenney Interface Sounds — https://kenney.nl/assets/interface-sounds (CC0;
  Godot WAV mirror: https://github.com/Calinou/kenney-interface-sounds)
- VSCO 2 Community Edition — https://github.com/sgossner/VSCO-2-CE (CC0)
- Single Key Press Sounds by eklee, qubodup —
  https://opengameart.org/content/single-key-press-sounds (CC-BY 3.0)
  - Original recordings:
    https://freesound.org/people/eklee/sounds/158057/ and
    https://freesound.org/people/eklee/sounds/158058/
  - License: https://creativecommons.org/licenses/by/3.0/
- FreePats Kalimba (CC0) reserved for a future kalimba pass:
  https://freepats.zenvoid.org/Ethnic/kalimba.html

Upstream license texts are in `audio/licenses/`.

## Notes

- All processing is non-destructive; source archives are not committed.
- The card sounds intentionally preserve paper rustle/slide rather than being
  over-processed into synthetic clicks.
- No music or ambience is included.
