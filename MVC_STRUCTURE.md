# WalkPenang — MVC structure

The `lib/` folder follows the architecture diagram: Model, View, Controller,
plus a service layer for Firebase access.

```
lib/
├── models/          →  UserProfile                  (Model)
├── services/        →  AuthService, ProfileStore    (Data Access Objects / Firebase Service)
├── controllers/     →  one controller per screen    (Controller)
├── theme/           →  design tokens                (Presentation)
└── views/           →  one view per screen          (View)
    └── widgets/     →  the shared WalkPenang UI kit
```

## Who does what

| Layer | Responsibility | May import |
|---|---|---|
| `models/` | Data shape + business rules (BMI, `isComplete`, JSON mapping) | nothing app-specific |
| `services/` | Talks to Firebase Auth, Firestore, Storage, SharedPreferences | `models/` |
| `controllers/` | Screen state, validation, calls services, decides *what* happens next | `models/`, `services/` |
| `theme/` | Colour, type and radius tokens; the `ThemeData` | nothing app-specific |
| `views/` | Builds widgets, runs `Navigator`, shows snackbars/dialogs | `controllers/`, `models/`, `theme/`, `views/widgets/` |

## Design system

`theme/app_theme.dart` transcribes the Figma "00 · Design Tokens" sheet and is
the **only** place a hex value or font size is allowed to be written down:

| Token | Value |
|---|---|
| Primary | `#E4B592` |
| Background | `#FFF3EA` |
| Surface (black cards) | `#000000` |
| On-primary / ink | `#111111` |
| Border (input fill) | `#FFFFFF` |
| Radius | SM 10 (cards, inputs) · MD 50 (pills) |
| Type | Jost — Bold 32 / SemiBold 18 / Medium 15 |
| Mono labels | IBM Plex Mono 10, uppercase, tracked out |

Jost and IBM Plex Mono arrive through the `google_fonts` package, which fetches
them once on first launch and caches them on-device.

`views/widgets/wp_components.dart` holds the pieces every screen is built from
— `WpScreen`, `WpPageTitle`, `WpField`, `WpPrimaryButton`, `WpOutlineButton`,
`WpAvatar`, `WpChip`, `WpStatTile`, `WpModuleCard`, `WpDetailRow`,
`WpBottomNav`. A view should reach for one of these before writing a raw
`Container`, so that a change to button height or corner radius happens once.

A view never touches Firebase or `ImagePicker` directly, and a controller never
touches `BuildContext` or `Navigator`.

## The pattern

Controllers with changing state extend `ChangeNotifier`; views own the
controller instance and rebuild through `ListenableBuilder`. No extra package
is required — this is plain Flutter.

```dart
// controller
class HomeController extends ChangeNotifier {
  HomeController(this._profile);
  UserProfile _profile;
  UserProfile get profile => _profile;

  void updateProfile(UserProfile profile) {
    _profile = profile;
    notifyListeners();
  }
}

// view
class _HomeViewState extends State<HomeView> {
  late final HomeController _controller = HomeController(widget.profile);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => Text(_controller.profile.nickname),
      );
}
```

`LogoController`, `LoadingController` and `SettingsController` hold no changing
state, so they are plain classes rather than `ChangeNotifier`s.

### Navigation

Controllers can't navigate, so a controller that needs to redirect returns a
value describing the decision and the view acts on it:

- `LoadingController.resolveDestination()` returns a `LoadingRoute`
  (`onboarding` / `verifyEmail` / `completeProfile` / `home`).
- `OnboardingController` methods return an `OnboardingOutcome`
  (`stay` / `verifyEmail` / `home`, plus an optional error message).
- `VerifyEmailController` exposes an `onVerified` callback, because the poll
  timer decides when to move on rather than a user tap.

### Async safety

Controllers that keep working after a screen closes guard notifications with a
`_safeNotify()` helper, since calling `notifyListeners()` on a disposed
`ChangeNotifier` throws.

## Screen map

| View | Controller |
|---|---|
| `logo_view.dart` | `logo_controller.dart` |
| `loading_view.dart` | `loading_controller.dart` |
| `onboarding_view.dart` | `onboarding_controller.dart` |
| `verify_email_view.dart` | `verify_email_controller.dart` |
| `home_view.dart` | `home_controller.dart` |
| `edit_profile_view.dart` | `edit_profile_controller.dart` |
| `settings_view.dart` | `settings_controller.dart` |
| `otp_verification_view.dart` | `otp_verification_controller.dart` |

`otp_verification_view.dart` is **not reachable** from any navigation path —
the app verifies email addresses through Firebase email links. It is kept as a
starting point for a future SMS/OTP flow; delete both files if you don't want it.

## Adding a screen

1. `lib/controllers/<name>_controller.dart` — state, validation, service calls.
2. `lib/views/<name>_view.dart` — widgets only; create the controller in
   `initState`, dispose it in `dispose`. Build it out of `views/widgets/` and
   `theme/` — never a hard-coded colour or font size.
3. If it needs new data, add the model to `models/` and the Firebase calls to
   `services/` — never to the view.
