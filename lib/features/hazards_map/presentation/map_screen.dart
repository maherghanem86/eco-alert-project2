import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:hive/hive.dart';

class MapScreen extends StatefulWidget {
  final LatLng? targetLocation; 

  const MapScreen({Key? key, this.targetLocation}) : super(key: key); 

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<Marker> _hazardMarkers = [];
  
  // 1. إنشاء متحكم للخريطة للتحكم بها برمجياً (تكبير/تصغير/تحريك)
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadMarkersFromCache();
  }

  void _loadMarkersFromCache() {
    final box = Hive.box('alerts_cache_box');
    List<Marker> markers = [];

    for (int i = 0; i < box.length; i++) {
      final alert = box.getAt(i) as Map<dynamic, dynamic>;
      final coords = alert['coordinates'];
      
      if (coords != null && coords['latitude'] != null && coords['longitude'] != null) {
        final double lat = (coords['latitude'] as num).toDouble();
        final double lng = (coords['longitude'] as num).toDouble();
        final String severity = alert['severity'] ?? 'low';

        Color markerColor = Colors.green;
        if (severity == 'high') markerColor = Colors.red;
        if (severity == 'medium') markerColor = Colors.orange;

        markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 40,
            height: 40,
            child: Icon(
              Icons.location_on,
              color: markerColor,
              size: 40,
            ),
          ),
        );
      }
    }

    setState(() {
      _hazardMarkers = markers;
    });
  }

  // 2. دالة التكبير (Zoom In)
  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    final currentCenter = _mapController.camera.center;
    // زيادة مستوى التكبير بمقدار 1
    _mapController.move(currentCenter, currentZoom + 1);
  }

  // 3. دالة التصغير (Zoom Out)
  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    final currentCenter = _mapController.camera.center;
    // إنقاص مستوى التكبير بمقدار 1
    _mapController.move(currentCenter, currentZoom - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('خريطة المخاطر البيئية'),
        backgroundColor: Colors.green,
      ),
      // استخدام Stack لنتمكن من وضع الأزرار فوق الخريطة
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController, // ربط المتحكم بالخريطة هنا
            options: MapOptions(
              initialCenter: widget.targetLocation ?? const LatLng(34.8021, 38.9968),
              initialZoom: widget.targetLocation != null ? 9.0 : 6.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.ecoalert.app',
              ),
              MarkerLayer(
                markers: _hazardMarkers,
              ),
            ],
          ),
          
          // 4. واجهة أزرار التكبير والتصغير العائمة
          Positioned(
            bottom: 30,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "btnZoomIn", // يجب وضع heroTag مختلف إذا كان هناك أكثر من FAB
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add, color: Colors.green),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "btnZoomOut",
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove, color: Colors.green),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}