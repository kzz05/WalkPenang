# WalkPenang

Flutter + Firebase mobile application promoting walking tourism in Penang, Malaysia.

## Branches

| Branch | Purpose | Owner |
|---|---|---|
| `main` | Release version — the stable build for real users. | Team |
| `master` | Integration and testing branch. All modules are combined and tested here before release. | Team |
| `dataset` | Destination and attraction seed data for Firestore. | |
| `User-Authentication-&-Profile-Module` | Module 1 — registration, login, and user profile management. | Ian Wong Jing Li |
| `Food-&-Attraction-Discovery-Module` | Module 2 — search, filter, view, save. | Ong Song Wei |
| `Map-&-GPS-Module` | Module 3 — map display, route plotting, and GPS navigation. | Tang Yue Hann |
| `Walking-and-Carbon-Module` | Module 4 — transport mode selection, pre-walk summary, carbon savings, calorie estimation, destination proximity verification, and walking journey completion. | Poon Wei Seng |
| `Reward-and-Achievement-Module` | Module 5 — points awarding, badge unlocking, walking journal, and statistics dashboard. | Tang Khuan Zhi |

## Module ownership

Five modules, one owner each. Never edit files belonging to another module
without being told to explicitly.

| Module | Prefix | Responsibility |
| --- | --- | --- |
| User & Profile | `user` | Registration, login, logout, profile view and edit |
| Destination & Attraction | `dest` | Destination listing, search, filter, detail view |
| Route & Navigation | `route` | Map display, route generation, turn-by-turn directions |
| Walking & Carbon | `walk` | Transport mode selection, GPS tracking, arrival verification, carbon and calorie calculation |
| Reward & Achievement | `reward` | Points, badges, walking journal, statistics dashboard |

**The boundary most often violated:** Walking & Carbon owns GPS retrieval,
arrival verification, and the carbon/calorie formulas. Reward & Achievement owns
points and badges. Reward receives a completed, verified journey and never
computes distance, carbon, or calories itself. Do not blur these.

---

## Folder structure

Place every new file according to its MVC layer. Do not invent new top-level
folders.

```
lib/
├── main.dart
├── models/                  # plain data classes, fromMap / toMap only
├── views/
│   ├── user/
│   ├── destination/
│   ├── route/
│   ├── walking/
│   └── reward/
├── controllers/             # one controller per module
├── services/                # firestore_service.dart, auth_service.dart,
│                            # location_service.dart, maps_service.dart
├── widgets/                 # reusable widgets shared across modules
└── utils/                   # constants.dart, formatters.dart, validators.dart

test/                        # mirrors lib/ exactly
```

---

## Layer rules

These are the rules most likely to be broken by generated code. Check each one
before returning a file.

- **Views contain no logic.** No arithmetic, no conditionals on business rules,
  no Firestore calls. A View builds UI and calls a Controller method.
- **Views never import `cloud_firestore`.** If a View needs data, the Controller
  supplies it.
- **Controllers contain no Firestore SDK calls.** Controllers call
  `FirestoreService`. Controllers hold the business rules.
- **Services contain no business rules.** Services read and write documents and
  return models. A service never decides whether a badge is earned.
- **Models are dumb.** Fields, a constructor, `fromMap`, `toMap`. No network
  access, no calculation beyond trivial derived getters.
- **Cross-module calls go through the Controller.** The walking controller calls
  `RewardController.awardPointsForJourney(journey)`. It never writes to the
  reward fields in Firestore directly.

---

## Firestore schema

Use exactly these collection and field names. Do not rename, do not pluralise
differently, do not add fields without being asked.

**`users`** — document ID is the Firebase Auth UID
```
name, email, photoUrl, joinedDate,
totalPoints, totalCheckIns, totalDistanceKm,
totalCarbonSaved, totalCalories
```

**`destinations`**
```
name, description, category, imageUrl,
latitude, longitude, address, openingHours
```

**`journeys`**
```
userId, destinationId, destinationName, checkInTime,
distanceKm, transportMode, carbonSaved, caloriesBurned, pointsEarned
```

**`badges`** — static definitions, seeded once
```
name, description, iconUrl, milestoneType, milestoneValue
```

**`user_badges`**
```
userId, badgeId, dateEarned
```

Rules:

- Collection names are lowercase; field names are `lowerCamelCase`.
- Timestamps are stored as Firestore `Timestamp`, never as a formatted string.
- The cumulative totals on `users` are denormalised counters, updated
  incrementally on check-in. Do not recompute them by reading every journey.
- Every query is filtered by `userId`. Never fetch a whole collection.

---

## Business rules

Hard-coded values are forbidden anywhere except `utils/constants.dart`. These
are the authoritative values — do not change or "improve" them.

| Rule | Value | Owner |
| --- | --- | --- |
| Arrival radius for a valid check-in | 100 metres | Walking & Carbon |
| Points per completed check-in | 10 | Reward |
| Bonus points | 1 point per 0.1 km walked, rounded down | Reward |
| Explorer badge | 5 check-ins | Reward |
| Trailblazer badge | 10 km cumulative | Reward |
| Penang Wanderer badge | 50 km cumulative | Reward |
| Transport modes | Walking, Public Transport, Driving | Walking & Carbon |
| Points awarded for non-walking modes | None — driving is the carbon baseline only | Walking & Carbon / Reward |

---

## Naming

| Element | Convention | Example |
| --- | --- | --- |
| Class / Widget | UpperCamelCase | `BadgeGalleryScreen` |
| File / folder | lowercase_with_underscores | `reward_controller.dart` |
| Variable / method | lowerCamelCase | `calculatePoints()` |
| Private member | leading underscore | `_evaluateMilestone()` |
| Boolean | `is` / `has` / `can` prefix | `isBadgeUnlocked` |
| Constant | lowerCamelCase with `const` | `const pointsPerCheckIn = 10;` |
| Screen class | ends in `Screen` | `StatisticsDashboardScreen` |
| Controller class | ends in `Controller` | `WalkingController` |
| Service class | ends in `Service` | `FirestoreService` |
| Model class | ends in `Model` | `JourneyModel` |
| Test file | source name + `_test` | `reward_controller_test.dart` |

---

## Formatting

- 2-space indentation. No tabs.
- Maximum 80 characters per line.
- Trailing commas on all multi-line parameter lists.
- Braces always, including single-statement `if` blocks.
- Import order: Dart SDK, Flutter, third-party packages, project files — each
  group separated by one blank line.
- Run `dart format .` on every file you produce.

---

## Code you must always write

**File header on every new file**

```dart
// ---------------------------------------------------------
// File    : reward_controller.dart
// Module  : Reward & Achievement
// Author  : <owner name>
// Purpose : Handles point calculation and badge unlock logic
// ---------------------------------------------------------
```

**DartDoc on every public class and method**, referencing the FR or use case ID
where one exists

```dart
/// Calculates points earned for a completed check-in.
///
/// 10 points per check-in plus 1 point per 0.1 km walked,
/// rounded down. See UC500 constraint C1 (FR-R01).
int calculatePoints(double distanceKm) { ... }
```

**Error handling on every Firestore and network call**

```dart
try {
  await _firestore.collection('journeys').add(journey.toMap());
} on FirebaseException catch (e) {
  debugPrint('Firestore error: ${e.code}');
  rethrow;                     // controller decides what the user sees
}
```

- The View turns a caught error into a SnackBar with plain language. Never show
  a raw exception string to the user. Never swallow an exception silently.
- **Async UI states.** Every screen that loads data handles three states:
  loading (`CircularProgressIndicator`), error (retry message), and empty (an
  encouraging message, not a blank screen). Do not ship a screen that only
  handles the happy path.

---

## Code you must never write

- `setState` inside a Controller or Service.
- Firestore imports in `views/` or `models/`.
- Magic numbers — `10`, `100`, `0.1`, `50` belong in `constants.dart`.
- Hard-coded API keys, `google-services.json`, or any credential in source.
- `print()` — use `debugPrint()`.
- Commented-out code left in a committed file.
- Placeholder or stub bodies (`// TODO: implement`) unless explicitly asked for
  a skeleton. Write working code.
- A `build()` method longer than about 50 lines — extract private sub-widgets.
- New packages in `pubspec.yaml` without saying clearly that you are adding one
  and why.
- `StatefulWidget` where a `StatelessWidget` would do.

---

## Tests

Every controller method containing a business rule needs a unit test. Tests
mirror `lib/` under `test/` and follow Arrange–Act–Assert with a descriptive
name.

```dart
test('calculatePoints returns 10 when distance is zero', () {
  // Arrange
  const distance = 0.0;
  // Act
  final result = controller.calculatePoints(distance);
  // Assert
  expect(result, 10);
});
```

- Always cover boundary cases: zero, exactly at a threshold, just below, just
  above.
- Firestore is mocked with `fake_cloud_firestore`; tests never hit a live
  database.

---

## Before you finish a task

Run through this list and state which items you checked.

- [ ] File is in the correct MVC folder for its layer
- [ ] Layer rules are not violated
- [ ] Collection and field names match the Firestore schema exactly
- [ ] Business values match the business rules table and come from `constants.dart`
- [ ] Naming conventions followed
- [ ] File header and DartDoc present
- [ ] Loading, error and empty states handled
- [ ] Nothing from "code you must never write" is present
- [ ] `dart format .`, `flutter analyze`, `flutter test` would all pass
- [ ] No file outside the requested module was modified

---

## Git

Branch from `develop`, never from `main`.

```
feature/<prefix>-<short-description>      feature/reward-badge-unlock
bugfix/<prefix>-<short-description>       bugfix/walk-gps-timeout
```

Commit format `<type>(<prefix>): <imperative summary>`

```
feat(reward): add badge unlock evaluation logic
fix(walk): correct arrival radius comparison
test(reward): add boundary tests for calculatePoints
docs(dest): document destination filter query
```

- Types: `feat` `fix` `docs` `test` `refactor` `style` `chore`
- Pull requests target `develop`, state the user story ID, and need one
  approving review.
- Do not commit `google-services.json`, `GoogleService-Info.plist`,
  `android/key.properties`, `/build/`, or `.dart_tool/`.

---

## When you are unsure

Ask rather than guess, specifically when:

- A change would touch a file outside the module you were asked to work on
- A required Firestore field does not exist in the schema above
- A business rule is needed that is not listed in the business rules table
- The request implies adding a package or changing the architecture

State the ambiguity and propose the option that stays inside these rules.
