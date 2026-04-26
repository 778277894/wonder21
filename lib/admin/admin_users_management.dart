// lib/admin/admin_users_management.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
// الربط بالسيرفر الموحد
import './server_config.dart';

class AdminUsersManagement extends StatefulWidget {
  const AdminUsersManagement({super.key});
  @override
  State<AdminUsersManagement> createState() => _AdminUsersManagementState();
}

class _AdminUsersManagementState extends State<AdminUsersManagement>
    with SingleTickerProviderStateMixin {
  // ===== حالة التطبيق العامة =====
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> branches = [];
  int? branchFilterId; // فلتر الفروع العلوي

  // ===== التبويبات الأصلية =====
  late TabController tabController;
  final rolesTabs = const [
    _RoleTab(keyName: null, label: 'الكل'),
    _RoleTab(keyName: 'admin', label: 'مدراء النظام'),
    _RoleTab(keyName: 'accountant', label: 'المحاسبون'),
    _RoleTab(keyName: 'warehouse', label: 'موظفو المخازن'),
    _RoleTab(keyName: 'user', label: 'العملاء'),
  ];

  final searchC = TextEditingController();

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: rolesTabs.length, vsync: this);
    tabController.addListener(() {
      if (!tabController.indexIsChanging) setState(() {});
    });
    _bootstrap();
    searchC.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    tabController.dispose();
    searchC.dispose();
    super.dispose();
  }

  // ===== جلب البيانات من السيرفر =====
  Future<void> _bootstrap() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final resB = await http.get(Uri.parse("$kServerIp/get_branches.php"));
      final resU = await http.get(Uri.parse("$kServerIp/get_users.php"));

      if (resB.statusCode == 200) {
        final jB = jsonDecode(resB.body);
        branches = List<Map<String, dynamic>>.from(jB['branches'] ?? []);
      }
      if (resU.statusCode == 200) {
        final jU = jsonDecode(resU.body);
        users = List<Map<String, dynamic>>.from(jU['users'] ?? []);
      }
    } catch (e) {
      error = "خطأ في الاتصال بالسيرفر: $e";
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ===== حذف المستخدم بالمعرف الصحيح =====
  Future<void> _deleteUser(Map<String, dynamic> u) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text('هل أنت متأكد من حذف ${u['username']}؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      final r = await http.post(Uri.parse("$kServerIp/delete_user.php"),
          body: {"user_id": "${u['user_id']}"});
      if (jsonDecode(r.body)['success'] == true) {
        _bootstrap();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم الحذف بنجاح')));
      }
    }
  }

  // ===== دالة الحفظ الشاملة لجميع الحقول =====
  Future<void> _saveUser(Map<String, String> body, {int? id}) async {
    final url =
        id == null ? "$kServerIp/add_user.php" : "$kServerIp/update_user.php";
    if (id != null) body["user_id"] = id.toString();

    try {
      final r = await http.post(Uri.parse(url), body: body);
      final j = jsonDecode(r.body);
      if (j['success'] == true) {
        _bootstrap();
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم حفظ البيانات')));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(j['message'] ?? 'فشل الحفظ')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ سيرفر: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleKey = rolesTabs[tabController.index].keyName;
    final q = searchC.text.toLowerCase().trim();

    final filtered = users.where((u) {
      final matchRole = roleKey == null ? true : u['role'] == roleKey;
      final matchBranch = branchFilterId == null
          ? true
          : (u['branch_id'].toString() == branchFilterId.toString());
      final name = (u['username'] ?? '').toString().toLowerCase();
      final phone = (u['phone'] ?? '').toString();
      final matchSearch =
          q.isEmpty ? true : (name.contains(q) || phone.contains(q));
      return matchRole && matchBranch && matchSearch;
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة المستخدمين - روائع اليمن'),
          backgroundColor: const Color.fromARGB(255, 231, 177, 95),
          bottom: TabBar(
            controller: tabController,
            isScrollable: true,
            tabs: rolesTabs.map((t) => Tab(text: t.label)).toList(),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: branchFilterId,
                  hint: const Text('كل الفروع',
                      style: TextStyle(color: Colors.black)),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('كل الفروع')),
                    ...branches.map((b) => DropdownMenuItem(
                        value: b['branch_id'],
                        child: Text(b['branch_name'] ?? ''))),
                  ],
                  onChanged: (v) => setState(() => branchFilterId = v),
                ),
              ),
            ),
            IconButton(onPressed: _bootstrap, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: TextField(
                controller: searchC,
                decoration: InputDecoration(
                  hintText: 'بحث بالاسم أو رقم الجوال...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final u = filtered[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          child: ListTile(
                            leading: CircleAvatar(
                                child: Text(u['username'][0].toUpperCase())),
                            title: Text(u['username'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                "الجوال: ${u['phone']}\nالدور: ${u['role']} • التسعير: ${u['price_tier']}"),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue),
                                    onPressed: () => _openUserForm(u)),
                                IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () => _deleteUser(u)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color.fromARGB(255, 103, 134, 195),
          onPressed: () => _openUserForm(null),
          child: const Icon(Icons.person_add),
        ),
      ),
    );
  }

  // ===== نموذج الإدخال مصلح لتجنب الشاشة الحمراء =====
  void _openUserForm(Map<String, dynamic>? u) {
    final isEdit = u != null;
    final usernameC = TextEditingController(text: u?['username'] ?? '');
    final phoneC = TextEditingController(text: u?['phone'] ?? '');
    final passwordC = TextEditingController();
    final countryC = TextEditingController(text: u?['country'] ?? 'اليمن');
    final govC = TextEditingController(text: u?['governorate'] ?? '');
    final addrC = TextEditingController(text: u?['address'] ?? '');
    final tradeC = TextEditingController(text: u?['trade_name'] ?? '');
    final discC = TextEditingController(
        text: (u?['extra_discount_percent'] ?? '0').toString());

    String role = u?['role'] ?? 'user';
    // حل مشكلةretail/تجزئة لعدم انهيار التطبيق
    String tier = (u?['price_tier'] == null || u?['price_tier'] == '')
        ? 'retail'
        : u!['price_tier'];

    bool canAll = (u?['can_view_all_branches'] ?? 0).toString() == "1";
    List<int> selectedBranches =
        (u?['branch_ids'] != null && u!['branch_ids'].toString().isNotEmpty)
            ? u['branch_ids']
                .toString()
                .split(',')
                .map((e) => int.parse(e))
                .toList()
            : [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(isEdit ? 'تعديل مستخدم' : 'إضافة مستخدم جديد'),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                      controller: usernameC,
                      decoration:
                          const InputDecoration(labelText: 'اسم المستخدم *')),
                  TextField(
                      controller: phoneC,
                      decoration:
                          const InputDecoration(labelText: 'رقم الهاتف *'),
                      keyboardType: TextInputType.phone),
                  if (!isEdit)
                    TextField(
                        controller: passwordC,
                        decoration:
                            const InputDecoration(labelText: 'كلمة المرور *'),
                        obscureText: true),
                  // القائمة مصلحة لتتطابق مع قاعدة البيانات
                  DropdownButtonFormField<String>(
                    value: tier,
                    decoration: const InputDecoration(labelText: 'فئة التسعير'),
                    items: const [
                      DropdownMenuItem(value: 'retail', child: Text('تجزئة')),
                      DropdownMenuItem(value: 'wholesale', child: Text('جملة')),
                      DropdownMenuItem(
                          value: 'bulk', child: Text('جملة الجملة')),
                    ],
                    onChanged: (v) => setS(() => tier = v!),
                  ),
                  DropdownButtonFormField<String>(
                    value: role,
                    decoration:
                        const InputDecoration(labelText: 'الدور (الصلاحية)'),
                    items: const [
                      DropdownMenuItem(
                          value: 'admin', child: Text('مدير نظام')),
                      DropdownMenuItem(
                          value: 'accountant', child: Text('محاسب')),
                      DropdownMenuItem(
                          value: 'warehouse', child: Text('موظف مخازن')),
                      DropdownMenuItem(value: 'user', child: Text('عميل')),
                    ],
                    onChanged: (v) => setS(() => role = v!),
                  ),
                  TextField(
                      controller: countryC,
                      decoration: const InputDecoration(labelText: 'الدولة')),
                  TextField(
                      controller: govC,
                      decoration: const InputDecoration(labelText: 'المحافظة')),
                  TextField(
                      controller: addrC,
                      decoration: const InputDecoration(labelText: 'العنوان')),
                  TextField(
                      controller: tradeC,
                      decoration:
                          const InputDecoration(labelText: 'الاسم التجاري')),
                  TextField(
                      controller: discC,
                      decoration:
                          const InputDecoration(labelText: 'نسبة الخصم %'),
                      keyboardType: TextInputType.number),
                  const Divider(),
                  SwitchListTile(
                      title: const Text('رؤية كافة الفروع'),
                      value: canAll,
                      onChanged: (v) => setS(() => canAll = v)),
                  const Text("الفروع المسموحة:"),
                  Wrap(
                    spacing: 8,
                    children: branches.map((b) {
                      final bId = b['branch_id'] as int;
                      final isSel = selectedBranches.contains(bId);
                      return FilterChip(
                        label: Text(b['branch_name'] ?? ''),
                        selected: isSel,
                        onSelected: canAll
                            ? null
                            : (v) => setS(() => v
                                ? selectedBranches.add(bId)
                                : selectedBranches.remove(bId)),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () => _saveUser({
                  "username": usernameC.text,
                  "phone": phoneC.text,
                  "password": passwordC.text,
                  "role": role,
                  "country": countryC.text,
                  "governorate": govC.text,
                  "address": addrC.text,
                  "trade_name": tradeC.text,
                  "price_tier": tier,
                  "extra_discount_percent": discC.text,
                  "can_view_all_branches": canAll ? "1" : "0",
                  "branch_ids": selectedBranches.join(','),
                  "branch_id": selectedBranches.isNotEmpty
                      ? selectedBranches.first.toString()
                      : "0",
                }, id: isEdit ? int.parse(u['user_id'].toString()) : null),
                child: const Text('حفظ'),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _RoleTab {
  final String? keyName;
  final String label;
  const _RoleTab({this.keyName, required this.label});
}
