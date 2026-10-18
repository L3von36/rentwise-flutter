/// Appwrite Cloud connection for the RentWise project.
///
/// Public client configuration: the project ID is not a secret (Appwrite
/// enforces auth via user sessions + collection permissions). Administrative
/// API keys are NEVER shipped here — they only exist in the CI/seeding
/// scripts.
class AppwriteConfig {
  AppwriteConfig._();

  static const String endpoint = 'https://cloud.appwrite.io/v1';
  static const String projectId = 'rentwise';

  /// Appwrite database + collection ids used by the workspace.
  static const String databaseId = 'rentwise-db';

  /// Workspace member profiles (role, title). Clients may READ profiles
  /// and CREATE them in exactly two cases: the one-time owner bootstrap
  /// (registerAccount, refused once an owner exists) and the owner's
  /// Add-employee action (createEmployee). Profiles are never updated or
  /// deleted by clients — a role is fixed at creation and only changeable
  /// with the API key. Employee accounts therefore always come from the
  /// owner (Owner Dashboard → Access & roles).
  static const String colProfiles = 'profiles';

  /// Per-user preferences (one document per user id, document-level
  /// security). The only profile-adjacent thing a client may write
  /// after sign-up (e.g. the active-workspace pointer).
  static const String colUserPrefs = 'user_prefs';

  static const String colInventory = 'inventory_items';
  static const String colCustomers = 'customers';
  static const String colOrders = 'orders';
  static const String colActivities = 'activities';
  static const String colPickups = 'pickups';
  static const String colWorkspaces = 'workspaces';
  static const String colMetrics = 'metrics';
}
