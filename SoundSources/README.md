# Sound sources

Original recordings, kept as-is. These are **not** bundled into the app.
The game uses the cleaned-up versions in `DontWakeTheKids/Audio/Sounds/`.

| Recording | Used as | Processing |
|---|---|---|
| `Floor_squeak_3.m4a` (Douglas Mello, own recording) | `creak.caf`: creaky floorboards; played quietly when tiptoeing, full volume when walking | Trimmed 0.06 s of silence, rumble cut below 80 Hz, normalized, +6 dB with a limiter (peak −2 dB), short fades, mono 44.1 kHz |

To redo the processing with ffmpeg:

```sh
ffmpeg -i SoundSources/Floor_squeak_3.m4a -ss 0.06 -t 1.38 -ac 1 -ar 44100 \
  -af "highpass=f=80,loudnorm=I=-20:TP=-1.5:LRA=11,volume=6dB,alimiter=limit=0.84,afade=t=in:d=0.01,afade=t=out:st=1.28:d=0.1" \
  -c:a pcm_s16le DontWakeTheKids/Audio/Sounds/creak.caf
```

For sounds you didn't record yourself, note the source and license here.
