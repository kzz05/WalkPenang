# WalkPenang

Flutter app for walking around Penang: maps and GPS, food and attraction
discovery, walking and carbon tracking, and a rewards/badge system.

This branch (`in-develop`) is the integration branch where the per-module
feature branches are merged. Branch off it, not off `main`.

## Structure

| Folder | Layer | Contents |
|---|---|---|
| `lib/models/` | Model | Profile, places, search filters, transport mode, walking/journey state, badges, points |
| `lib/controllers/` | Controller | Per-module flow control — home, onboarding, OTP, discovery, map, walking, reward |
| `lib/views/` | View | Screens; `views/reward/` groups the reward screens, `views/widgets/` holds the shared `wp_components.dart` kit |
| `lib/widgets/reward/` | View | Reward components — badge card, emblem, unlock/points notifications, stat card |
| `lib/services/` | Service | Auth, OTP, profile store, place repository/filter, location, map, routes, navigation launcher |
| `lib/dao/` | DAO | Firestore read/write access — models never call Firestore directly |
| `lib/utils/`, `lib/constants/`, `lib/theme/` | — | Milestone thresholds, formula constants, app theme |
| `test/` | — | Mirrors `lib/`: `test/controllers/`, `test/models/`, `test/views/`, `test/reward/` |

## Coding Standards

Dart Style Guide + `flutter_lints`. Code must pass `flutter analyze` before commit.

- Classes `UpperCamelCase` · files `lowercase_with_underscores` · members `lowerCamelCase`
- Private members prefixed with `_`; booleans prefixed with `is` / `has` / `can`
- 2-space indent, 80-char lines, trailing commas on multi-line widget parameters
- No business logic in View classes — delegate to `RewardController`
- No magic numbers — all thresholds and formulas live in `utils/constants.dart`
- All Firestore calls wrapped in `try–catch`; errors shown to the user as a SnackBar
- `///` DartDoc on every public class and method; no commented-out code committed

Run before every commit:

```bash
dart format .
flutter analyze
flutter test
```

---

## Branch & Commit Convention

Branch off `develop`, never off `main`:

```bash
git checkout develop && git pull origin develop
git checkout -b feature/reward-badge-unlock
```

Naming: `feature/reward-<short-description>` · `bugfix/reward-<short-description>`

Commit format `<type>(reward): <imperative summary>`

```
feat(reward): add badge unlock evaluation logic
fix(reward): correct points rounding for 0.1km increments
test(reward): add unit tests for calculatePoints()
docs(reward): update use case descriptions UC500-UC530
```

Types: `feat` `fix` `docs` `test` `refactor` `style` `chore`

---

## Pull Requests

1. PR targets `develop`, never `main`.
2. Title states the user story ID (e.g. `US-R02`).
3. Include a screenshot for any UI change.
4. One approving review required from another member before merge.
5. Must not be merged with failing `flutter analyze` or `flutter test`.
6. Merge conflicts are resolved by the branch author, locally, before merging.
7. Delete the feature branch after merge.

---

## Testing

Unit tests mirror the `lib/` structure under `test/` and follow
Arrange–Act–Assert. Minimum coverage before a PR is opened:

- `calculatePoints()` — zero distance, partial 0.1 km, exact boundary, large distance
- Badge evaluation — below threshold, exactly at threshold, above threshold, already unlocked
- Empty-state handling for the journal and dashboard

```bash
flutter test
```
