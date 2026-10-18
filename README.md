# RentWise — Event Rental Operations Workspace (Flutter)

One calm, connected place for event-rental **inventory, orders, customers, and activity** — built with Flutter from the RentWise screen design pack. Single responsive codebase targeting **Android, iOS, Web, macOS, Windows, and Linux**.

![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?logo=flutter) ![Dart](https://img.shields.io/badge/Dart-3.5+-0175C2?logo=dart) [![Build & Release](https://github.com/L3von36/rentwise-flutter/actions/workflows/release.yml/badge.svg)](https://github.com/L3von36/rentwise-flutter/actions/workflows/release.yml)

## What's inside

All 11 screens from the design pack, pixel-faithful:

| Screen | Highlights |
| --- | --- |
| **Sign-in / Sign-up** | Email + password sign-in with remember-me, plus one-time **owner registration** (bootstraps the workspace; closed once an owner exists), forgot-password flow, split hero layout |
| **Password recovery** | Account recovery card with success state |
| **Dashboard (Operations overview)** | Owner: financial KPIs, earnings chart with gradient "today" bar, top categories, inventory snapshot. Employee: gradient **shift hero** (greeting, live shift-progress rail, UP NEXT panel), numbered priority task list with filters, dispatch timeline, quick actions, personal activity timeline |
| **Owner dashboard (mobile/tablet)** | Business-open banner, today-at-a-glance tiles, live activity, next dispatch card |
| **Inventory** | Status-driven KPIs — **each card drills into its own metric** (totals / available / on-rent per category), lifecycle status chips (In stock · Partially out · Rented out · Maintenance) with live counts, table/list switch, add-item dialog, stock adjust + real **maintenance flag**, +Rent shortcut |
| **Access & roles** (Owner only) | Redesigned console (v1.18/v1.20): gradient **security hero with live team stats**, team directory with **search**, pastel initials avatars (owners wear a shield badge), "You" chip, dashed **＋ Add employee** tile, role & title editing, employee password resets, role-preview tiles, grouped **permission matrix**, appearance picker, current-session card, **danger zone: reset workspace data** (type-RESET confirm). **Phone-verified (v1.20)**: team forms + danger confirm open as modal **bottom sheets** on mobile, card headers reflow (actions drop below the title), matrix role columns widened — no flex crashes or overflows at 390 px (pinned by `test/access_phone_layout_test.dart`) |
| **Orders** | KPIs, All/Upcoming/Completed tabs, order table + cards, status actions from the overflow menu |
| **Customers** | KPIs, directory with search, add customer, purple "Relationship Pulse" insight panel |
| **Activity Log** | Stat strip, timeline with type badges, filter menu + chips |
| **Reports** (Owner only) | Gradient month-performance hero (live revenue / utilization / momentum tiles), honest live KPI grid (revenue, utilization, awaiting payment, late returns), dynamic revenue trend chart with best-day / average / days-booked footer, ranked category breakdown with share %, live order-pipeline counters |
| **New rental booking** | Dialog on desktop, bottom sheet on mobile — customer, event, date picker, item lines with qty steppers, live total |

Everything runs against **Appwrite Cloud** — the single source of truth. Creating a booking decrements inventory availability, appends an order, writes an activity entry and bumps the sidebar badge locally, and every mutation is **written through to the cloud immediately** (orders, inventory, customers, activities, pickups, workspaces, profiles, metrics). Sign-in failures surface honestly — there is **no offline/demo fallback**: until a sign-in succeeds the workspace is simply empty.

## Tech stack

- **Flutter 3.24+ / Dart 3.5+**, Material 3
- **Appwrite Cloud** — auth (email/password sessions) + database (`rentwise-db`: profiles, workspaces, inventory_items, customers, orders, activities, pickups, metrics)
- **provider** for state management (one `WorkspaceState` store)
- **fl_chart** for the owner revenue trend
- **intl** for money/date formatting
- **Inter** font bundled locally (`assets/fonts/`) — no network fetch at runtime

## Getting started

```bash
flutter pub get
flutter run                 # pick a device or run on Chrome
```

Run on a specific platform:

```bash
flutter run -d chrome       # Flutter Web
flutter run -d macos|windows|linux
flutter run -d <device-id>  # Android / iOS device or emulator
```

Sign in with an **Appwrite account registered in your project** (the role — owner or employee — is resolved server-side from the `profiles` collection), create a booking from **New rental booking** or any **+ Rent** button, then watch the dashboard, orders, inventory, and activity log react. Data is written through to Appwrite Cloud as you act.

## Roles & permissions (v1.16)

Two roles exist: **owner** and **employee**. The role is fixed at profile creation (server-side `profiles` collection; clients can never update it) and resolved at sign-in. Employee accounts are created **only by the owner** from the Owner Dashboard → Access & roles — self-registration closes as soon as the owner exists.

### Permission matrix

| Feature | Owner | Employee |
| --- | :---: | :---: |
| Employee operations dashboard | Yes | Yes |
| Owner financial dashboard | Yes | No |
| Create bookings | Yes | Yes |
| Accept payments | Yes | Yes |
| Process returns / mark dispatched | Yes | Yes |
| Adjust stock quantities | Yes | Yes |
| View & manage customers | Yes | Yes |
| Add inventory catalog items | Yes | No |
| Delete inventory items / change pricing | Yes | No |
| Reports & CSV exports | Yes | No |
| Create employee accounts (Owner dashboard) | Yes | No |
| Edit member roles & titles (Owner dashboard) | Yes | No |
| Reset an employee's password (Owner dashboard) | Yes | No |
| Rotate your own password (Profile) | Yes | Yes |
| Reset workspace data (danger zone) | Yes | No |
| Create / switch workspaces | Yes | No |
| View financial metrics | Yes | No |

The single source of truth is the `UserRoleX` capability extension in `lib/models/account.dart` (`canOperateRentals`, `canAdjustStock`, `canCreateInventory`, `canViewReports`, `canManageTeam`, `canManageWorkspaces`, …). Screens hide what a role cannot do **and** every state mutation in `WorkspaceState` re-checks the capability before touching the store or the cloud — hiding a button is never the only guard. If a restricted action is somehow triggered, the user sees:

> Owner access required — "…" is managed by the workspace owner.

Owner-only screens (`Reports`, `Access & roles`) additionally render a `RestrictedPanel` as a second line of defence, and employees see a locked (not tappable) workspace switcher.

### Order lifecycle enforcement

Status changes follow one transition map (`kOrderTransitions` in `lib/models/rental_order.dart`): `confirmed → preparing/outForDelivery/needsPayment`, `preparing → …`, `needsPayment → confirmed (payment accepted) / returned`, `returned` is terminal. The order screen only offers legal, action-labelled transitions (**Accept payment**, **Mark dispatched**, **Mark returned**…) and the state layer rejects illegal jumps with an error notice — a crafted call cannot resurrect a returned order. Returning an order never auto-restocks: employees restock from Inventory after inspection, and every action lands in the activity log.

### Cloud-side hardening (v1.15)

Re-run the idempotent provisioner to tighten the live project:

```bash
AW_KEY=<api key with databases/users/teams scopes> bash scripts/appwrite_provision.sh
```

- `profiles` — clients get **read + create only**: a role is fixed at creation and can never be changed from the app (no self-promotion, no role edits). Create happens in exactly two flows: the one-time owner bootstrap and the owner's Add-employee action.
- `user_prefs` (new) — per-user document-level-security prefs holding the active-workspace pointer, replacing profile updates.
- `metrics` — readable **only by the `owners` team**; the script syncs every owner profile (including in-app bootstrapped owners) into that team, so employees cannot pull financial metrics even with a session.
- Operational collections stay member-writable so the shift can run; owner-only mutations are enforced in-app and activity-logged.
- If the owner dashboard shows 0 revenue after hardening, confirm the owner is a confirmed member of the owners team (Appwrite console → Auth → Teams → Owners).

### Registration — how accounts are created (v1.16)

- **Owner (you)**: tap **Create an account** on the sign-in card ONCE — this registers the workspace's **owner** and creates the starter workspace. As soon as an owner exists, self-registration is permanently closed: later sign-up attempts are refused with *"Registration is closed — this workspace already has an owner."*
- **Employees**: created **only by the owner** from **Owner Dashboard → Access & roles → Team members → Add employee**. The dialog creates the Appwrite auth account (email + temporary password, min 8 chars) and the employee profile in one step — the team list updates instantly and the action is activity-logged. Share the credentials with the employee; they sign in on the normal **Sign in** screen (employees cannot sign up).
- **Managing the team (v1.17)**: every row in **Team members** has actions —
  - **Role & title (pencil)** — promote an employee to owner or demote, and edit job titles. Roles are enforced twice: the app checks capabilities AND the cloud only lets owner user ids update profile documents (document-level permissions; run `scripts/appwrite_provision.sh` once to migrate an existing project). You can never change your own role, and the last owner cannot be demoted.
  - **Reset password (key)** — sets a new password for an employee right away (with a strong-password suggestion). Requires the one-time `reset-password` Appwrite Function deployment: see `scripts/functions/reset_password/README.md` (Console → Functions → paste → add `APPWRITE_API_KEY`). Until it is deployed the app tells you exactly that, honestly.
  - **Your own password**: Profile → Password → rotate it any time (needs your current password; the session stays signed in).
- **Signing in with an unknown/unassigned account** (e.g. a console-created user with no profile) is refused: *"This account is not added to a RentWise workspace yet. Employee accounts are created by the workspace owner (Owner Dashboard → Access & roles)."* — no role is ever granted silently.
- **From the Appwrite console**: Auth → Add user alone is NOT enough anymore — without a `profiles` document the account cannot sign in. Create the `profiles` document with the API key, or better: add the employee from the Owner Dashboard.
- Customers are NOT app accounts — they are records in the `customers` collection, managed by owner/staff from the Customers screen.

### Item status & maintenance

Inventory rows show a derived lifecycle status: **In stock** (all units free) · **Partially out** (some units rented) · **Rented out** (every unit out) · **Maintenance** (explicit operator flag). Maintenance items are excluded from the Available/On-rent KPI pools — a broken chair is not "on rent" — and appear on the watch list. Toggle it from the edit dialog. The inventory KPI cards each open their OWN filtered view (Total → category breakdown, Available / On rent / Needs attention → status-filtered list), and status chips with live counts filter the table. Requires the `maintenance` boolean attribute on `inventory_items` (idempotent `scripts/appwrite_provision.sh` adds it; older clouds keep working — the app degrades gracefully and stock numbers still persist).

### Starting fresh — clearing the sample dataset

The one-shot seeding harness can preload the "Riverside Events" sample workspace. To replace it with your real data: sign in as **owner** → **Access & roles → Danger zone → Reset data** (type RESET to confirm). All inventory, orders, customers, activity and pickups are deleted from Appwrite; your account, team profiles and workspaces are kept.

### Tests & analysis

```bash
flutter analyze             # zero issues
flutter test                # 67 tests: role journeys (owner/employee/customer),
                            # RBAC guarantees (capability matrix, denial notices,
                            # illegal transitions, surfaced sync failures, stock
                            # invariants), item-status rules, sign-up/bootstrap,
                            # danger-zone reset, write-through assertions,
                            # no-demo guarantees
```

One-shot backend tooling (CI-safe, skipped without env vars):

```bash
AW_KEY=<key> AW_SEED=1 flutter test test/seed_appwrite_test.dart   # provision collections + workspace data
AW_E2E=1 flutter test test/live_login_test.dart                    # live auth + load probe against Cloud
```

## Prebuilt binaries (GitHub Releases)

CI builds and publishes installers for every release tag — grab them from the [Releases page](https://github.com/L3von36/rentwise-flutter/releases):

| Asset | Platform |
| --- | --- |
| `RentWise-<version>-android.apk` | Android 5.0+ (universal APK) |
| `RentWise-<version>-windows-x64.zip` | Windows 10/11 |
| `RentWise-<version>-macos.zip` | macOS 10.14+ (unsigned — right-click → Open) |
| `RentWise-<version>-linux-x64.tar.gz` | Linux x64 (GTK 3) |

Each release also includes `SHA256SUMS.txt`. Android builds additionally run `flutter analyze` + `flutter test` as a quality gate.

## Windows desktop experience

The Windows build behaves like a native desktop app, not a web page in a window:

- **Custom frameless title bar** — the native caption is replaced by in-window chrome (`TitleBarStyle.hidden` + runner patch): draggable brand region, double-click to maximize, right-click native window menu, and Windows-style minimize / maximize / restore / close buttons (close hovers red). The close button parks the app in the tray instead of quitting.
- **Dark mode (Noir v2)** — a dark theme designed as a dark theme, not a mirror: readable surface elevation ramp (canvas → panel → card → raise), strokes that actually read, luminous status washes over deep tints, indigo→violet gradients with a soft glow on primary actions, lifted dialogs/menus/tooltips. **System / Light / Dark** selector in *Access & roles → Appearance*, a sun/moon toggle in the **top bar for every role on every platform**, one in the title bar, and a tray quick action. Persists via `SharedPreferences`; `ThemeMode.system` follows the OS.
- **Tray quick actions** — branded tray icon with left-click to restore the window and a right-click menu: Show RentWise, Dashboard · live task count, Orders, Inventory, theme switch, and Quit. The "tasks on deck" line and theme label rebuild live from the workspace store (`system_tray`).
- **State management** — UI-shell state lives in a dedicated `ShellState` ChangeNotifier (theme mode + persistence + the native window/tray bridge), cleanly split from the domain store `WorkspaceState`; both flow through `provider`.
- **Window management** — opens at 1280×800, centered, with a 960×640 minimum size (the responsive layout never breaks) and a proper `RentWise — <section>` window title that follows navigation (via `window_manager`).
- **Keyboard shortcuts** — `Ctrl+K` global search, `Ctrl+B` new rental booking, `Ctrl+1–5` jump to Dashboard / Inventory / Orders / Customers / Activity, `Ctrl+/` shortcuts help panel, `Esc` closes dialogs (⌘ equivalents on macOS).
- **Branded app icon** — the runner ships a RentWise .ico (indigo rounded square + white R) for the title bar, taskbar, tray, and shortcuts.
- **Search dialog hints** — the footer reminds keyboard users of the fast paths; the search field badge shows `Ctrl K` on Windows (⌘K on macOS).

**Cutting a release:**
1. Push a tag: `git tag v1.0.1 && git push origin v1.0.1`, **or**
2. Go to **Actions → Build & Release → Run workflow** and enter a version (e.g. `v1.0.1`). Empty input uses the pubspec version.

## Project structure

```
lib/
├── main.dart               # app bootstrap + provider scope
├── app.dart                # MaterialApp + auth gate
├── core/                   # design tokens: colors, theme, breakpoints, formatters
├── models/                 # account, inventory item, order, customer, activity, pickup
├── data/
│   ├── appwrite_mappers.dart   # cloud documents ⇄ models (icon/status/color codecs)
│   └── catalog.dart            # static UI options only (category chips, hours copy)
├── services/
│   ├── appwrite_config.dart    # endpoint/project/collection ids
│   ├── appwrite_backend.dart   # auth + load + write-through persistence
│   └── system_proxy.dart       # route HTTP through the OS proxy when present
├── state/workspace_state.dart  # single ChangeNotifier store (auth, nav, data, actions)
├── widgets/                # brand, chips, cards, KPI cards, sidebar, top bar, tables…
└── screens/
    ├── auth/               # sign-in + password recovery (shared hero scaffold)
    ├── dashboard/          # operations overview + owner compact variant
    ├── inventory/ orders/ customers/ activity/ access/ reports/
    └── booking/            # new rental booking modal/sheet
```

## Responsive behavior

| Width | Layout |
| --- | --- |
| ≥ 950 px | Permanent sidebar, 4-up KPI grid, data tables (design: desktop-1440 / tablet-landscape-1024) |
| < 950 px | Hamburger + drawer, stacked cards (design: tablet-768 / mobile-390) |
| < 640 px | Booking modal becomes a bottom sheet |

Owner role additionally unlocks the **Reports** section and the **Owner dashboard** flavor on compact screens.
