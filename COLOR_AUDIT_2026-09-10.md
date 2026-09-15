# Zameel Color Audit & Retheme — 2026-09-10

## Result
- Audited all 55 Dart files under `lib/`.
- Centralized the visual palette in `lib/theme/app_theme.dart`.
- Replaced the old repeated teal/navy/purple/yellow/grey design colors with shared `AppTheme` tokens.
- Removed direct design use of `Colors.grey`, `Colors.pink`, and `Colors.purple`.
- Kept red/green/orange/transparent/white/black where they serve semantic states, contrast, glass overlays, or shadows rather than primary branding.
- Preserved the graduation book as a distinct warm-paper surface, but moved its full palette into shared theme tokens so it remains visually coordinated with Zameel.
- Fixed the generated `Color(AppTheme.token)` patterns so theme tokens are used directly as `Color` values.

## Theme groups
- Brand: primary teal, deep teal text, soft mint.
- Supporting: teal-family secondary/accent; no unrelated purple/yellow as UI branding.
- Neutrals: warm-light background, white surface, soft mint-grey surface, single border color.
- Semantic: success, warning, error.
- Glass: centralized white transparency tokens.
- Graduation: centralized paper, earth, teal, border, and shadow tokens.

## Remaining raw colors outside theme
- `0XFF16A34A`: 1
- `0X811C9DC5`: 1
- `0X01000193`: 1
- `0XFFFFFFFF`: 1

## Remaining direct Colors.* design names outside theme
- `Colors.white`: 350
- `Colors.white70`: 123
- `Colors.red`: 59
- `Colors.green`: 37
- `Colors.black`: 34
- `Colors.transparent`: 29
- `Colors.white60`: 25
- `Colors.orange`: 15
- `Colors.white24`: 13
- `Colors.white54`: 9
- `Colors.redAccent`: 5
- `Colors.black87`: 4
- `Colors.white38`: 3
- `Colors.black54`: 2
- `Colors.black45`: 2
- `Colors.white10`: 1
- `Colors.black12`: 1
- `Colors.black26`: 1
