import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/breakpoints.dart';
import '../core/palette.dart';
import '../state/workspace_state.dart';
import '../screens/booking/new_booking_sheet.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/inventory/inventory_screen.dart';
import '../screens/orders/orders_screen.dart';
import '../screens/customers/customers_screen.dart';
import '../screens/activity/activity_log_screen.dart';
import '../screens/access/access_roles_screen.dart';
import '../screens/reports/reports_screen.dart';
import 'side_nav.dart';
import 'top_bar.dart';
import 'bottom_nav.dart';
import 'desktop.dart';
import 'motion.dart';

/// Shows one-shot state notices (permission denials, cloud write
/// failures) as floating snackbars. Keyed on [StateNotice.id] so a
/// notice is shown exactly once, no matter how many rebuilds fire.
class _NoticeListener extends StatefulWidget {
  final Widget child;
  const _NoticeListener({required this.child});

  @override
  State<_NoticeListener> createState() => _NoticeListenerState();
}

class _NoticeListenerState extends State<_NoticeListener> {
  int _lastShownId = 0;

  @override
  Widget build(BuildContext context) {
    final notice = context.watch<WorkspaceState>().lastNotice;
    if (notice != null && notice.id != _lastShownId) {
      _lastShownId = notice.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          content: Text(notice.message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: notice.isError ? AppPalette.red : null,
          duration: const Duration(seconds: 4),
        ));
      });
    }
    return widget.child;
  }
}

/// Responsive workspace scaffold:
/// ≥950px → permanent sidebar; 768–950 → hamburger + drawer;
/// <768 (phones) → native-app layout with bottom navigation bar.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();
    final width = MediaQuery.sizeOf(context).width;
    final useBottomNav = Breakpoints.useBottomNav(width);
    final useDrawer = !useBottomNav && Breakpoints.useDrawer(width);
    final scaffoldKey = GlobalKey<ScaffoldState>();

    final Widget content = switch (state.section) {
      Section.dashboard => const DashboardScreen(),
      Section.inventory => const InventoryScreen(),
      Section.orders => const OrdersScreen(),
      Section.customers => const CustomersScreen(),
      Section.activity => const ActivityLogScreen(),
      Section.access => const AccessRolesScreen(),
      Section.reports => const ReportsScreen(),
    };

    // Crossfade + slide between sections (motion kit).
    final Widget animatedContent =
        SectionFade(tag: state.section, child: content);

    final Widget scrolledContent = LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: animatedContent,
        ),
      ),
    );

    // Desktop fast paths: search, booking and section jumps. Dialogs
    // push their own routes above this scope, so shortcuts never fire
    // while a dialog is open (Esc closes them natively).
    final shortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyK, control: true):
          () => openGlobalSearch(context),
      const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
          () => openGlobalSearch(context),
      const SingleActivator(LogicalKeyboardKey.keyB, control: true):
          () => showNewBookingSheet(context),
      const SingleActivator(LogicalKeyboardKey.keyB, meta: true):
          () => showNewBookingSheet(context),
      const SingleActivator(LogicalKeyboardKey.digit1, control: true):
          () => state.navigate(Section.dashboard),
      const SingleActivator(LogicalKeyboardKey.digit2, control: true):
          () => state.navigate(Section.inventory),
      const SingleActivator(LogicalKeyboardKey.digit3, control: true):
          () => state.navigate(Section.orders),
      const SingleActivator(LogicalKeyboardKey.digit4, control: true):
          () => state.navigate(Section.customers),
      const SingleActivator(LogicalKeyboardKey.digit5, control: true):
          () => state.navigate(Section.activity),
      const SingleActivator(LogicalKeyboardKey.slash, control: true):
          () => showShortcutsHelp(context),
      const SingleActivator(LogicalKeyboardKey.slash, meta: true):
          () => showShortcutsHelp(context),
    };

    final brightness = Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: brightness,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            dark ? Brightness.light : Brightness.dark,
      ),
      child: CallbackShortcuts(
        bindings: shortcuts,
        child: Focus(
          autofocus: true,
          child: _NoticeListener(
            child: Scaffold(
            key: scaffoldKey,
            drawer: useDrawer ? const AppDrawer() : null,
            bottomNavigationBar:
                useBottomNav ? const RentWiseBottomNav() : null,
            backgroundColor: AppPalette.canvas,
            body: (useDrawer || useBottomNav)
                ? Column(
                    children: [
                      WindowTitleSync(section: state.section),
                      TopBar(
                        compact: true,
                        onOpenDrawer: useDrawer
                            ? () => scaffoldKey.currentState?.openDrawer()
                            : null,
                      ),
                      const Divider(height: 1),
                      Expanded(child: scrolledContent),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SideNav(width: 230),
                      Expanded(
                        child: Column(
                          children: [
                            WindowTitleSync(section: state.section),
                            const TopBar(compact: false),
                            const Divider(height: 1),
                            Expanded(child: scrolledContent),
                          ],
                        ),
                      ),
                    ],
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
