import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// تأكد من صحة هذه المسارات في مشروعك
import 'package:wonderful2/admin/server_config.dart';
import 'package:wonderful2/admin/group/main_group_model.dart';

class MainGroupsScreen extends StatefulWidget {
  const MainGroupsScreen({super.key});

  @override
  State<MainGroupsScreen> createState() => _MainGroupsScreenState();
}

class _MainGroupsScreenState extends State<MainGroupsScreen> {
  List<MainGroup> _groups = [];
  List<MainGroup> _filteredGroups = []; // للقائمة المفلترة عند البحث
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchGroups();
  }

  // 1. جلب البيانات (مع دعم السحب للتحديث)
  Future<void> _fetchGroups() async {
    try {
      if (!_isSearching) setState(() => _isLoading = true);

      final response =
          await http.get(Uri.parse("$kServerIp/get_main_groups.php"));

      if (response.statusCode == 200) {
        final List decodedData = json.decode(response.body);
        setState(() {
          _groups =
              decodedData.map((item) => MainGroup.fromJson(item)).toList();
          _filteredGroups =
              _groups; // في البداية القائمة المفلترة هي نفسها الأصلية
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Fetch Error: $e");
    }
  }

  // دالة البحث
  void _filterGroups(String query) {
    setState(() {
      _filteredGroups = _groups
          .where((g) =>
              g.groupName.contains(query) ||
              g.groupId.toString().contains(query))
          .toList();
    });
  }

  // دالة الحفظ
  Future<void> _saveGroup(
      {required bool isEdit,
      required String id,
      required String name,
      required String desc}) async {
    final url = isEdit
        ? "$kServerIp/update_main_group.php"
        : "$kServerIp/add_main_group.php";
    try {
      final response = await http.post(Uri.parse(url), body: {
        "group_id": id,
        "group_name": name,
        "group_description": desc,
      });

      if (response.statusCode == 200) {
        final res = json.decode(response.body);
        _showSnackBar(res['message']);
        if (res['status'] == 'success') _fetchGroups();
      }
    } catch (e) {
      _showSnackBar("خطأ في الاتصال بالسيرفر");
    }
  }

  // دالة الحذف
  Future<void> _deleteGroup(int id) async {
    try {
      final response = await http.post(
        Uri.parse("$kServerIp/delete_main_group.php"),
        body: {"group_id": id.toString()},
      );
      final res = json.decode(response.body);
      _showSnackBar(res['message']);
      if (res['status'] == 'success') _fetchGroups();
    } catch (e) {
      _showSnackBar("فشل في طلب الحذف");
    }
  }

  // واجهة الإضافة والتعديل
  void _showGroupDialog({MainGroup? group}) {
    bool isEdit = group != null;
    final idController =
        TextEditingController(text: isEdit ? group.groupId.toString() : "");
    final nameController =
        TextEditingController(text: isEdit ? group.groupName : "");
    final descController =
        TextEditingController(text: isEdit ? group.groupDescription : "");

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(isEdit ? "تعديل المجموعة" : "إضافة مجموعة جديدة",
              style: const TextStyle(color: Color(0xFF1A237E))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(idController, "رقم المجموعة", Icons.numbers,
                    enabled: !isEdit, isNumber: true),
                const SizedBox(height: 10),
                _buildTextField(nameController, "اسم المجموعة", Icons.category),
                const SizedBox(height: 10),
                _buildTextField(descController, "الوصف", Icons.description),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("إلغاء")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              onPressed: () {
                if (idController.text.isEmpty || nameController.text.isEmpty)
                  return;
                _saveGroup(
                    isEdit: isEdit,
                    id: idController.text,
                    name: nameController.text,
                    desc: descController.text);
                Navigator.pop(ctx);
              },
              child: const Text("حفظ", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {bool enabled = true, bool isNumber = false}) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1A237E)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: !enabled,
        fillColor: Colors.grey[200],
      ),
    );
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, textAlign: TextAlign.right),
        behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(255, 179, 113, 52),
          elevation: 0,
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      hintText: "بحث عن مجموعة...",
                      hintStyle: TextStyle(color: Colors.white70),
                      border: InputBorder.none),
                  onChanged: _filterGroups,
                )
              : const Text("المجموعات الرئيسية",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 243, 245, 245))),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search,
                  color: Colors.white),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _filteredGroups = _groups;
                    _searchController.clear();
                  }
                });
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showGroupDialog(),
          backgroundColor: const Color.fromARGB(255, 206, 143, 56),
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                    color: Color.fromARGB(255, 230, 167, 31)))
            : RefreshIndicator(
                onRefresh: _fetchGroups, // ميزة السحب للتحديث
                color: const Color.fromARGB(255, 209, 158, 28),
                child: _filteredGroups.isEmpty
                    ? const Center(child: Text("لا توجد بيانات متاحة"))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _filteredGroups.length,
                        itemBuilder: (ctx, i) {
                          final g = _filteredGroups[i];
                          return Card(
                            elevation: 4,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    color:
                                        const Color.fromARGB(255, 213, 126, 4)
                                            .withOpacity(0.1),
                                    shape: BoxShape.circle),
                                child: Text(g.groupId.toString(),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color:
                                            Color.fromARGB(255, 126, 93, 26))),
                              ),
                              title: Text(g.groupName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20)),
                              subtitle: Text(g.groupDescription,
                                  style: TextStyle(
                                      color:
                                          const Color.fromARGB(255, 10, 5, 1))),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: Colors.blue),
                                      onPressed: () =>
                                          _showGroupDialog(group: g)),
                                  IconButton(
                                    icon: const Icon(Icons.delete_forever,
                                        color:
                                            Color.fromARGB(255, 202, 35, 33)),
                                    onPressed: () => _confirmDelete(g.groupId),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
      ),
    );
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تأكيد الحذف"),
        content: const Text("هل أنت متأكد من حذف هذه المجموعة؟"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _deleteGroup(id);
              },
              child: const Text("حذف", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}
