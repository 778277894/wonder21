// lib/carts/cart_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'cart.dart'; // كلاس السلة (Cart / CartItem)
import '../admin/server_config.dart'; // يحتوي kServerIp = "http://192.168.0.16" مثلاً

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final TextEditingController noteC = TextEditingController();
  bool submitting = false;

  @override
  void dispose() {
    noteC.dispose();
    super.dispose();
  }

  // -------- Helpers --------
  num _numOf(dynamic v) => v is num ? v : (num.tryParse('${v ?? ''}') ?? 0);

  int _productIdOf(CartItem it) => int.tryParse(it.id) ?? 0;

  /// يضمن أن العنوان يبدأ بـ http(s) ولا يحتوي سلاش زائد قبل اسم الملف
  String _endpoint(String base, String filePath) {
    var b = base.trim();
    if (!b.startsWith('http://') && !b.startsWith('https://')) {
      b = 'http://$b';
    }
    if (b.endsWith('/')) b = b.substring(0, b.length - 1);
    if (filePath.startsWith('/')) filePath = filePath.substring(1);
    return '$b/$filePath';
  }

  Future<void> _checkout() async {
    if (Cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('السلة فارغة')),
      );
      return;
    }

    setState(() => submitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // نحاول بأكثر من مفتاح لأن صيغة التخزين قد تختلف
      final int? userId = prefs.getInt('userId') ??
          prefs.getInt('user_id') ??
          int.tryParse(prefs.getString('id') ?? '');

      final int? branchId =
          prefs.getInt('branchId') ?? prefs.getInt('branch_id');

      if (userId == null || userId <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يجب تسجيل الدخول أولاً')),
        );
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) Navigator.pushNamed(context, '/login');
        setState(() => submitting = false);
        return;
      }

      // تجهيز الخطوط
      final lines = Cart.items
          .map((it) => {
                'product_id': _productIdOf(it), // int
                'quantity': it.qty, // int
                'price': _numOf(it.price), // num
              })
          .toList();

      final payload = {
        'user_id': userId,
        if (branchId != null) 'branch_id': branchId,
        'note': noteC.text.trim(),
        'lines': lines,
      };

      final uri = Uri.parse(_endpoint(kServerIp, 'create_order.php'));
      final res = await http
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));

      final body = res.body;

      // جرّب نفك JSON، وإن فشل اعرض النص كما هو (قد يكون HTML خطأ PHP)
      Map<String, dynamic>? data;
      try {
        data = jsonDecode(body) as Map<String, dynamic>;
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'رد غير JSON من الخادم:\n${body.length > 400 ? body.substring(0, 400) + '…' : body}',
            ),
            duration: const Duration(seconds: 6),
          ),
        );
        setState(() => submitting = false);
        return;
      }

      // إن كان كود HTTP ليس 200، أو success=false
      if (res.statusCode != 200 ||
          (data['success'] != true && data['status'] != 'success')) {
        final msg = (data['message'] ?? 'فشل إنشاء الطلب').toString();
        final err = (data['error'] ?? '').toString();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err.isEmpty ? msg : '$msg\n$err')),
        );
        setState(() => submitting = false);
        return;
      }

      // نجاح
      final orderIdRaw = data['order_id'] ?? data['id'] ?? 0;
      final totalRaw = data['total'] ?? Cart.total();

      final orderId =
          orderIdRaw is int ? orderIdRaw : (int.tryParse('$orderIdRaw') ?? 0);

      final total = totalRaw is num
          ? totalRaw.toDouble()
          : (double.tryParse('$totalRaw') ?? Cart.total().toDouble());

      final orderDate = data['order_date']?.toString();

      // نظّف السلة وانتقل لصفحة النجاح
      Cart.clear();
      if (!mounted) return;

      Navigator.pushNamed(
        context,
        '/order_success',
        arguments: {
          'orderId': orderId,
          'total': total,
          'note': noteC.text.trim(),
          'orderDate': orderDate,
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e')),
      );
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = Cart.items;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('السلة'),
          backgroundColor: const Color(0xFFE9B270),
          actions: [
            // بادج ديناميكي باستخدام ValueListenableBuilder
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ValueListenableBuilder<int>(
                valueListenable: Cart.count,
                builder: (_, c, __) => Text(
                  '($c)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() => Cart.clear());
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم إفراغ السلة')),
                );
              },
              child: const Text('تفريغ', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('لا توجد عناصر في السلة'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 16),
                      itemBuilder: (_, i) {
                        final it = items[i];
                        final lineTotal = _numOf(it.price) * it.qty;

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // حذف
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() => Cart.remove(it.id));
                              },
                            ),
                            // - / الكمية / +
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () => setState(
                                      () => Cart.setQty(it.id, it.qty + 1)),
                                ),
                                Text('${it.qty}'),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () => setState(
                                      () => Cart.setQty(it.id, it.qty - 1)),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            // صورة
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: (it.imageUrl.isEmpty)
                                  ? const SizedBox(
                                      width: 64,
                                      height: 64,
                                      child: Icon(Icons.image),
                                    )
                                  : Image.network(
                                      it.imageUrl,
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const SizedBox(
                                        width: 64,
                                        height: 64,
                                        child: Icon(Icons.broken_image),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 8),
                            // اسم + أسعار
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    it.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Flexible(
                                        child:
                                            Text('السعر: ${_numOf(it.price)}'),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                            'الإجمالي: ${lineTotal.toStringAsFixed(2)}'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),

            // ملاحظات
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: noteC,
                decoration: const InputDecoration(
                  hintText: 'ملاحظات الطلب (اختياري)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ),

            // الإجمالي + إتمام الشراء
            Container(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                  )
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'الإجمالي: ${Cart.total().toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('إتمام الشراء'),
                    onPressed: submitting ? null : _checkout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
