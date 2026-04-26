import 'package:flutter/foundation.dart';

/// نموذج بسيط للسلة بداخل الذاكرة مع ValueNotifier لعرض البادج
class Cart {
  static final List<Map<String, dynamic>> items = [];
  static final ValueNotifier<int> count = ValueNotifier<int>(0);

  static void add(Map<String, dynamic> item) {
    items.add(item);
    count.value = items.length;
  }

  static void removeAt(int index) {
    items.removeAt(index);
    count.value = items.length;
  }

  static void clear() {
    items.clear();
    count.value = 0;
  }

  static double get total =>
      items.fold(0.0, (sum, m) => sum + ((m['price'] as num?)?.toDouble() ?? 0.0) * (m['qty'] ?? 1));
}