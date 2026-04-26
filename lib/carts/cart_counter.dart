import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartCounter {
  static const _key = "cart_json";
  static final ValueNotifier<int> count = ValueNotifier<int>(0);

  /// استدعها مرة واحدة عند تشغيل التطبيق (main أو MyApp.initState)
  static Future<void> init() async {
    await refresh();
  }

  /// حساب العدد من SharedPreferences وتحديث البادج
  static Future<void> refresh() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw == null || raw.isEmpty) {
        count.value = 0;
        return;
      }
      final List list = jsonDecode(raw);
      int c = 0;
      for (final it in list) {
        c += int.tryParse("${it["qty"] ?? 1}") ?? 1;
      }
      count.value = c;
    } catch (_) {
      count.value = 0;
    }
  }

  /// لمسح العدد بعد تفريغ السلة
  static void reset() => count.value = 0;
}
