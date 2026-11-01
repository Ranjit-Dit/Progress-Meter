# Progress Meter icon

The cream gauge represents measured progress. The rising line and lime milestone represent learning toward a target. Forest green matches the app’s interface.

`progress-meter.svg` is the vector master and `progress-meter.png` is its full-resolution preview. Both are generated from the single vector definition in `tool/branding/generate_app_icons.swift`, along with every iOS, macOS, and Android icon size. To regenerate from the project root on a Mac:

```sh
swift tool/branding/generate_app_icons.swift
```

iOS PNGs have an opaque square background; iOS applies its own corner mask. macOS and legacy Android PNGs have a rounded background and transparent outer margin. Native asset catalogs retain their original filenames and size mappings.
