import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
// استيراد ملف الإعدادات الذي تم توليده بواسطة flutterfire configure
import 'firebase_options.dart'; 

// استيراد الشاشة الرئيسية
import 'features/alerts/presentation/dashboard_screen.dart';

void main() async {
  // 1. التأكد من تهيئة فلاتر قبل تنفيذ أي عمليات غير متزامنة
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. تهيئة قاعدة البيانات المحلية (Hive)
  await Hive.initFlutter();
  await Hive.openBox('alerts_cache_box');

  // 3. تهيئة خدمات فايربيس بشكل صحيح باستخدام ملف الإعدادات
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("تنبيه: حدث خطأ أثناء تهيئة Firebase: $e");
  }
  
  // تشغيل واجهة التطبيق
  runApp(const EcoAlertApp());
}

class EcoAlertApp extends StatelessWidget {
  const EcoAlertApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eco Alert',
      debugShowCheckedModeBanner: false, 
      
      // ضبط الثيم الخاص بالتطبيق
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 2,
          foregroundColor: Colors.white,
        ),
      ),
      
      // الشاشة الأولى
      home: const DashboardScreen(),
    );
  }
}