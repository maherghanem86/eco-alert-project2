import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

class AlertsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Box _alertsBox = Hive.box('alertsBox');

  // جلب التنبيهات: يعتمد على الكاش المحلي أولاً، ثم يحدث من السحابة
  Stream<List<Map<String, dynamic>>> getAlerts() async* {
    // 1. عرض البيانات المخزنة محلياً فوراً (Offline)
    if (_alertsBox.isNotEmpty) {
      yield _alertsBox.values.toList().cast<Map<String, dynamic>>();
    }

    // 2. محاولة جلب أحدث البيانات من Firestore
    try {
      _firestore.collection('environmental_hazards')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen((snapshot) {
        
        List<Map<String, dynamic>> freshAlerts = [];
        for (var doc in snapshot.docs) {
          final data = doc.data();
          freshAlerts.add(data);
        }
        
        // تحديث قاعدة البيانات المحلية (Cache)
        _alertsBox.clear();
        _alertsBox.addAll(freshAlerts);
      });
      
      // إرسال البيانات المحدثة للواجهة
      yield _alertsBox.values.toList().cast<Map<String, dynamic>>();
    } catch (e) {
      // في حال انقطاع الإنترنت، سيكتفي التطبيق بما تم إرساله من الكاش
      print("Network Error: Using offline cache.");
    }
  }
}
