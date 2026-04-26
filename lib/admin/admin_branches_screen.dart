import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import './server_config.dart'; // يحتوي kServerIp = "http://192.168.0.16"

class AdminBranchesScreen extends StatefulWidget {
  const AdminBranchesScreen({
    super.key,
    this.currentUserId,
    this.isAdmin = false,
  });

  final int? currentUserId;
  final bool isAdmin;

  @override
  State<AdminBranchesScreen> createState() => _AdminBranchesScreenState();
}

class _AdminBranchesScreenState extends State<AdminBranchesScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> branches = [];
  List<Map<String, dynamic>> filtered = [];
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final uri = Uri.parse("$kServerIp/get_branches.php").replace(
          queryParameters: widget.currentUserId == null
              ? null
              : {"user_id": "${widget.currentUserId}"});

      final res = await http.get(uri, headers: {'Accept': 'application/json'});
      if (res.statusCode != 200) throw Exception("HTTP ${res.statusCode}");
      final j = jsonDecode(res.body);
      if (j['success'] == true) {
        final List list = j['branches'] ?? [];
        branches = list.cast<Map<String, dynamic>>();
        _applyFilter();
      } else {
        error = j['message'] ?? 'فشل جلب الفروع';
      }
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _applyFilter() {
    final q = _search.text.trim().toLowerCase();
    setState(() {
      filtered = q.isEmpty
          ? List<Map<String, dynamic>>.from(branches)
          : branches.where((b) {
              final name = (b['branch_name'] ?? '').toString().toLowerCase();
              final id = (b['branch_id'] ?? '').toString().toLowerCase();
              return name.contains(q) || id.contains(q);
            }).toList();
    });
  }

  Future<void> _addOrEditDialog({Map<String, dynamic>? row}) async {
    if (!widget.isAdmin && row != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('التعديل متاح للمدير فقط')),
      );
      return;
    }
    final nameC = TextEditingController(text: row?['branch_name'] ?? '');
    bool active = (row?['active'] ?? 1).toString() == '1';

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(row == null ? 'إضافة فرع' : 'تعديل الفرع'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameC,
                decoration: const InputDecoration(
                  labelText: 'اسم الفرع',
                  prefixIcon: Icon(Icons.store),
                ),
              ),
              const SizedBox(height: 8),
              if (widget.isAdmin)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('مفعل'),
                  value: active,
                  onChanged: (v) => active = v,
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('حفظ')),
          ],
        ),
      ),
    );

    if (ok != true) return;

    final name = nameC.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اسم الفرع مطلوب')),
      );
      return;
    }

    try {
      final isEdit = row != null;
      final uri = Uri.parse(
          "$kServerIp/${isEdit ? 'update_branch.php' : 'add_branch.php'}");
      final body = <String, String>{
        if (widget.currentUserId != null) "user_id": "${widget.currentUserId}",
        if (isEdit) "branch_id": "${row!['branch_id']}",
        "branch_name": name,
        "active": active ? "1" : "0",
      };

      final res = await http.post(uri, body: body);
      final j = jsonDecode(res.body);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(j['message']?.toString() ??
                (j['success'] == true ? 'تم الحفظ' : 'فشل الحفظ'))),
      );
      if (j['success'] == true) _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> row, bool v) async {
    if (!widget.isAdmin) return;
    try {
      final res = await http.post(
        Uri.parse("$kServerIp/update_branch.php"),
        body: {
          if (widget.currentUserId != null)
            "user_id": "${widget.currentUserId}",
          "branch_id": "${row['branch_id']}",
          "active": v ? "1" : "0",
        },
      );
      final j = jsonDecode(res.body);
      if (!mounted) return;
      if (j['success'] == true) {
        setState(() {
          row['active'] = v ? 1 : 0;
        });
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(j['message'] ?? 'تم التحديث')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    if (!widget.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الحذف للمدير فقط')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text('هل تريد حذف الفرع: ${row['branch_name']} ؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    try {
      final res = await http.post(
        Uri.parse("$kServerIp/delete_branch.php"),
        body: {
          "branch_id": "${row['branch_id']}",
          if (widget.currentUserId != null)
            "user_id": "${widget.currentUserId}",
        },
      );
      final j = jsonDecode(res.body);
      if (!mounted) return;

      if (j['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(j['message'] ?? 'تم الحذف')),
        );
        _load();
      } else {
        final msg =
            j['message'] ?? 'تعذر الحذف. قد يكون الفرع مرتبطًا بعمليات.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Widget _badge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة الفروع'),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        floatingActionButton: widget.isAdmin
            ? FloatingActionButton.extended(
                onPressed: () => _addOrEditDialog(),
                icon: const Icon(Icons.add_business),
                label: const Text('إضافة فرع'),
              )
            : null,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'ابحث باسم الفرع أو الرقم...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                      ? Center(
                          child: Text(error!,
                              style: const TextStyle(color: Colors.red)))
                      : filtered.isEmpty
                          ? const Center(child: Text('لا توجد فروع'))
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 0),
                              itemBuilder: (_, i) {
                                final b = filtered[i];
                                final active =
                                    (b['active'] ?? 1).toString() == '1';
                                final usersCount =
                                    int.tryParse('${b['users_count'] ?? 0}') ??
                                        0;
                                final ordersCount =
                                    int.tryParse('${b['orders_count'] ?? 0}') ??
                                        0;

                                return ListTile(
                                  leading: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _badge('مستخدمين', usersCount,
                                          Colors.blue.shade600),
                                      const SizedBox(height: 6),
                                      _badge('طلبات', ordersCount,
                                          Colors.deepPurple.shade600),
                                    ],
                                  ),
                                  title: Text(b['branch_name'] ?? ''),
                                  subtitle: Text(
                                    'رقم: ${b['branch_id']} • الحالة: ${active ? "مفعل" : "موقوف"} • مستخدمون: $usersCount • طلبات: $ordersCount',
                                  ),
                                  isThreeLine: true,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (widget.isAdmin)
                                        Switch(
                                          value: active,
                                          onChanged: (v) => _toggleActive(b, v),
                                        ),
                                      if (widget.isAdmin)
                                        IconButton(
                                          icon: const Icon(Icons.edit,
                                              color: Colors.blue),
                                          onPressed: () =>
                                              _addOrEditDialog(row: b),
                                        ),
                                      if (widget.isAdmin)
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red),
                                          onPressed: () => _delete(b),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
