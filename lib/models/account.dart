/// User roles available in the workspace.
enum UserRole { employee, owner }

extension UserRoleX on UserRole {
  String get label => this == UserRole.employee ? 'Employee' : 'Owner';

  String get tagline =>
      this == UserRole.employee ? 'Day-to-day operations' : 'Full business visibility';

  bool get canExportReports => this == UserRole.owner;
  bool get canManageTeam => this == UserRole.owner;
  bool get canChangeSettings => this == UserRole.owner;
  bool get canExportCustomersCsv => this == UserRole.owner;
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
