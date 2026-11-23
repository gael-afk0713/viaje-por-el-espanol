# Design

## World: travel postcard

The interface reads like the papers a traveller collects: postcards, luggage labels, and passport stamps. Each country is a stamp in the menu. Conversations and the album are postcards with airmail stripes. Finishing a level is a "¡Saludos desde…!" postcard with a red postmark.

## Color (`main.gd` constants)

| Token | Hex | Use |
|---|---|---|
| PAPER | `#f4ead5` | Every card, panel, and secondary button |
| PAPER_2 | `#e6d7b6` | Pressed paper, scroll track |
| INK | `#1d2840` | Main text, primary button |
| INK_2 | `#55607a` | Secondary text on paper (≥4.5:1) |
| STAMP | `#b8322a` | The regional word, name tags, postmarks, jump button, errors |
| GREEN | `#2f6f34` | Correct answer |
| NIGHT | `#142033` | Menu background, overlay dim |
| PAPER_DIM / PAPER_FAINT | `#d9d2c2` / `#a3acbf` | Text on NIGHT |

Rules:
- The regional word is always STAMP red and bold. Nothing else uses that combination.
- The school logo has white lettering, so it only goes on NIGHT surfaces.

## Type

- **Display:** Alfa Slab One. Used for country names, titles, and name tags.
- **Text:** Atkinson Hyperlegible, regular and bold. It was chosen for first-time readers on an iPad.
- Fonts are in `assets/fonts/`, under the OFL license.
- Sizes: dialogue 28–30, answers 26, body 20–22, labels 13–17.

## Components

- `_button(kind)`:
  - `ink` is the primary action.
  - `paper` is secondary, with a 2 px ink outline.
  - `answer` is a 74 px tall answer card with a 3 px outline. It turns solid green when correct and fades out when wrong.
  - Every button is at least 52 px tall.
- `_postcard()`: a paper panel with an airmail band (`scripts/ui/airmail.gd`) at the top and bottom.
- `_name_tag()`: a red label with the speaker's name.
- `scripts/ui/stamp_face.gd`: the menu stamp. It has perforated edges, a flag, three progress dots, and a "¡HECHO!" postmark.
- `scripts/ui/flag.gd`: simplified striped flag with a canton.
- `scripts/ui/postmark.gd`: a double circle, tilted, with text that shrinks to fit.
- Touch controls (`scripts/touch_controls.gd`):
  - Arrows sit on paper discs.
  - Jump is a red disc. Attack (ATACAR) is an ink disc with a sword glyph.
  - The shadow disappears when a control is pressed.

## Elevation and motion

- Shadows sit 5 px down with a 12 px blur.
- Panels use only a shadow.
- Outlined buttons keep the shadow as lift, and lose it when pressed.
- The one motion is an exponential fade on toasts and on the question line. Text types out with the existing typewriter effect.

## Start screen, saves, settings

- **Start screen** (`_build_title`):
  - A real level from a random country plays behind the screen, with the camera panning slowly (`level.attract`).
  - A NIGHT gradient on the left carries the title and the button stack.
  - Buttons: Jugar (`stamp`), Cargar partida (`paper`), Configuración and Salir (`ghost`). Each has a PT hint beside it.
  - There is a "21 PAÍSES" postmark and a tag naming the country in view.
  - The one entrance motion is the left column sliding in.
- **Saves** (`_build_slots`):
  - Three postcards, one per save. Each has a passport of the 21 countries (`scripts/ui/passport.gd`), the word count, completed countries, and when it was last played.
  - Data lives in `user://partida_N.cfg`. The old `progreso.cfg` is migrated into Partida 1.
  - "Borrar" asks for a second tap before deleting.
- **Settings** (`_build_settings`, saved in `user://ajustes.cfg`):
  - Voice volume slider.
  - Segmented controls for text speed, graphics quality (`LevelScript.quality_mode`), touch buttons (`TouchControls.mode`), and fullscreen.

