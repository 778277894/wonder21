import 'dart:io';

enum AppEnv { dev, prod }

class Env {
  static AppEnv current = AppEnv.dev;

  /// عدّل هذا فقط لو بتجرب من موبايل حقيقي
  static const String localNetworkIp = "127.0.0.1";
  // استبدل 192.168.1.5 بالـ IP تبع الكمبيوتر اللي فيه XAMPP/WAMP

  static String get baseUrl {
    switch (current) {
      case AppEnv.dev:
        // كشف الجهاز أو المحاكي
        if (Platform.isAndroid) {
          // Android Emulator
          return "http://127.0.0.1/wonderful2";
        } else if (Platform.isIOS) {
          // iOS Simulator
          return "http://127.0.0.1/wonderful2";
        } else {
          // موبايل حقيقي (Android/iOS) أو حتى Desktop
          return "http://$localNetworkIp/wonderful2";
        }

      case AppEnv.prod:
        return "https://your-production-domain.com/api";
    }
  }
}
