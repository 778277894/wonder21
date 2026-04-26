import 'package:flutter/material.dart';

class AdminSetting extends StatefulWidget {
  const AdminSetting({super.key});

  @override
  State<AdminSetting> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSetting> {
  bool notificationsEnabled = true;
  bool darkMode = false;
  bool biometricLock = false;

  String language = 'ar';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      // لضمان RTL
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الإعدادات'),
          backgroundColor: const Color.fromARGB(255, 234, 211, 64),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'الحساب',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: const Text('اسم المسؤول'),
              subtitle: const Text('admin@example.com'),
              trailing: TextButton(
                onPressed: () {
                  // TODO: فتح صفحة تعديل الحساب
                },
                child: const Text('تعديل'),
              ),
            ),
            const Divider(height: 24),
            const Text(
              'التطبيق',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SwitchListTile(
              title: const Text('الوضع الداكن'),
              value: darkMode,
              onChanged: (v) {
                setState(() => darkMode = v);
                // TODO: ربطه بالـ Theme / Provider إن وُجد
              },
              secondary: const Icon(Icons.dark_mode),
            ),
            SwitchListTile(
              title: const Text('الإشعارات'),
              value: notificationsEnabled,
              onChanged: (v) => setState(() => notificationsEnabled = v),
              secondary: const Icon(Icons.notifications_active),
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('اللغة'),
              trailing: DropdownButton<String>(
                value: language,
                items: const [
                  DropdownMenuItem(value: 'ar', child: Text('العربية')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                ],
                onChanged: (v) => setState(() => language = v ?? 'ar'),
              ),
            ),
            const Divider(height: 24),
            const Text(
              'الأمان',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SwitchListTile(
              title: const Text('قفل ببصمة/وجه'),
              value: biometricLock,
              onChanged: (v) => setState(() => biometricLock = v),
              secondary: const Icon(Icons.fingerprint),
            ),
            ListTile(
              leading: const Icon(Icons.lock_reset),
              title: const Text('تغيير كلمة المرور'),
              onTap: () {
                // TODO: فتح تغيير كلمة المرور
              },
            ),
            const Divider(height: 24),
            const Text(
              'حول التطبيق',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('الإصدار'),
              subtitle: const Text('1.0.0'),
            ),
            ListTile(
              leading: const Icon(Icons.cleaning_services),
              title: const Text('مسح الكاش'),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('تأكيد'),
                    content: const Text('هل تريد مسح بيانات الكاش؟'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('إلغاء')),
                      ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('نعم')),
                    ],
                  ),
                );
                if (ok == true) {
                  // TODO: تنفيذ مسح الكاش
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم مسح الكاش بنجاح')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
