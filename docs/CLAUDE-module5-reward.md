CLAUDE.md — Module 5: Reward & Achievement

Context file for AI coding agents working on the Reward-and-Achievement-Module branch of WalkPenang.

Ownership

Module 5 (Reward & Achievement) is owned by Tang Khuan Zhi (2414351), who also serves as the team's Testing & Documentation Lead. Do not modify files belonging to other modules. If a change appears to require touching another module, stop and raise it instead of editing across the boundary.

Module	Owner	Scope
1 — User & Profile	—	Auth, profile data. Code available; provides the current user ID
2 — Destination & Attraction	—	Destination catalogue
3 — Route & Navigation	—	Route planning
4 — Walking & Carbon	Poon Wei Seng	GPS check-in verification, distance, carbon, calories
5 — Reward & Achievement	Tang Khuan Zhi	Points, badges, walking journal, statistics dashboard
Critical scope boundary with Module 4

Module 5 begins at "receive verified check-in data." Everything before that belongs to Poon Wei Seng.

Module 5 must never:

Retrieve GPS coordinates
Verify arrival radius (the 100 m check is Module 4's, per FR-W05)
Calculate distance walked, carbon saved, or calories burned

Module 5 consumes those values as inputs via CheckInResult. If a task seems to require computing any of them, the boundary has been crossed — stop and flag it.

Integration contract with Module 4

Decision: Module 4 calls Module 5 directly. Module 5 does not listen to the Firestore check-in collection.

Rationale, for anyone tempted to change it: this app is client-only Flutter talking straight to Firestore, with no Cloud Functions. A Firestore snapshot listener fires only while the app is foregrounded and the listener is still mounted, so a tourist who checks in and immediately closes the app would never be awarded points. Listener-based triggering is a server-side pattern and does not survive being moved onto a disposable client. Direct invocation also matches UC500 basic flow step 4, which already states that the system passes journey data to the Reward Module.

Coupling is kept loose through a narrow interface. Module 4 depends only on the abstraction:

dart
// lib/controllers/reward_service.dart
abstract class RewardService {
Future<RewardOutcome> onCheckInVerified(CheckInResult result);
}

RewardController implements RewardService. The concrete instance is injected at app startup, so Module 4 never imports Module 5's internals, and either side can substitute a fake in tests.

Idempotency is mandatory

The same check-in must never award points twice. This is what T-R01.5's "repeated check-in cases" refers to.

Use the checkInId as the document ID of the points ledger entry, so a retry overwrites rather than appends. Additionally guard on a rewardProcessed flag on the check-in document before processing.

Use atomic increments

Never read-then-write a cumulative total. Use FieldValue.increment() so concurrent writes cannot clobber each other and no transaction is required:

dart
await usersRef.doc(userId).update({
'totalPoints': FieldValue.increment(points),
'totalCheckIns': FieldValue.increment(1),
});

A recovery sweep for check-ins written but never rewarded (app killed mid-flow) is deliberately out of scope. Note it in the report as a limitation rather than implementing it.

Architecture

Logical MVC. The team uses a shared folder structure across all five modules — not a feature-first layout. Screens are grouped into a per-module subfolder under views/.

lib/
controllers/  Business rules and orchestration
dao/          Data access layer (Firestore reads/writes)
models/       Plain Dart data classes
utils/        Constants and shared helpers
views/
reward/     Module 5 screens
Existing files

These files already exist as empty stubs. Fill them; do not invent parallel files with different names.

Path	Holds
controllers/reward_controller.dart	RewardController implements RewardService — orchestrates award, evaluate, persist
dao/reward_dao.dart	Points and cumulative totals
dao/badge_dao.dart	Badge definitions and earned badges
dao/journal_dao.dart	Check-in records for the walking journal
models/reward_model.dart	RewardModel — cumulative stats (points, distance, carbon, calories, check-in count)
models/badge_model.dart	BadgeModel — a milestone definition (id, name, description, criterion, threshold)
models/user_badge_model.dart	UserBadgeModel — an earned badge instance (badgeId, dateEarned)
models/journal_entry_model.dart	JournalEntryModel — one journal row
utils/reward_constants.dart	Points formula constants, badge thresholds, Firestore collection and field names, design tokens
views/reward/badge_gallery_screen.dart	FR-R05 gallery grid
views/reward/badge_detail_screen.dart	FR-R05 single badge detail
views/reward/journal_detail_screen.dart	FR-R03 single entry detail

Two files still need creating:

models/check_in_result.dart — the Module 4 boundary object
controllers/reward_service.dart — the abstract interface Module 4 depends on
Dependency rules

These rules are what let the domain layer be written and tested independently of Flutter and Firebase. Enforce them strictly.

Files in models/, utils/, and the pure-logic parts of controllers/ must not import package:flutter/* or package:cloud_firestore/*.
Firestore types (DocumentSnapshot, Timestamp, FieldValue) appear only in dao/ implementations. Models serialise to and from Map<String, dynamic> and DateTime; the DAO converts at its edge.
Each DAO file declares an abstract class for the contract plus a Firestore implementation. Controllers depend on the abstraction, so tests run against a fake with no Firebase project.
Colours in utils/reward_constants.dart are stored as int hex literals (0xFF2E9E6B), not Color, so the file stays Flutter-free. Views wrap them in Color(...) at the point of use.
Business rules

Fixed by the submitted proposal and the use case description tables. Do not change them, and do not scatter them as literals — they live in utils/reward_constants.dart.

Points formula (UC500, constraint C1): 10 points per completed check-in, plus 1 point per 0.1 km walked, rounded down.

Compute the distance bonus in integer metres, not by multiplying the kilometre double. (distanceKm * 10).floor() is unsafe: 1.3 can be represented as 12.999999999999998 and floor to 12 instead of 13. Convert to metres first, then integer-divide by 100.

Badge milestones (UC510, constraint C1):

Badge	Criterion	Threshold
Explorer	Total check-ins	5
Trailblazer	Cumulative distance	10 km
Penang Wanderer	Cumulative distance	50 km

A single check-in may cross more than one threshold at once. The evaluator must return all newly-qualifying badges, and must never re-award a badge already held.

Badge visual specification

Only three badges exist, so they are hand-authored SVG in assets/badges/, rendered with flutter_svg. Do not copy any existing badge artwork found online — generate to this specification.

Shared structure, 120 × 140 viewBox:

Hexagonal shield outline with a slightly lighter inner shield inset by 8 units
A sunburst of 12 alternating-tone rays radiating from centre, clipped to the inner shield
A single centred glyph, flat vector, no gradients inside the glyph itself
A four-point sparkle accent at roughly (38, 42), white at 90% opacity
A ribbon banner across the lower third carrying the badge name, with notched ends

Per-badge palette and glyph, each a single hue in three tones (dark outline, mid shield, light ray):

Badge	Hue	Glyph
Explorer	Green 0xFF2E9E6B	Compass rose
Trailblazer	Blue 0xFF2F80ED	Footprint pair
Penang Wanderer	Amber 0xFFF2A93B	Crown

Locked state is produced at render time, never as a second asset file. Wrap the SVG in ColorFiltered with a greyscale colour matrix and drop opacity to 40%. This satisfies FR-R05's requirement to visually distinguish locked from unlocked while keeping one asset per badge.

Terminology

Aligned with the submitted proposal. Deviating creates inconsistencies the tutor has flagged before.

Use	Not
check-in	journey
"Check In" (button label)	"Complete"
confirmation message	notification
Tourist (actor name)	user, traveller

"Notification" implies FCM push, which is out of scope. The UI shows an in-app confirmation message.

File header convention

Every Dart file opens with a header comment mapping it to its use case and functional requirement:

dart
// ---------------------------------------------------------------------------
// reward_controller.dart
// Module 5 — Reward & Achievement
// Use Case : UC500 Earn points from activities
// FR       : FR-R01 Points Award System
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
Use case to file mapping
Use case	FR	Primary files
UC500 Earn points from activities	FR-R01	models/check_in_result.dart, controllers/reward_controller.dart, dao/reward_dao.dart
UC510 Unlock badges	FR-R02	models/badge_model.dart, models/user_badge_model.dart, dao/badge_dao.dart
UC520 View walking journal	FR-R03	models/journal_entry_model.dart, dao/journal_dao.dart, views/reward/journal_detail_screen.dart
UC530 View statistics dashboard	FR-R04	models/reward_model.dart
Badge gallery	FR-R05	views/reward/badge_gallery_screen.dart, views/reward/badge_detail_screen.dart
Testing expectations

The module owner is Testing Lead, so test quality carries weight beyond correctness. Business rules are pure functions and must be covered with no Firebase dependency.

Required coverage:

Points at zero distance, fractional distance, and exact 0.1 km boundaries
Floating-point representative values (1.3 km, 2.9 km) that expose naive floor() bugs
Badge evaluation at exactly the threshold, just under, and just over
Multiple badges unlocked from a single check-in
Already-held badges never re-awarded
The same checkInId submitted twice awards points only once
Empty state: zero check-ins yields zero totals and no badges

Use the test package. For DAO-level tests, use fake_cloud_firestore rather than a live Firebase project.

Style
const constructors on models where possible
Named parameters with required for anything with more than two fields
No section numbering in Markdown documentation; refer to sections by name
Comments explain why a rule exists, traceable to a UC or FR, not what the line does

Current sprint scope

Sprint 1 covers five tasks only. Implement these and stop. Do not work ahead.

Task	Deliverable
T-R01.1	dao/reward_dao.dart — abstract contract plus Firestore implementation
T-R01.2	Points formula and the cumulative field structure in utils/reward_constants.dart
T-R01.5	Unit tests for points calculation: boundaries, and the same check-in submitted twice
T-R02.1	models/badge_model.dart and the three badge definition records
T-R02.2	Threshold evaluation logic returning newly-qualifying badges

Explicitly out of scope this sprint, even though this file documents them:

Writing an unlocked badge to Firestore and recording the date earned (T-R02.3, Sprint 2)
Badge unit tests (T-R02.5, Sprint 2)
Anything under views/ — every screen task is Sprint 2 or later
Any confirmation message UI (T-R01.4, T-R02.4, Sprint 2)
The RewardController orchestration and the Module 4 handoff (T-R01.3, Sprint 3)
Generating badge SVG assets (T-R05.5, Sprint 3)

The Module 4 integration contract, badge visual specification, and terminology rules below are recorded so that later sprints stay consistent. They are reference, not this sprint's work.

controllers/reward_service.dart may be created this sprint as an empty interface declaration, because Module 4 needs the signature to plan against. Do not implement it yet.