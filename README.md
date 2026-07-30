# WalkPenang

Flutter + Firebase mobile application promoting walking tourism in Penang, Malaysia.

## Branches

| Branch | Purpose | Owner |
|---|---|---|
| `main` | Release version — the stable build for real users. | Team |
| `master` | Integration and testing branch. All modules are combined and tested here before release. | Team |
| `dataset` | Destination and attraction seed data for Firestore. | |
| `User-Authentication-&-Profile-Module` | Module 1 — registration, login, and user profile management. | |
| `Map-&-GPS-Module` | Module 3 — map display, route plotting, and GPS navigation. | |
| `Reward-and-Achievement-Module` | Module 5 — points awarding, badge unlocking, walking journal, and statistics dashboard. | Tang Khuan Zhi |

## Workflow

1. Work on your own module branch — never commit directly to `master` or `main`.
2. Pull from `master` regularly so your branch stays current with other modules.
3. Open a pull request into `master` when your module is ready for integration testing.
4. Once all modules are integrated and tested on `master`, the team merges into `main` for release.
