/// Platform-wide constants for the TakEsep ecosystem.
abstract final class TakEsepConstants {
  /// API base URL for development
  static const String apiBaseUrlDev = 'http://localhost:3000/api';

  /// API base URL for production
  static const String apiBaseUrlProd = 'https://api.takesep.com';

  /// API version
  static const String apiVersion = 'v1';

  /// App names
  static const String appNameWarehouse = 'TakEsep Склад';
  static const String appNameMarketplace = 'TakEsep Маркет';
  static const String appNameMessenger = 'TakEsep Чат';

  /// Pagination defaults
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
}
