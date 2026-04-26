import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// تأكد من صحة هذه المسارات في مشروعك
import '../admin/server_config.dart';
import '../admin/categories/category_model.dart';
import '../carts/cart_models.dart';
import '../carts/cart_screen.dart';

class CategoriesClientScreen extends StatefulWidget {
  final int groupId;
  final String groupName;

  const CategoriesClientScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<CategoriesClientScreen> createState() => _CategoriesClientScreenState();
}

class _CategoriesClientScreenState extends State<CategoriesClientScreen> {
  bool _loading = true;
  String? _error;
  List<Category> _items = [];
  List<Category> _filteredItems = [];
  final TextEditingController _searchC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  // جلب الفئات المرتبطة بالمجموعة المحددة
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await http.post(
        Uri.parse("$kServerIp/get_categories_by_group.php"),
        body: {"group_id": widget.groupId.toString()},
      );

      if (response.statusCode == 200) {
        final List decodedData = json.decode(response.body);
        setState(() {
          _items = decodedData
              .map((item) => Category.fromJson(item))
              .where((c) => c.active)
              .toList();
          _filteredItems = _items;
          _loading = false;
        });
      } else {
        throw "فشل في جلب البيانات: ${response.statusCode}";
      }
    } catch (e) {
      setState(() {
        _error = "تأكد من اتصال السيرفر: $e";
        _loading = false;
      });
    }
  }

  // البحث المحلي
  void _onSearch(String query) {
    setState(() {
      _filteredItems = _items
          .where((c) =>
              c.name.toLowerCase().contains(query.toLowerCase()) ||
              (c.description?.toLowerCase().contains(query.toLowerCase()) ??
                  false))
          .toList();
    });
  }

  void _openCategory(Category c) {
    Navigator.pushNamed(
      context,
      '/all_products_screen',
      arguments: {
        'category_id': c.id,
        'category_name': c.name,
      },
    );
  }

  void _openAllProducts() {
    Navigator.pushNamed(context, '/all_products_screen', arguments: {
      'group_id': widget.groupId,
      'group_name': widget.groupName,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text('فئات ${widget.groupName}'),
          centerTitle: true,
          // توحيد اللون مع شاشة المجموعات (اللون الذهبي/البني)
          backgroundColor: const Color.fromARGB(255, 126, 101, 26),
          foregroundColor: Colors.white,
          actions: [
            // زر السلة مع إشعار العدد
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined, size: 26),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const CartScreen()),
                    );
                  },
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 14, minHeight: 14),
                    child: const Text(
                      '0',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          ],
        ),
        body: Column(
          children: [
            // حقل البحث
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchC,
                onChanged: _onSearch,
                decoration: InputDecoration(
                  hintText: 'ابحث في فئات ${widget.groupName}...',
                  prefixIcon:
                      const Icon(Icons.search, color: Color(0xFF1A237E)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // زر تصفح كل منتجات المجموعة
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
                        Color.fromARGB(
                            255, 126, 101, 26), // متناسق مع الـ AppBar
                        Color.fromARGB(255, 168, 140, 50)
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black26,
                          blurRadius: 5,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.all_inclusive, color: Colors.white, size: 28),
                      SizedBox(width: 15),
                      Text(
                        'عرض جميع منتجات المجموعة',
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

            // عرض الفئات
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                color: const Color.fromARGB(255, 126, 101, 26),
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(
              color: Color.fromARGB(255, 126, 101, 26)));
    }

    if (_error != null) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Column(
              children: [
                const Icon(Icons.wifi_off, size: 60, color: Colors.grey),
                const SizedBox(height: 10),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 126, 101, 26)),
                  onPressed: _load,
                  child: const Text('إعادة المحاولة',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_filteredItems.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          const Center(child: Text("لا توجد فئات حالياً لهذه المجموعة")),
        ],
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.0,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _filteredItems.length,
      itemBuilder: (_, i) {
        final c = _filteredItems[i];
        return _CategoryCardNoImage(
          title: c.name,
          subtitle: c.description,
          onTap: () => _openCategory(c),
          color: Colors.primaries[i % Colors.primaries.length],
        );
      },
    );
  }
}

class _CategoryCardNoImage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color color;

  const _CategoryCardNoImage({
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              radius: 28,
              child: Icon(Icons.category_outlined, color: color, size: 30),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.black87),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
