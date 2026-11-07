# Bundled reader fonts

`google_fonts` 6.3.3 resolves these exact asset basenames with runtime fetching
disabled. The regular file supplies each body face; Flutter synthesizes emphasis
where a bundled family has no separate weight or italic. Existing Literata,
Source Serif 4 and Cormorant Garamond assets remain unchanged.

Added from google/fonts (HEAD `86aced91de05cd4f96a06838124cca45be337b2b`):

| App asset | Upstream path | SHA-256 |
| --- | --- | --- |
| OldStandardTT-Regular.ttf | ofl/oldstandardtt/OldStandard-Regular.ttf | 42717a1280b523a506ca2b0285cca380e77fe214b1f6e3d75a8b925005f19eac |
| Kurale-Regular.ttf | ofl/kurale/Kurale-Regular.ttf | 6055aaca6870ca64210dd81fa47f8bb71595a9c8fbe570351ed45a15f1a0820d |

Each adjacent `OFL-*.txt` is the upstream SIL Open Font License, registered through
`LicenseRegistry` in `main.dart`. The file basename for Old Standard TT matches
Google Fonts' `OldStandardTT` loader name; the font itself is unmodified.
`test/bundled_fonts_test.dart` checks the actual cmap mappings for ў/Ў, і/І, ё/Ё.
