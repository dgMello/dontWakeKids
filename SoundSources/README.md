# Sound sources

Original recordings, kept as-is. These are **not** bundled into the app.
The game uses the cleaned-up versions in `DontWakeTheKids/Audio/Sounds/`.

| Recording | Used as | Processing |
|---|---|---|
| `Floor_squeak_3.m4a` (Douglas Mello, own recording) | `creak.caf`: creaky floorboards; played quietly when tiptoeing, full volume when walking | Trimmed 0.06 s of silence, rumble cut below 80 Hz, normalized, +6 dB with a limiter (peak −2 dB), short fades, mono 44.1 kHz |
| `Floor_squeak_5.m4a` (Douglas Mello, own recording) | `creak2.caf`: second creak; the game picks one of the two at random | Same as above, +7 dB to match `creak.caf` |
| `Washing_hands.m4a` (Douglas Mello, own recording) | `water.caf`: brushing teeth; the shower plays it slowed to 0.8× and looped | 0.40–4.40 s, rumble cut, normalized, +5 dB with a limiter, 0.15 s fade in, 0.4 s fade out |
| `Drawers_opening_and_closing.m4a` (Douglas Mello, own recording) | `drawer.caf`: getting dressed; the drawer thumps shut as the 3 s task ends | First open-and-close only (0.15–3.45 s), rumble cut, normalized, short fades |
| `Door_closing.m4a` (Douglas Mello, own recording) | `doorClose.caf`: leaving through the front door (winning) | First 1.15 s, rumble cut, normalized, 0.2 s fade out |
| `Baby_cry.m4a` (Douglas Mello, own recording) | `babyCry.caf`: the baby waking up (losing) | Rumble cut, normalized, 0.7 s fade out because the recording ends mid-cry |
| `Dog_barking.m4a` (Douglas Mello, own recording) | `bark.caf`: the dog barking | Rumble cut, normalized, 0.2 s fade out because the recording ends mid-bark |
| `Fridge_open-close.m4a` (Douglas Mello, own recording) | Part of `lunch.caf`: the fridge opening, 0–0.85 s | Opening only (0.10–1.15 s), rumble cut, +13.2 dB, fades. The closing thump at 2.6 s isn't used |
| `Cutting_board.m4a` (Douglas Mello, own recording) | Part of `lunch.caf`: chopping, 0.85–2.4 s | 0.55–2.25 s, rumble cut, +2.5 dB, fades |
| `Silverware_drawer.m4a` (Douglas Mello, own recording) | Part of `lunch.caf`: drawer rattle and clang, 2.4–3.95 s | 0.20–1.75 s, rumble cut, +2.6 dB, fades |
| `Spoon_drop.m4a` (Douglas Mello, own recording) | `spoon.caf`: dropping a spoon while packing lunches (random); plays over the lunch sound | Rumble cut, normalized, +3 dB with a limiter (peak −2.5 dB), 0.25 s fade out |
| `Grilling_food.m4a` (Douglas Mello, own recording) | Not used yet | — |
| `Dirty_dishes_clanging.m4a` (Douglas Mello, own recording) | Not used yet | — |
| `Game_song.m4a` (Doug Mello, own composition, GarageBand for iOS) | `Audio/Music/theme.m4a`: title jingle on the start screen | Dropped the first 6.98 s of silence, normalized (peak −1.5 dB), 0.5 s fade out, cover art and metadata removed, stereo AAC 192 kb/s |

Sound effects are trimmed, converted to mono 44.1 kHz `.caf`, with rumble cut below 80 Hz (`highpass=f=80`) and loudness evened out (`loudnorm`). For example, to redo the first creak with ffmpeg:

```sh
ffmpeg -i SoundSources/Floor_squeak_3.m4a -ss 0.06 -t 1.38 -ac 1 -ar 44100 \
  -af "highpass=f=80,loudnorm=I=-20:TP=-1.5:LRA=11,volume=6dB,alimiter=limit=0.84,afade=t=in:d=0.01,afade=t=out:st=1.28:d=0.1" \
  -c:a pcm_s16le DontWakeTheKids/Audio/Sounds/creak.caf
```

`lunch.caf` is the three lunch recordings mixed in sequence with slight overlaps (fridge at 0 s, chopping from 0.85 s, drawer from 2.4 s), each set to an exact volume, then a limiter, cut to 4.0 s to match the task.

For sounds you didn't record yourself, note the source and license here.
