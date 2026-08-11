# Audio assets (placeholder stage)

`AudioService` (`lib/services/audio_service.dart`) defines every SFX hook point
the game triggers: tower placement, tower fire, enemy death, core damage, wave
start, level win/lose, UI tap.

No real audio files are committed yet. `AudioService` is defensive: a missing
file is caught and ignored so the game runs silently until real SFX are dropped
in here and registered in `AudioService.sfx`.
