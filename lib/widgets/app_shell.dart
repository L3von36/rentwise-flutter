import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/breakpoints.dart';
import '../state/workspace_state.dart';
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

    final Widget scrolledContent = LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: content,
        ),
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        key: scaffoldKey,
        drawer: useDrawer ? const AppDrawer() : null,
        bottomNavigationBar: useBottomNav ? const RentWiseBottomNav() : null,
        backgroundColor: AppShellColors.background,
        body: (useDrawer || useBottomNav)
            ? Column(
                children: [
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
                        const TopBar(compact: false),
                        const Divider(height: 1),
                        Expanded(child: scrolledContent),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class AppShellColors {
  static const background = Color(0xFFF6F7FB);
}
