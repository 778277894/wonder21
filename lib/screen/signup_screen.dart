import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  static const String serverIp = "192.168.0.16"; // غيّر إلى 10.0.2.2 للمحاكي
  String get baseUrl => "http://$serverIp";

  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _phoneC = TextEditingController();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  final _confirmC = TextEditingController();
  final _addressC = TextEditingController();
  final _tradeNameC = TextEditingController();

  final List<String> _countries = const ["اليمن"];
  final List<String> _yemenGovs = const [
    'أمانة العاصمة',
    'صنعاء',
    'عدن',
    'تعز',
    'الحديدة',
    'إب',
    'ذمار',
    'حجة',
    'البيضاء',
    'مأرب',
    'الجوف',
    'صعدة',
    'عمران',
    'المحويت',
    'ريمة',
    'الضالع',
    'لحج',
    'أبين',
    'شبوة',
    'حضرموت',
    'المهرة',
    'سقطرى'
  ];

  String? _country = "اليمن";
  String? _governorate;
  int? _branchId;
  bool _loading = false;
  List<Map<String, dynamic>> _branches = [];

  @override
  void initState() {
    super.initState();
    _fetchBranches();
  }

  Future<void> _fetchBranches() async {
    try {
      final res = await http.get(Uri.parse("$baseUrl/get_branches.php"),
          headers: const {'Accept': 'application/json'});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          final List list = data['branches'] ?? [];
          setState(() {
            _branches = list.cast<Map<String, dynamic>>();
            if (_branches.isNotEmpty) {
              _branchId = int.tryParse("${_branches.first['id']}");
            }
          });
        } else {
          _snack("فشل تحميل الفروع");
        }
      } else {
        _snack("HTTP ${res.statusCode}: ${res.reasonPhrase}");
      }
    } catch (e) {
      _snack("خطأ تحميل الفروع: $e");
    }
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passC.text != _confirmC.text) {
      _snack("كلمتا المرور غير متطابقتين");
      return;
    }
    if (_country != "اليمن") {
      _snack("الدولة يجب أن تكون اليمن");
      return;
    }
    if (_branchId == null) {
      _snack("اختر الفرع");
      return;
    }

    setState(() => _loading = true);
    try {
      final uri = Uri.parse("$baseUrl/signup.php");
      final res = await http.post(
        uri,
        headers: const {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: {
          'username': _nameC.text.trim(),
          'phone': _phoneC.text.trim(),
          'email': _emailC.text.trim(),
          'password': _passC.text.trim(),
          'role': 'user',
          'branch_id': "${_branchId!}",
          'country': _country ?? 'اليمن',
          'governorate': _governorate ?? '',
          'address': _addressC.text.trim(),
          'trade_name': _tradeNameC.text.trim(),
        },
      );

      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          // ✅ عرض رسالة ترحيب قبل الانتقال
          _showSuccessDialog(data['message'] ?? "تم إنشاء الحساب بنجاح");
        } else {
          _snack("❌ ${data['message'] ?? 'فشل التسجيل'}");
        }
      } else {
        String msg = "HTTP ${res.statusCode}";
        try {
          msg += " • ${jsonDecode(res.body)['message'] ?? ''}";
        } catch (_) {}
        _snack(msg);
      }
    } catch (e) {
      if (mounted) _snack("خطأ: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          "🎉 تهانينا!",
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
        ),
        content: Text(
          "$message\n\nسيتم تحويلك إلى صفحة تسجيل الدخول...",
          textAlign: TextAlign.center,
        ),
      ),
    );

    // ⏳ بعد 5ثوان يغلق الرسالة وينتقل
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        Navigator.of(context).pop(); // إغلاق الرسالة
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m, textAlign: TextAlign.center)),
    );
  }

  @override
  void dispose() {
    _nameC.dispose();
    _phoneC.dispose();
    _emailC.dispose();
    _passC.dispose();
    _confirmC.dispose();
    _addressC.dispose();
    _tradeNameC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
            title: const Text("إنشاء حساب"), backgroundColor: Colors.orange),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(children: [
                    DropdownButtonFormField<int>(
                      value: _branchId,
                      decoration: const InputDecoration(
                          labelText: 'الفرع', border: OutlineInputBorder()),
                      items: _branches
                          .map((b) => DropdownMenuItem<int>(
                                value: int.tryParse("${b['branch_id']}"),
                                child: Text("${b['branch_name']}"),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _branchId = v),
                      validator: (v) => v == null ? "اختر الفرع" : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _country,
                      decoration: const InputDecoration(
                          labelText: 'الدولة', border: OutlineInputBorder()),
                      items: _countries
                          .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setState(() => _country = v),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? "اختر الدولة" : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _governorate,
                      decoration: const InputDecoration(
                          labelText: 'المحافظة', border: OutlineInputBorder()),
                      items: _yemenGovs
                          .map(
                              (g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) => setState(() => _governorate = v),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? "اختر المحافظة" : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressC,
                      decoration: const InputDecoration(
                          labelText: 'العنوان', border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? "أدخل العنوان"
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _tradeNameC,
                      decoration: const InputDecoration(
                          labelText: 'الاسم التجاري',
                          border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? "أدخل الاسم التجاري"
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameC,
                      decoration: const InputDecoration(
                          labelText: 'الاسم الكامل',
                          border: OutlineInputBorder()),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? "أدخل الاسم" : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneC,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                          labelText: 'رقم الهاتف',
                          border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? "أدخل الهاتف"
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailC,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                          labelText: 'البريد الإلكتروني',
                          border: OutlineInputBorder()),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return "أدخل البريد";
                        final re = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
                        if (!re.hasMatch(v.trim())) return "البريد غير صالح";
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passC,
                      obscureText: true,
                      decoration: const InputDecoration(
                          labelText: 'كلمة المرور',
                          border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.length < 9)
                          ? "9 أحرف على الأقل"
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmC,
                      obscureText: true,
                      decoration: const InputDecoration(
                          labelText: 'تأكيد كلمة المرور',
                          border: OutlineInputBorder()),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? "أدخل التأكيد" : null,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _signup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text("تسجيل الحساب"),
                      ),
                    ),
                  ]),
                ),
              ),
      ),
    );
  }
}
