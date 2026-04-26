import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import './server_config.dart'; // يحتوي على kServerIp مثل: const kServerIp = "http://192.168.0.16";

class BranchesAdminScreen extends StatefulWidget {
  const BranchesAdminScreen({super.key});
  @override
  State<BranchesAdminScreen> createState() => _BranchesAdminScreenState();
}

class _BranchesAdminScreenState extends State<BranchesAdminScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> branches = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ====== مساعد لمسار الصورة ======
  String _fixImageUrl(String raw) {
    String v = (raw).toString().trim();
    if (v.isEmpty) return '';
    if (v.startsWith('http://') || v.startsWith('https://')) return v;
    if (v.startsWith('/')) return '$kServerIp$v';
    return '$kServerIp/$v';
  }

  // ========== جلب الفروع ==========
  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await http.get(Uri.parse('$kServerIp/get_branches.php'));
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      final j = jsonDecode(r.body);
      if (j['success'] == true) {
        final List list = j['branches'] ?? [];
        branches = list
            .map<Map<String, dynamic>>((e) => {
                  'branch_id':
                      int.tryParse('${e['branch_id'] ?? e['id'] ?? 0}') ?? 0,
                  'branch_name': '${e['branch_name'] ?? e['name'] ?? ''}',
                  'active': (e['active'].toString() == '1'),
                  'image_url': '${e['image_url'] ?? ''}',
                })
            .toList();
      } else {
        error = j['message'] ?? 'فشل جلب الفروع';
      }
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ========== إضافة / تعديل مع صورة ==========
  Future<void> _saveBranch({
    int? id,
    required String name,
    required bool active,
    XFile? image,
    bool removeImage = false,
  }) async {
    try {
      final url = id == null
          ? '$kServerIp/add_branch.php'
          : '$kServerIp/update_branch.php';

      final uri = Uri.parse(url);
      final req = http.MultipartRequest('POST', uri);

      // الحقول
      req.fields['branch_name'] = name;
      req.fields['active'] = active ? '1' : '0';
      if (id != null) {
        req.fields['branch_id'] = '$id';
      }
      if (removeImage) {
        req.fields['remove_image'] = '1';
      }

      // ملف الصورة إن وجد
      if (image != null) {
        req.files.add(
          await http.MultipartFile.fromPath('image', image.path),
        );
      }

      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);

      Map<String, dynamic> j;
      try {
        j = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        j = {'success': false, 'message': res.body};
      }

      final ok = j['success'] == true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            j['message'] ??
                (ok
                    ? (id == null ? 'تمت الإضافة بنجاح' : 'تم الحفظ بنجاح')
                    : 'فشل الحفظ'),
          ),
        ),
      );
      if (ok) _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  // ========== حذف ==========
  Future<void> _deleteBranch(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: const Text('هل تريد حذف هذا الفرع؟'),
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
    if (confirm != true) return;
    try {
      final r = await http.post(
        Uri.parse('$kServerIp/delete_branch.php'),
        body: {'branch_id': '$id'},
      );
      final j = jsonDecode(r.body);
      final ok = j['success'] == true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(j['message'] ?? (ok ? 'تم الحذف' : 'فشل الحذف')),
        ),
      );
      if (ok) _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  // ========== نافذة الإضافة / التعديل ==========
  void _openBranchDialog({Map<String, dynamic>? branch}) {
    final nameC = TextEditingController(text: branch?['branch_name'] ?? '');
    bool active = branch?['active'] ?? true;
    final String oldImageUrl = branch?['image_url'] ?? '';
    XFile? pickedImage;
    bool removeImage = false;

    final ImagePicker picker = ImagePicker();

    Future<void> pickImage() async {
      final x = await picker.pickImage(source: ImageSource.gallery);
      if (x != null) {
        pickedImage = x;
        // إذا اختار صورة جديدة نلغي خيار إزالة الصورة
        removeImage = false;
        // لازم نعمل setState للـ Dialog
      }
    }

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) {
          Widget preview;

          final hasOld = oldImageUrl.trim().isNotEmpty;
          if (pickedImage != null) {
            preview = ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                // ignore: deprecated_member_use
                // في الإصدارات الجديدة من image_picker يمكن استخدام XFile مباشرة بطرق أخرى
                // هنا أبسط حل:
                // File من dart:io في حال كنت تستهدف موبايل فقط، أو استبدله بطريقة مناسبة للويب إن لزم
                // لكن بما أنك تستخدمه للأندرويد فقط لا مشكلة
                // تحتاج إضافة: import 'dart:io';
                // تم حذفها هنا لتبسيط المثال، أضفها أعلى الملف لو أردت تشغيل الكود كما هو.
                //
                // ملاحظة: لو تريد دعم الويب 100% استبدل هذا بـ Image.memory مع readAsBytes
                //
                File(pickedImage!.path),
                width: 90,
                height: 90,
                fit: BoxFit.cover,
              ),
            );
          } else if (hasOld && !removeImage) {
            final url = _fixImageUrl(oldImageUrl);
            preview = ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                width: 90,
                height: 90,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.broken_image, size: 40),
              ),
            );
          } else {
            preview = const Icon(Icons.image, size: 40, color: Colors.grey);
          }

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text(branch == null ? 'إضافة فرع جديد' : 'تعديل الفرع'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameC,
                      decoration: const InputDecoration(labelText: 'اسم الفرع'),
                    ),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      value: active,
                      onChanged: (v) =>
                          setStateDialog(() => active = v ?? true),
                      title: const Text('الفرع نشط'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            await pickImage();
                            setStateDialog(() {});
                          },
                          icon: const Icon(Icons.image),
                          label: const Text('اختيار صورة'),
                        ),
                        const SizedBox(width: 12),
                        preview,
                      ],
                    ),
                    if (branch != null && oldImageUrl.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: removeImage,
                        onChanged: (v) {
                          setStateDialog(() {
                            removeImage = v ?? false;
                            if (removeImage) pickedImage = null;
                          });
                        },
                        title: const Text('إزالة الصورة الحالية'),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء')),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameC.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('أدخل اسم الفرع')),
                      );
                      return;
                    }
                    await _saveBranch(
                      id: branch?['branch_id'],
                      name: name,
                      active: active,
                      image: pickedImage,
                      removeImage: removeImage,
                    );
                    if (!mounted) return;
                    Navigator.pop(context);
                  },
                  child: const Text('حفظ'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ========== واجهة ==========
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('قائمة الفروع'),
          backgroundColor: const Color(0xFFE9B270),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: branches.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              Center(child: Text('لا توجد فروع')),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: branches.length,
                            itemBuilder: (_, i) {
                              final b = branches[i];
                              final img = (b['image_url'] ?? '').toString();
                              Widget leading;
                              if (img.trim().isEmpty) {
                                leading = Icon(
                                  b['active']
                                      ? Icons.store_mall_directory
                                      : Icons.store_outlined,
                                  color:
                                      b['active'] ? Colors.green : Colors.grey,
                                );
                              } else {
                                final url = _fixImageUrl(img);
                                leading = ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    url,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(
                                      b['active']
                                          ? Icons.store_mall_directory
                                          : Icons.store_outlined,
                                      color: b['active']
                                          ? Colors.green
                                          : Colors.grey,
                                    ),
                                  ),
                                );
                              }

                              return Card(
                                child: ListTile(
                                  leading: leading,
                                  title: Text(b['branch_name']),
                                  subtitle: Text(
                                      'الحالة: ${b['active'] ? 'نشط' : 'متوقف'}'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit,
                                            color: Colors.blue),
                                        onPressed: () =>
                                            _openBranchDialog(branch: b),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () => _deleteBranch(
                                            b['branch_id'] as int),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openBranchDialog(),
          backgroundColor: const Color(0xFFE9B270),
          icon: const Icon(Icons.add_business),
          label: const Text('إضافة فرع'),
        ),
      ),
    );
  }
}
