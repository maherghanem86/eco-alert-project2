import 'package:hive/hive.dart';
import '../constants/app_constants.dart';

class LocalStorageService {
  late Box _alertsBox;
  late Box _userPrefsBox;

  // تهيئة صناديق التخزين
  Future<void> init() async {
    _alertsBox = await Hive.openBox(AppConstants.alertsBoxName);
    _userPrefsBox = await Hive.openBox(AppConstants.userPreferencesBoxName);
  }

  // حفظ التنبيهات محلياً
  Future<void> cacheAlerts(List<Map<String, dynamic>> alerts) async {
    await _alertsBox.clear(); // مسح القديم
    for (var i = 0; i < alerts.length; i++) {
      await _alertsBox.put(i, alerts[i]);
    }
  }

  // جلب التنبيهات المخزنة (عند انقطاع الإنترنت)
  List<Map<String, dynamic>> getCachedAlerts() {
    if (_alertsBox.isEmpty) {
      return [];
    }
    return _alertsBox.values.toList().cast<Map<String, dynamic>>();
  }

  // حفظ تفضيلات المستخدم
  Future<void> saveUserPreference(String key, dynamic value) async {
    await _userPrefsBox.put(key, value);
  }

  // جلب تفضيلات المستخدم
  dynamic getUserPreference(String key) {
    return _userPrefsBox.get(key);
  }
}
