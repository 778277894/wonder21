// lib/client/account/my_account_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

/// ===== إعداد السيرفر =====
/// عدّل IP حسب شبكتك
const String kServerBase = "http://192.168.0.16";

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool loading = true;
  String? error; // رسالة خطأ مفهومة
  Map<String, dynamic>? user; // بيانات المستخدم
  bool isGuest = false; // هل المستخدم زائر؟

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  /// جلب user_id من SharedPreferences
  Future<int?> _getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();

    // جرّب المفتاحين للتوافق مع كود تسجيل الدخول
    final id1 = prefs.getInt('user_id');
    final id2 = prefs.getInt('userId');

    final id = id1 ?? id2;
    if (id == null || id <= 0) return null;
    return id;
  }

  Future<void> _loadProfile() async {
    setState(() {
      loading = true;
      error = null;
      user = null;
      isGuest = false;
    });

    try {
      final userId = await _getCurrentUserId();

      // لو ما في user_id → اعتبره زائر
      if (userId == null) {
        setState(() {
          isGuest = true;
        });
        return;
      }

      final uri = Uri.parse("$kServerBase/get_profile.php?user_id=$userId");

      final res = await http.get(uri);

      // خطأ HTTP
      if (res.statusCode < 200 || res.statusCode >= 300) {
        String msg = 'HTTP ${res.statusCode}';
        try {
          final j = jsonDecode(res.body);
          if (j is Map && j['message'] != null) {
            msg = 'HTTP ${res.statusCode}: ${j['message']}';
          } else {
            msg =
                'HTTP ${res.statusCode}: ${res.body.toString().substring(0, res.body.length.clamp(0, 300))}';
          }
        } catch (_) {
          if (res.body.isNotEmpty) {
            final short = res.body.length > 300
                ? '${res.body.substring(0, 300)}...'
                : res.body;
            msg = 'HTTP ${res.statusCode}\n$short';
          }
        }
        throw Exception(msg);
      }

      // فك JSON
      final j = jsonDecode(res.body);
      if (j is! Map || j['success'] != true || j['user'] == null) {
        throw Exception(j is Map && j['message'] != null
            ? j['message'].toString()
            : 'استجابة غير متوقعة من الخادم');
      }

      setState(() {
        user = (j['user'] as Map).cast<String, dynamic>();
      });
    } catch (e) {
      setState(() {
        error = _humanizeError(e);
      });
      if (mounted && error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error!), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _humanizeError(Object e) {
    final s = e.toString();
    return s.length > 400 ? '${s.substring(0, 400)}...' : s;
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (isGuest) {
      body = _GuestView(
          onGoLogin: () {
            Navigator.pushReplacementNamed(
                context, '/login'); // عدّل المسار لو مختلف
          },
          onRefresh: _loadProfile);
    } else if (error != null) {
      body = _ErrorView(
        message: error!,
        onRetry: _loadProfile,
      );
    } else {
      body = _ProfileView(user: user!, onRefresh: _loadProfile);
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('حسابي'),
          backgroundColor: const Color(0xFFFFC107),
          actions: [
            IconButton(
              onPressed: _loadProfile,
              tooltip: 'تحديث',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: body,
      ),
    );
  }
}

/// ============= شاشة الزائر =============
class _GuestView extends StatelessWidget {
  final VoidCallback onGoLogin;
  final Future<void> Function() onRefresh;

  const _GuestView({
    required this.onGoLogin,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.person_outline,
                      size: 60, color: Colors.orange),
                  const SizedBox(height: 12),
                  const Text(
                    'أنت الآن تتصفح كتـاج زائر.\nلا توجد بيانات حساب لعرضها.',
                    textAlign: TextAlign.center,
                    style: TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: onGoLogin,
                    icon: const Icon(Icons.login),
                    label: const Text('تسجيل الدخول'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ============= شاشة الخطأ =============
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRetry(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.red.withOpacity(.06),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 36),
                  const SizedBox(height: 8),
                  SelectableText(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ============= عرض بيانات الحساب =============
class _ProfileView extends StatelessWidget {
  final Map<String, dynamic> user;
  final Future<void> Function() onRefresh;

  const _ProfileView({required this.user, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final username = '${user['username'] ?? ''}';
    final phone = '${user['phone'] ?? ''}';
    final email = '${user['email'] ?? ''}';
    final role = '${user['role'] ?? 'user'}';
    final branchName = '${user['branch_name'] ?? ''}';
    final canAll = (user['can_view_all_branches'] ?? 0).toString() == '1';
    final priceTier = '${user['price_tier'] ?? 'retail'}';
    final extraDisc =
        (user['extra_discount_percent'] ?? 0).toString(); // نص لعرض سهل
    final allowed = (user['allowed_branches'] is List)
        ? (user['allowed_branches'] as List).cast<Map>()
        : const <Map>[];

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // بطاقة العنوان
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange.shade100,
                child: Text(
                  username.isNotEmpty ? username.characters.first : '?',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(username,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('الدور: ${_roleLabel(role)}'),
              trailing: Chip(
                label: Text(_tierLabel(priceTier)),
                backgroundColor: Colors.green.shade50,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // تفاصيل أساسية
          _infoCard(
            children: [
              _row('رقم المستخدم', '${user['user_id'] ?? user['id'] ?? ''}'),
              _row('الجوال', phone.isEmpty ? '-' : phone),
              _row('البريد', email.isEmpty ? '-' : email),
              _row('التسعير', _tierLabel(priceTier)),
              if (extraDisc != '0') _row('خصم إضافي', '$extraDisc%'),
            ],
          ),

          const SizedBox(height: 10),

          // الفروع
          _infoCard(
            title: 'الفروع',
            children: [
              _row('صلاحية الفروع', canAll ? 'كل الفروع' : 'فروع محددة'),
              if (!canAll && branchName.isNotEmpty)
                _row('الفرع الافتراضي', branchName),
              if (!canAll && allowed.isNotEmpty) ...[
                const Divider(),
                const Text('قائمة الفروع المسموح بها:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: allowed.map((e) {
                    final name = '${e['branch_name'] ?? ''}';
                    return Chip(label: Text(name));
                  }).toList(),
                ),
              ],
            ],
          ),

          const SizedBox(height: 10),

          // العناوين
          _infoCard(
            title: 'العنوان',
            children: [
              _row('الدولة', '${user['country'] ?? ''}'),
              _row('المحافظة', '${user['governorate'] ?? ''}'),
              _row('العنوان', '${user['address'] ?? ''}'),
              _row('الاسم التجاري', '${user['trade_name'] ?? ''}'),
            ],
          ),

          const SizedBox(height: 10),

          // الطوابع الزمنية
          _infoCard(
            title: 'السجلات',
            children: [
              _row('أُنشئ', '${user['created_at'] ?? ''}'),
              _row('آخر تعديل', '${user['updated_at'] ?? ''}'),
            ],
          ),
        ],
      ),
    );
  }

  static String _tierLabel(String v) {
    switch (v) {
      case 'wholesale':
        return 'جملة';
      case 'bulk':
        return 'جملة الجملة';
      default:
        return 'تجزئة';
    }
  }

  static String _roleLabel(String v) {
    switch (v) {
      case 'admin':
        return 'مدير';
      case 'accountant':
        return 'محاسب';
      case 'warehouse':
        return 'موظف مخازن';
      default:
        return 'عميل';
    }
  }

  Widget _infoCard({String? title, required List<Widget> children}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
            ],
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    final v = (value).trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              v.isEmpty ? '-' : v,
              textAlign: TextAlign.start,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
