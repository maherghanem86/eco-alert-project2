import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart'; // تأكد من تشغيل flutter pub add geolocator
import '../../../core/services/hazards_sync_service.dart';
import '../../hazards_map/presentation/map_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Box _alertsBox;
  bool _isLoading = false;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _initHiveAndLoadData();
  }

  Future<void> _initHiveAndLoadData() async {
    setState(() => _isLoading = true);
    
    _alertsBox = await Hive.openBox('alerts_cache_box');
    
    bool hasConnection = await InternetConnectionChecker.createInstance().hasConnection;
    setState(() => _isOffline = !hasConnection);

    if (hasConnection) {
      await _syncFromFirestoreToLocal();
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _syncFromFirestoreToLocal() async {
    try {
      debugPrint("جاري محاولة الاتصال بـ Firestore...");
      final snapshot = await FirebaseFirestore.instance
          .collection('environmental_hazards')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      debugPrint("تم جلب ${snapshot.docs.length} مستند.");
      await _alertsBox.clear();
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['timestamp'] is Timestamp) {
          data['timestamp'] = (data['timestamp'] as Timestamp).toDate().toIso8601String();
        }
        await _alertsBox.put(doc.id, data);
      }
    } catch (e) {
      debugPrint("خطأ كارثي: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), duration: const Duration(seconds: 5)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _syncOpenData() async {
     setState(() => _isLoading = true);
     await HazardsSyncService().fetchAndSaveEarthquakes();
     await _syncFromFirestoreToLocal();
     setState(() => _isLoading = false);
     
     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('تم تحديث البيانات بنجاح!')),
       );
     }
  }

  Future<void> _submitCommunityReport(String type, String severity) async {
    if (_isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('عذراً، يجب أن تكون متصلاً بالإنترنت لتقديم بلاغ.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('تم رفض صلاحية الوصول للموقع');
        }
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      // إرسال البلاغ مع مستوى الشدة
      await FirebaseFirestore.instance.collection('community_reports').add({
        'type': type,
        'severity': severity, // إضافة الشدة هنا
        'coordinates': {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending_verification',
        'source': 'community',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال بلاغك! النظام سيقوم بالتحقق منه فوراً.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في إرسال البلاغ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showReportDialog() {
    String selectedType = 'حريق';
    String selectedSeverity = 'medium'; // افتراضياً متوسط

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('الإبلاغ عن خطر بيئي', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('1. حدد نوع الخطر:', style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: selectedType,
                      items: const [
                        DropdownMenuItem(value: 'حريق', child: Text('🔥 حريق غابات / منشأة')),
                        DropdownMenuItem(value: 'فيضان', child: Text('🌊 سيول / فيضان')),
                        DropdownMenuItem(value: 'تلوث', child: Text('💨 تلوث هوائي خانق / تسرب')),
                      ],
                      onChanged: (val) => setDialogState(() => selectedType = val!),
                    ),
                    const SizedBox(height: 16),
                    const Text('2. حدد شدة الخطر:', style: TextStyle(fontWeight: FontWeight.bold)),
                    RadioListTile<String>(
                      title: const Text('عالي (خطر مباشر)'),
                      value: 'high',
                      groupValue: selectedSeverity,
                      activeColor: Colors.red,
                      onChanged: (val) => setDialogState(() => selectedSeverity = val!),
                    ),
                    RadioListTile<String>(
                      title: const Text('متوسط'),
                      value: 'medium',
                      groupValue: selectedSeverity,
                      activeColor: Colors.orange,
                      onChanged: (val) => setDialogState(() => selectedSeverity = val!),
                    ),
                    RadioListTile<String>(
                      title: const Text('منخفض'),
                      value: 'low',
                      groupValue: selectedSeverity,
                      activeColor: Colors.green,
                      onChanged: (val) => setDialogState(() => selectedSeverity = val!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  child: const Text('إرسال البلاغ', style: TextStyle(color: Colors.white)),
                  onPressed: () {
                    Navigator.pop(context);
                    _submitCommunityReport(selectedType, selectedSeverity);
                  },
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التنبيهات البيئية (Eco Alert)'),
        backgroundColor: _isOffline ? Colors.grey : Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'مزامنة يدوية',
            onPressed: _isOffline ? null : _syncOpenData,
          ),
          IconButton(
            icon: const Icon(Icons.map),
            tooltip: 'عرض الخريطة',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MapScreen()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showReportDialog,
        backgroundColor: Colors.redAccent,
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
        label: const Text('إبلاغ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          if (_isOffline)
            Container(
              width: double.infinity,
              color: Colors.redAccent,
              padding: const EdgeInsets.all(8),
              child: const Text(
                'أنت غير متصل بالإنترنت. يتم عرض البيانات المخزنة محلياً.',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),

          Expanded(
            child: ValueListenableBuilder(
              valueListenable: Hive.box('alerts_cache_box').listenable(),
              builder: (context, Box box, _) {
                if (box.isEmpty && !_isLoading) {
                  return const Center(
                    child: Text('لا توجد تنبيهات حالية.'),
                  );
                }

                return ListView.builder(
                  itemCount: box.length,
                  itemBuilder: (context, index) {
                    final dynamic rawData = box.getAt(index);
                    if (rawData == null) return const SizedBox.shrink();
                    
                    final Map<dynamic, dynamic> alert = rawData as Map<dynamic, dynamic>;

                    final String title = alert['title'] ?? 'تنبيه غير معروف';
                    final String type = alert['type'] ?? 'غير محدد';
                    final String severity = alert['severity'] ?? 'low';
                    final String location = alert['location_name'] ?? 'موقع غير معروف';
                    
                    Color severityColor = Colors.green;
                    if (severity == 'high') severityColor = Colors.red;
                    if (severity == 'medium') severityColor = Colors.orange;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 2,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: severityColor.withOpacity(0.2),
                          child: Icon(
                            type == 'Earthquake' ? Icons.waves : 
                            (type == 'حريق' ? Icons.local_fire_department : Icons.warning), 
                            color: severityColor
                          ),
                        ),
                        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('$type - $location'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          final coords = alert['coordinates'];
                          if (coords != null && coords['latitude'] != null && coords['longitude'] != null) {
                            final double lat = (coords['latitude'] as num).toDouble();
                            final double lng = (coords['longitude'] as num).toDouble();
                            
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MapScreen(
                                  targetLocation: LatLng(lat, lng),
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('إحداثيات هذا الخطر غير متوفرة')),
                            );
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}