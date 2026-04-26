import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// استيراد ملف الإعدادات الموحد للـ IP
import '../admin/server_config.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchProfile();
  }

  Future<void> fetchProfile() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final uri =
          Uri.parse("$kServerIp/get_profile.php?user_id=${widget.userId}");
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true) {
          setState(() {
            userData = decoded['user'];
            isLoading = false;
          });
        } else {
          setState(() {
            error = decoded['message'] ?? 'لم يتم العثور على بيانات';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          error = "خطأ في السيرفر: ${response.statusCode}";
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        error = "تعذر الوصول للسيرفر. تأكد من عنوان الـ IP والاتصال.";
      });
    }
  }

  // نظام النقاط الملونة (فئة السعر)
  Widget _buildPriceDots(String type) {
    String dots = '•';
    Color color = Colors.blue;

    if (type.contains('جملة الجملة')) {
      dots = '•••';
      color = Colors.red;
    } else if (type.contains('جملة')) {
      dots = '••';
      color = Colors.orange;
    }

    return Row(
      children: [
        Text(dots,
            style: TextStyle(
                fontSize: 30,
                color: color,
                fontWeight: FontWeight.bold,
                letterSpacing: 2)),
        const SizedBox(width: 10),
        Text(type, style: const TextStyle(fontSize: 14, color: Colors.black87)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = (userData?['username'] ?? '...').toString();
    final tradeName =
        (userData?['trade_name'] ?? 'لا يوجد اسم تجاري').toString();
    final branch = (userData?['branch_name'] ?? 'غير محدد').toString();
    final phone = (userData?['phone'] ?? '-').toString();
    final email = (userData?['email'] ?? '-').toString();
    final address =
        "${userData?['governorate'] ?? ''} ${userData?['address'] ?? ''}";
    final priceType = (userData?['price_type'] ?? 'تجزئة').toString();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: const Text("الملف الشخصي",
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: const Color(0xFFD29C07),
          centerTitle: true,
          elevation: 0,
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: fetchProfile),
          ],
        ),
        body: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFD29C07)))
            : error != null
                ? _buildErrorWidget()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildHeader(name, tradeName),
                        const SizedBox(height: 25),
                        _buildSectionTitle("الموقع والفرع"),
                        _infoTile(Icons.store_mall_directory_outlined,
                            "الفرع المعتمد", branch),
                        _infoTile(Icons.location_on_outlined, "العنوان الحالي",
                            address.trim().isEmpty ? "غير محدد" : address),
                        const SizedBox(height: 20),
                        _buildSectionTitle("معلومات التواصل"),
                        _infoTile(Icons.phone_android, "رقم الهاتف", phone),
                        _infoTile(
                            Icons.email_outlined, "البريد الإلكتروني", email),
                        const SizedBox(height: 20),
                        _buildSectionTitle("نظام التسعير المعتمد"),
                        _customCard(
                          child: ListTile(
                            leading: const Icon(Icons.stars_rounded,
                                color: Color(0xFFD29C07)),
                            title: const Text("فئة السعر",
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                            subtitle: _buildPriceDots(priceType),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildHeader(String name, String trade) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFD29C07), width: 2),
          ),
          child: CircleAvatar(
            radius: 45,
            backgroundColor: const Color(0xFFD29C07).withOpacity(0.1),
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                    fontSize: 35,
                    color: Color(0xFFD29C07),
                    fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),
        Text(name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        if (trade != "لا يوجد اسم تجاري")
          Text(trade,
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, right: 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black54)),
      ),
    );
  }

  Widget _infoTile(IconData icon, String title, String value) {
    return _customCard(
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFD29C07)),
        title: Text(title,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
        subtitle: Text(value,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
      ),
    );
  }

  Widget _customCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: child,
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 60, color: Colors.grey),
          const SizedBox(height: 15),
          Text(error ?? 'فشل الاتصال'),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD29C07)),
            onPressed: fetchProfile,
            child: const Text("تحديث الصفحة",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
