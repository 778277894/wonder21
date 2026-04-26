import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import './server_config.dart';

class AdminAnalytics extends StatefulWidget {
  const AdminAnalytics({super.key});

  @override
  State<AdminAnalytics> createState() => _AdminAnalyticsState();
}

class _AdminAnalyticsState extends State<AdminAnalytics> {
  bool loading = true;
  String? error;
  Map<String, dynamic> data = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final url = Uri.parse("$kServerIp/get_orders_summary.php");
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception(
            "السيرفر غير متاح حالياً (Error ${response.statusCode})");
      }

      // فحص إذا كانت الاستجابة تبدأ بـ { (JSON) أم بـ <html> (حماية السيرفر)
      if (!response.body.trim().startsWith('{')) {
        throw const FormatException(
            "نظام حماية السيرفر يمنع الوصول المباشر. يرجى مراجعة إعدادات الاستضافة.");
      }

      final jsonResponse = jsonDecode(response.body);

      if (jsonResponse['success'] == true) {
        setState(() {
          data = jsonResponse['summary'] ?? {};
        });
      } else {
        error = jsonResponse['message'] ?? 'فشل في جلب الإحصائيات';
      }
    } catch (e) {
      if (e is FormatException) {
        error = "خطأ في تنسيق البيانات القادمة من السيرفر (تأكد من ملف PHP)";
      } else {
        error = "حدث خطأ: ${e.toString()}";
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('إحصائيات الإدارة',
              style:
                  TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFFEAD340), // اللون الأصفر في تصميمك
          centerTitle: true,
          elevation: 0,
          actions: [
            IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh, color: Colors.black))
          ],
        ),
        body: loading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.amber))
            : error != null
                ? _buildErrorUI()
                : _buildContent(),
      ),
    );
  }

  Widget _buildErrorUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 70, color: Colors.grey),
            const SizedBox(height: 15),
            Text(error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 14)),
            const SizedBox(height: 20),
            ElevatedButton(
                onPressed: _load, child: const Text("إعادة المحاولة"))
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _statCard(
            'إجمالي الطلبات', '${data['orders_count'] ?? 0}', Colors.blue),
        _statCard('إجمالي الإيرادات', '${data['total_revenue'] ?? 0} ريال',
            Colors.green),
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
        _statTile('طلبات معلقة', '${data['pending'] ?? 0}', Colors.orange),
        _statTile('طلبات مدفوعة', '${data['paid'] ?? 0}', Colors.teal),
        _statTile('قيد الشحن', '${data['shipped'] ?? 0}', Colors.purple),
        _statTile('طلبات مكتملة', '${data['completed'] ?? 0}', Colors.blueGrey),
        _statTile('طلبات ملغية', '${data['canceled'] ?? 0}', Colors.red),
      ],
    );
  }

  Widget _statCard(String label, String val, Color color) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(colors: [color.withOpacity(0.7), color])),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 5),
            Text(val,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String label, String val, Color color) {
    return ListTile(
      leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(Icons.circle, size: 12, color: color)),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: Text(val,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
}
