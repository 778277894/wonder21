import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:wonderful2/admin/server_config.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<dynamic> _categories = [];
  List<dynamic> _filteredCategories = [];
  List<dynamic> _mainGroups = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchMainGroups();
  }

  Future<void> _fetchMainGroups() async {
    try {
      final response =
          await http.get(Uri.parse("$kServerIp/get_main_groups.php"));
      if (response.statusCode == 200) {
        setState(() {
          _mainGroups = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint("Groups Fetch Error: $e");
    }
  }

  Future<void> _fetchCategories() async {
    try {
      if (!_isSearching) setState(() => _isLoading = true);

      final response =
          await http.get(Uri.parse("$kServerIp/get_categories.php"));

      if (response.statusCode == 200) {
        String bodyText = response.body;
        // تنظيف النص في حال وجود أخطاء PHP
        if (bodyText.contains("<br />")) {
          bodyText = bodyText.substring(
              bodyText.indexOf('['), bodyText.lastIndexOf(']') + 1);
        }

        final dynamic decodedData = json.decode(bodyText);

        setState(() {
          _categories = (decodedData is List)
              ? decodedData
              : (decodedData['categories'] ?? []);
          _filteredCategories = _categories;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        _showSnackBar("فشل السيرفر في الرد: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("خطأ في الاتصال بالسيرفر");
    }
  }

  void _filterCategories(String query) {
    setState(() {
      _filteredCategories = _categories
          .where((c) =>
              c['category_name']
                  .toString()
                  .toLowerCase()
                  .contains(query.toLowerCase()) ||
              c['category_id'].toString().contains(query))
          .toList();
    });
  }

  // دالة الحفظ (إضافة أو تعديل)
  Future<void> _saveCategory({
    required bool isEdit,
    required String id,
    required String name,
    required String desc,
    required String groupId,
  }) async {
    final url = isEdit
        ? "$kServerIp/update_category.php"
        : "$kServerIp/add_category.php";
    try {
      final response = await http.post(Uri.parse(url), body: {
        "id": id,
        "name": name,
        "description": desc,
        "main_group_id": groupId,
      });

      if (response.statusCode == 200) {
        _fetchCategories();
        _showSnackBar("تمت العملية بنجاح");
      }
    } catch (e) {
      _showSnackBar("خطأ في الحفظ");
    }
  }

  Future<void> _deleteCategory(String id) async {
    try {
      final response = await http
          .post(Uri.parse("$kServerIp/delete_category.php"), body: {"id": id});
      if (response.statusCode == 200) {
        _fetchCategories();
        _showSnackBar("تم الحذف");
      }
    } catch (e) {
      _showSnackBar("فشل الحذف");
    }
  }

  void _showCategoryDialog({Map? category}) {
    bool isEdit = category != null;
    final idController = TextEditingController(
        text: isEdit ? category['category_id'].toString() : "");
    final nameController =
        TextEditingController(text: isEdit ? category['category_name'] : "");
    final descController = TextEditingController(
        text: isEdit ? (category['description'] ?? "") : "");
    String? selectedGroupId =
        isEdit ? category['main_group_id']?.toString() : null;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(isEdit ? "تعديل الفئة" : "إضافة فئة جديدة",
              style: const TextStyle(
                  color: Color(0xFF1A237E), fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(
                    idController, "رقم الفئة (اختياري)", Icons.numbers,
                    enabled: !isEdit, isNumber: true),
                const SizedBox(height: 10),
                _buildTextField(nameController, "اسم الفئة", Icons.category),
                const SizedBox(height: 10),
                _buildTextField(descController, "الوصف", Icons.description),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedGroupId,
                  hint: const Text("اختر المجموعة الرئيسية"),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.account_tree,
                        color: Color(0xFF1A237E)),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  items: _mainGroups.map((group) {
                    return DropdownMenuItem<String>(
                      value: group['group_id'].toString(),
                      child: Text(group['group_name']),
                    );
                  }).toList(),
                  onChanged: (val) => selectedGroupId = val,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("إلغاء")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E)),
              onPressed: () {
                if (nameController.text.isEmpty || selectedGroupId == null)
                  return;
                _saveCategory(
                    isEdit: isEdit,
                    id: idController.text,
                    name: nameController.text,
                    desc: descController.text,
                    groupId: selectedGroupId!);
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
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      hintText: "بحث...",
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.white70)),
                  onChanged: _filterCategories,
                )
              : const Text("إدارة الفئات",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search,
                  color: Colors.white),
              onPressed: () => setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _filteredCategories = _categories;
                  _searchController.clear();
                }
              }),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showCategoryDialog(),
          backgroundColor: const Color.fromARGB(255, 206, 143, 56),
          child: const Icon(Icons.add, color: Colors.white),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                    color: Color.fromARGB(255, 230, 167, 31)))
            : RefreshIndicator(
                onRefresh: _fetchCategories,
                child: _filteredCategories.isEmpty
                    ? const Center(child: Text("لا توجد فئات"))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _filteredCategories.length,
                        itemBuilder: (ctx, i) {
                          final c = _filteredCategories[i];
                          return Card(
                            elevation: 3,
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    const Color.fromARGB(255, 213, 126, 4)
                                        .withOpacity(0.1),
                                child: Text(c['category_id'].toString(),
                                    style: const TextStyle(
                                        color: Color.fromARGB(255, 126, 93, 26),
                                        fontSize: 12)),
                              ),
                              title: Text(c['category_name'] ?? "",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18)),
                              // التعديل هنا لإظهار المجموعة والوصف تحت بعضهما
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 5),
                                  Text("المجموعة: ${c['group_name'] ?? 'بدون'}",
                                      style: const TextStyle(
                                          color: Colors.blueGrey,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(
                                      "الوصف: ${c['description'] != "" ? c['description'] : 'لا يوجد وصف'}",
                                      style:
                                          TextStyle(color: Colors.grey[700])),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: Colors.blue),
                                      onPressed: () =>
                                          _showCategoryDialog(category: c)),
                                  IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () => _confirmDelete(
                                          c['category_id'].toString())),
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

  void _confirmDelete(String id) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text("تأكيد"),
              content: const Text("حذف هذه الفئة؟"),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("إلغاء")),
                TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _deleteCategory(id);
                    },
                    child:
                        const Text("حذف", style: TextStyle(color: Colors.red))),
              ],
            ));
  }
}
