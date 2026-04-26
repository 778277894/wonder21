// lib/auth/login_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 1. استيراد ملف الإعدادات الموحد
import '../admin/server_config.dart'; // يحتوي kServerIp = "http://192.168.0.16" مثلاً

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;

  // تم الاستغناء عن baseUrl المحلية واستخدام kBaseUrl من ملف server_config.dart

  Future<void> _authenticate() async {
    try {
      final ok = await auth.authenticate(
        localizedReason: 'الرجاء استخدام البصمة لتسجيل الدخول',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (ok && mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      _showMessage('فشل في التحقق: $e');
    }
  }

  Future<void> loginUser() async {
    final phone = phoneController.text.trim();
    final password = passwordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      _showMessage("يرجى إدخال رقم الهاتف وكلمة المرور");
      return;
    }

    setState(() => isLoading = true);

    try {
      // 2. استخدام kBaseUrl للاتصال بالسيرفر
      final uri = Uri.parse("$kServerIp/login.php");
      final response = await http.post(
        uri,
        headers: const {"Content-Type": "application/x-www-form-urlencoded"},
        body: {"phone": phone, "password": password},
      );

      if (response.statusCode != 200) {
        throw Exception(
            "HTTP ${response.statusCode}: ${response.reasonPhrase}");
      }

      final data = jsonDecode(response.body);

      final bool ok = (data is Map) &&
          (data["success"] == true || data["status"] == "success");

      if (!ok) {
        _showMessage("❌ ${data["message"] ?? "بيانات الدخول غير صحيحة"}");
        return;
      }

      final user = Map<String, dynamic>.from(data["user"] ?? {});
      final role = (user["role"] ?? "user").toString();

      final idStr = (user["id"] ?? user["user_id"] ?? '').toString();
      final idInt = int.tryParse(idStr) ?? 0;
      final branchId = int.tryParse('${user["branch_id"] ?? ''}');

      if (idInt <= 0) {
        _showMessage("تعذر تحديد معرّف المستخدم من الاستجابة.");
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('loggedIn', true);
      await prefs.setBool('is_guest', false);
      await prefs.setString('userRole', role);
      await prefs.setInt('userId', idInt);
      await prefs.setInt('user_id', idInt);
      await prefs.setString(
          'user_name', (user["name"] ?? user["username"] ?? '').toString());
      await prefs.setString('user_email', (user["email"] ?? '').toString());
      await prefs.setString('user_phone', (user["phone"] ?? '').toString());

      if (branchId != null) {
        await prefs.setInt('branchId', branchId);
        await prefs.setInt('branch_id', branchId);
      }

      _showMessage("✅ ${data["message"] ?? "تم تسجيل الدخول بنجاح"}");

      if (!mounted) return;

      if (role.toLowerCase() == "admin") {
        Navigator.pushReplacementNamed(context, '/admin_dashboard');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      _showMessage("حدث خطأ: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loginAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('loggedIn', false);
    await prefs.setBool('is_guest', true);
    await prefs.setInt('userId', 0);
    await prefs.setInt('user_id', 0);
    await prefs.remove('userRole');
    await prefs.remove('branchId');
    await prefs.remove('branch_id');

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        backgroundColor: const Color.fromARGB(255, 210, 156, 7),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      appBar: AppBar(
        title: const Text("تسجيل الدخول"),
        backgroundColor: const Color.fromARGB(255, 210, 156, 7),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  children: [
                    const Icon(Icons.person,
                        size: 80, color: Color.fromARGB(255, 210, 156, 7)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'رقم الهاتف',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: loginUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 210, 156, 7),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text("دخول"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/signup'),
                      child: const Text("ليس لديك حساب؟ إنشاء حساب جديد"),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/forgot_password'),
                      child: const Text("هل نسيت كلمة السر؟"),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _loginAsGuest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 180, 140, 0),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text("الدخول كزائر"),
                    ),
                    const SizedBox(height: 30),
                    GestureDetector(
                      onTap: _authenticate,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color.fromARGB(255, 210, 156, 7),
                        ),
                        child: const Icon(Icons.fingerprint, size: 60),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text("الدخول بالبصمة"),
                  ],
                ),
              ),
      ),
    );
  }
}
