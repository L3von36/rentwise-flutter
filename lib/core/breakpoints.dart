/// Responsive breakpoints derived from the design pack
/// (desktop-1440, tablet-landscape-1024, tablet-768, mobile-390).
class Breakpoints {
  Breakpoints._();

  /// Below this width the sidebar collapses into a drawer (tablet-768 & mobile).
  static const double drawer = 950;

  /// Below this width the app uses a phone-style bottom navigation bar
  /// (native-app feel) instead of the website-style drawer.
  static const double bottomNav = 768;

  /// Below this width KPI grids drop from 4 columns to 2.
  static const double kpiFourCol = 1100;

  /// Below this width data tables switch into stacked list cards.
  static const double tableToList = 860;

  /// Below this width the auth hero panel is hidden.
  static const double authHero = 1000;

  /// Below this width booking modal becomes a bottom sheet.
  static const double sheetBelow = 640;

  static bool useDrawer(double width) => width < drawer;
  static bool useBottomNav(double width) => width < bottomNav;
  static bool useCompactKpis(double width) => width < kpiFourCol;
  static bool useListCards(double width) => width < tableToList;
}
