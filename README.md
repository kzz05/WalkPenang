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
nickname, email, phoneNumber, photoUrl, joinedDate,
heightCm, weightKg, unitPreference,
totalPoints, totalCheckIns, totalDistanceKm,
totalCarbonSaved, totalCalories
```

**`favorites`** — subcollection under `users/{uid}/favorites`
```
placeId, placeName, category, latitude, longitude, savedAt
```

**`reviews`**
```
userId, placeId, rating, comment, timestamp
```

**`journeys`**
```
userId, destinationId, destinationName, checkInTime,
distanceKm, transportMode, carbonSaved, caloriesBurned, pointsEarned
```

**`badges`** — static definitions, seeded once
```
badgeId, name, description, iconUrl, milestoneType, milestoneValue
```

**`user_badges`**
```
userId, badgeId, badgeName, description, dateEarned
```

Rules:

- Collection names are lowercase; field names are `lowerCamelCase`.
- Timestamps are stored as Firestore `Timestamp`, never as a formatted string.
- Place data comes live from the Google Places API and is **not** mirrored into
  Firestore. Only the `placeId` and minimal display metadata are persisted.
- The cumulative totals on `users` are denormalised counters, updated
  incrementally on check-in. Do not recompute them by reading every journey.
- Every query is filtered by `userId`. Never fetch a whole collection.
- Firestore security rules restrict every read and write to the currently
  authenticated user's own documents.

---

## Business rules

Hard-coded values are forbidden anywhere except `utils/constants.dart`. These
are the authoritative values, taken from the approved use case descriptions — do
not change, round, or "improve" them.

### User & Profile

| Rule | Value |
| --- | --- |
| Password minimum length | 6 characters |
| Email format | Validated before any Firebase call |
| Registration behaviour | One combined form. If the email is new, create the account; if it already exists, automatically retry as a sign-in with the same credentials rather than showing an error |
| New account side effect | An empty Firestore profile document is created |
| Email verification method | 6-digit OTP issued and validated server-side via Cloud Function; the client refreshes its ID token afterwards |
| OTP resend cooldown | 30 seconds |
| OTP rejection reasons | Incorrect, expired, already consumed, or too many attempts |
| Google Sign-In accounts | Pre-verified — skip the email verification step entirely |
| Password accounts | Unverified accounts are routed to the Verify Email screen before any other destination |
| Routing after verification | Home screen, or the profile-setup form if the profile is incomplete |
| Editable profile fields | Nickname, contact number, avatar, height, weight, measurement unit |
| Avatar storage | Picked image is held locally until save, then uploaded to Firebase Storage; only the download URL is written to Firestore |
| Profile persistence | Written to both the local cache and Firestore on every save |
| Profile validation | Required fields non-empty; height and weight must be valid numbers |
| Logout | Requires a confirmation dialog, then clears the local cache, signs out of Google (if used) and Firebase, and clears the navigation history |

### Destination & Attraction

| Rule | Value |
| --- | --- |
| Search inputs | Keyword plus the user's current GPS coordinates |
| Result ordering | Ranked by relevance and proximity |
| Empty search query | Show a default list of popular nearby food spots and attractions — never an error |
| Categories | Cafe, Historic Site, Local Street Food, Museum |
| Filter scope | Applied to the active query within the current search radius |
| Place details source | Google Places / Yelp / TripAdvisor API — never cached as the source of truth |
| Review source | Cloud Firestore, keyed by place ID |
| Favourites | Require an authenticated user; tapping an already-saved place removes it |
| Rating scale | 1–5 stars, mandatory before submission |
| Review comment | Must meet the minimum length before submission is accepted |
| Review payload | userId, placeId, rating, comment, timestamp |
| Rating aggregate | Overall average is recalculated when a review is submitted |

### Route & Navigation (Map & GPS)

| Rule | Value |
| --- | --- |
| Search radius options | 1 km, 2 km, 5 km |
| Pin types | Food establishments and tourist attractions only |
| Geographic restriction | The map is restricted to the Penang boundary at all times |
| Boundary definition | A fixed `LatLngBounds` constant in `utils/constants.dart` |
| Boundary enforcement | `cameraTargetBounds` restricts panning; validation applies to both the user's location and every selected destination |
| Destination outside Penang | Selection is rejected, not silently corrected |
| GPS package | Flutter Geolocator, via the device GPS service |
| GPS updates | Continuous and real time while the map screen is active |
| GPS accuracy | Readings below the accuracy threshold are flagged; timeouts end the use case |
| Route units | Distance in kilometres, duration in minutes, from the Directions API walking-mode response |
| Navigation | Launched externally through a Google Maps deep link built from the destination coordinates, opened with `url_launcher` |
| Maps API key | Configured in `AndroidManifest.xml`; never inlined in Dart source |
| Module boundary | This module does not calculate carbon or calories, and does not perform check-in verification or award points |

### Walking & Carbon

| Rule | Value |
| --- | --- |
| Transport modes | Walking, Driving, Public Transport |
| Mode selection | Exactly one mode per journey |
| Feature gating | Carbon, calorie, journey completion, and reward features are enabled **only** when Walking is selected |
| Carbon formula | `carbonSaved = distanceKm × 0.21` kg CO₂, using average private car emissions as the baseline |
| Calorie formula | `caloriesBurned = distanceKm × weightKg × 0.9` |
| Body weight source | The user's profile; if it is missing, prompt the user to set it rather than substituting a default |
| Input validation | Distance in kilometres and weight in kilograms, both valid positive values |
| Pre-walk summary | Displayed for walking-mode journeys only |
| Arrival radius | 100 metres from the destination coordinates |
| GPS freshness | Verification uses a current reading; stale or low-accuracy readings are rejected and verification does not proceed |
| Journey completion | Permitted only after successful proximity verification |
| Duplicate completion | Each journey can be completed exactly once; a repeat attempt must not re-trigger reward processing |
| Data persistence | Carbon and calorie values are recorded only after successful completion |
| Module boundary | This module triggers reward processing but never calculates points or badges itself |

### Reward & Achievement

| Rule | Value |
| --- | --- |
| Points formula | 10 points per completed check-in + 1 point per 0.1 km walked, rounded down |
| Input received | distance (km), carbon saved (kg CO₂), calories burned (kcal) — already verified by Walking & Carbon |
| Explorer badge | 5 check-ins |
| Trailblazer badge | 10 km cumulative distance |
| Penang Wanderer badge | 50 km cumulative distance |
| Points write | Atomic increment (`FieldValue.increment`), never read-modify-write |
| Failed points write | Retried when the connection is restored; the pending update is held locally until synced |
| Badge write | Checked for an existing record first; duplicates are skipped, not overwritten |
| Badge record fields | badgeId, badgeName, description, dateEarned |
| Journal ordering | Reverse chronological, most recent first |
| Journal detail fields | Destination name, check-in date/time, distance walked, points earned, carbon saved, calories burned |
| Dashboard refresh | Real time whenever a new check-in is recorded |
| Record scope | Only the currently logged-in tourist's records, enforced by Firestore security rules |
| Module boundary | This module never retrieves GPS coordinates and never computes distance, carbon, or calories |

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
