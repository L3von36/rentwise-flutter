# RentWise — Event Rental Operations Workspace (Flutter)

One calm, connected place for event-rental **inventory, orders, customers, and activity** — built with Flutter from the RentWise screen design pack. Single responsive codebase targeting **Android, iOS, Web, macOS, Windows, and Linux**.

![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?logo=flutter) ![Dart](https://img.shields.io/badge/Dart-3.5+-0175C2?logo=dart) [![Build & Release](https://github.com/L3von36/rentwise-flutter/actions/workflows/release.yml/badge.svg)](https://github.com/L3von36/rentwise-flutter/actions/workflows/release.yml)

## What's inside

All 11 screens from the design pack, pixel-faithful:

| Screen | Highlights |
| --- | --- |
| **Sign-in** | Employee/Owner role toggle, email + password, remember me, Google button, split hero layout |
| **Password recovery** | Account recovery card with success state |
| **Dashboard (Operations overview)** | Owner: financial KPIs, earnings chart with gradient "today" bar, top categories, inventory snapshot. Employee: gradient **shift hero** (greeting, live shift-progress rail, UP NEXT panel), numbered priority task list with filters, dispatch timeline, quick actions, personal activity timeline |
| **Owner dashboard (mobile/tablet)** | Business-open banner, today-at-a-glance tiles, live activity, next dispatch card |
| **Inventory** | KPIs, search + category filter, table/list switch, add-item dialog, stock adjust + maintenance toggle, +Rent shortcut |
| **Orders** | KPIs, All/Upcoming/Completed tabs, order table + cards, status actions from the overflow menu |
| **Customers** | KPIs, directory with search, add customer, purple "Relationship Pulse" insight panel |
| **Activity Log** | Stat strip, timeline with type badges, filter menu + chips |
| **Access & roles** | Protected banner, owner role-preview switch, permission matrix, current session + sign out |
| **Reports** (Owner only) | Gross revenue / utilization KPIs, fl_chart revenue trend bars, top-category breakdown |
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

### Tests & analysis

```bash
flutter analyze             # zero issues
flutter test                # 44 tests: role journeys (owner/employee/customer),
                            # write-through assertions, no-demo guarantees, mappers
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
