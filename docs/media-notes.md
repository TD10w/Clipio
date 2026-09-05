# Public media inventory

Reviewed on 2026-09-05. This is an inventory, not a blanket clearance of all assets.

| Asset | Finding | Public presentation |
| --- | --- | --- |
| `docs/screenshots/clipio-shelf.png`, `clipio-search.png` | Current dark UI from the app source in `v2.6.1-beta.1`, isolated in-memory UI-test mode; native PNG captures with alpha preserved, visually checked with synthetic text and a public repository URL | Used in both READMEs |
| `Designs/Clipio-Demo/assets/clipio-shelf-reference.jpg` | Visually checked: sample product text and a public developer URL; earlier layout | Historical reference; replaced in the READMEs |
| `Designs/Clipio-Demo/` | 20-second reconstructed animation source; `renders/` currently has no exported video | Export after checking every shot and audio provenance; label as a product animation |
| `Designs/App-Store/00-AppPreview.mov` | Sampled frame shows the old vertical Maccy UI | Do not present as a Clipio demo |
| `Designs/App-Store/*.pxd`, `Promo/*.psd`, other legacy design sources | Inherited source assets; redistribution provenance not established by this review | Retain provenance; review before reusing in marketing |
| `Designs/Clipio-Demo/assets/fonts/*.woff2` | Geist / Geist Mono; license file was missing | Confirm exact font provenance and include the corresponding OFL license before redistributing the demo |
| `Designs/Clipio-Demo/assets/clipio-soundbed.m4a` | Music provenance/license not documented | Obtain source/permission or export without the soundtrack |
| `output/` and other demo image assets | Design experiments; not all images individually inspected | Do not treat as a privacy-reviewed screenshot set |

Geist's upstream license is available at [vercel/geist-font](https://github.com/vercel/geist-font/blob/main/LICENSE.txt). Confirm that it corresponds to the bundled files. The repository's MIT code license does not establish rights to unrelated assets.

## Minimum useful launch set

1. A real current-build shelf screenshot with invented text, an image, and a color card.
2. A second screenshot showing search or image preview; include light/dark variants only if useful.
3. A short silent demo (roughly 15–25 seconds): copy → open → search → select → paste → pin.

Capture with a clean sample clipboard, hide notifications and account names, and inspect the full frame for filenames and private text. Record the build commit. Check the rendered video from beginning to end; a safe sample frame is not clearance for a whole recording.

Use a lightweight PNG/JPEG in the README, optionally a short GIF. Put the MP4 in Release assets and link it from the README or use a GitHub attachment in a suitable discussion/issue. Do not assume a repository `.mov` link will play inline in README rendering. Keep large generated renders out of Git history.
