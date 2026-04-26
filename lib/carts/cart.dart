// lib/carts/cart.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// عنصر واحد في السلة
class CartItem {
  final String id; // product_id أو id كـ String
  final String name;
  final String imageUrl; // قد يكون فارغاً
  final num price; // سعر الوحدة
  int qty; // الكمية

  CartItem({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.price,
    required this.qty,
  });

  /// إنشاء من خريطة (مثلاً منتج قادم من API أو من التخزين)
  factory CartItem.fromMap(Map<String, dynamic> m) {
    String _str(dynamic v) => (v ?? '').toString();

    // يدعم وجود product_id أو id
    final pid = _str(m['product_id']).isNotEmpty
        ? _str(m['product_id'])
        : _str(m['id']);

    num _num(dynamic v) {
      if (v is num) return v;
      return num.tryParse(_str(v)) ?? 0;
    }

    return CartItem(
      id: pid,
      name: _str(m['name']),
      imageUrl: _str(m['image_url']),
      price: _num(m['price']),
      qty: int.tryParse(_str(m['qty'])) ??
          int.tryParse(_str(m['quantity'])) ??
          1,
    );
  }

  /// تحويل إلى خريطة لتخزينها محلياً
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'image_url': imageUrl,
        'price': price,
        'qty': qty,
      };
}

/// السلة (ثابتة على مستوى التطبيق)
class Cart {
  static final List<CartItem> _items = <CartItem>[];

  /// بادج ديناميكي (يُحدّث تلقائياً في الواجهات عبر ValueListenableBuilder)
  static final ValueNotifier<int> count = ValueNotifier<int>(0);

  static List<CartItem> get items => List.unmodifiable(_items);

  static const _storeKey = 'cart_items';

  /// استدعِها مرة في بداية التطبيق لتحميل السلة من التخزين
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storeKey);
    if (raw == null || raw.isEmpty) {
      count.value = 0;
      return;
    }
    try {
      final List list = jsonDecode(raw);
      _items
        ..clear()
        ..addAll(list
            .cast<Map>()
            .map((e) => CartItem.fromMap(Map<String, dynamic>.from(e))));
      _notify();
    } catch (_) {
      // في حال فساد البيانات
      _items.clear();
      _notify();
    }
  }

  /// يحفظ السلة إلى SharedPreferences
  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _items.map((e) => e.toMap()).toList();
    await prefs.setString(_storeKey, jsonEncode(list));
  }

  static void _notify() {
    count.value = _items.fold<int>(0, (s, e) => s + e.qty);
    // حفظ بدون انتظار
    _save();
  }

  static String _idFrom(Map product) {
    String _s(dynamic v) => (v ?? '').toString();
    final pid = _s(product['product_id']);
    if (pid.isNotEmpty) return pid;
    return _s(product['id']);
  }

  static num _priceOf(dynamic v) {
    if (v is num) return v;
    return num.tryParse((v ?? '').toString()) ?? 0;
  }

  /// إضافة منتج (إن كان موجوداً يزيد الكمية فقط)
  static void addProduct(Map<String, dynamic> product, {int qty = 1}) {
    final id = _idFrom(product);
    if (id.isEmpty) return;

    final name = (product['name'] ?? '').toString();
    final imageUrl = (product['image_url'] ?? '').toString();
    final price = _priceOf(product['price']);
    if (price <= 0) {
      // يمكن السماح بـ 0، لكن نحافظ على منطق واضح
    }

    final idx = _items.indexWhere((e) => e.id == id);
    if (idx >= 0) {
      _items[idx].qty += qty;
      if (_items[idx].qty < 1) _items[idx].qty = 1;
    } else {
      _items.add(CartItem(
        id: id,
        name: name,
        imageUrl: imageUrl,
        price: price,
        qty: qty > 0 ? qty : 1,
      ));
    }
    _notify();
  }

  static void remove(String id) {
    _items.removeWhere((e) => e.id == id);
    _notify();
  }

  static void setQty(String id, int qty) {
    final i = _items.indexWhere((e) => e.id == id);
    if (i < 0) return;
    if (qty <= 0) {
      _items.removeAt(i);
    } else {
      _items[i].qty = qty;
    }
    _notify();
  }

  /// مجموع الكميات (للإحصاء)
  static int itemsCount() => _items.fold(0, (s, e) => s + e.qty);

  /// الإجمالي
  static num total() => _items.fold<num>(0, (s, e) => s + (e.price * (e.qty)));

  static void clear() {
    _items.clear();
    _notify();
  }
}
