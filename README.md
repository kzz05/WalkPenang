Folder skeleton for Module 5 (Tang Khuan Zhi, 2414351)

## Structure

| Folder | Layer | Contents |
|---|---|---|
| `lib/models/` | Model | Points formula, badge milestone rules, data models for BADGES, USER_BADGES, JOURNEYS |
| `lib/controllers/` | Controller | `reward_controller.dart` — UC500, UC510, UC520, UC530 flow control |
| `lib/views/reward/` | View | 5 screens: badge gallery, badge detail, walking journal, journal detail, statistics dashboard |
| `lib/widgets/reward/` | View | Reusable UI components: notifications, badge card, journal tile, stat card |
| `lib/dao/` | DAO / API Manager | All Firestore read/write access — models never call Firestore directly |
| `lib/utils/` | — | Milestone thresholds and points formula constants |
| `test/reward/` | — | Unit tests for points formula, badge thresholds, controller flow |
| `assets/badges/` | — | Badge icon images (locked / unlocked states) |
| `docs/module5_reward/` | — | UML diagrams, ERD, MVC diagram, use case descriptions |

## Notes

- Merge these folders into the shared team repository — teammates add their own
  module files inside the same `models/` `views/` `controllers/` `dao/` folders.
- Work on a feature branch (e.g. `feature/module5-reward`), not `main`.
- Confirm the folder convention with the team before coding starts so the repo
  matches the MVC diagram in the report.
