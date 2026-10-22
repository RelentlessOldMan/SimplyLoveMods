# SimplyLoveMods

Quality-of-life mods for the [Simply Love](https://github.com/Simply-Love/Simply-Love-SM5) StepMania theme: a one-press "Just Play" start, a remembered speed mod, a pause menu, live projected/max score with star-pace colors, and session stats on the song select screen.

Built for **Simply Love 5.3.0 on StepMania 5.1**. The files are drop-in replacements laid out like the theme. Copy them over your theme folder and you're done.

## What's in it

### Title menu: Just Play
A new **Just Play** item, selected by default, which skips the usual Gameplay → color → 1 Player → ITG → Regular screens. One press of Start takes you straight to song select: one player, ITG mode, your last theme color.

### Your speed mod sticks
Simply Love normally saves your options only after you finish a song, so a mod set and then quit (or set and then the game closed) was lost. Now your profile is saved when you leave the options screen and again when each song starts. Set M320 once and it's there next time, even after a restart. This needs a local profile (Options → Manage Local Profiles).

### Gameplay
- **PROJ**: the score you'll finish with if you keep playing like you have so far (points so far ÷ points possible so far).
- **MAX**: the best score still reachable if everything left is perfect. It can only go down.
- Both are drawn as big as the score next to it, and change color with star pace, using the theme's full-combo colors:

  | At least | Color | Stars |
  |---|---|---|
  | 99% | blue | 3–4 |
  | 98% | gold | 2 |
  | 96% | green | 1 |

  With two players there's less room, so they're shown small beside each score.
- The song bar reads **"Song Title, 138 bpm, 42%"**: current BPM (with the rate, if any) and how much of the song is done. It replaces the separate BPM number. Split BPMs for two players still use the old display.

### Pause menu
Spacebar (or Select) pauses the song and opens a small menu: **Resume**, **Restart Song** and **Exit to Song Select**. You can drive it from the keyboard or the pad. Back or Spacebar resumes.

### Song select header
- **Session steps** (`hit/total` for everything you've played since starting the game, where hits count any timing window and misses count against you; mines don't count) next to the theme's session timer, both evenly spaced across the header.

### Heart-rate feed (optional, off by default)
For [HeartRateMonitor](https://github.com/RelentlessOldMan/HeartRateMonitor): writes song begin/end, pause and resume events as small JSON files to `Save/HeartRate/events/`, so the app can split your heart-rate recording by song. It's **off unless the folder `Save/HeartRate/` exists**. Create that folder (in `%APPDATA%\StepMania 5.1\` on Windows) to turn it on.

If a simfile has a `//HRM-SEGMENTS {json}` comment line before its first `#NOTES`, those segments are sent instead of the theme's stream/break detection. See `Scripts/SL-HeartRate.lua` and `BGAnimations/ScreenGameplay overlay/HeartRate.lua` for the format.

## Install

1. Have Simply Love **5.3.0** installed. On Windows it's usually `%APPDATA%\StepMania 5.1\Themes\Simply Love`.
2. **Back up that folder.**
3. Copy everything inside this repo's `mods/Simply Love/` over it, replacing files.
4. Restart StepMania.

A few files (`metrics.ini`, `Languages/en.ini`, `Scripts/SL_Init.lua`, and some gameplay/options Lua) are whole-file replacements of the 5.3.0 originals. Copying them over a different theme version, or over your own edits, will undo those. To uninstall, restore your backup.

## Files

| File | |
|---|---|
| `BGAnimations/ScreenQuickStart overlay.lua` | new: Just Play setup |
| `BGAnimations/ScreenGameplay overlay/PauseMenu.lua` | new: pause menu |
| `BGAnimations/ScreenGameplay overlay/SessionSteps.lua` | new: session step totals |
| `BGAnimations/ScreenGameplay overlay/HeartRate.lua` | new: heart-rate events |
| `BGAnimations/ScreenGameplay underlay/PerPlayer/ScoreProjection.lua` | new: PROJ / MAX |
| `Scripts/SL-HeartRate.lua` | new: heart-rate event writer |
| `Scripts/SL-SaveProfilesNow.lua` | new: early profile save |
| `BGAnimations/ScreenGameplay overlay/default.lua` | changed: loads the above |
| `BGAnimations/ScreenGameplay underlay/default.lua` | changed: loads PROJ / MAX |
| `BGAnimations/ScreenGameplay underlay/Shared/SongInfoBar.lua` | changed: title, bpm, % |
| `BGAnimations/ScreenGameplay underlay/Shared/BPMDisplay.lua` | changed: hidden when the bar shows bpm |
| `BGAnimations/ScreenPlayerOptions overlay/default.lua` | changed: saves on leaving |
| `Graphics/ScreenSelectMusic header.lua` | changed: session timer + steps |
| `Scripts/SL_Init.lua` | changed: session step counter |
| `metrics.ini`, `Languages/en.ini` | changed: Just Play menu item |

## License

GPL-3.0, the same as Simply Love, which these files are modified from. See [LICENSE](LICENSE). Simply Love is by its [original authors and contributors](https://github.com/Simply-Love/Simply-Love-SM5).
