# Third-party notices

## Adapted print utilities

`kosovo_cards/vendor/layout.py` adapts geometry and word wrapping from:
https://github.com/martin-maly/flashcards (`src/layout.py`, `src/generator.py`).
Copyright (c) 2024 Martin Maly. MIT license retained in `kosovo_cards/vendor/LICENSE-flashcards`.
Changes are described in the module header. The upstream project is not affiliated with this tool.

## Artwork

Twemoji graphics: Copyright Twitter, Inc. and contributors. Licensed under Creative Commons Attribution 4.0 International (CC BY 4.0): https://creativecommons.org/licenses/by/4.0/
Source: https://github.com/jdecked/twemoji/tree/v15.1.0/assets/svg
Full license: `kosovo_cards/assets/images/LICENSE-Twemoji`.
Per-asset source URLs: `kosovo_cards/assets/images.json`.

Original SVGs are retained. The bundled PNGs are conversions to 512 × 512 pixels with transparency; no intentional changes to artwork. Display scaling is applied when printing. Credits appear in the review report and PDF footers. Retain these notices and the relevant credits when redistributing artwork or cards. New user-supplied images retain their own licenses; metadata records attribution but does not grant rights.

## Fonts

Bitstream Vera regular and bold fonts are bundled for reliable Albanian ë/ç rendering. Copyright (c) 2003 Bitstream, Inc. All rights reserved. Bitstream Vera is a trademark of Bitstream, Inc. Font license: `kosovo_cards/assets/fonts/bitstream-vera-license.txt`.

## Runtime libraries

ReportLab: BSD license, https://pypi.org/project/reportlab/
Pillow: MIT-CMU license, https://python-pillow.github.io/
These dependencies retain their own distributed licenses; this source archive does not bundle their implementations.
