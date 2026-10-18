/// User roles available in the workspace.
enum UserRole { employee, owner }

/// Centralized permission matrix.
///
/// Every capability lives HERE — widgets and state methods ask
/// `role.canX` instead of scattering `role == UserRole.owner` checks.
/// Rules:
///  • `owner`  → true for every capability.
///  • `employee` → true only for operational capabilities.
extension UserRoleX on UserRole {
  String get label => this == UserRole.employee ? 'Employee' : 'Owner';

  String get tagline =>
      this == UserRole.employee ? 'Day-to-day operations' : 'Full business visibility';

  // ------------------------------------------------------- operations
  /// Create bookings / move orders through the rental pipeline.
  bool get canOperateRentals => true; // both roles run the shift

  /// Adjust stock when receiving, returning or repairing items.
  bool get canAdjustStock => true; // both roles

  /// Manage customers (add, view, book for them).
  bool get canManageCustomers => true; // both roles

  // ------------------------------------------------------------ owner
  /// Add new catalog items to inventory.
  bool get canCreateInventory => this == UserRole.owner;

  /// Delete catalog items from inventory.
  bool get canDeleteInventory => this == UserRole.owner;

  /// Change rental pricing (rate per day).
  bool get canEditPricing => this == UserRole.owner;

  /// View reports / financial metrics / revenue dashboards.
  bool get canViewReports => this == UserRole.owner;

  /// View revenue, profit and financial KPIs.
  bool get canViewFinancials => this == UserRole.owner;

  /// Export business data as CSV.
  bool get canExportReports => this == UserRole.owner;

  /// Export the customer directory as CSV.
  bool get canExportCustomersCsv => this == UserRole.owner;

  /// Manage employees and their roles (Access & roles screen).
  bool get canManageTeam => this == UserRole.owner;

  /// Change workspace settings.
  bool get canChangeSettings => this == UserRole.owner;

  /// Create or switch workspaces.
  bool get canManageWorkspaces => this == UserRole.owner;
}

/// Signed-in workspace member.
class Account {
  final String name;
  final String email;
  final UserRole role;
  final String initials;
  final String title;

  const Account({
    required this.name,
    required this.email,
    required this.role,
    required this.initials,
    required this.title,
  });

  Account copyWith({UserRole? role}) => Account(
        name: name,
        email: email,
        role: role ?? this.role,
        initials: initials,
        title: title,
      );
}
