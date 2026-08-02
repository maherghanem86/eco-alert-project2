class AppConstants {
  // اسم التطبيق
  static const String appName = 'Eco Alert';

  // روابط الـ APIs (في حال تم استدعاؤها مباشرة، رغم أن الأفضل استدعاؤها عبر Cloud Functions)
  static const String usgsEarthquakeApiUrl = 'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_hour.geojson';
  
  // أسماء صناديق التخزين المحلي (Hive Boxes)
  static const String alertsBoxName = 'alerts_cache_box';
  static const String userPreferencesBoxName = 'user_prefs_box';

  // مفاتيح الإعدادات
  static const String fcmTokenKey = 'fcm_token';
  static const String isFirstLaunchKey = 'is_first_launch';
}
