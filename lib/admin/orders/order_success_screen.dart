// lib/orders/order_success_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrderSuccessScreen extends StatelessWidget {
  final int orderId;
  final double total;
  final String? note;
  final String? orderDate; // بصيغة ISO من السيرفر (اختياري)

  const OrderSuccessScreen({
    super.key,
    required this.orderId,
    required this.total,
    this.note,
    this.orderDate,
  });

  // تنسيق التاريخ والوقت بالعربي (تأكد أنك استدعيت initializeDateFormatting('ar') في main)
  String _formatArDate(String? iso) {
    try {
      final dt = (iso != null && iso.isNotEmpty)
          ? DateTime.parse(iso).toLocal()
          : DateTime.now();
      final dateStr = DateFormat('EEEE، d MMMM y', 'ar').format(dt);
      final timeStr = DateFormat('h:mm a', 'ar').format(dt);
      return '$dateStr  $timeStr';
    } catch (_) {
      return DateFormat('d/M/y h:mm a', 'ar').format(DateTime.now());
    }
  }

  String _money(double v) => v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final displayDate = _formatArDate(orderDate);

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF5E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE9B270),
        automaticallyImplyLeading: false,
        title: const Text('تم إتمام الطلب'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end, // RTL قادم من MaterialApp
          children: [
            const SizedBox(height: 20),
            const Center(
              child: Icon(Icons.check_circle, color: Colors.green, size: 90),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'شكرًا لك! تم استلام طلبك بنجاح 🎉',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 25),

            // بطاقة معلومات الطلب
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              elevation: 1.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _infoRow('رقم الطلب', '#$orderId'),
                    _infoRow('الإجمالي', '${_money(total)} ر.س'),
                    _infoRow('التاريخ', displayDate),
                    if (note != null && note!.trim().isNotEmpty)
                      _infoRow('الملاحظات', note!.trim()),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),

            // الذهاب لصفحة الطلبات
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.list_alt),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE9B270),
                  foregroundColor: Colors.black,
                ),
                onPressed: () =>
                    Navigator.pushNamed(context, '/my_orders_screen'),
                label: const Text('عرض الطلبات'),
              ),
            ),
            const SizedBox(height: 12),

            // الرجوع للرئيسية
            Center(
              child: TextButton.icon(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/home',
                  (route) => false,
                ),
                icon: const Icon(Icons.home),
                label: const Text('العودة إلى الرئيسية'),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.left,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
