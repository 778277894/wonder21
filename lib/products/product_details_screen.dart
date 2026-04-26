// lib/products/product_details_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// 1. استيراد ملف الإعدادات الموحد
import '../admin/server_config.dart'; // يحتوي kServerIp = "http://192.168.0.16" مثلاً

import '../carts/cart.dart';
import '../carts/cart_screen.dart';

/// دالة إصلاح الروابط (تستخدم الآن kServerIp و kBaseUrl من الملف الخارجي)
String fixImageUrl(dynamic raw) {
  String v = (raw ?? '').toString().trim().replaceAll('\\', '/');
  if (v.isEmpty) return '';
  if (v.startsWith('http://') || v.startsWith('https://'))
    return Uri.encodeFull(v);

  // الربط مع kServerIp لضمان جلب الصورة من المسار الصحيح
  if (v.startsWith('/')) return Uri.encodeFull("$kServerIp$v");
  if (v.startsWith('uploads/')) return Uri.encodeFull("$kServerIp/$v");
  return Uri.encodeFull("$kServerIp/uploads/$v");
}

class ProductDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  final String? heroTag;

  const ProductDetailsScreen({super.key, required this.product, this.heroTag});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int qty = 1;
  List<String> allImages = [];
  bool loadingImages = true;

  @override
  void initState() {
    super.initState();
    _loadProductGallery();
  }

  // جلب الصور الإضافية باستخدام kBaseUrl
  Future<void> _loadProductGallery() async {
    final pid = widget.product['product_id'] ?? widget.product['id'];

    // إضافة الصورة الرئيسية أولاً
    final mainImg = fixImageUrl(widget.product['image_url']);
    if (mainImg.isNotEmpty) allImages.add(mainImg);

    try {
      // استخدام kBaseUrl للطلب من السيرفر
      final res = await http
          .get(Uri.parse("$kServerIp/get_product_images.php?product_id=$pid"));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success') {
          final List extras = data['images'] ?? [];
          for (var item in extras) {
            final url = fixImageUrl(item['image_url']);
            if (url.isNotEmpty && !allImages.contains(url)) {
              allImages.add(url);
            }
          }
        }
      }
    } catch (e) {
      debugPrint("خطأ في جلب صور المعرض: $e");
    } finally {
      if (allImages.isEmpty) allImages.add('');
      setState(() => loadingImages = false);
    }
  }

  num _num(dynamic v) => v is num ? v : num.tryParse(v?.toString() ?? '') ?? 0;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final name = (p['name'] ?? '').toString();
    final desc = (p['description'] ?? '').toString();
    final price = _num(p['price_retail'] ?? p['price']);
    final stock = (p['stock'] ?? '').toString();
    final category = (p['category_name'] ?? p['category'] ?? '').toString();
    final tag = widget.heroTag ?? 'p_${p['product_id'] ?? p['id']}';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(name, overflow: TextOverflow.ellipsis),
          backgroundColor: Colors.green,
          actions: [_buildCartBadge()],
        ),
        body: loadingImages
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  ProductGallery(images: allImages, heroTag: tag),
                  const SizedBox(height: 16),
                  Text(name,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('$price ريال',
                          style: const TextStyle(
                              fontSize: 20,
                              color: Color.fromARGB(255, 239, 177, 6),
                              fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (stock.isNotEmpty)
                        Badge(
                            label: Text('المتوفر: $stock'),
                            backgroundColor: Colors.orange),
                    ],
                  ),
                  if (category.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Chip(
                      avatar: const Icon(Icons.category,
                          size: 16, color: Colors.white),
                      label: Text('الفئة: $category',
                          style: const TextStyle(color: Colors.white)),
                      backgroundColor: const Color.fromARGB(255, 217, 168, 5),
                    ),
                  ],
                  const Divider(height: 30),
                  if (desc.isNotEmpty) ...[
                    const Text('وصف المنتج',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(desc,
                        style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade800,
                            height: 1.5)),
                  ],
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_shopping_cart, size: 24),
                    label: const Text('أضف إلى السلة',
                        style: TextStyle(fontSize: 18)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 222, 175, 5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: () {
                      Cart.addProduct(p);
                      _showSuccessSnack(context);
                    },
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCartBadge() {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.shopping_cart),
          onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const CartScreen())),
        ),
        if (Cart.items.isNotEmpty)
          Positioned(
            right: 6,
            top: 6,
            child: CircleAvatar(
              radius: 9,
              backgroundColor: Colors.red,
              child: Text('${Cart.items.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 11)),
            ),
          ),
      ],
    );
  }

  void _showSuccessSnack(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('تمت إضافة المنتج للسلة'),
        action: SnackBarAction(
            label: 'فتح السلة',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CartScreen()))),
      ),
    );
  }
}

// ===== ويدجت المعرض (تعرض الصور المربوطة بالسيرفر الجديد) =====
class ProductGallery extends StatefulWidget {
  final List<String> images;
  final String? heroTag;

  const ProductGallery({super.key, required this.images, this.heroTag});

  @override
  State<ProductGallery> createState() => _ProductGalleryState();
}

class _ProductGalleryState extends State<ProductGallery> {
  late final PageController _ctrl;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imgs = widget.images;
    final hasAny = imgs.isNotEmpty && imgs.first.isNotEmpty;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2)
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 1.2,
              child: hasAny
                  ? PageView.builder(
                      controller: _ctrl,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemCount: imgs.length,
                      itemBuilder: (_, i) {
                        final imgWidget = Image.network(
                          imgs[i],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.broken_image, size: 80),
                        );
                        if (i == 0 && widget.heroTag != null) {
                          return InteractiveViewer(
                              child:
                                  Hero(tag: widget.heroTag!, child: imgWidget));
                        }
                        return InteractiveViewer(child: imgWidget);
                      },
                    )
                  : const Center(
                      child: Icon(Icons.image_not_supported,
                          size: 80, color: Colors.grey)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (hasAny && imgs.length > 1)
          SizedBox(
            height: 65,
            child: Center(
              child: ListView.separated(
                shrinkWrap: true,
                scrollDirection: Axis.horizontal,
                itemCount: imgs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final isSel = i == _index;
                  return GestureDetector(
                    onTap: () => _ctrl.animateToPage(i,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 65,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: isSel ? Colors.green : Colors.transparent,
                            width: 2.5),
                        image: DecorationImage(
                            image: NetworkImage(imgs[i]), fit: BoxFit.cover),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
