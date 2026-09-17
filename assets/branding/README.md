# Branding assets

- `app_logo.png` — the BOZKRI wordmark (gold on black), cropped from the
  supplied artwork. Used at its own aspect ratio (not forced square) by
  `AppLogo` (`lib/view/core/widgets/app_logo.dart`), currently shown in the
  side-nav header. Falls back to a generic icon if this file is ever removed.
- `app_icon_source.png` — a square, tightly-cropped version of just the
  bird/plane glyph (no wordmark text, since "BOZKRI" is illegible at 16–32px)
  on the same black background. This is the source `flutter_launcher_icons`
  reads from — see the `flutter_launcher_icons:` block in `pubspec.yaml`.
- `logo.jpeg` — the original supplied screenshot, kept for reference /
  re-cropping if the logo ever changes. Not read by the app or the icon
  generator.

## Regenerating native app icons

Whenever `app_icon_source.png` changes:

```bash
dart run flutter_launcher_icons
```

This already regenerated the macOS icon set in
`macos/Runner/Assets.xcassets/AppIcon.appiconset/`. It could **not** generate
the Windows icon in this checkout because the `windows/` platform folder
doesn't exist here yet (see [SETUP.md](../../SETUP.md) — run
`flutter create . --platforms=macos,windows` once first). On a machine that
has `windows/`, just rerun the same command above and it will also produce
`windows/runner/resources/app_icon.ico`.

## Splash screen

Flutter desktop has no built-in splash-screen API the way mobile does (no
native launch screen to theme) — there isn't a separate splash asset to wire
up here. The side-nav wordmark is the closest equivalent and is already live.
