# Gojo Brand Kit — Domain Edition

This package follows the Gojo “AI Workspace · Domain Expansion” visual system.
SVG files are the editable source assets. PNG and macOS files are deterministic
exports from those vectors.

## Directory layout

```text
BrandAssets/
├── sources/
│   ├── logo/                 # Editable logo SVG masters
│   └── wordmark/             # Editable wordmark SVG masters
├── exports/
│   ├── logo/
│   │   ├── color/            # Full-color PNG exports
│   │   └── monochrome/       # Monochrome PNG exports
│   └── wordmark/             # Horizontal PNG lockups
└── platform/
    └── macos/                # Compiled icon and source iconset
```

## Source assets

- `sources/logo/gojo-logo.svg`: full-color 1024 px master mark with a dark
  rounded tile, luminous G portal, three aggregation rings, and a blue AI core.
- `sources/logo/gojo-logo-small.svg`: optically adjusted source for 16–64 px
  rendering, with a heavier portal silhouette and reduced micro-detail.
- `sources/logo/gojo-logo-mono.svg`: monochrome dark-tile mark without filters.
- `sources/wordmark/gojo-wordmark.svg`: horizontal dark-background lockup with
  the full-color icon, white Gojo lettering, and a blue j dot.
- `sources/wordmark/gojo-wordmark-mono.svg`: horizontal light-background lockup
  with a monochrome icon and dark lettering.

## Exported assets

- `exports/logo/color/`: full-color icon at 128, 256, 512, and 1024 px.
- `exports/logo/monochrome/`: monochrome icon at 128, 256, 512, and 1024 px.
- `exports/wordmark/`: full-color and monochrome horizontal PNG lockups.
- `platform/macos/Gojo.iconset/`: complete 16–1024 px macOS iconset.
- `platform/macos/Gojo.icns`: compiled macOS app icon.

The copies under `Sources/Gojo/Resources/` are application runtime/package
resources. Keep them there; regenerate the app icon with `Scripts/make-icon.sh`.

## Brand colors

- Core Blue: `#3B82F6`
- Light Blue: `#60A5FA`
- Deep Ink: `#111827`
- Slate: `#374151`
- Cloud: `#F8FAFC`

## Usage notes

- Use the full-color master at 128 px and above.
- Use the small-size source for icons below 128 px.
- Keep the clear space around the G at least equal to the core diameter.
- Do not recolor the blue core, alter the portal opening, or add text inside
  the app tile.
- Preserve transparency outside the rounded tile.
