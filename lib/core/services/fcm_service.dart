import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FCMService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  static Future<void> initializeFCM() async {
    // طلب صلاحيات الإشعارات من المستخدم
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) {
        print('User granted permission');
      }
      
      // الحصول على الـ Token الخاص بالجهاز لربطه بالموقع المفضل
      String? token = await _firebaseMessaging.getToken();
      if (kDebugMode) {
        print('FCM Token: $token');
      }

      // الاستماع للإشعارات والتطبيق يعمل في الخلفية أو الواجهة
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('Got a message whilst in the foreground!');
          print('Message data: ${message.data}');
        }
        if (message.notification != null) {
          // هنا يتم إضافة الكود لتخزين الإشعار في Hive ليعمل Offline
          print('Message also contained a notification: ${message.notification}');
        }
      });
    }
  }
}
