# RentWise — Event Rental Operations Workspace (Flutter)

One calm, connected place for event-rental **inventory, orders, customers, and activity** — built with Flutter from the RentWise screen design pack. Single responsive codebase targeting **Android, iOS, Web, macOS, Windows, and Linux**.

![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?logo=flutter) ![Dart](https://img.shields.io/badge/Dart-3.5+-0175C2?logo=dart) ![Tests](https://img.shields.io/badge/tests-passing-brightgreen)

## What's inside

All 11 screens from the design pack, pixel-faithful:

| Screen | Highlights |
| --- | --- |
| **Sign-in** | Employee/Owner role toggle, email + password, remember me, Google button, split hero layout |
| **Password recovery** | Account recovery card with success state |
| **Dashboard (Operations overview)** | 4 KPI cards, inventory snapshot with availability bars, recent activity feed, upcoming pickups, workspace health |
| **Owner dashboard (mobile/tablet)** | Business-open banner, today-at-a-glance tiles, live activity, next dispatch card |
| **Inventory** | KPIs, search + category filter, table/list switch, add-item dialog, stock adjust + maintenance toggle, +Rent shortcut |
| **Orders** | KPIs, All/Upcoming/Completed tabs, order table + cards, status actions from the overflow menu |
| **Customers** | KPIs, directory with search, add customer, purple "Relationship Pulse" insight panel |
| **Activity Log** | Stat strip, timeline with type badges, filter menu + chips |
| **Access & roles** | Protected banner, role switcher (swaps demo persona), permission matrix, current session + sign out |
| **Reports** (Owner only) | Gross revenue / utilization KPIs, fl_chart revenue trend bars, top-category breakdown |
| **New rental booking** | Dialog on desktop, bottom sheet on mobile — customer, event, date picker, item lines with qty steppers, live total |

The app is a **living demo**: creating a booking decrements inventory availability, appends a `#RW-20xx` order, writes an activity entry, and bumps the sidebar badge — all through a single `ChangeNotifier` store.

## Tech stack

- **Flutter 3.24+ / Dart 3.5+**, Material 3
- **provider** for state management (one `WorkspaceState` store)
- **fl_chart** for the owner revenue trend
- **intl** for money/date formatting
- **Inter** font bundled locally (`assets/fonts/`) — no network fetch at runtime
- Zero backend — rich seed data mirrors the design pack exactly

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

Try the app: sign in with either role (credentials are pre-filled), create a booking from **New rental booking** or any **+ Rent** button, then watch the dashboard, orders, inventory, and activity log react.

### Tests & analysis

```bash
flutter analyze             # zero issues
flutter test                # 3 tests: sign-in flow, booking side effects, role gating
```

## Project structure

```
lib/
├── main.dart               # app bootstrap + provider scope
├── app.dart                # MaterialApp + auth gate
├── core/                   # design tokens: colors, theme, breakpoints, formatters
├── models/                 # account, inventory item, order, customer, activity, pickup
├── data/seed_data.dart     # demo dataset matching the design pack
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
