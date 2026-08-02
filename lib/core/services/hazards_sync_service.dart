import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class HazardsSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // هذه الدالة هي البديل البرمجي لـ Cloud Function
  Future<void> fetchAndSaveEarthquakes() async {
    try {
      print("جاري جلب البيانات من USGS...");
      // رابط بيانات الزلازل (أكبر من 4.5 خلال اليوم الماضي)
      const url = 'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/4.5_day.geojson';
      
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List features = data['features'];

        if (features.isEmpty) {
          print("لا يوجد زلازل حديثة.");
          return;
        }

        // استخدام batch لرفع البيانات دفعة واحدة لتقليل استهلاك Firebase
        final batch = _firestore.batch();
        final hazardsRef = _firestore.collection('environmental_hazards');

        for (var feature in features) {
          final properties = feature['properties'];
          final geometry = feature['geometry'];
          
          final String hazardId = feature['id'];
          final double magnitude = (properties['mag'] as num).toDouble();
          final String place = properties['place'];
          final int timeMillis = properties['time'];

          // تحديد خطورة الزلزال
          String severity = 'low';
          if (magnitude >= 6.0) severity = 'high';
          else if (magnitude >= 5.0) severity = 'medium';

          // تجهيز البيانات لرفعها لـ Firestore
          final hazardData = {
            'title': 'زلزال بقوة $magnitude ريختر',
            'type': 'Earthquake',
            'severity': severity,
            'location_name': place,
            'coordinates': {
              'latitude': geometry['coordinates'][1],
              'longitude': geometry['coordinates'][0],
            },
            'timestamp': Timestamp.fromMillisecondsSinceEpoch(timeMillis),
            'source': 'USGS',
            'details': properties['url']
          };

          // إضافتها إلى الـ Batch (مع دمج البيانات لمنع التكرار)
          batch.set(hazardsRef.doc(hazardId), hazardData, SetOptions(merge: true));
        }

        // تنفيذ الرفع
        await batch.commit();
        print("تم جلب وتخزين ${features.length} زلزالاً بنجاح في Firestore.");

      } else {
        print("فشل جلب البيانات. كود الخطأ: ${response.statusCode}");
      }
    } catch (e) {
      print("حدث خطأ أثناء المزامنة: $e");
    }
  }
}