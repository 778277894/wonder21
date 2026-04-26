// lib/products/all_products_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// استيراد ملف الإعدادات الخاص بك
import '../admin/server_config.dart'; // يحتوي kServerIp = "http://192.168.0.16" مثلاً

import '../carts/cart.dart';
import '../carts/cart_screen.dart';
import 'product_details_screen.dart';

/// دالة إصلاح روابط الصور (تعتمد الآن على kServerIp من ملف الإعدادات)
String fixImageUrl(dynamic raw) {
  String v = (raw ?? '').toString().trim().replaceAll('\\', '/');
  if (v.isEmpty) return '';
  if (v.startsWith('http://') || v.startsWith('https://')) {
    return Uri.encodeFull(v);
  }

  // استخدام kServerIp مباشرة لضمان الربط الصحيح
  if (v.startsWith('/')) {
    return Uri.encodeFull("$kServerIp$v");
  }
  if (v.startsWith('uploads/')) {
    return Uri.encodeFull("$kServerIp/$v");
  }
  return Uri.encodeFull("$kServerIp/uploads/$v");
}

class AllProductsScreen extends StatefulWidget {
  const AllProductsScreen({super.key});
  @override
  State<AllProductsScreen> createState() => _AllProductsScreenState();
}

class _AllProductsScreenState extends State<AllProductsScreen> {
  // ===== الحالة العامة =====
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String? _error;

  // ===== فلاتر =====
  int? _categoryId;
  String? _categoryName;
  final _searchC = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        _categoryId =
            int.tryParse('${args['category_id'] ?? args['id'] ?? ''}');
        _categoryName =
            args['category_name']?.toString() ?? args['name']?.toString();
      }
      _fetch();
    });
    _searchC.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchC.dispose();
    super.dispose();
  }

  // ===== بناء URI الطلب باستخدام kBaseUrl من الملف الخارجي =====
  Uri _productsUri() {
    final qp = <String, String>{'limit': '200'};
    if (_categoryId != null && _categoryId! > 0) {
      qp['category_id'] = '$_categoryId';
    }
    final q = _searchC.text.trim();
    if (q.isNotEmpty) qp['q'] = q;

    // الربط مع kBaseUrl
    return Uri.parse('$kServerIp/get_products.php')
        .replace(queryParameters: qp);
  }

  // ===== جلب المنتجات =====
  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http
          .get(_productsUri(), headers: const {'Accept': 'application/json'});
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

      final parsed = json.decode(res.body);
      if (parsed is! Map ||
          (parsed['status'] != 'success' && parsed['success'] != true)) {
        throw Exception(parsed is Map
            ? (parsed['message'] ?? 'فشل تحميل البيانات')
            : 'استجابة غير متوقعة');
      }

      final List list = parsed['products'] ?? [];
      _products = list.cast<Map<String, dynamic>>();
      _applyFilter();
    } catch (e) {
      _error = e.toString();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ===== فلترة محلية بالبحث =====
  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _applyFilter);
  }

  void _applyFilter() {
    final q = _searchC.text.toLowerCase().trim();
    setState(() {
      if (q.isEmpty) {
        _filtered = List<Map<String, dynamic>>.from(_products);
      } else {
        _filtered = _products
            .where(
                (p) => (p['name'] ?? '').toString().toLowerCase().contains(q))
            .toList();
      }
    });
  }

  num _num(dynamic v) => v is num ? v : num.tryParse(v?.toString() ?? '') ?? 0;

  void _addToCart(Map<String, dynamic> p) {
    Cart.addProduct(p);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تمت إضافة ${p['name']} إلى السلة'),
        action: SnackBarAction(
          label: 'عرض السلة',
          onPressed: () async {
            await Navigator.push(
                context, MaterialPageRoute(builder: (_) => const CartScreen()));
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = (_categoryName?.isNotEmpty ?? false)
        ? 'منتجات: ${_categoryName!}'
        : 'كافة المنتجات';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFFE9B270),
          title: Text(title),
          actions: [
            IconButton(onPressed: _fetch, icon: const Icon(Icons.refresh)),
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined),
                  onPressed: () async {
                    await Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const CartScreen()));
                    if (mounted) setState(() {});
                  },
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: ValueListenableBuilder<int>(
                    valueListenable: Cart.count,
                    builder: (_, cnt, __) {
                      if (cnt <= 0) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12)),
                        child: Text('$cnt',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _fetch,
                            icon: const Icon(Icons.refresh),
                            label: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetch,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: TextField(
                            controller: _searchC,
                            decoration: InputDecoration(
                              hintText: 'ابحث عن منتج...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        Expanded(
                          child: _filtered.isEmpty
                              ? const Center(child: Text('لا توجد منتجات'))
                              : GridView.builder(
                                  padding: const EdgeInsets.all(10),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 3 / 5,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                  ),
                                  itemCount: _filtered.length,
                                  itemBuilder: (_, i) {
                                    final p = _filtered[i];
                                    final img = fixImageUrl(p['image_url']);
                                    final price =
                                        _num(p['price_retail'] ?? p['price']);
                                    final heroTag =
                                        'p_${p['product_id'] ?? p['id'] ?? i}';

                                    return Card(
                                      elevation: 3,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ProductDetailsScreen(
                                                      product: p,
                                                      heroTag: heroTag),
                                            ),
                                          );
                                        },
                                        child: Column(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                      top: Radius.circular(12)),
                                              child: AspectRatio(
                                                aspectRatio: 1,
                                                child: Hero(
                                                  tag: heroTag,
                                                  child: Image.network(
                                                    img.isEmpty
                                                        ? 'about:blank'
                                                        : '$img?t=1',
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __,
                                                            ___) =>
                                                        const Icon(
                                                            Icons.broken_image,
                                                            size: 50),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 6),
                                              child: Column(
                                                children: [
                                                  Text(
                                                    (p['name'] ?? '')
                                                        .toString(),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '$price ريال',
                                                    style: const TextStyle(
                                                        color: Colors.green,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  SizedBox(
                                                    width: double.infinity,
                                                    child: ElevatedButton.icon(
                                                      icon: const Icon(Icons
                                                          .add_shopping_cart),
                                                      label: const Text(
                                                          'أضف إلى السلة'),
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            Colors.green,
                                                        foregroundColor:
                                                            Colors.white,
                                                        minimumSize: const Size
                                                            .fromHeight(40),
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(10),
                                                        ),
                                                      ),
                                                      onPressed: () =>
                                                          _addToCart(p),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
