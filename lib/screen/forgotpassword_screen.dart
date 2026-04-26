import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController phoneController = TextEditingController();
  bool isLoading = false;

  void resetPassword() async {
    String phone = phoneController.text.trim();

    if (phone.isEmpty) {
      showMessage("الرجاء إدخال رقم الهاتف");
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(
            "http://127.0.0.1/forgot_password.php"), // عدل الرابط حسب السيرفر
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"phone": phone}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) {
          showMessage("✅ ${data["message"]}");
          Navigator.pop(context); // يرجع لصفحة تسجيل الدخول
        } else {
          showMessage("❌ ${data["message"]}");
        }
      } else {
        showMessage("خطأ في السيرفر: ${response.statusCode}");
      }
    } catch (e) {
      showMessage("حدث خطأ: $e");
    }

    setState(() => isLoading = false);
  }

  void showMessage(String msg) {
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
      appBar: AppBar(
        title: const Text("استعادة كلمة المرور"),
        backgroundColor: const Color.fromARGB(255, 210, 156, 7),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  const Icon(Icons.lock_reset,
                      size: 80, color: Color.fromARGB(255, 210, 156, 7)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: "رقم الهاتف",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: resetPassword,
                    child: const Text("إرسال طلب استعادة"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 210, 156, 7),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
