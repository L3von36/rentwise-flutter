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
  static const String colProfiles = 'profiles';
  static const String colInventory = 'inventory_items';
  static const String colCustomers = 'customers';
  static const String colOrders = 'orders';
  static const String colActivities = 'activities';
  static const String colPickups = 'pickups';
  static const String colWorkspaces = 'workspaces';
  static const String colMetrics = 'metrics';
}
