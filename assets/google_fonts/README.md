# Bundled reader fonts

`google_fonts` 6.3.3 resolves these exact asset basenames with runtime fetching
disabled. Old Standard TT includes genuine regular, bold and italic faces;
Kurale has the upstream regular face (Flutter synthesizes other styles).
Existing Literata,
Source Serif 4 and Cormorant Garamond assets remain unchanged.

Added from google/fonts (HEAD `86aced91de05cd4f96a06838124cca45be337b2b`):

| App asset | Upstream path | SHA-256 |
| --- | --- | --- |
| OldStandardTT-Regular.ttf | ofl/oldstandardtt/OldStandard-Regular.ttf | 42717a1280b523a506ca2b0285cca380e77fe214b1f6e3d75a8b925005f19eac |
| OldStandardTT-Bold.ttf | ofl/oldstandardtt/OldStandard-Bold.ttf | 7d831e9d799ad23ee98e889381a9db2a283b2dac7f228dd5c06071decb9c54db |
| OldStandardTT-Italic.ttf | ofl/oldstandardtt/OldStandard-Italic.ttf | 4b9522f4711317fc06e2413a58b4662c249cb707df193d682b9d640e365ef564 |
| Kurale-Regular.ttf | ofl/kurale/Kurale-Regular.ttf | 6055aaca6870ca64210dd81fa47f8bb71595a9c8fbe570351ed45a15f1a0820d |

Each adjacent `OFL-*.txt` is the upstream SIL Open Font License, registered through
`LicenseRegistry` in `main.dart`. The file basename for Old Standard TT matches
Google Fonts' `OldStandardTT` loader name; the font itself is unmodified.
`test/bundled_fonts_test.dart` checks the actual cmap mappings for ў/Ў, і/І, ё/Ё.
