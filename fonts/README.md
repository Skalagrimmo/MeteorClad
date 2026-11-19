# Noto Sans Regular

MeteorClad uses **Noto Sans Regular** for its UI so Ukrainian Cyrillic characters render correctly on systems where the LÖVE default font lacks those glyphs.

## Required asset

Download the official static TTF:

https://notofonts.github.io/latin-greek-cyrillic/fonts/NotoSans/hinted/ttf/NotoSans-Regular.ttf

Save it in this directory with this exact name:

`NotoSans-Regular.ttf`

The game loads it from `main.lua` at startup. If the file is missing, the game falls back to the LÖVE default font and logs a warning instead of crashing.

## License and attribution

The font is distributed under the SIL Open Font License 1.1. Keep `OFL.txt` beside the font when redistributing it.

Copyright 2022 The Noto Project Authors:
https://github.com/notofonts/latin-greek-cyrillic
