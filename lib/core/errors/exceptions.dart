// استثناء عند فشل جلب البيانات من السيرفر
class ServerException implements Exception {
  final String message;
  ServerException({required this.message});
}

// استثناء عند فشل جلب البيانات من التخزين المحلي (العمل دون اتصال)
class CacheException implements Exception {
  final String message;
  CacheException({required this.message});
}

// استثناء خاص بانقطاع شبكة الإنترنت
class NetworkException implements Exception {
  final String message;
  NetworkException({this.message = 'لا يوجد اتصال بالإنترنت'});
}
