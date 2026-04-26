import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// استيراد الملفات الخاصة بمشروعك
import '../admin/server_config.dart';
import 'categories_client_screen.dart';
import '../carts/cart_screen.dart';

class MainGroupsClientScreen extends StatefulWidget {
  const MainGroupsClientScreen({super.key});

  @override
  State<MainGroupsClientScreen> createState() => _MainGroupsClientScreenState();
}

class _MainGroupsClientScreenState extends State<MainGroupsClientScreen> {
  bool loading = true;
  String? error;
  List<dynamic> _groups = [];
  List<dynamic> _filteredGroups = []; // القائمة المفلترة للبحث
  final TextEditingController _searchC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  // جلب المجموعات من السيرفر
  Future<void> _loadGroups() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response =
          await http.get(Uri.parse("$kServerIp/groups_api.php?action=GET_ALL"));
      if (response.statusCode == 200) {
        setState(() {
          _groups = json.decode(response.body);
          _filteredGroups = _groups; // في البداية نعرض الكل
          loading = false;
        });
      } else {
        throw "فشل في تحميل المجموعات";
      }
    } catch (e) {
      setState(() {
        error = "حدث خطأ في الاتصال: $e";
        loading = false;
      });
    }
  }

  // دالة البحث المحلي السريع
  void _onSearch(String query) {
    setState(() {
      _filteredGroups = _groups
          .where((group) =>
              group['group_name']
                  .toString()
                  .toLowerCase()
                  .contains(query.toLowerCase()) ||
              (group['group_description']
                      ?.toString()
                      .toLowerCase()
                      .contains(query.toLowerCase()) ??
                  false))
          .toList();
    });
  }

  // فتح شاشة جميع المنتجات
  void _openAllProducts() {
    Navigator.pushNamed(context, '/all_products_screen', arguments: {
      'group_name': 'جميع المنتجات',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text(
            'المجموعات الرئيسية',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color.fromARGB(255, 203, 154, 20),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          actions: [
            // زر السلة
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined, size: 28),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const CartScreen()),
                    );
                  },
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: const Text(
                      '0',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadGroups,
            ),
            const SizedBox(width: 5),
          ],
        ),
        body: Column(
          children: [
            // --- أولاً: حقل البحث ---
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchC,
                onChanged: _onSearch,
                decoration: InputDecoration(
                  hintText: 'ابحث عن مجموعة معينة...',
                  prefixIcon: const Icon(Icons.search,
                      color: Color.fromARGB(255, 203, 154, 20)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // --- ثانياً: زر عرض جميع المنتجات ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: InkWell(
                onTap: _openAllProducts,
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: const LinearGradient(
                      colors: [
                        Color.fromARGB(255, 203, 154, 20),
                        Color.fromARGB(255, 230, 180, 50),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 5,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.category_rounded,
                          color: Colors.white, size: 28),
                      SizedBox(width: 15),
                      Text(
                        'عرض جميع منتجات الشركة',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                      Spacer(),
                      Icon(Icons.arrow_forward_ios,
                          color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // --- ثالثاً: عرض شبكة المجموعات ---
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadGroups,
                color: const Color.fromARGB(255, 203, 154, 20),
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: Color.fromARGB(255, 203, 154, 20)))
                    : error != null
                        ? _buildErrorWidget()
                        : _buildGrid(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    if (_filteredGroups.isEmpty) {
      return const Center(child: Text('لا توجد مجموعات مطابقة لبحثك'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _filteredGroups.length,
      itemBuilder: (context, i) {
        final group = _filteredGroups[i];
        return _GroupCard(
          title: group['group_name'],
          subtitle: group['group_description'],
          iconColor: Colors.primaries[i % Colors.primaries.length],
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CategoriesClientScreen(
                  groupId: int.parse(group['group_id'].toString()),
                  groupName: group['group_name'],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 50, color: Colors.grey),
          const SizedBox(height: 10),
          Text(error ?? "خطأ غير معروف"),
          const SizedBox(height: 15),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 203, 154, 20),
            ),
            onPressed: _loadGroups,
            child: const Text('إعادة المحاولة',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final MaterialColor iconColor;

  const _GroupCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [iconColor.withOpacity(0.05), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.grid_view_rounded, size: 40, color: iconColor),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(
                  subtitle!,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
