// lib/admin/admin_products_management.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

// 1. استيراد المسار الموحد
import './server_config.dart';

class AdminProductsManagement extends StatefulWidget {
  const AdminProductsManagement({super.key});

  @override
  State<AdminProductsManagement> createState() =>
      _AdminProductsManagementState();
}

class _AdminProductsManagementState extends State<AdminProductsManagement> {
  // تم إزالة serverIp و baseUrl و uploadsBase المحلية
  // الاعتماد الآن كلياً على القيم القادمة من server_config.dart

  // ===== أدوات الصور =====
  XFile? selectedImage;
  List<XFile> selectedExtraImages = [];
  List<Map<String, dynamic>> existingExtraImages = [];

  // ===== بيانات المنتجات والفئات =====
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> filteredProducts = [];
  bool isLoading = false;
  String errorMessage = "";
  List<Map<String, dynamic>> categories = [];
  int? selectedCategoryIdForFilter;

  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bootstrap();
    searchController.addListener(_filterProducts);
  }

  Future<void> _bootstrap() async {
    await fetchCategories();
    await fetchProducts();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ===== أدوات مساعدة للروابط (تستخدم الآن baseUrl الموحد) =====
  String fixImageUrl(dynamic raw) {
    String v = (raw ?? '').toString().trim().replaceAll('\\', '/');
    if (v.isEmpty) return '';
    if (v.startsWith('http://') || v.startsWith('https://'))
      return Uri.encodeFull(v);

    // استخدام baseUrl من ملف الإعدادات
    if (v.startsWith('/')) return Uri.encodeFull("$kServerIp$v");
    if (v.startsWith('uploads/')) return Uri.encodeFull("$kServerIp/$v");
    return Uri.encodeFull("$kServerIp/uploads/$v");
  }

  int _pidOf(Map<String, dynamic>? p) =>
      p == null ? 0 : int.tryParse('${p['product_id'] ?? p['id'] ?? ''}') ?? 0;
  String _pidText(Map<String, dynamic>? p) =>
      p == null ? '' : '${p['product_id'] ?? p['id'] ?? ''}';

  // ===== جلب البيانات من السيرفر =====
  Future<void> fetchCategories() async {
    try {
      // استخدام baseUrl الموحد
      final res = await http.get(Uri.parse("$kServerIp/get_categories.php"));
      if (res.statusCode == 200) {
        final List list =
            jsonDecode(res.body); // الكود القديم كان يتوقع قائمة مباشرة
        setState(() {
          categories = list
              .map<Map<String, dynamic>>((e) => {
                    'id': int.tryParse('${e['category_id'] ?? 0}') ?? 0,
                    'name': '${e['category_name'] ?? ''}',
                  })
              .where((c) => c['id'] != 0 && (c['name'] as String).isNotEmpty)
              .toList();
        });
      }
    } catch (e) {
      debugPrint("خطأ جلب الفئات: $e");
    }
  }

  Future<void> fetchProducts() async {
    setState(() {
      isLoading = true;
      errorMessage = "";
    });
    try {
      // استخدام baseUrl الموحد
      final res = await http.get(Uri.parse("$kServerIp/get_products.php"));
      if (res.statusCode != 200) throw Exception("HTTP ${res.statusCode}");
      final data = jsonDecode(res.body);
      if (data["status"] == "success" || data["success"] == true) {
        products = (data["products"] ?? []).cast<Map<String, dynamic>>();
        filteredProducts = products;
      } else {
        errorMessage = data["message"]?.toString() ?? "فشل التحميل";
      }
    } catch (e) {
      errorMessage = "خطأ: $e";
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _filterProducts() {
    final q = searchController.text.toLowerCase().trim();
    setState(() {
      filteredProducts = products.where((p) {
        final id = (p['product_id'] ?? p['id'] ?? '').toString().toLowerCase();
        final name = (p['name'] ?? '').toString().toLowerCase();
        final matchesSearch = q.isEmpty || id.contains(q) || name.contains(q);
        final catIdOfRow = int.tryParse('${p['category_id'] ?? 0}');
        final matchesCat = selectedCategoryIdForFilter == null ||
            (catIdOfRow == selectedCategoryIdForFilter);
        return matchesSearch && matchesCat;
      }).toList();
    });
  }

  // ===== وظيفة الرفع =====
  Future<void> uploadProduct(Map<String, String> fields, {int? id}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) =>
          const Center(child: CircularProgressIndicator(color: Colors.green)),
    );

    try {
      final formData = FormData.fromMap(fields);

      if (id != null && id > 0) {
        formData.fields.add(MapEntry("product_id", id.toString()));
        formData.fields.add(MapEntry("id", id.toString()));
      }

      if (selectedImage != null) {
        formData.files
            .add(MapEntry("image", await _prepareFile(selectedImage!)));
      }

      if (selectedExtraImages.isNotEmpty) {
        for (final file in selectedExtraImages) {
          formData.files.add(MapEntry("images[]", await _prepareFile(file)));
        }
      }

      // استخدام baseUrl من server_config
      final dio = Dio(BaseOptions(
        baseUrl: kServerIp,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
      ));

      final endpoint =
          (id != null && id > 0) ? "/update_product.php" : "/add_product.php";

      final response = await dio.post(endpoint, data: formData);

      Navigator.pop(context);

      final data =
          response.data is Map ? response.data : jsonDecode(response.data);

      if (!mounted) return;

      if (data["status"] == "success" || data["success"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data["message"] ?? "تمت العملية بنجاح")));

        setState(() {
          selectedImage = null;
          selectedExtraImages.clear();
        });
        await fetchProducts();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data["message"] ?? "فشل الحفظ")));
      }
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      _showSnack("حدث خطأ أثناء الرفع: $e");
    }
  }

  Future<MultipartFile> _prepareFile(XFile file) async {
    if (kIsWeb)
      return MultipartFile.fromBytes(await file.readAsBytes(),
          filename: file.name);
    return await MultipartFile.fromFile(file.path, filename: file.name);
  }

  // ===== إدارة صور السيرفر =====
  Future<void> _loadExtraImages(int pid, Function setStateDialog) async {
    try {
      final r = await http
          .get(Uri.parse('$kServerIp/get_product_images.php?product_id=$pid'));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body);
        if (j['status'] == 'success') {
          setStateDialog(() => existingExtraImages =
              List<Map<String, dynamic>>.from(j['images']));
        }
      }
    } catch (_) {}
  }

  Future<void> _deleteImageFromServer(
      int imgId, Function setStateDialog) async {
    try {
      final r = await http.post(
          Uri.parse('$kServerIp/delete_product_image.php'),
          body: {'image_id': '$imgId'});
      if (jsonDecode(r.body)['status'] == 'success') {
        setStateDialog(() =>
            existingExtraImages.removeWhere((e) => e['image_id'] == imgId));
        _showSnack("تم حذف الصورة من السيرفر");
      }
    } catch (_) {}
  }

  // ===== نافذة الحوار الموحدة (محتوى طويل حافظت عليه كاملاً) =====
  void showProductDialog({Map<String, dynamic>? product}) {
    final pid = _pidOf(product);
    final idC = TextEditingController(text: _pidText(product));
    final nameC = TextEditingController(text: product?["name"] ?? "");
    final descC = TextEditingController(text: product?["description"] ?? "");
    final stockC =
        TextEditingController(text: product?["stock"]?.toString() ?? "");
    final retailC = TextEditingController(
        text: (product?["price_retail"] ?? "").toString());
    final wholesaleC = TextEditingController(
        text: (product?["price_wholesale"] ?? "").toString());
    final bulkC = TextEditingController(
        text: (product?["price_bulk_wholesale"] ?? "").toString());
    final purchaseC = TextEditingController(
        text: (product?["purchase_price"] ?? "").toString());
    final lengthC =
        TextEditingController(text: (product?["length"] ?? "").toString());
    final widthC =
        TextEditingController(text: (product?["width"] ?? "").toString());
    final heightC =
        TextEditingController(text: (product?["height"] ?? "").toString());
    final depthC =
        TextEditingController(text: (product?["depth"] ?? "").toString());
    final thicknessC =
        TextEditingController(text: (product?["thickness"] ?? "").toString());
    final flexibilityC =
        TextEditingController(text: (product?["flexibility"] ?? "").toString());
    final barcodeC =
        TextEditingController(text: (product?["barcode"] ?? "").toString());

    int? categoryId = int.tryParse('${product?["category_id"]}');

    selectedImage = null;
    selectedExtraImages = [];
    existingExtraImages = [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          if (pid > 0 && existingExtraImages.isEmpty)
            _loadExtraImages(pid, setStateDialog);

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text(
                  product == null ? "إضافة صنف جديد" : "تعديل بيانات الصنف"),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: _field(idC, "رقم المنتج", Icons.tag,
                                  isNum: true)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _field(
                                  nameC, "اسم المنتج", Icons.shopping_bag)),
                        ],
                      ),
                      DropdownButtonFormField<int?>(
                        value: (categoryId == 0) ? null : categoryId,
                        decoration: const InputDecoration(
                            labelText: "الفئة",
                            prefixIcon: Icon(Icons.category)),
                        items: categories
                            .map((c) => DropdownMenuItem<int?>(
                                value: c['id'] as int, child: Text(c['name'])))
                            .toList(),
                        onChanged: (v) => setStateDialog(() => categoryId = v),
                      ),
                      _field(descC, "الوصف", Icons.description, lines: 2),
                      const Divider(),
                      Wrap(
                        spacing: 8,
                        children: [
                          _smallField(lengthC, "الطول"),
                          _smallField(widthC, "العرض"),
                          _smallField(heightC, "الارتفاع"),
                          _smallField(depthC, "العمق"),
                          _smallField(thicknessC, "السماكة"),
                          _smallField(flexibilityC, "الليونة", isNum: false),
                        ],
                      ),
                      const Divider(),
                      Wrap(
                        spacing: 8,
                        children: [
                          _smallField(retailC, "تجزئة"),
                          _smallField(wholesaleC, "جملة"),
                          _smallField(bulkC, "جملة الجملة"),
                          _smallField(purchaseC, "شراء"),
                          _smallField(stockC, "الكمية"),
                          _smallField(barcodeC, "الباركود", isNum: false),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          _imgBtn("الصورة الرئيسية", Icons.image, () async {
                            final img = await ImagePicker().pickImage(
                                source: ImageSource.gallery, imageQuality: 50);
                            if (img != null)
                              setStateDialog(() => selectedImage = img);
                          }),
                          const SizedBox(width: 8),
                          _imgBtn("صور إضافية", Icons.collections, () async {
                            final imgs = await ImagePicker()
                                .pickMultiImage(imageQuality: 40);
                            if (imgs.isNotEmpty)
                              setStateDialog(
                                  () => selectedExtraImages.addAll(imgs));
                          }),
                        ],
                      ),
                      if (selectedImage != null)
                        _preview(selectedImage!,
                            () => setStateDialog(() => selectedImage = null)),
                      if (selectedExtraImages.isNotEmpty) ...[
                        const Divider(),
                        SizedBox(
                          height: 90,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: selectedExtraImages.length,
                            itemBuilder: (c, i) => _previewTile(
                                selectedExtraImages[i],
                                () => setStateDialog(
                                    () => selectedExtraImages.removeAt(i))),
                          ),
                        ),
                      ],
                      if (existingExtraImages.isNotEmpty) ...[
                        const Divider(),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: existingExtraImages
                              .map((img) => Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                            fixImageUrl(img['image_url']),
                                            width: 65,
                                            height: 65,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error,
                                                    stackTrace) =>
                                                const Icon(Icons.broken_image,
                                                    size: 40)),
                                      ),
                                      Positioned(
                                          right: 0,
                                          child: InkWell(
                                              onTap: () =>
                                                  _deleteImageFromServer(
                                                      img['image_id'],
                                                      setStateDialog),
                                              child: const CircleAvatar(
                                                  radius: 12,
                                                  backgroundColor: Colors.red,
                                                  child: Icon(Icons.delete,
                                                      size: 14,
                                                      color: Colors.white)))),
                                    ],
                                  ))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("إلغاء")),
                ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () {
                    if (nameC.text.isEmpty || categoryId == null) {
                      _showSnack("يرجى إدخال اسم المنتج والفئة");
                      return;
                    }
                    uploadProduct({
                      "product_id": idC.text,
                      "name": nameC.text,
                      "description": descC.text,
                      "category_id": categoryId.toString(),
                      "stock": stockC.text,
                      "price_retail": retailC.text,
                      "price_wholesale": wholesaleC.text,
                      "price_bulk_wholesale": bulkC.text,
                      "purchase_price": purchaseC.text,
                      "length": lengthC.text,
                      "width": widthC.text,
                      "height": heightC.text,
                      "depth": depthC.text,
                      "thickness": thicknessC.text,
                      "flexibility": flexibilityC.text,
                      "barcode": barcodeC.text,
                    }, id: product != null ? pid : null);
                    Navigator.pop(ctx);
                  },
                  child: const Text("حفظ التغييرات",
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ===== بناء الواجهة الرئيسية =====
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
            title: const Text("روائع اليمن - إدارة المنتجات"),
            backgroundColor: const Color.fromARGB(255, 218, 126, 6),
            actions: [
              IconButton(
                  onPressed: fetchProducts, icon: const Icon(Icons.refresh))
            ]),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                              hintText: "بحث بالاسم أو الرقم...",
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12))))),
                  const SizedBox(width: 8),
                  _catFilter(),
                ],
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: filteredProducts.length,
                      itemBuilder: (c, i) {
                        final p = filteredProducts[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          child: ListTile(
                            leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                    fixImageUrl(p['image_url']),
                                    width: 55,
                                    height: 55,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) =>
                                        const Icon(Icons.image))),
                            title: Text(p['name'] ?? ""),
                            subtitle: Text(
                                "رقم: ${_pidText(p)} - السعر: ${p['price_retail']} ريال"),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue),
                                    onPressed: () =>
                                        showProductDialog(product: p)),
                                IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () => _confirmDelete(p)),
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
            onPressed: () => showProductDialog(),
            backgroundColor: const Color.fromARGB(255, 175, 119, 76),
            child: const Icon(Icons.add, color: Color.fromARGB(255, 26, 3, 3))),
      ),
    );
  }

  // ===== أدوات الـ UI المساعدة =====
  Widget _field(TextEditingController c, String l, IconData i,
          {bool isNum = false, int lines = 1}) =>
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: TextField(
              controller: c,
              maxLines: lines,
              keyboardType: isNum ? TextInputType.number : TextInputType.text,
              decoration: InputDecoration(
                  labelText: l,
                  prefixIcon: Icon(i),
                  border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10))))));

  Widget _smallField(TextEditingController c, String l, {bool isNum = true}) =>
      SizedBox(
          width: 100,
          child: TextField(
              controller: c,
              keyboardType: isNum ? TextInputType.number : TextInputType.text,
              decoration: InputDecoration(labelText: l)));

  Widget _imgBtn(String l, IconData i, VoidCallback t) => Expanded(
      child: OutlinedButton.icon(
          onPressed: t,
          icon: Icon(i),
          label: Text(l, style: const TextStyle(fontSize: 12))));

  Widget _preview(XFile file, VoidCallback r) => Stack(children: [
        Container(
            margin: const EdgeInsets.only(top: 10),
            height: 110,
            width: double.infinity,
            child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _renderFile(file))),
        Positioned(
            right: 5,
            top: 15,
            child: CircleAvatar(
                radius: 15,
                backgroundColor: Colors.red,
                child: IconButton(
                    onPressed: r,
                    icon: const Icon(Icons.close,
                        size: 15, color: Colors.white))))
      ]);

  Widget _previewTile(XFile file, VoidCallback r) => Padding(
      padding: const EdgeInsets.all(4),
      child: Stack(children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(width: 85, height: 85, child: _renderFile(file))),
        Positioned(
            right: 0,
            child: InkWell(
                onTap: r,
                child: const CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.red,
                    child: Icon(Icons.close, size: 12, color: Colors.white))))
      ]));

  Widget _renderFile(XFile file) => kIsWeb
      ? Image.network(file.path, fit: BoxFit.cover)
      : Image.file(File(file.path), fit: BoxFit.cover);

  Widget _catFilter() => SizedBox(
      width: 150,
      child: DropdownButtonFormField<int?>(
          isDense: true,
          value: selectedCategoryIdForFilter,
          decoration: const InputDecoration(
              labelText: "الفئة", border: OutlineInputBorder()),
          items: [
            const DropdownMenuItem(value: null, child: Text("الكل")),
            ...categories.map((c) =>
                DropdownMenuItem(value: c['id'] as int, child: Text(c['name'])))
          ],
          onChanged: (v) {
            selectedCategoryIdForFilter = v;
            _filterProducts();
          }));

  void _confirmDelete(Map<String, dynamic> p) async {
    final ok = await showDialog(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text("تأكيد الحذف"),
                content: Text("هل تريد حذف الصنف ${p['name']} نهائياً؟"),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text("إلغاء")),
                  TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text("حذف",
                          style: TextStyle(color: Colors.red)))
                ]));
    if (ok == true) {
      final r = await http.post(Uri.parse("$kServerIp/delete_product.php"),
          body: {"product_id": "${p['product_id'] ?? p['id']}"});
      if (jsonDecode(r.body)['status'] == 'success') fetchProducts();
    }
  }

  void _showSnack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}
