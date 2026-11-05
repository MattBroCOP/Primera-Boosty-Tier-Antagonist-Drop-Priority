These original body sprites come from [DS13-2.0](https://github.com/DS-13-Dev-Team/DS13-2.0), commit `4c8813536f72a1e2efafb661b62821bb62a5a514`.

DS13's [asset license statement](https://github.com/DS-13-Dev-Team/DS13-2.0/blob/4c8813536f72a1e2efafb661b62821bb62a5a514/README.md#license) licenses icons under [Creative Commons Attribution-ShareAlike 3.0](https://creativecommons.org/licenses/by-sa/3.0/) unless otherwise indicated. Retain this attribution and license when redistributing or adapting these assets.

| Local file | Original file under `deadspace/icons/necromorphs/` |
| --- | --- |
| `slasher.dmi` | `slasher/fleshy.dmi` |
| `twitcher.dmi` | `twitcher.dmi` |
| `hunter.dmi` | `hunter.dmi` |
| `brute.dmi` | `brute.dmi` |
| `spitter.dmi` | `puker/puker.dmi` |
| `exploder.dmi` | `exploder/exploder.dmi` |

The six body DMI files listed above are unmodified binary copies; only their locations and the Puker file's local role name changed. Their original states, directions, frame timing and animation data are preserved. The Paradise mutation code uses the bodypart states, not the interface `preview` state.

## Melee interface and swing assets

These assets are credited to the DS13-2.0 contributors and use the same pinned source commit and [CC BY-SA 3.0 license](https://creativecommons.org/licenses/by-sa/3.0/) cited above.

- `hunter_swing.dmi` is an unmodified binary copy of [`deadspace/icons/necromorphs/swinging_limbs.dmi`](https://github.com/DS-13-Dev-Team/DS13-2.0/blob/4c8813536f72a1e2efafb661b62821bb62a5a514/deadspace/icons/necromorphs/swinging_limbs.dmi). The entire original 128 by 128 DMI sheet, including its states, directions and animation metadata, is preserved. The mutation uses its `hunter_left` and `hunter_right` states.
- `melee_hud.dmi` is a derivative distributed under **CC BY-SA 3.0**. Its twelve 32 by 32 interface states adapt the original body-arm artwork listed above: the SOUTH direction's first frame of `slasher_l_arm` / `slasher_r_arm`, `twitcher_l_arm` / `twitcher_r_arm`, `hunter_l_arm` / `hunter_r_arm`, `brute_l_arm` / `brute_r_arm`, `puker_l_arm` / `puker_r_arm`, and `exploder_r_arm`. Each arm is cropped to its nontransparent pixels, fitted proportionally inside 28 by 28 pixels with nearest-neighbor scaling, and centered on a transparent canvas with at least two pixels of padding. No artwork was redrawn or recolored. Both `exploder_left` and `exploder_right` reuse the free right arm; the explosive left-arm pustule is not represented as a melee weapon. The Puker-derived HUD states use the local form name `spitter`.

SHA-256:

- `hunter_swing.dmi`: `f9cbbc86f8863fdd475d2dc2a1d470a06b57a8b6e718bc2d5bfd1c26f629dcff`
- `melee_hud.dmi`: `d03c9b5feb6c01e3a85052d4f3a9f3c8fce165e00ce7a61ff6b2c820bf51456c`
